
import 'rox_proxy_native_platform_interface.dart';

class RoxProxyNative {
  Future<String?> getPlatformVersion() {
    return RoxProxyNativePlatform.instance.getPlatformVersion();
  }
}
