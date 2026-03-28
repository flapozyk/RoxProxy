import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/proxy_settings.dart';

class SettingsService {
  static const _fileName = 'settings.json';
  static const _appSupportDir = 'RoxProxy';

  Future<File> _settingsFile() async {
    final appSupport = await getApplicationSupportDirectory();
    final dir = Directory('${appSupport.path}/$_appSupportDir');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return File('${dir.path}/$_fileName');
  }

  Future<ProxySettings> load() async {
    try {
      final file = await _settingsFile();
      if (!file.existsSync()) return ProxySettings();
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return ProxySettings.fromJson(json);
    } catch (_) {
      return ProxySettings();
    }
  }

  Future<void> save(ProxySettings settings) async {
    try {
      final file = await _settingsFile();
      file.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(settings.toJson()),
      );
    } catch (_) {}
  }
}
