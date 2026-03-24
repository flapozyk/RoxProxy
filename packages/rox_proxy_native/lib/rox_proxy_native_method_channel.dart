import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'rox_proxy_native_platform_interface.dart';

/// An implementation of [RoxProxyNativePlatform] that uses method channels.
class MethodChannelRoxProxyNative extends RoxProxyNativePlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('rox_proxy_native');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
