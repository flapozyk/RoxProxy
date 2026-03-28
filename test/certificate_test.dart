import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:rox_proxy/services/proxy_channel.dart';
import 'certificate_test.mocks.dart';

@GenerateMocks([ProxyChannel])
void main() {
  group('Certificate Tests', () {
    late ProxyChannel proxyChannel;

    setUp(() {
      proxyChannel = MockProxyChannel();
    });

    test('installCACertificate should return true on success', () async {
      when(proxyChannel.installCACertificate()).thenAnswer((_) async => true);
      final result = await proxyChannel.installCACertificate();
      expect(result, isTrue);
    });

    test('checkCATrust should return a boolean', () async {
      when(proxyChannel.checkCATrust()).thenAnswer((_) async => true);
      final result = await proxyChannel.checkCATrust();
      expect(result, isA<bool>());
    });

    test('getCAStatus should return a valid CaStatus object', () async {
      when(proxyChannel.getCAStatus()).thenAnswer((_) async => CaStatus(initialized: true, trusted: true));
      final result = await proxyChannel.getCAStatus();
      expect(result, isA<CaStatus>());
      expect(result.initialized, isTrue);
      expect(result.trusted, isTrue);
    });
  });
}
