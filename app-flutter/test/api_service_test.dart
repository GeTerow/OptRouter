import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rotaotimizada/domain/app_failure.dart';
import 'package:rotaotimizada/services/api_service.dart';

void main() {
  group('ApiService.optimizeRoute', () {
    test('returns OptimizedRoute on valid 200 response', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/optimize');
        return http.Response(
          jsonEncode({
            'stops': [
              {'address': 'Rua A'},
              {'address': 'Rua B'},
            ],
            'totalTime': '15 min',
            'totalDistance': '5 km',
            'numberOfStops': 2,
          }),
          200,
        );
      });

      final service = ApiService(client: client);
      final route = await service.optimizeRoute(['Rua A', 'Rua B']);

      expect(route.stops.length, 2);
      expect(route.stops[0].address, 'Rua A');
      expect(route.totalTime, '15 min');
      expect(route.totalDistance, '5 km');
      expect(route.numberOfStops, 2);
    });

    test('throws AppFailure with server kind on HTTP 500', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Internal error'}),
          500,
        );
      });

      final service = ApiService(client: client);

      expect(
        () => service.optimizeRoute(['Rua A', 'Rua B']),
        throwsA(
          isA<AppFailure>()
              .having((f) => f.kind, 'kind', AppFailureKind.server),
        ),
      );
    });

    test('throws AppFailure with addressNotFound on known error message',
        () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'message':
                'Nenhum resultado retornado pela API do Google Maps para ...',
          }),
          400,
        );
      });

      final service = ApiService(client: client);

      expect(
        () => service.optimizeRoute(['Rua Inexistente']),
        throwsA(
          isA<AppFailure>()
              .having((f) => f.kind, 'kind', AppFailureKind.addressNotFound),
        ),
      );
    });

    test('throws AppFailure with invalidResponse on malformed JSON', () async {
      final client = MockClient((request) async {
        return http.Response('not json at all', 200);
      });

      final service = ApiService(client: client);

      expect(
        () => service.optimizeRoute(['Rua A', 'Rua B']),
        throwsA(
          isA<AppFailure>()
              .having((f) => f.kind, 'kind', AppFailureKind.invalidResponse),
        ),
      );
    });

    test('throws AppFailure with network kind on ClientException', () async {
      final client = MockClient((request) async {
        throw http.ClientException('Connection refused');
      });

      final service = ApiService(client: client);

      expect(
        () => service.optimizeRoute(['Rua A', 'Rua B']),
        throwsA(
          isA<AppFailure>()
              .having((f) => f.kind, 'kind', AppFailureKind.network),
        ),
      );
    });

    test('includes statusCode in AppFailure on HTTP error', () async {
      final client = MockClient((request) async {
        return http.Response('', 502);
      });

      final service = ApiService(client: client);

      expect(
        () => service.optimizeRoute(['A', 'B']),
        throwsA(
          isA<AppFailure>()
              .having((f) => f.statusCode, 'statusCode', 502),
        ),
      );
    });
  });
}
