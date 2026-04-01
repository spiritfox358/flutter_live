import Flutter
import UIKit

public class HardcoreMixerPlugin: NSObject, FlutterPlugin {
    var engine: HardcoreEngine?
    var registry: FlutterTextureRegistry?

    public static func register(with registrar: FlutterPluginRegistrar) {
        // 注意：这里换成你自己真实的 Channel 名字，如果有区别请保留你原来的
        let channel = FlutterMethodChannel(name: "hardcore_mixer", binaryMessenger: registrar.messenger())
        let instance = HardcoreMixerPlugin()
        instance.registry = registrar.textures()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "initEngine" {
            // 🚀🚀🚀 核心防串音装甲：如果在初始化新房间时，发现旧引擎还在喘气，当场击毙！
            engine?.stop()
            engine = nil

            if let reg = registry {
                engine = HardcoreEngine(registry: reg)
                result(engine?.textureId ?? -1)
            } else {
                result(-1)
            }
        } else if call.method == "playStreams" {
            if let args = call.arguments as? [String: Any],
               let urls = args["urls"] as? [String],
               let layouts = args["layouts"] as? [[NSNumber]] {
                engine?.start9Grid(urls, layouts: layouts)
            }
            result(nil)
        } else if call.method == "getReadyUrls" {
            let urls = engine?.getReadyUrls() ?? []
            result(urls)
        // 🚀🚀🚀 核心防线：确保这里有 setMuted 的接收器！！！
        } else if call.method == "setMuted" {
            if let args = call.arguments as? [String: Any],
               let url = args["url"] as? String,
               let isMuted = args["isMuted"] as? Bool {
                engine?.setMuted(isMuted, forUrl: url)
                print("🔊 [Swift 桥接] 收到静音指令: url=\(url), isMuted=\(isMuted)")
            }
            result(nil)
        } else if call.method == "disposeMixer" {
            engine?.stop()
            engine = nil
            result(nil)
        } else {
            result(FlutterMethodNotImplemented)
        }
    }
}