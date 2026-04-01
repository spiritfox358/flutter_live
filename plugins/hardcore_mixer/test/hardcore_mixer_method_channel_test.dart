import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardcore_mixer/hardcore_mixer_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelHardcoreMixer platform = MethodChannelHardcoreMixer();
  const MethodChannel channel = MethodChannel('hardcore_mixer');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
