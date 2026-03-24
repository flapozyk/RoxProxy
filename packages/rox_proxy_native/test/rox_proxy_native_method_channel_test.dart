import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rox_proxy_native/rox_proxy_native_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelRoxProxyNative platform = MethodChannelRoxProxyNative();
  const MethodChannel channel = MethodChannel('rox_proxy_native');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return '42';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
