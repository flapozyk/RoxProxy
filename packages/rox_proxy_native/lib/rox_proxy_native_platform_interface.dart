import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'rox_proxy_native_method_channel.dart';

abstract class RoxProxyNativePlatform extends PlatformInterface {
  /// Constructs a RoxProxyNativePlatform.
  RoxProxyNativePlatform() : super(token: _token);

  static final Object _token = Object();

  static RoxProxyNativePlatform _instance = MethodChannelRoxProxyNative();

  /// The default instance of [RoxProxyNativePlatform] to use.
  ///
  /// Defaults to [MethodChannelRoxProxyNative].
  static RoxProxyNativePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [RoxProxyNativePlatform] when
  /// they register themselves.
  static set instance(RoxProxyNativePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
