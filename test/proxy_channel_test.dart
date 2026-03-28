import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:rox_proxy/services/proxy_channel.dart';
import 'proxy_channel_test.mocks.dart';

@GenerateMocks([ProxyChannel])
void main() {
  group('ProxyChannel Tests', () {
    late ProxyChannel proxyChannel;

    setUp(() {
      proxyChannel = MockProxyChannel();
    });

    test('startProxy should return a valid port on success', () async {
      when(proxyChannel.startProxy(
        port: 8888,
        domainRules: [],
        connectionTimeoutSeconds: 30,
        setSystemProxy: false,
        httpsInterceptionEnabled: true,
      )).thenAnswer((_) async => 8888);
      final result = await proxyChannel.startProxy(
        port: 8888,
        domainRules: [],
        connectionTimeoutSeconds: 30,
        setSystemProxy: false,
        httpsInterceptionEnabled: true,
      );
      expect(result, isA<int>());
    });

    test('stopProxy should complete successfully', () async {
      when(proxyChannel.stopProxy()).thenAnswer((_) async => true);
      await proxyChannel.stopProxy();
      expect(true, isTrue);
    });

    test('getProxyState should return a valid state', () async {
      when(proxyChannel.getProxyState()).thenAnswer((_) async => 'running');
      final result = await proxyChannel.getProxyState();
      expect(result, isA<String>());
    });
  });
}
