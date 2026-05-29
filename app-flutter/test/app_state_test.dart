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
        expect(request.url.host, 'maps.googleapis.com');
        return http.Response(
          jsonEncode({
            'status': 'OK',
            'routes': [
              {
                'waypoint_order': [0],
                'legs': [
                  {
                    'duration': {'value': 600},
                    'distance': {'value': 1200},
                  },
                  {
                    'duration': {'value': 900},
                    'distance': {'value': 1800},
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
      expect(state.optimizedRoute!.stops.length, 3);
      expect(state.optimizedRoute!.stops.first.address, 'Rua A');
      expect(state.optimizedRoute!.stops.last.address, 'Rua A');
      expect(state.optimizedRoute!.totalTime, '25min');
    });

    test('notifies listeners on success', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status': 'OK',
            'routes': [
              {
                'waypoint_order': [0],
                'legs': [
                  {
                    'duration': {'value': 60},
                    'distance': {'value': 500},
                  },
                  {
                    'duration': {'value': 60},
                    'distance': {'value': 500},
                  },
                ],
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
      Uri? requestUri;
      final client = MockClient((request) async {
        requestUri = request.url;
        return http.Response(
          jsonEncode({
            'status': 'OK',
            'routes': [
              {
                'waypoint_order': [0],
                'legs': [
                  {
                    'duration': {'value': 60},
                    'distance': {'value': 500},
                  },
                  {
                    'duration': {'value': 60},
                    'distance': {'value': 500},
                  },
                ],
              },
            ],
          }),
          200,
        );
      });

      final state = _createState(client: client);
      await state.optimizeRoute([' A ', ' B ', '']);

      expect(requestUri, isNotNull);
      expect(requestUri!.queryParameters['origin'], 'A');
      expect(requestUri!.queryParameters['destination'], 'A');
      expect(requestUri!.queryParameters['waypoints'], 'optimize:true|B');
    });

    test('stores route from OpenAI fallback when Google fails', () async {
      final client = MockClient((request) async {
        if (request.url.host == 'maps.googleapis.com') {
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
                        {'address': 'Rua A'},
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
        ['Rua A', 'Rua B', 'Rua A'],
      );
      expect(state.optimizedRoute!.totalTime, 'Estimado 20 min');
    });
  });
}
