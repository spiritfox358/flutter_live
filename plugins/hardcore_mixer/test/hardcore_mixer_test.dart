import 'package:flutter_test/flutter_test.dart';
import 'package:hardcore_mixer/hardcore_mixer.dart';
import 'package:hardcore_mixer/hardcore_mixer_platform_interface.dart';
import 'package:hardcore_mixer/hardcore_mixer_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockHardcoreMixerPlatform
    with MockPlatformInterfaceMixin
    implements HardcoreMixerPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final HardcoreMixerPlatform initialPlatform = HardcoreMixerPlatform.instance;

  test('$MethodChannelHardcoreMixer is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelHardcoreMixer>());
  });

  test('getPlatformVersion', () async {
    HardcoreMixer hardcoreMixerPlugin = HardcoreMixer();
    MockHardcoreMixerPlatform fakePlatform = MockHardcoreMixerPlatform();
    HardcoreMixerPlatform.instance = fakePlatform;

    // expect(await hardcoreMixerPlugin.getPlatformVersion(), '42');
  });
}
