import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../domain/app_failure.dart';
import '../domain/optimized_route.dart';
import '../domain/stop.dart';
import 'base_api_service.dart';
import 'maps_link_builder.dart';

/// Serviço focado na reordenação otimizada de paradas em uma rota de entrega.
/// Tenta utilizar a API oficial do Google Directions e, em caso de falha ou indisponibilidade,
/// recorre a um fallback inteligente e pessimista utilizando a API do OpenAI.
class RouteOptimizationService extends BaseApiService {
  RouteOptimizationService({
    required super.client,
    required String googleMapsApiKey,
    required String openAiApiKey,
    required String openAiRouteModel,
    required Uri googleDirectionsUri,
    required Uri openAiResponsesUri,
  })  : _googleMapsApiKey = googleMapsApiKey,
        _openAiApiKey = openAiApiKey,
        _openAiRouteModel = openAiRouteModel,
        _googleDirectionsUri = googleDirectionsUri,
        _openAiResponsesUri = openAiResponsesUri;

  final String _googleMapsApiKey;
  final String _openAiApiKey;
  final String _openAiRouteModel;
  final Uri _googleDirectionsUri;
  final Uri _openAiResponsesUri;

  /// Inicia a otimização lógica da rota para a lista de endereços informada.
  /// O primeiro endereço será a origem e o último endereço será o destino final da rota.
  Future<OptimizedRoute> optimizeRoute(List<String> addresses) {
    return safeCall(
      operationLabel: 'otimizar rota',
      action: () async {
        if (_googleMapsApiKey.isEmpty && _openAiApiKey.isEmpty) {
          throw const AppFailure(
            kind: AppFailureKind.configuration,
            message:
                'As chaves GOOGLE_MAPS_API_KEY e OPENAI_API_KEY não foram configuradas.',
          );
        }

        final List<String> normalizedAddresses;
        if (addresses.isNotEmpty && addresses.first != addresses.last) {
          normalizedAddresses = [...addresses, addresses.first];
        } else {
          normalizedAddresses = List.of(addresses);
        }

        debugLog('Otimizando rota: tentando Google Directions.');
        final googleAttempt = await _tryOptimizeWithGoogleMaps(normalizedAddresses);
        if (googleAttempt.route != null) {
          debugLog('Otimizacao concluida pelo Google Directions.');
          return googleAttempt.route!;
        }
        debugLog(
          'Google Directions falhou (${googleAttempt.kind.name}): ${googleAttempt.message ?? 'sem detalhe'}',
        );

        if (_openAiApiKey.isEmpty) {
          if (googleAttempt.kind ==
              _GoogleOptimizationAttemptKind.addressNotFound) {
            throw const AppFailure(
              kind: AppFailureKind.addressNotFound,
              message: 'Nenhuma rota encontrada para os endereços informados.',
            );
          }

          throw const AppFailure(
            kind: AppFailureKind.configuration,
            message:
                'A chave OPENAI_API_KEY não foi configurada para o fallback de rota.',
          );
        }

        try {
          debugLog(
            'Google Directions nao retornou rota utilizavel. Tentando fallback OpenAI.',
          );
          return await _optimizeWithOpenAi(normalizedAddresses);
        } on FormatException catch (error) {
          if (googleAttempt.kind ==
              _GoogleOptimizationAttemptKind.addressNotFound) {
            throw AppFailure(
              kind: AppFailureKind.addressNotFound,
              message: 'Nenhuma rota encontrada para os endereços informados.',
              technicalMessage: error.message,
            );
          }
          rethrow;
        } on AppFailure catch (error) {
          if (googleAttempt.kind !=
              _GoogleOptimizationAttemptKind.addressNotFound) {
            rethrow;
          }

          if (error.kind == AppFailureKind.invalidResponse ||
              error.kind == AppFailureKind.server ||
              error.kind == AppFailureKind.unknown) {
            throw AppFailure(
              kind: AppFailureKind.addressNotFound,
              message: 'Nenhuma rota encontrada para os endereços informados.',
              technicalMessage: error.toString(),
            );
          }

          rethrow;
        }
      },
    );
  }

  /// Tenta otimizar a rota usando a API do Google Directions.
  Future<_GoogleOptimizationAttempt> _tryOptimizeWithGoogleMaps(
    List<String> addresses,
  ) async {
    if (_googleMapsApiKey.isEmpty) {
      return const _GoogleOptimizationAttempt.failed(
        'GOOGLE_MAPS_API_KEY ausente.',
      );
    }

    try {
      final intermediates = addresses.length > 2
          ? addresses.sublist(1, addresses.length - 1)
          : <String>[];
      final queryParams = <String, String>{
        'origin': addresses.first,
        'destination': addresses.last,
        'mode': 'driving',
        'departure_time': 'now',
        'language': 'pt-BR',
        'key': _googleMapsApiKey,
      };
      if (intermediates.isNotEmpty) {
        queryParams['waypoints'] =
            'optimize:true|${intermediates.join('|')}';
      }
      final response = await client
          .get(
            _googleDirectionsUri.replace(
              queryParameters: queryParams,
            ),
          )
          .timeout(AppConfig.mapsTimeout);
      debugLog(
        'Google Directions HTTP ${response.statusCode}: ${truncateForLog(response.body)}',
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _GoogleOptimizationAttempt.failed(
          extractProviderMessage(response.body),
        );
      }

      final decoded = decodeJsonObject(
        response.body,
        endpoint: 'Google Directions',
      );
      final status = (decoded['status'] as String?)?.trim() ?? '';

      if (status == 'OK') {
        return _GoogleOptimizationAttempt.success(
          _parseGoogleRoute(
            decoded,
            originalAddresses: addresses,
          ),
        );
      }

      if (_isGoogleAddressNotFoundStatus(status)) {
        return _GoogleOptimizationAttempt.addressNotFound(
          status.isEmpty ? 'Nenhuma rota encontrada.' : status,
        );
      }

      return _GoogleOptimizationAttempt.failed(
        _extractGoogleStatusMessage(decoded, status),
      );
    } on TimeoutException catch (error) {
      return _GoogleOptimizationAttempt.failed(error.toString());
    } on FormatException catch (error) {
      return _GoogleOptimizationAttempt.failed(error.message);
    } on http.ClientException catch (error) {
      return _GoogleOptimizationAttempt.failed(error.message);
    }
  }

  /// Tenta otimizar a rota usando a API estruturada do OpenAI como fallback de segurança.
  Future<OptimizedRoute> _optimizeWithOpenAi(List<String> addresses) async {
    final response = await client
        .post(
          _openAiResponsesUri,
          headers: jsonHeaders(bearerToken: _openAiApiKey),
          body: jsonEncode(_buildRouteOptimizationRequest(addresses)),
        )
        .timeout(AppConfig.openAiRouteTimeout);
    debugLog(
      'OpenAI route HTTP ${response.statusCode}: ${truncateForLog(response.body)}',
    );

    throwIfFailed(
      response,
      providerName: 'OpenAI',
    );

    final decoded = extractOpenAiStructuredJson(
      response.body,
      endpoint: 'OpenAI route',
    );
    final rawStops = decoded['stops'];
    if (rawStops is! List) {
      throw const FormatException('Resposta inválida da OpenAI para rota.');
    }

    final orderedAddresses = _normalizeOpenAiRouteStops(
      originalAddresses: addresses,
      rawStops: rawStops,
    );
    _validateOpenAiRoute(
      originalAddresses: addresses,
      orderedAddresses: orderedAddresses,
    );

    final totalTime = (decoded['totalTime'] as String?)?.trim();
    final totalDistance = (decoded['totalDistance'] as String?)?.trim();
    if (totalTime == null ||
        totalTime.isEmpty ||
        totalDistance == null ||
        totalDistance.isEmpty) {
      throw const FormatException(
        'Resposta inválida da OpenAI para totais da rota.',
      );
    }

    return _buildOptimizedRoute(
      orderedAddresses,
      totalTime: totalTime,
      totalDistance: totalDistance,
    );
  }

  /// Faz o parsing da rota retornada pelo Google Directions API.
  OptimizedRoute _parseGoogleRoute(
    Map<String, dynamic> decoded, {
    required List<String> originalAddresses,
  }) {
    final routes = decoded['routes'];
    if (routes is! List || routes.isEmpty) {
      throw const FormatException('Google Directions sem rotas retornadas.');
    }

    final firstRoute = routes.first;
    if (firstRoute is! Map) {
      throw const FormatException('Google Directions retornou rota inválida.');
    }

    final route = Map<String, dynamic>.from(firstRoute);
    final waypointOrderRaw = route['waypoint_order'];
    final legsRaw = route['legs'];
    if (waypointOrderRaw is! List || legsRaw is! List) {
      throw const FormatException(
          'Google Directions retornou rota incompleta.');
    }

    final waypointOrder =
        waypointOrderRaw.map((value) => (value as num?)?.toInt()).toList();
    if (waypointOrder.any((value) => value == null)) {
      throw const FormatException(
          'Google Directions retornou waypoint_order inválido.');
    }

    final intermediates = originalAddresses.length > 2
        ? originalAddresses.sublist(1, originalAddresses.length - 1)
        : <String>[];
    final orderedStops = <String>[originalAddresses.first];
    for (final index in waypointOrder.cast<int>()) {
      if (index < 0 || index >= intermediates.length) {
        throw const FormatException(
            'Google Directions retornou waypoint fora do intervalo.');
      }
      orderedStops.add(intermediates[index]);
    }
    orderedStops.add(originalAddresses.last);

    if (legsRaw.length != orderedStops.length - 1) {
      throw const FormatException(
          'Google Directions retornou legs inconsistentes.');
    }

    var totalSeconds = 0;
    var totalMeters = 0;
    for (final legValue in legsRaw) {
      if (legValue is! Map) {
        throw const FormatException('Google Directions retornou leg inválida.');
      }

      final leg = Map<String, dynamic>.from(legValue);
      final duration = _extractNestedInt(
        leg,
        parentKey: 'duration',
        childKey: 'value',
      );
      final distance = _extractNestedInt(
        leg,
        parentKey: 'distance',
        childKey: 'value',
      );
      totalSeconds += duration;
      totalMeters += distance;
    }

    return _buildOptimizedRoute(
      orderedStops,
      totalTime: _formatDuration(totalSeconds),
      totalDistance: '${(totalMeters / 1000).toStringAsFixed(1)} km',
    );
  }

  /// Instancia o objeto [OptimizedRoute] contendo as paradas e o link do Google Maps Directions.
  OptimizedRoute _buildOptimizedRoute(
    List<String> orderedAddresses, {
    required String totalTime,
    required String totalDistance,
  }) {
    final stops = [
      for (final address in orderedAddresses) Stop(address: address),
    ];

    final routeWithoutMapsUrl = OptimizedRoute(
      stops: stops,
      totalTime: totalTime,
      totalDistance: totalDistance,
      numberOfStops: stops.length,
    );

    return OptimizedRoute(
      stops: stops,
      totalTime: totalTime,
      totalDistance: totalDistance,
      numberOfStops: stops.length,
      mapsUrl: MapsLinkBuilder.googleDirectionsUrl(routeWithoutMapsUrl),
    );
  }

  /// Monta o payload JSON da requisição estruturada para o OpenAI.
  Map<String, dynamic> _buildRouteOptimizationRequest(List<String> addresses) {
    return {
      'model': _openAiRouteModel,
      'instructions': [
        'Voce e um otimizador de rotas para entregas urbanas no Brasil.',
        'O primeiro endereco e a origem e o ultimo endereco e o destino final.',
        'Reordene apenas os enderecos intermediarios (do segundo ao penultimo) para minimizar a distancia total.',
        'Nao invente paradas novas.',
        'Em stops, retorne originalIndex usando exatamente os numeros da lista informada.',
        'O primeiro stop deve ter originalIndex 1 (origem) e o ultimo stop deve ter originalIndex ${addresses.length} (destino).',
        'SEJA PESSIMISTA E ADICIONE MARGEM DE SEGURANCA: Para garantir que o motorista nao se atrase, estime a distancia e o tempo de transito de forma bastante conservadora e pessimista.',
        '- Para totalDistance: Estime uma quilometragem folgada, adicionando uma margem de segurança (considerando desvios e busca por vagas).',
        '- Para totalTime: Estime um tempo de transito bem folgado e pessimista, somando pelo menos 25% a 30% a mais do que o tempo de transito livre (considerando semaforos, transito pesado e o tempo de estacionar/desembarcar em cada parada).',
        'Retorne totalTime and totalDistance como estimativas textuais pessimistas em portugues (ex: "55 min" ou "1h 10min" e "15.4 km").',
      ].join(' '),
      'input': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'input_text',
              'text': [
                'Otimize esta rota e retorne JSON no schema solicitado.',
                'A rota deve comecar no primeiro endereco (origem), visitar os intermediarios na melhor ordem, e terminar no ultimo endereco (destino).',
                'Use originalIndex 1 para a origem no primeiro stop e originalIndex ${addresses.length} para o destino no ultimo stop.',
                'Seja bastante pessimista nas estimativas finais de totalDistance e totalTime: adicione uma margem de seguranca folgada para cobrir imprevistos como semaforos, transito pesado, procura por vagas de estacionamento e o tempo gasto em cada entrega.',
                for (var i = 0; i < addresses.length; i++)
                  '${i + 1}. ${addresses[i]}',
              ].join('\n'),
            },
          ],
        },
      ],
      'max_output_tokens': 1200,
      'text': {
        'format': _jsonSchemaFormat(
          name: 'optimized_route',
          schema: {
            'type': 'object',
            'additionalProperties': false,
            'properties': {
              'totalTime': {'type': 'string'},
              'totalDistance': {'type': 'string'},
              'stops': {
                'type': 'array',
                'items': {
                  'type': 'object',
                  'additionalProperties': false,
                  'properties': {
                    'originalIndex': {'type': 'integer'},
                  },
                  'required': ['originalIndex'],
                },
              },
            },
            'required': ['totalTime', 'totalDistance', 'stops'],
          },
        ),
      },
    };
  }

  /// Retorna o formato JSON Schema rígido necessário para o OpenAI Structured Outputs.
  Map<String, dynamic> _jsonSchemaFormat({
    required String name,
    required Map<String, dynamic> schema,
  }) {
    return {
      'type': 'json_schema',
      'name': name,
      'strict': true,
      'schema': schema,
    };
  }

  /// Extrai chaves inteiras aninhadas dentro da resposta do Google Directions (ex: legs[i].duration.value).
  int _extractNestedInt(
    Map<String, dynamic> source, {
    required String parentKey,
    required String childKey,
  }) {
    final parent = source[parentKey];
    if (parent is! Map) {
      throw FormatException('Campo $parentKey ausente na resposta.');
    }

    final value = parent[childKey];
    if (value is! num) {
      throw FormatException('Campo $parentKey.$childKey ausente na resposta.');
    }

    return value.toInt();
  }

  /// Normaliza as paradas geradas pelo OpenAI para garantir integridade e alinhar com o formato original.
  List<String> _normalizeOpenAiRouteStops({
    required List<String> originalAddresses,
    required List<dynamic> rawStops,
  }) {
    if (rawStops.isEmpty) {
      throw const FormatException('A OpenAI retornou rota sem paradas.');
    }

    final returnedIndexes = rawStops
        .map(_openAiStopOriginalIndex)
        .whereType<int>()
        .toList(growable: false);
    if (returnedIndexes.length == rawStops.length) {
      final normalizedIndexes = _normalizeOpenAiRouteIndexes(
        originalAddresses: originalAddresses,
        returnedIndexes: returnedIndexes,
      );
      return [
        for (final index in normalizedIndexes) originalAddresses[index],
      ];
    }

    final returnedAddresses = rawStops
        .whereType<Map>()
        .map((stop) => (stop['address'] as String?)?.trim() ?? '')
        .where((address) => address.isNotEmpty)
        .toList();

    // Se a rota for um circuito fechado (retorno à origem) e a OpenAI omitir a última parada
    if (originalAddresses.length > 3 &&
        originalAddresses.first == originalAddresses.last &&
        returnedAddresses.length == originalAddresses.length - 1 &&
        returnedAddresses.last != originalAddresses.last) {
      returnedAddresses.add(originalAddresses.last);
    }

    final normalized = _mapOpenAiAddressesToOriginals(
      originalAddresses: originalAddresses,
      returnedAddresses: returnedAddresses,
    );
    final origin = originalAddresses.first;
    final destination = originalAddresses.last;

    if (normalized.first != origin) {
      throw const FormatException('A OpenAI não preservou a origem da rota.');
    }

    if (normalized.length == originalAddresses.length &&
        normalized.last != destination) {
      final withoutDest = normalized
          .where((a) => a != destination)
          .toList();
      withoutDest.add(destination);
      return withoutDest;
    }

    return normalized;
  }

  /// Converte o índice do OpenAI de formato 1-based para o formato 0-based do Dart.
  int? _openAiStopOriginalIndex(dynamic stopValue) {
    if (stopValue is! Map) return null;

    final rawIndex = stopValue['originalIndex'];
    if (rawIndex is! num || rawIndex.toInt() != rawIndex) return null;

    return rawIndex.toInt() - 1;
  }

  /// Reconstrói índices caso o OpenAI tenha omitido alguma parada ou retornado lixo no array.
  List<int> _normalizeOpenAiRouteIndexes({
    required List<String> originalAddresses,
    required List<int> returnedIndexes,
  }) {
    if (returnedIndexes.first != 0) {
      throw const FormatException('A OpenAI não preservou a origem da rota.');
    }

    final lastIndex = originalAddresses.length - 1;
    final seen = <int>{0, lastIndex};
    final orderedIntermediates = <int>[];
    for (final index in returnedIndexes.skip(1)) {
      if (index <= 0 || index >= originalAddresses.length) continue;
      if (index == lastIndex) continue;
      if (seen.add(index)) {
        orderedIntermediates.add(index);
      }
    }

    for (var index = 1; index < lastIndex; index++) {
      if (seen.add(index)) {
        orderedIntermediates.add(index);
      }
    }

    return [0, ...orderedIntermediates, lastIndex];
  }

  /// Mapeia o texto dos endereços retornados pelo OpenAI (que podem conter diferenças leves) aos textos originais da lista.
  List<String> _mapOpenAiAddressesToOriginals({
    required List<String> originalAddresses,
    required List<String> returnedAddresses,
  }) {
    if (returnedAddresses.length != originalAddresses.length &&
        returnedAddresses.length != originalAddresses.length + 1) {
      throw const FormatException(
          'A OpenAI retornou quantidade de paradas inválida.');
    }

    final origin = originalAddresses.first;
    final originKey = _addressKey(origin);
    final remainingIntermediates = <String, List<String>>{};
    for (final address in originalAddresses.sublist(1)) {
      remainingIntermediates
          .putIfAbsent(_addressKey(address), () => <String>[])
          .add(address);
    }

    final mapped = <String>[];
    for (var i = 0; i < returnedAddresses.length; i++) {
      final key = _addressKey(returnedAddresses[i]);
      if ((i == 0 || i == returnedAddresses.length - 1) && key == originKey) {
        mapped.add(origin);
        continue;
      }

      final candidates = remainingIntermediates[key];
      if (candidates == null || candidates.isEmpty) {
        throw const FormatException('A OpenAI alterou os endereços da rota.');
      }

      mapped.add(candidates.removeAt(0));
    }

    return mapped;
  }

  /// Garante que todos os endereços originais foram mantidos na rota reordenada gerada pelo OpenAI.
  void _validateOpenAiRoute({
    required List<String> originalAddresses,
    required List<String> orderedAddresses,
  }) {
    if (orderedAddresses.length != originalAddresses.length) {
      throw const FormatException(
          'A OpenAI retornou quantidade de paradas inválida.');
    }

    if (orderedAddresses.first != originalAddresses.first) {
      throw const FormatException('A OpenAI não preservou a origem da rota.');
    }

    if (orderedAddresses.last != originalAddresses.last) {
      throw const FormatException('A OpenAI não preservou o destino da rota.');
    }

    final originalIntermediates =
        originalAddresses.sublist(1, originalAddresses.length - 1);
    final returnedIntermediates =
        orderedAddresses.sublist(1, orderedAddresses.length - 1);
    if (!_sameAddressBag(originalIntermediates, returnedIntermediates)) {
      throw const FormatException('A OpenAI alterou os endereços da rota.');
    }
  }

  /// Verifica se duas listas de endereços contêm exatamente os mesmos itens, independente da ordem.
  bool _sameAddressBag(List<String> left, List<String> right) {
    if (left.length != right.length) return false;

    final counts = <String, int>{};
    for (final address in left) {
      counts.update(address, (value) => value + 1, ifAbsent: () => 1);
    }

    for (final address in right) {
      final current = counts[address];
      if (current == null) return false;
      if (current == 1) {
        counts.remove(address);
      } else {
        counts[address] = current - 1;
      }
    }

    return counts.isEmpty;
  }

  /// Gera uma chave de normalização de endereço para fins de mapeamento tolerante a formatações.
  String _addressKey(String address) {
    const replacements = {
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
    };

    final buffer = StringBuffer();
    for (final codeUnit in address.toLowerCase().codeUnits) {
      final char = String.fromCharCode(codeUnit);
      buffer.write(replacements[char] ?? char);
    }

    return buffer
        .toString()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Extrai a mensagem de erro da resposta decodificada do Google Directions API.
  String _extractGoogleStatusMessage(
      Map<String, dynamic> decoded, String status) {
    final errorMessage = decoded['error_message'];
    if (errorMessage is String && errorMessage.trim().isNotEmpty) {
      return errorMessage;
    }

    if (status.isNotEmpty) {
      return 'Google Directions retornou $status.';
    }

    return 'Google Directions não retornou uma rota válida.';
  }

  /// Verifica se o status retornado pelo Google indica endereço não encontrado ou rota inexistente.
  bool _isGoogleAddressNotFoundStatus(String status) {
    return status == 'ZERO_RESULTS' || status == 'NOT_FOUND';
  }

  /// Formata segundos inteiros em uma string amigável de duração de trânsito.
  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}min';
    }
    if (minutes > 0) {
      return '${minutes}min';
    }
    return '${seconds}s';
  }
}

/// Representa o resultado interno de uma tentativa de otimização no Google.
enum _GoogleOptimizationAttemptKind {
  success,
  failed,
  addressNotFound,
}

class _GoogleOptimizationAttempt {
  const _GoogleOptimizationAttempt._({
    required this.kind,
    this.route,
    this.message,
  });

  const _GoogleOptimizationAttempt.success(OptimizedRoute route)
      : this._(
          kind: _GoogleOptimizationAttemptKind.success,
          route: route,
        );

  const _GoogleOptimizationAttempt.failed(String message)
      : this._(
          kind: _GoogleOptimizationAttemptKind.failed,
          message: message,
        );

  const _GoogleOptimizationAttempt.addressNotFound(String message)
      : this._(
          kind: _GoogleOptimizationAttemptKind.addressNotFound,
          message: message,
        );

  final _GoogleOptimizationAttemptKind kind;
  final OptimizedRoute? route;
  final String? message;
}
