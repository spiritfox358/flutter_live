import 'dart:async';
import 'package:flutter/services.dart';

class HardcoreMixer {
  static const MethodChannel _channel = MethodChannel('hardcore_mixer');

  int? textureId;

  /// 初始化底层引擎，返回 Texture ID
  Future<int?> initialize() async {
    textureId = await _channel.invokeMethod<int>('initializeMixer');
    return textureId;
  }

  /// 喂给底层 1~9 个视频流地址
  Future<void> playStreams(List<String> urls) async {
    await _channel.invokeMethod('playStreams', {'urls': urls});
  }

  /// 销毁引擎
  Future<void> dispose() async {
    await _channel.invokeMethod('disposeMixer');
    textureId = null;
  }
}