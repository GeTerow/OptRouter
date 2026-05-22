import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../domain/address_rules.dart';
import '../domain/app_failure.dart';
import '../domain/optimized_route.dart';
import '../domain/stop.dart';
import '../services/api_service.dart';

class AppState extends ChangeNotifier {
  AppState({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  List<String> _addresses = const [];
  OptimizedRoute? _optimizedRoute;

  List<String> get addresses => _addresses;
  OptimizedRoute? get optimizedRoute => _optimizedRoute;

  void setAddresses(List<String> addresses) {
    _addresses = List.unmodifiable(AddressRules.normalize(addresses));
    notifyListeners();
  }

  void clearRoute() {
    _optimizedRoute = null;
    notifyListeners();
  }

  Future<void> optimizeRoute(List<String> addresses) async {
    final normalized = AddressRules.normalize(addresses);

    if (normalized.length < 2) {
      throw const AppFailure(
        kind: AppFailureKind.validation,
        message: 'Forneça pelo menos 2 endereços.',
      );
    }

    if (AppConfig.offlinePreview) {
      _optimizedRoute = _buildPreviewRoute(normalized);
      notifyListeners();
      return;
    }

    try {
      _optimizedRoute = await _apiService.optimizeRoute(normalized);
    } on AppFailure catch (error) {
      if (!_canUsePreviewRoute(error)) rethrow;
      _optimizedRoute = _buildPreviewRoute(normalized);
    }
    notifyListeners();
  }

  Future<List<String>> scanImage(
    String imagePath, {
    Iterable<String>? baseAddresses,
  }) async {
    final extracted = await _apiService.scanAddressImage(imagePath);
    final merged = AddressRules.mergeUnique(
      baseAddresses ?? _addresses,
      extracted,
    );
    _addresses = List.unmodifiable(merged);
    notifyListeners();
    return extracted;
  }

  Future<List<String>> scanImageBytes(
    Uint8List bytes, {
    required String filename,
    Iterable<String>? baseAddresses,
  }) async {
    final extracted = await _apiService.scanAddressImageBytes(
      bytes,
      filename: filename,
    );
    final merged = AddressRules.mergeUnique(
      baseAddresses ?? _addresses,
      extracted,
    );
    _addresses = List.unmodifiable(merged);
    notifyListeners();
    return extracted;
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }

  bool _canUsePreviewRoute(AppFailure error) {
    return switch (error.kind) {
      AppFailureKind.network ||
      AppFailureKind.timeout ||
      AppFailureKind.unknown =>
        true,
      AppFailureKind.validation ||
      AppFailureKind.invalidResponse ||
      AppFailureKind.server ||
      AppFailureKind.addressNotFound =>
        false,
    };
  }

  OptimizedRoute _buildPreviewRoute(List<String> addresses) {
    final stopCount = addresses.length;
    final estimatedMinutes = 12 * (stopCount - 1);
    final estimatedKm = (4.5 * (stopCount - 1)).toStringAsFixed(1);

    return OptimizedRoute(
      stops: [
        for (final address in addresses) Stop(address: address),
      ],
      totalTime: '$estimatedMinutes min (prévia)',
      totalDistance: '$estimatedKm km (prévia)',
      numberOfStops: stopCount,
    );
  }
}
