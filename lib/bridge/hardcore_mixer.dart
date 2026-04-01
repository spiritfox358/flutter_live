import 'package:flutter/services.dart';

class HardcoreMixer {
  static const MethodChannel _channel = MethodChannel('hardcore_mixer');

  // 1. 初始化引擎，获取这块“神圣画布”的 ID
  static Future<int?> initEngine() async {
    final int? textureId = await _channel.invokeMethod('initEngine');
    return textureId;
  }

  // hardcore_mixer.dart
  static Future<void> playStreams(List<String> urls, List<List<double>> layouts, double containerWidth, double containerHeight) async {
    await _channel.invokeMethod('playStreams', {
      'urls': urls,
      'layouts': layouts,
      // 🚀 终极钥匙：把 Flutter 容器的真实像素尺寸传给底层！
      'containerWidth': containerWidth,
      'containerHeight': containerHeight,
    });
  }

  // 3. 销毁引擎，打扫战场
  static Future<void> dispose() async {
    await _channel.invokeMethod('disposeMixer');
  }

  // 🚀 新增：闭环雷达查询接口
  static Future<List<String>> getReadyUrls() async {
    try {
      final List<dynamic>? urls = await _channel.invokeMethod('getReadyUrls');
      return urls?.map((e) => e.toString()).toList() ?? [];
    } catch (e) {
      return [];
    }
  }

  // 🚀 新增：控制底层物理静音
  static Future<void> setMuted(String streamUrl, bool isMuted) async {
    try {
      await _channel.invokeMethod('setMuted', {
        'url': streamUrl,
        'isMuted': isMuted,
      });
    } catch (e) {
      print("设置静音失败: $e");
    }
  }
}