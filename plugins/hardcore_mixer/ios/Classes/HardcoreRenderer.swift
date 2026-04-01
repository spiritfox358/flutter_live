import Flutter
import CoreVideo
import AVFoundation
import CoreGraphics
import VideoToolbox

class HardcoreRenderer: NSObject, FlutterTexture {
    var textureId: Int64 = -1
    private var activeStreamCount: Int = 0
    private var shouldClearCanvas: Bool = true

    private var registry: FlutterTextureRegistry
    private var videoOutputs: [AVPlayerItemVideoOutput?] = Array(repeating: nil, count: 9)

    private let canvasSize = CGSize(width: 1080, height: 1080)
    private var displayLink: CADisplayLink?

    private let stateLock = NSLock()

    // 🚀 零阻塞快递站专属锁
    private let frontBufferLock = NSLock()
    private var frontBuffer: CVPixelBuffer?
    private var isRendering = false

    private let renderQueue = DispatchQueue(label: "com.hardcore.cpuRenderQueue", qos: .userInitiated)
    private let colorSpace = CGColorSpaceCreateDeviceRGB()

    private lazy var canvasBuffer: CVPixelBuffer? = {
        var pb: CVPixelBuffer?
        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        CVPixelBufferCreate(kCFAllocatorDefault, Int(canvasSize.width), Int(canvasSize.height), kCVPixelFormatType_32BGRA, attributes as CFDictionary, &pb)
        return pb
    }()

    private lazy var pixelBufferPool: CVPixelBufferPool? = {
        var pool: CVPixelBufferPool?
        let poolAttributes: [String: Any] = [kCVPixelBufferPoolMinimumBufferCountKey as String: 5]
        let bufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(canvasSize.width),
            kCVPixelBufferHeightKey as String: Int(canvasSize.height),
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        CVPixelBufferPoolCreate(kCFAllocatorDefault, poolAttributes as CFDictionary, bufferAttributes as CFDictionary, &pool)
        return pool
    }()

    init(registry: FlutterTextureRegistry) {
        self.registry = registry
        super.init()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            self.displayLink = CADisplayLink(target: self, selector: #selector(self.renderLoop))
            if #available(iOS 10.0, *) {
                self.displayLink?.preferredFramesPerSecond = 30
            } else {
                self.displayLink?.frameInterval = 2
            }
            self.displayLink?.add(to: .main, forMode: .common)
            print("🍏 [Renderer] 渲染引擎已启动 (CoreGraphics 零阻塞极限丝滑版！)")
        }
    }

    func updateStreamCount(_ count: Int) {
        stateLock.lock()
        if activeStreamCount != count {
            activeStreamCount = count
            shouldClearCanvas = true
        }
        stateLock.unlock()
    }

    func setVideoOutput(_ output: AVPlayerItemVideoOutput?, at index: Int) {
        stateLock.lock()
        if index < 9 {
            self.videoOutputs[index] = output
            self.shouldClearCanvas = true
        }
        stateLock.unlock()
    }

    @objc private func renderLoop() {
        if textureId == -1 { return }

        stateLock.lock()
        if isRendering {
            stateLock.unlock()
            return
        }
        let count = activeStreamCount
        let outputs = videoOutputs
        let needClear = shouldClearCanvas
        stateLock.unlock()

        var hasNewFrame = needClear
        let hostTime = CACurrentMediaTime()

        if !hasNewFrame {
            for i in 0..<count {
                guard let output = outputs[i] else { continue }
                let itemTime = output.itemTime(forHostTime: hostTime)
                if itemTime.isValid && output.hasNewPixelBuffer(forItemTime: itemTime) {
                    hasNewFrame = true
                    break
                }
            }
        }

        if hasNewFrame {
            stateLock.lock()
            isRendering = true
            stateLock.unlock()

            renderQueue.async { [weak self] in
                self?.performRender()
            }
        }
    }

    private func performRender() {
        defer {
            stateLock.lock()
            isRendering = false
            stateLock.unlock()
        }

        stateLock.lock()
        let localStreamCount = activeStreamCount
        let localOutputs = videoOutputs
        var localNeedClear = false
        if shouldClearCanvas {
            localNeedClear = true
            shouldClearCanvas = false
        }
        stateLock.unlock()

        guard localStreamCount > 0, let canvas = canvasBuffer else { return }

        var frameUpdated = localNeedClear

        // ===============================================
        // 🎨 步骤 1：后台画师开始画图 (不卡 UI)
        // ===============================================
        autoreleasepool {
            CVPixelBufferLockBaseAddress(canvas, [])
            defer { CVPixelBufferUnlockBaseAddress(canvas, []) }

            guard let baseAddress = CVPixelBufferGetBaseAddress(canvas) else { return }
            let width = CVPixelBufferGetWidth(canvas)
            let height = CVPixelBufferGetHeight(canvas)
            let bytesPerRow = CVPixelBufferGetBytesPerRow(canvas)

            let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.noneSkipFirst.rawValue

            guard let context = CGContext(data: baseAddress,
                                          width: width,
                                          height: height,
                                          bitsPerComponent: 8,
                                          bytesPerRow: bytesPerRow,
                                          space: colorSpace,
                                          bitmapInfo: bitmapInfo) else { return }

            context.setShouldAntialias(false)
            context.interpolationQuality = .low
            context.setBlendMode(.copy)

            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: 1.0, y: -1.0)

            if localNeedClear {
                context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
                context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            }

            let hostTime = CACurrentMediaTime()

            for i in 0..<localStreamCount {
                guard let output = localOutputs[i] else { continue }

                let itemTime = output.itemTime(forHostTime: hostTime)

                if itemTime.isValid, output.hasNewPixelBuffer(forItemTime: itemTime) {
                    if let pb = output.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil) {

                        var cgImage: CGImage?
                        VTCreateCGImageFromCVPixelBuffer(pb, options: nil, imageOut: &cgImage)

                        if let img = cgImage {
                            frameUpdated = true
                            let cellRect = getFrame(index: i, total: localStreamCount, canvasSize: canvasSize)

                            context.saveGState()
                            context.clip(to: cellRect)

                            var displaySize = CVImageBufferGetDisplaySize(pb)
                            if displaySize.width <= 0 || displaySize.height <= 0 {
                                displaySize = CGSize(width: CGFloat(img.width), height: CGFloat(img.height))
                            }

                            let cellRatio = cellRect.width / cellRect.height
                            let videoRatio = displaySize.width / displaySize.height
                            var drawWidth: CGFloat = 0
                            var drawHeight: CGFloat = 0

                            if cellRatio > videoRatio {
                                drawWidth = cellRect.width
                                drawHeight = cellRect.width / videoRatio
                            } else {
                                drawHeight = cellRect.height
                                drawWidth = cellRect.height * videoRatio
                            }

                            let drawX = cellRect.origin.x + (cellRect.width - drawWidth) / 2.0
                            let drawY = cellRect.origin.y + (cellRect.height - drawHeight) / 2.0
                            let drawRect = CGRect(x: drawX, y: drawY, width: drawWidth, height: drawHeight)

                            context.translateBy(x: drawRect.minX, y: drawRect.maxY)
                            context.scaleBy(x: 1.0, y: -1.0)

                            let nativeCGRect = CGRect(x: 0, y: 0, width: drawRect.width, height: drawRect.height)
                            context.draw(img, in: nativeCGRect)
                            context.restoreGState()
                        }
                    }
                }
            }
        }

        if !frameUpdated { return }

        // ===============================================
        // 📦 步骤 2：后台内存打包 (不卡 UI)
        // ===============================================
        guard let pool = pixelBufferPool else { return }
        var outputPixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &outputPixelBuffer)
        guard status == kCVReturnSuccess, let deliveryBuffer = outputPixelBuffer else { return }

        CVPixelBufferLockBaseAddress(canvas, .readOnly)
        CVPixelBufferLockBaseAddress(deliveryBuffer, [])

        if let src = CVPixelBufferGetBaseAddress(canvas),
           let dst = CVPixelBufferGetBaseAddress(deliveryBuffer) {
            let srcBytesPerRow = CVPixelBufferGetBytesPerRow(canvas)
            let dstBytesPerRow = CVPixelBufferGetBytesPerRow(deliveryBuffer)
            let height = CVPixelBufferGetHeight(canvas)

            if srcBytesPerRow == dstBytesPerRow {
                memcpy(dst, src, srcBytesPerRow * height)
            } else {
                let copyBytes = min(srcBytesPerRow, dstBytesPerRow)
                for y in 0..<height {
                    let srcRow = src.advanced(by: y * srcBytesPerRow)
                    let dstRow = dst.advanced(by: y * dstBytesPerRow)
                    memcpy(dstRow, srcRow, copyBytes)
                }
            }
        }

        CVPixelBufferUnlockBaseAddress(deliveryBuffer, [])
        CVPixelBufferUnlockBaseAddress(canvas, .readOnly)

        // ===============================================
        // 🚀 步骤 3：把包裹放在快递站 (只锁定纳秒级别)
        // ===============================================
        frontBufferLock.lock()
        self.frontBuffer = deliveryBuffer
        frontBufferLock.unlock()

        // 按门铃通知 Flutter 来拿！
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.textureId != -1 {
                self.registry.textureFrameAvailable(self.textureId)
            }
        }
    }

    // ===============================================
    // 💨 步骤 4：Flutter 前台秒速拿包裹 (零阻塞！)
    // ===============================================
    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        frontBufferLock.lock()
        guard let buffer = frontBuffer else {
            frontBufferLock.unlock()
            return nil
        }
        let retainedBuffer = Unmanaged.passRetained(buffer)
        frontBufferLock.unlock()
        return retainedBuffer
    }

    private func getFrame(index: Int, total: Int, canvasSize: CGSize) -> CGRect {
        let w = canvasSize.width; let h = canvasSize.height
        switch total {
        case 9: let col = CGFloat(index%3); let row = CGFloat(index/3); return CGRect(x: col*(w/3), y: row*(h/3), width: w/3, height: h/3)
        case 8: let col = CGFloat(index%4); let row = CGFloat(index/4); return CGRect(x: col*(w/4), y: row*(h/2), width: w/4, height: h/2)
        case 7: if index < 3 { return CGRect(x: CGFloat(index)*(w/3), y: 0, width: w/3, height: h/2) } else { return CGRect(x: CGFloat(index-3)*(w/4), y: h/2, width: w/4, height: h/2) }
        case 6: let col = CGFloat(index%3); let row = CGFloat(index/3); return CGRect(x: col*(w/3), y: row*(h/2), width: w/3, height: h/2)
        case 5: if index < 2 { return CGRect(x: CGFloat(index)*(w/2), y: 0, width: w/2, height: h/2) } else { return CGRect(x: CGFloat(index-2)*(w/3), y: h/2, width: w/3, height: h/2) }
        case 4: let col = CGFloat(index%2); let row = CGFloat(index/2); return CGRect(x: col*(w/2), y: row*(h/2), width: w/2, height: h/2)
        case 3: if index == 0 { return CGRect(x: 0, y: 0, width: w/2, height: h) } else { return CGRect(x: w/2, y: CGFloat(index-1)*(h/2), width: w/2, height: h/2) }
        case 2: return CGRect(x: CGFloat(index)*(w/2), y: 0, width: w/2, height: h)
        case 1: return CGRect(x: 0, y: 0, width: w, height: h)
        default: return .zero
        }
    }

    func release() {
        displayLink?.invalidate()
        displayLink = nil

        stateLock.lock()
        videoOutputs = Array(repeating: nil, count: 9)
        stateLock.unlock()
    }
}