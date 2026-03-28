import 'package:flutter_test/flutter_test.dart';
import 'package:rox_proxy_native/rox_proxy_native.dart';
import 'package:rox_proxy_native/rox_proxy_native_platform_interface.dart';
import 'package:rox_proxy_native/rox_proxy_native_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockRoxProxyNativePlatform
    with MockPlatformInterfaceMixin
    implements RoxProxyNativePlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final RoxProxyNativePlatform initialPlatform = RoxProxyNativePlatform.instance;

  test('$MethodChannelRoxProxyNative is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelRoxProxyNative>());
  });

  test('getPlatformVersion', () async {
    RoxProxyNative roxProxyNativePlugin = RoxProxyNative();
    MockRoxProxyNativePlatform fakePlatform = MockRoxProxyNativePlatform();
    RoxProxyNativePlatform.instance = fakePlatform;

    expect(await roxProxyNativePlugin.getPlatformVersion(), '42');
  });
}
