import Flutter
import UIKit
import AVFoundation

class WeakTargetProxy {
    weak var target: NativeAlphaPlayerView?
    init(target: NativeAlphaPlayerView) { self.target = target }
    @objc func onTick(_ sender: CADisplayLink) { target?.displayLinkCallback(sender: sender) }
}

class NativeAlphaPlayerView: NSObject, FlutterPlatformView {
    private var _view: UIView
    private var metalView: LHVideoGiftAlphaVideoMetalView?

    private var player: AVPlayer?
    private var videoOutput: AVPlayerItemVideoOutput?
    private var displayLink: CADisplayLink?
    private let channel: FlutterMethodChannel

    private var isFinishedSent = false
    private var drawCount: Int = 0
    private var isPlayingActive = false

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger
    ) {
        self._view = UIView(frame: frame)
        self._view.backgroundColor = .clear

        let channelName = "com.example.live/alpha_player_\(viewId)"
        self.channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
        super.init()

        let mv = LHVideoGiftAlphaVideoMetalView(frame: frame)
        mv.contentMode = .scaleAspectFit
        mv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mv.isHidden = true
        self._view.addSubview(mv)
        self.metalView = mv

        self.channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }

        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers, .defaultToSpeaker])
        try? AVAudioSession.sharedInstance().setActive(true)

        if let params = args as? [String: Any], let url = params["url"] as? String {
            playVideo(url: url)
        }
    }

    deinit {
        stopPlayback_Custom()
        self.channel.setMethodCallHandler(nil)
    }

    func view() -> UIView { return _view }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "play" {
            if let args = call.arguments as? [String: Any], let path = args["url"] as? String {
                playVideo(url: path)
            }
            result(nil)
        } else if call.method == "stop" {
            stopPlayback_Custom()
            result(nil)
        } else {
            result(FlutterMethodNotImplemented)
        }
    }

    private func playVideo(url: String) {
        stopPlayback_Custom()
        self.isFinishedSent = false
        self.drawCount = 0
        self.isPlayingActive = true

        guard let targetURL = url.hasPrefix("http") ? URL(string: url) : URL(fileURLWithPath: url) else {
            notifyPlayFinished()
            return
        }

        let playerItem = AVPlayerItem(url: targetURL)

        // 🟢 优化 1：缓冲区预加载优化
        // 允许系统多缓冲一点数据，防止两个视频同时读取磁盘导致的 I/O 瞬间掉速
        playerItem.preferredForwardBufferDuration = 1.0

        self.player = AVPlayer(playerItem: playerItem)

        // 🔴 注意：保持 automaticallyWaitsToMinimizeStalling 为默认值 true
        // 这样在双路解码压力过大时，系统会自动进行微小的缓冲等待，而不是直接彻底抛弃播放导致死锁卡住。

        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: attributes)
        output.suppressesPlayerRendering = true
        playerItem.add(output)
        self.videoOutput = output

        NotificationCenter.default.addObserver(self, selector: #selector(playerItemFailed), name: .AVPlayerItemFailedToPlayToEndTime, object: playerItem)
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidFinish), name: .AVPlayerItemDidPlayToEndTime, object: playerItem)

        self.displayLink = CADisplayLink(target: WeakTargetProxy(target: self), selector: #selector(WeakTargetProxy.onTick(_:)))

        // 🟢 优化 2：下达 GPU 限速令（强制最高 60 帧）
        // 如果不限制，在 120Hz 屏幕上两个视频会疯狂抽取 240 次/秒，直接撑爆内存带宽和解码器，导致瞬间冻结。
        if #available(iOS 15.0, *) {
            self.displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        } else {
            self.displayLink?.preferredFramesPerSecond = 60
        }

        self.displayLink?.add(to: .main, forMode: .common)

        self.player?.play()
    }

    @objc func displayLinkCallback(sender: CADisplayLink) {
        guard self.isPlayingActive, let output = self.videoOutput else { return }

        let nextVSync = sender.timestamp + sender.duration
        let itemTime = output.itemTime(forHostTime: nextVSync)

        if output.hasNewPixelBuffer(forItemTime: itemTime) {
            if let pixelBuffer = output.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil) {
                self.drawCount += 1
                if self.drawCount <= 2 { return }

                self.metalView?.renderPixelBuffer(pixelBuffer)

                if self.metalView?.isHidden == true {
                    self.metalView?.isHidden = false
                }
            }
        }

        // 🟢 优化 3：起搏器机制 与 结尾兜底
        if let p = self.player, let item = p.currentItem, item.status == .readyToPlay {
            let duration = item.duration
            let current = item.currentTime()

            if duration.isNumeric && current.isNumeric {
                let durationSec = CMTimeGetSeconds(duration)
                let currentSec = CMTimeGetSeconds(current)

                // 【起搏器核心】
                // 哪怕底层因为极度争抢资源把 Player 暂停了 (rate == 0 / .paused)
                // 只要还没播完，强行拉起让它继续给我播！绝不允许停在半路！
                if p.timeControlStatus == .paused && currentSec < (durationSec - 0.2) {
                    p.play()
                }

                // 【结尾兜底释放机制】
                // 防止视频因为尾帧时长异常，导致系统永远不发通知卡在最后一张图。
                if durationSec > 0 && currentSec >= (durationSec - 0.05) {
                    self.playerDidFinish()
                }
            }
        }
    }

    @objc private func playerDidFinish() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isPlayingActive else { return }
            self.stopPlayback_Custom()
            self.notifyPlayFinished()
        }
    }

    @objc private func playerItemFailed() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isPlayingActive else { return }
            self.stopPlayback_Custom()
            self.notifyPlayFinished()
        }
    }

    private func stopPlayback_Custom() {
        self.isPlayingActive = false
        self.player?.pause()

        if let output = self.videoOutput, let item = self.player?.currentItem {
            item.remove(output)
        }

        self.player = nil
        self.videoOutput = nil

        self.displayLink?.invalidate()
        self.displayLink = nil

        NotificationCenter.default.removeObserver(self)

        let targetMetalView = self.metalView
        let clearAction = {
            targetMetalView?.clear()
            targetMetalView?.isHidden = true
        }
        if Thread.isMainThread { clearAction() }
        else { DispatchQueue.main.async { clearAction() } }
    }

    private func notifyPlayFinished() {
        if !isFinishedSent {
            isFinishedSent = true
            DispatchQueue.main.async {
                self.channel.invokeMethod("onPlayFinished", arguments: nil)
            }
        }
    }
}