import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig._();

  static const _configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const googleMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
  static const openAiApiKey = String.fromEnvironment('OPENAI_API_KEY');
  static const openAiRouteModel = String.fromEnvironment(
    'OPENAI_ROUTE_MODEL',
    defaultValue: 'gpt-5.4-mini-2026-03-17',
  );
  static const openAiScanModel = String.fromEnvironment(
    'OPENAI_SCAN_MODEL',
    defaultValue: 'gpt-4o',
  );

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

  static const mapsTimeout = Duration(seconds: 15);
  static const openAiRouteTimeout = Duration(seconds: 60);
  static const apiTimeout = mapsTimeout;
  static const scanTimeout = Duration(seconds: 30);

  static const offlinePreview = bool.fromEnvironment(
    'OFFLINE_PREVIEW',
    defaultValue: false,
  );
}
