import Flutter
import UIKit

public class MyAlphaPlayerPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "my_alpha_player", binaryMessenger: registrar.messenger())
    let instance = MyAlphaPlayerPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)

    // 注意：这里的 viewId 必须和 Dart 端的 viewType 一致
    let factory = NativeAlphaPlayerFactory(messenger: registrar.messenger())
    registrar.register(factory, withId: "com.example.live/alpha_player")
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
