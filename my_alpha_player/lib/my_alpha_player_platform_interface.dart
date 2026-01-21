import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'my_alpha_player_method_channel.dart';

abstract class MyAlphaPlayerPlatform extends PlatformInterface {
  /// Constructs a MyAlphaPlayerPlatform.
  MyAlphaPlayerPlatform() : super(token: _token);

  static final Object _token = Object();

  static MyAlphaPlayerPlatform _instance = MethodChannelMyAlphaPlayer();

  /// The default instance of [MyAlphaPlayerPlatform] to use.
  ///
  /// Defaults to [MethodChannelMyAlphaPlayer].
  static MyAlphaPlayerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [MyAlphaPlayerPlatform] when
  /// they register themselves.
  static set instance(MyAlphaPlayerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
