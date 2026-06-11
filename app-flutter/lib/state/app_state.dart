import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../domain/address_rules.dart';
import '../domain/app_failure.dart';
import '../domain/optimized_route.dart';
import '../domain/route_draft.dart';
import '../domain/user_settings.dart';
import '../domain/stop.dart';
import '../services/api_service.dart';
import '../services/route_draft_service.dart';

class AppState extends ChangeNotifier {
  AppState({
    ApiService? apiService,
    RouteDraftService? routeDraftService,
  })  : _apiService = apiService ?? ApiService(),
        _routeDraftService = routeDraftService;

  final ApiService _apiService;
  final RouteDraftService? _routeDraftService;

  List<String> _addresses = const [];
  OptimizedRoute? _optimizedRoute;
  String? _routeDraftId;

  List<String> get addresses => _addresses;
  OptimizedRoute? get optimizedRoute => _optimizedRoute;
  String? get routeDraftId => _routeDraftId;

  void setAddresses(List<String> addresses) {
    _addresses = List.unmodifiable(AddressRules.normalize(addresses));
    notifyListeners();
  }

  void clearRoute() {
    _optimizedRoute = null;
    notifyListeners();
  }

  void beginRouteDraft(UserSettings settings) {
    _routeDraftId = null;
    _optimizedRoute = null;
    _addresses = List.unmodifiable(
      AddressRules.normalize([
        settings.defaultOrigin,
        settings.defaultDestination,
      ]),
    );
    notifyListeners();
  }

  void loadRouteDraft({
    required String routeId,
    required List<String> addresses,
  }) {
    _routeDraftId = routeId;
    _optimizedRoute = null;
    _addresses = List.unmodifiable(AddressRules.normalize(addresses));
    notifyListeners();
  }

  void clearCurrentDraft() {
    _routeDraftId = null;
    _optimizedRoute = null;
    _addresses = const [];
    notifyListeners();
  }

  Future<void> saveRouteDraft(RouteDraft draft) async {
    final service = _routeDraftService ?? RouteDraftService();
    _routeDraftId = await service.saveRouteDraft(
      draft,
      routeId: _routeDraftId,
    );
    _addresses =
        List.unmodifiable(AddressRules.normalize(draft.orderedAddresses));
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

    _optimizedRoute = await _apiService.optimizeRoute(normalized);
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

  Future<List<String>> extractAddressesFromImageBytes(
    Uint8List bytes, {
    required String filename,
  }) {
    return _apiService.scanAddressImageBytes(
      bytes,
      filename: filename,
    );
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
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
