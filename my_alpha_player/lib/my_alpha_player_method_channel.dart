import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'my_alpha_player_platform_interface.dart';

/// An implementation of [MyAlphaPlayerPlatform] that uses method channels.
class MethodChannelMyAlphaPlayer extends MyAlphaPlayerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('my_alpha_player');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
