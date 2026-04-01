import Foundation
import AVFoundation

class VideoDecoderPool {
    private var players: [AVPlayer?] = Array(repeating: nil, count: 9)
    private var videoOutputs: [AVPlayerItemVideoOutput?] = Array(repeating: nil, count: 9)
    private var loopObservers: [NSObjectProtocol?] = Array(repeating: nil, count: 9)
    private var statusObservers: [NSKeyValueObservation?] = Array(repeating: nil, count: 9)

    private var currentSlotUrls: [String?] = Array(repeating: nil, count: 9)
    private var currentSessionId: String = ""
    private weak var renderer: HardcoreRenderer?

    init(renderer: HardcoreRenderer) {
        self.renderer = renderer
        print("🍏 [DecoderPool] iOS 9路【极致资源均摊版】已就绪！")
    }

    func playStreams(urls: [String]) {
        renderer?.updateStreamCount(urls.count)
        let sessionId = UUID().uuidString
        self.currentSessionId = sessionId

        for i in 0..<9 {
            let targetUrl: String? = (i < urls.count && urls[i].hasPrefix("http")) ? urls[i] : nil
            if self.currentSlotUrls[i] == targetUrl { continue }

            cleanUp(index: i)
            self.currentSlotUrls[i] = targetUrl

            guard let urlString = targetUrl, let url = URL(string: urlString) else { continue }

            // 🚀 均摊大招 1：错峰起跑！
            // 每个视频延后 0.3 秒加载，彻底避开 TCP 并发连接的“交通堵塞”
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.3) { [weak self] in
                guard let self = self, self.currentSessionId == sessionId else { return }

                let playerItem = AVPlayerItem(url: url)

                // 🚀 终极压榨 1：强制极低分辨率！
                // 把九宫格每一个小格子的分辨率锁死在 320x320 甚至更低。
                // 这样即使后 4 个视频被迫使用 CPU 软解，CPU 也完全扛得住！
                playerItem.preferredMaximumResolution = CGSize(width: 320, height: 320)

                // 🚀 终极压榨 2：限制极限峰值码率 (如果是 m3u8 HLS 流)
                // 告诉服务器，我只要最差的画质，把带宽降到 400kbps 以下！
                playerItem.preferredPeakBitRate = 400_000

                if #available(iOS 10.0, *) {
                    // 只准囤 0.2 秒的粮，多一点都不准下！
                    playerItem.preferredForwardBufferDuration = 0.2
                    playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = false
                }

                let videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                    kCVPixelBufferMetalCompatibilityKey as String: true,
                    kCVPixelBufferIOSurfacePropertiesKey as String: [:]
                ])
                playerItem.add(videoOutput)

                let player = AVPlayer(playerItem: playerItem)

                player.volume = 1.0
                player.isMuted = (i != 0)
                player.actionAtItemEnd = .none

                // 🚀🚀🚀 终极压榨 3：关闭“防卡顿等待”！(极其关键)
                // 默认是 true（一旦解码慢了，视频就停下等）。
                // 改成 false 后，视频引擎会“宁可丢掉来不及解的画面，也要继续往下播”！
                // 这能极大程度掩盖 CPU 软解跟不上带来的“严重停顿感”。
                player.automaticallyWaitsToMinimizeStalling = false

                self.videoOutputs[i] = videoOutput
                self.renderer?.setVideoOutput(videoOutput, at: i)

                let observer = playerItem.observe(\.status, options: [.new]) { [weak player] item, _ in
                    if item.status == .readyToPlay {
                        DispatchQueue.main.async {
                            player?.play()
                        }
                    }
                }

                let endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: .main) { [weak player] _ in
                    player?.seek(to: .zero)
                    player?.play()
                }

                self.players[i] = player
                self.statusObservers[i] = observer
                self.loopObservers[i] = endObserver
            }
        }
    }

    // --- 👇 下面保留了你要求的音频控制接口 👇 ---

    func setMute(at index: Int, isMuted: Bool) {
        guard index >= 0 && index < 9 else { return }
        players[index]?.isMuted = isMuted
        print("🔊 [AudioControl] 坑位 \(index) 静音状态切换为: \(isMuted)")
    }

    func setVolume(at index: Int, volume: Float) {
        guard index >= 0 && index < 9 else { return }
        players[index]?.volume = volume
        print("🔊 [AudioControl] 坑位 \(index) 音量调整为: \(volume)")
    }

    private func cleanUp(index i: Int) {
        statusObservers[i]?.invalidate()
        statusObservers[i] = nil
        if let oldObserver = loopObservers[i] { NotificationCenter.default.removeObserver(oldObserver) }
        loopObservers[i] = nil
        players[i]?.pause()
        players[i] = nil
        videoOutputs[i] = nil
        renderer?.setVideoOutput(nil, at: i)
    }

    func release() {
        self.currentSessionId = ""
        for i in 0..<9 {
            cleanUp(index: i)
            self.currentSlotUrls[i] = nil
        }
    }
}