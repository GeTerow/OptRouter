import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig._();

  static const _configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (_configuredApiBaseUrl.isNotEmpty) return _configuredApiBaseUrl;
    if (kIsWeb) return 'http://localhost:3008';

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'http://10.0.2.2:3008',
      _ => 'http://localhost:3008',
    };
  }

  static Uri apiUri(String path) {
    final normalizedBase = apiBaseUrl.replaceFirst(RegExp(r'/$'), '');
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$normalizedBase$normalizedPath');
  }

  static const apiTimeout = Duration(seconds: 10);
  static const scanTimeout = Duration(seconds: 30);

  static const offlinePreview = bool.fromEnvironment(
    'OFFLINE_PREVIEW',
    defaultValue: false,
  );
}
