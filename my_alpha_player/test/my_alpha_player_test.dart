import 'package:flutter_test/flutter_test.dart';
import 'package:my_alpha_player/my_alpha_player.dart';
import 'package:my_alpha_player/my_alpha_player_platform_interface.dart';
import 'package:my_alpha_player/my_alpha_player_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockMyAlphaPlayerPlatform
    with MockPlatformInterfaceMixin
    implements MyAlphaPlayerPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final MyAlphaPlayerPlatform initialPlatform = MyAlphaPlayerPlatform.instance;

  test('$MethodChannelMyAlphaPlayer is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelMyAlphaPlayer>());
  });

  test('getPlatformVersion', () async {
    MyAlphaPlayer myAlphaPlayerPlugin = MyAlphaPlayer();
    MockMyAlphaPlayerPlatform fakePlatform = MockMyAlphaPlayerPlatform();
    MyAlphaPlayerPlatform.instance = fakePlatform;

    expect(await myAlphaPlayerPlugin.getPlatformVersion(), '42');
  });
}
