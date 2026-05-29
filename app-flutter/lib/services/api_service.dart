import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../domain/optimized_route.dart';
import 'address_scan_service.dart';
import 'route_optimization_service.dart';

/// Classe Facade que unifica os serviços de API da aplicação.
/// Mantém total compatibilidade com a assinatura e métodos públicos originais,
/// atuando como ponto único de entrada para chamadas externas.
class ApiService {
  ApiService({
    http.Client? client,
    String? googleMapsApiKey,
    String? openAiApiKey,
    String? openAiRouteModel,
    String? openAiScanModel,
    Uri? googleDirectionsUri,
    Uri? openAiResponsesUri,
  })  : _client = client ?? http.Client() {
    final actualGoogleMapsApiKey =
        (googleMapsApiKey ?? AppConfig.googleMapsApiKey).trim();
    final actualOpenAiApiKey = (openAiApiKey ?? AppConfig.openAiApiKey).trim();
    final actualOpenAiRouteModel =
        (openAiRouteModel ?? AppConfig.openAiRouteModel).trim();
    final actualOpenAiScanModel =
        (openAiScanModel ?? AppConfig.openAiScanModel).trim();
    final actualGoogleDirectionsUri = googleDirectionsUri ??
        Uri.https('maps.googleapis.com', '/maps/api/directions/json');
    final actualOpenAiResponsesUri =
        openAiResponsesUri ?? Uri.https('api.openai.com', '/v1/responses');

    _scanService = AddressScanService(
      client: _client,
      openAiApiKey: actualOpenAiApiKey,
      openAiScanModel: actualOpenAiScanModel,
      openAiResponsesUri: actualOpenAiResponsesUri,
    );

    _routeService = RouteOptimizationService(
      client: _client,
      googleMapsApiKey: actualGoogleMapsApiKey,
      openAiApiKey: actualOpenAiApiKey,
      openAiRouteModel: actualOpenAiRouteModel,
      googleDirectionsUri: actualGoogleDirectionsUri,
      openAiResponsesUri: actualOpenAiResponsesUri,
    );
  }

  final http.Client _client;
  late final AddressScanService _scanService;
  late final RouteOptimizationService _routeService;

  /// Delegado para [AddressScanService.scanAddressImage] para escanear endereço por caminho de imagem.
  Future<List<String>> scanAddressImage(String imagePath) {
    return _scanService.scanAddressImage(imagePath);
  }

  /// Delegado para [AddressScanService.scanAddressImageBytes] para escanear endereço por bytes.
  Future<List<String>> scanAddressImageBytes(
    Uint8List bytes, {
    required String filename,
  }) {
    return _scanService.scanAddressImageBytes(
      bytes,
      filename: filename,
    );
  }

  /// Delegado para [RouteOptimizationService.optimizeRoute] para otimização de rotas.
  Future<OptimizedRoute> optimizeRoute(List<String> addresses) {
    return _routeService.optimizeRoute(addresses);
  }

  /// Fecha o cliente HTTP comum e desaloca os recursos dos serviços.
  void dispose() {
    _client.close();
  }
}
