import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rotaotimizada/domain/app_failure.dart';
import 'package:rotaotimizada/services/api_service.dart';
import 'package:rotaotimizada/state/app_state.dart';

AppState _createState({http.Client? client}) {
  return AppState(
    apiService: ApiService(
      client: client ??
          MockClient((_) async {
            return http.Response('{}', 200);
          }),
      googleMapsApiKey: 'google-key',
      openAiApiKey: 'openai-key',
    ),
  );
}

void main() {
  group('AppState.setAddresses', () {
    test('normalizes and stores addresses', () {
      final state = _createState();
      state.setAddresses([' Rua A ', '', 'Rua B']);
      expect(state.addresses, ['Rua A', 'Rua B']);
    });

    test('produces unmodifiable list', () {
      final state = _createState();
      state.setAddresses(['Rua A']);
      expect(
        () => (state.addresses as List).add('X'),
        throwsUnsupportedError,
      );
    });

    test('notifies listeners', () {
      final state = _createState();
      var notified = false;
      state.addListener(() => notified = true);
      state.setAddresses(['Rua A']);
      expect(notified, isTrue);
    });
  });

  group('AppState.clearRoute', () {
    test('sets optimizedRoute to null and notifies', () {
      final state = _createState();
      var notified = false;
      state.addListener(() => notified = true);
      state.clearRoute();
      expect(state.optimizedRoute, isNull);
      expect(notified, isTrue);
    });
  });

  group('AppState.optimizeRoute', () {
    test('throws validation when less than 2 addresses', () {
      final state = _createState();
      expect(
        () => state.optimizeRoute(['Rua A']),
        throwsA(
          isA<AppFailure>()
              .having((f) => f.kind, 'kind', AppFailureKind.validation),
        ),
      );
    });

    test('throws validation on empty list', () {
      final state = _createState();
      expect(
        () => state.optimizeRoute([]),
        throwsA(
          isA<AppFailure>()
              .having((f) => f.kind, 'kind', AppFailureKind.validation),
        ),
      );
    });

    test('stores optimized route on success', () async {
      final client = MockClient((request) async {
        expect(request.url.host, 'routes.googleapis.com');
        return http.Response(
          jsonEncode({
            'routes': [
              {
                'duration': '600s',
                'distanceMeters': 1200,
              },
            ],
          }),
          200,
        );
      });

      final state = _createState(client: client);
      await state.optimizeRoute(['Rua A', 'Rua B']);

      expect(state.optimizedRoute, isNotNull);
      expect(state.optimizedRoute!.stops.length, 2);
      expect(state.optimizedRoute!.stops.first.address, 'Rua A');
      expect(state.optimizedRoute!.stops.last.address, 'Rua B');
      expect(state.optimizedRoute!.totalTime, '10min');
    });

    test('notifies listeners on success', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'routes': [
              {
                'duration': '60s',
                'distanceMeters': 500,
              },
            ],
          }),
          200,
        );
      });

      final state = _createState(client: client);
      var notified = false;
      state.addListener(() => notified = true);
      await state.optimizeRoute(['A', 'B']);
      expect(notified, isTrue);
    });

    test('normalizes addresses before sending', () async {
      Map<String, dynamic>? requestBody;
      final client = MockClient((request) async {
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'routes': [
              {
                'duration': '60s',
                'distanceMeters': 500,
              },
            ],
          }),
          200,
        );
      });

      final state = _createState(client: client);
      await state.optimizeRoute([' A ', ' B ', '']);

      expect(requestBody, isNotNull);
      expect(requestBody!['origin'], {'address': 'A'});
      expect(requestBody!['destination'], {'address': 'B'});
      expect(requestBody!.containsKey('intermediates'), isFalse);
    });

    test('stores route from OpenAI fallback when Google fails', () async {
      final client = MockClient((request) async {
        if (request.url.host == 'routes.googleapis.com') {
          return http.Response('unavailable', 503);
        }

        return http.Response(
          jsonEncode({
            'output': [
              {
                'type': 'message',
                'content': [
                  {
                    'type': 'output_text',
                    'text': jsonEncode({
                      'totalTime': 'Estimado 20 min',
                      'totalDistance': 'Estimado 6 km',
                      'stops': [
                        {'address': 'Rua A'},
                        {'address': 'Rua B'},
                      ],
                    }),
                  },
                ],
              },
            ],
          }),
          200,
        );
      });

      final state = _createState(client: client);
      await state.optimizeRoute(['Rua A', 'Rua B']);

      expect(state.optimizedRoute, isNotNull);
      expect(
        state.optimizedRoute!.stops.map((stop) => stop.address).toList(),
        ['Rua A', 'Rua B'],
      );
      expect(state.optimizedRoute!.totalTime, 'Estimado 20 min');
    });
  });
}
