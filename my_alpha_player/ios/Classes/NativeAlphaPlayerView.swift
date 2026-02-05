import Flutter
import UIKit
import AVFoundation

// 移除 import BDAlphaPlayer，因为我们已经不需要它了

class NativeAlphaPlayerView: NSObject, FlutterPlatformView {
    private var _view: UIView

    // 🟢 我们的新 Metal 视图 (OC 类)
    private var metalView: LHVideoGiftAlphaVideoMetalView?

    // 🟢 播放核心 (系统原生)
    private var player: AVPlayer?
    private var videoOutput: AVPlayerItemVideoOutput?
    private var displayLink: CADisplayLink?

    private let channel: FlutterMethodChannel

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

        // 初始化 Metal 视图
        let mv = LHVideoGiftAlphaVideoMetalView(frame: frame)
        mv.contentMode = .scaleAspectFit // 保持比例
        mv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self._view.addSubview(mv)
        self.metalView = mv

        self.channel.setMethodCallHandler(handle)

        // 激活音频会话 (让声音从扬声器出来)
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers, .defaultToSpeaker])
        try? AVAudioSession.sharedInstance().setActive(true)

        if let params = args as? [String: Any],
           let url = params["url"] as? String {
             playVideo(url: url)
        }
    }

    func view() -> UIView {
        return _view
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "play" {
            if let args = call.arguments as? [String: Any], let path = args["url"] as? String {
                playVideo(url: path)
                result(nil)
            }
        } else if call.method == "stop" {
            stop()
            result(nil)
        } else {
            result(FlutterMethodNotImplemented)
        }
    }

    private func playVideo(url: String) {
        stop() // 先清理旧的
        self.metalView?.alpha = 0
        print("🎬 [NativeAlphaPlayer] 收到播放请求: \(url)")

        var videoURL: URL?
        // 简单判断：如果是 http 开头，当做网络流；否则当做本地文件
        if url.hasPrefix("http") || url.hasPrefix("https") {
            videoURL = URL(string: url)
        } else {
            // ⚠️ 关键修正：本地文件必须用 fileURLWithPath
            videoURL = URL(fileURLWithPath: url)
        }

        guard let targetURL = videoURL else {
            print("❌ [NativeAlphaPlayer] URL转换失败，无法播放")
            return
        }

        print("✅ [NativeAlphaPlayer] 正在加载: \(targetURL.absoluteString)")

        // 1. 创建 PlayerItem
        let playerItem = AVPlayerItem(url: targetURL)

        // 🔍 添加监听：监控是否加载失败
        NotificationCenter.default.addObserver(self, selector: #selector(playerItemFailedToPlayToEndTime(_:)), name: .AVPlayerItemFailedToPlayToEndTime, object: playerItem)

        self.player = AVPlayer(playerItem: playerItem)

        // 2. 配置 Output (偷画面)
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferOpenGLESCompatibilityKey as String: true
        ]
        self.videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: attributes)
        self.videoOutput?.suppressesPlayerRendering = true

        if let output = self.videoOutput {
            playerItem.add(output)
        }

        // 3. 监听播放结束
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidFinish), name: .AVPlayerItemDidPlayToEndTime, object: playerItem)

        // 4. 启动 CADisplayLink (帧循环)
        self.displayLink = CADisplayLink(target: self, selector: #selector(displayLinkCallback))
        self.displayLink?.add(to: .main, forMode: .common)

        // 5. 开播
        self.player?.play()
        print("▶️ [NativeAlphaPlayer] 播放器已启动 (Rate: \(self.player?.rate ?? 0))")
    }

    // 新增：捕获播放报错
    @objc private func playerItemFailedToPlayToEndTime(_ notification: Notification) {
        if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
            print("❌ [NativeAlphaPlayer] 播放失败: \(error.localizedDescription)")
        }
    }

    @objc private func displayLinkCallback(sender: CADisplayLink) {
        guard let output = self.videoOutput, let playerItem = self.player?.currentItem else { return }

        // 计算当前播放器的时间
        let nextVSync = sender.timestamp + sender.duration
        let outputItemTime = output.itemTime(forHostTime: nextVSync)

        // 如果这一秒有画面
        if output.hasNewPixelBuffer(forItemTime: outputItemTime) {
            // 拿到每一帧的原始数据
            if let pixelBuffer = output.copyPixelBuffer(forItemTime: outputItemTime, itemTimeForDisplay: nil) {
                // 喂给 OC 写的 Metal 视图去画
                self.metalView?.display(pixelBuffer)
                // Swift 会自动管理 PixelBuffer 的释放，通常不需要手动 Release，
                // 但如果是 CoreVideo 的 API 返回的 Unmanaged 对象则需要。
                // copyPixelBuffer 返回的是 CVPixelBuffer? (Optional)，ARC 会处理。
                if let alpha = self.metalView?.alpha, alpha < 1.0 {
                    UIView.animate(withDuration: 0.1) {
                        self.metalView?.alpha = 1.0
                    }
                }
            }
        }
    }

    @objc private func playerDidFinish() {
        self.channel.invokeMethod("onPlayFinished", arguments: nil)
        // 可以在这里写循环逻辑：
        // self.player?.seek(to: .zero)
        // self.player?.play()
    }

    private func stop() {
        self.player?.pause()
        self.player = nil

        if let output = self.videoOutput {
            self.player?.currentItem?.remove(output)
        }
        self.videoOutput = nil

        self.displayLink?.invalidate()
        self.displayLink = nil

        NotificationCenter.default.removeObserver(self)

        // 停止时也可以隐藏，双重保险
        self.metalView?.alpha = 0
    }
}