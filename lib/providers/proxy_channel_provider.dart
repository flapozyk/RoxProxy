import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/proxy_channel.dart';

final proxyChannelProvider = Provider<ProxyChannel>((ref) {
  return ProxyChannel();
});
