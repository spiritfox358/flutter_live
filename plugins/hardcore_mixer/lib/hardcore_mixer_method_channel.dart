import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'hardcore_mixer_platform_interface.dart';

/// An implementation of [HardcoreMixerPlatform] that uses method channels.
class MethodChannelHardcoreMixer extends HardcoreMixerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('hardcore_mixer');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
