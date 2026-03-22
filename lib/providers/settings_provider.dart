import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/domain_rule.dart';
import '../models/proxy_settings.dart';
import '../services/settings_service.dart';

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService();
});

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, ProxySettings>((ref) {
  return SettingsNotifier(ref.read(settingsServiceProvider));
});

class SettingsNotifier extends StateNotifier<ProxySettings> {
  final SettingsService _service;

  SettingsNotifier(this._service) : super(ProxySettings()) {
    _load();
  }

  Future<void> _load() async {
    state = await _service.load();
  }

  Future<void> _save() => _service.save(state);

  void setPort(int port) {
    state = state.copyWith(port: port);
    _save();
  }

  void setAutoStartProxy(bool value) {
    state = state.copyWith(autoStartProxy: value);
    _save();
  }

  void setIsRecording(bool value) {
    state = state.copyWith(isRecording: value);
    _save();
  }

  void setMaxExchanges(int value) {
    state = state.copyWith(maxExchanges: value);
    _save();
  }

  void setConnectionTimeout(int seconds) {
    state = state.copyWith(connectionTimeoutSeconds: seconds);
    _save();
  }

  void addDomain(String domain) {
    final trimmed = domain.trim();
    if (trimmed.isEmpty) return;
    if (state.domainRules.any((r) => r.domain == trimmed)) return;
    state = state.copyWith(
      domainRules: [...state.domainRules, DomainRule(domain: trimmed)],
    );
    _save();
  }

  void removeDomain(String id) {
    state = state.copyWith(
      domainRules: state.domainRules.where((r) => r.id != id).toList(),
    );
    _save();
  }

  void toggleDomain(String id) {
    state = state.copyWith(
      domainRules: state.domainRules
          .map((r) => r.id == id
              ? DomainRule(id: r.id, domain: r.domain, isEnabled: !r.isEnabled)
              : r)
          .toList(),
    );
    _save();
  }
}
