import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rotaotimizada/domain/app_failure.dart';
import 'package:rotaotimizada/services/api_service.dart';

ApiService _createService(
  MockClient client, {
  String googleMapsApiKey = 'google-key',
  String openAiApiKey = 'openai-key',
  String openAiRouteModel = 'gpt-4o-mini',
  String openAiScanModel = 'gpt-4o',
}) {
  return ApiService(
    client: client,
    googleMapsApiKey: googleMapsApiKey,
    openAiApiKey: openAiApiKey,
    openAiRouteModel: openAiRouteModel,
    openAiScanModel: openAiScanModel,
  );
}

http.Response _openAiStructuredResponse(Map<String, dynamic> payload) {
  return http.Response(
    jsonEncode({
      'output': [
        {
          'type': 'message',
          'content': [
            {
              'type': 'output_text',
              'text': jsonEncode(payload),
            },
          ],
        },
      ],
    }),
    200,
  );
}

void main() {
  group('ApiService.scanAddressImageBytes', () {
    test('returns extracted addresses from OpenAI structured output', () async {
      final client = MockClient((request) async {
        expect(request.url.host, 'api.openai.com');
        expect(request.url.path, '/v1/responses');
        expect(request.method, 'POST');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], 'scan-model');

        final input = body['input'] as List<dynamic>;
        final content =
            (input.first as Map<String, dynamic>)['content'] as List<dynamic>;
        final imagePart = content[1] as Map<String, dynamic>;
        expect(imagePart['type'], 'input_image');
        expect(
            (imagePart['image_url'] as String)
                .startsWith('data:image/png;base64,'),
            isTrue);

        return _openAiStructuredResponse({
          'addresses': [' Rua A ', 'Rua B', ''],
        });
      });

      final service = _createService(
        client,
        googleMapsApiKey: '',
        openAiScanModel: 'scan-model',
      );

      final addresses = await service.scanAddressImageBytes(
        Uint8List.fromList([1, 2, 3]),
        filename: 'capture.png',
      );

      expect(addresses, ['Rua A', 'Rua B']);
    });

    test('throws invalidResponse when OpenAI structured output is invalid',
        () async {
      final client = MockClient((request) async {
        return _openAiStructuredResponse({
          'unexpected': true,
        });
      });

      final service = _createService(
        client,
        googleMapsApiKey: '',
      );

      expect(
        () => service.scanAddressImageBytes(
          Uint8List.fromList([1, 2, 3]),
          filename: 'capture.jpg',
        ),
        throwsA(
          isA<AppFailure>()
              .having((f) => f.kind, 'kind', AppFailureKind.invalidResponse),
        ),
      );
    });
  });

  group('ApiService.optimizeRoute', () {
    test('returns Google-optimized route on valid response', () async {
      final client = MockClient((request) async {
        expect(request.url.host, 'routes.googleapis.com');
        expect(request.url.path, '/directions/v2:computeRoutes');
        expect(request.method, 'POST');
        expect(request.headers['X-Goog-Api-Key'], 'google-key');
        expect(
          request.headers['X-Goog-FieldMask'],
          'routes.duration,routes.distanceMeters,routes.optimizedIntermediateWaypointIndex',
        );

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['origin'], {'address': 'Origem'});
        expect(body['destination'], {'address': 'Destino C'});
        expect(body['travelMode'], 'DRIVE');
        expect(body['languageCode'], 'pt-BR');
        expect(body['units'], 'METRIC');
        expect(body['optimizeWaypointOrder'], true);
        expect(body['routingPreference'], 'TRAFFIC_AWARE');
        expect(
          DateTime.parse(body['departureTime'] as String).isUtc,
          isTrue,
        );
        expect(
          body['intermediates'],
          [
            {'address': 'Destino A'},
            {'address': 'Destino B'},
          ],
        );

        return http.Response(
          jsonEncode({
            'routes': [
              {
                'optimizedIntermediateWaypointIndex': [1, 0],
                'duration': '2100s',
                'distanceMeters': 7500,
              },
            ],
          }),
          200,
        );
      });

      final service = _createService(client);
      final route = await service.optimizeRoute([
        'Origem',
        'Destino A',
        'Destino B',
        'Destino C',
      ]);

      expect(
        route.stops.map((stop) => stop.address).toList(),
        ['Origem', 'Destino B', 'Destino A', 'Destino C'],
      );
      expect(route.totalTime, '35min');
      expect(route.totalDistance, '7.5 km');
      expect(route.numberOfStops, 4);
      expect(route.mapsUrl, isNotEmpty);
    });

    test('does not request waypoint optimization for one intermediate',
        () async {
      final client = MockClient((request) async {
        expect(
          request.headers['X-Goog-FieldMask'],
          'routes.duration,routes.distanceMeters',
        );

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['routingPreference'], 'TRAFFIC_AWARE');
        expect(body['intermediates'], [
          {'address': 'Destino A'},
        ]);
        expect(body.containsKey('optimizeWaypointOrder'), isFalse);
        expect(
          DateTime.parse(body['departureTime'] as String).isUtc,
          isTrue,
        );

        return http.Response(
          jsonEncode({
            'routes': [
              {
                'duration': '1500s',
                'distanceMeters': 5000,
              },
            ],
          }),
          200,
        );
      });

      final service = _createService(client);
      final route = await service.optimizeRoute([
        'Origem',
        'Destino A',
        'Destino B',
      ]);

      expect(
        route.stops.map((stop) => stop.address).toList(),
        ['Origem', 'Destino A', 'Destino B'],
      );
    });

    test('falls back to OpenAI when Google request fails', () async {
      final client = MockClient((request) async {
        if (request.url.host == 'routes.googleapis.com') {
          return http.Response('gateway error', 502);
        }

        expect(request.url.host, 'api.openai.com');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], 'fallback-model');
        final text = body['text'] as Map<String, dynamic>;
        final format = text['format'] as Map<String, dynamic>;
        final schema = format['schema'] as Map<String, dynamic>;
        final properties = schema['properties'] as Map<String, dynamic>;
        final stops = properties['stops'] as Map<String, dynamic>;
        final items = stops['items'] as Map<String, dynamic>;
        final stopProperties = items['properties'] as Map<String, dynamic>;
        expect(stopProperties.keys, contains('originalIndex'));

        return _openAiStructuredResponse({
          'totalTime': 'Estimado 35 min',
          'totalDistance': 'Estimado 8 km',
          'stops': [
            {'originalIndex': 1},
            {'originalIndex': 3},
            {'originalIndex': 2},
          ],
        });
      });

      final service = _createService(
        client,
        openAiRouteModel: 'fallback-model',
      );

      final route = await service.optimizeRoute([
        'Origem',
        'Destino A',
        'Destino B',
      ]);

      expect(
        route.stops.map((stop) => stop.address).toList(),
        ['Origem', 'Destino A', 'Destino B'],
      );
      expect(route.totalTime, 'Estimado 35 min');
      expect(route.totalDistance, 'Estimado 8 km');
    });

    test('preserves original address text when OpenAI returns indexes',
        () async {
      final client = MockClient((request) async {
        if (request.url.host == 'routes.googleapis.com') {
          return http.Response('gateway error', 502);
        }

        return _openAiStructuredResponse({
          'totalTime': 'Estimado 40 min',
          'totalDistance': 'Estimado 12 km',
          'stops': [
            {'originalIndex': 1},
            {'originalIndex': 3},
            {'originalIndex': 2},
          ],
        });
      });

      final service = _createService(client);
      final route = await service.optimizeRoute([
        'Rua São João, 10 - Centro',
        'Av. Brasil, 200',
        'Praça XV, 5',
      ]);

      expect(
        route.stops.map((stop) => stop.address).toList(),
        [
          'Rua São João, 10 - Centro',
          'Av. Brasil, 200',
          'Praça XV, 5',
        ],
      );
    });

    test('repairs OpenAI index route when it omits stops or returns extras',
        () async {
      final client = MockClient((request) async {
        if (request.url.host == 'routes.googleapis.com') {
          return http.Response('gateway error', 502);
        }

        return _openAiStructuredResponse({
          'totalTime': 'Estimado 40 min',
          'totalDistance': 'Estimado 12 km',
          'stops': [
            {'originalIndex': 1},
            {'originalIndex': 3},
            {'originalIndex': 99},
            {'originalIndex': 3},
            {'originalIndex': 4},
          ],
        });
      });

      final service = _createService(client);
      final route = await service.optimizeRoute([
        'Origem',
        'Destino A',
        'Destino B',
        'Destino C',
      ]);

      expect(
        route.stops.map((stop) => stop.address).toList(),
        ['Origem', 'Destino B', 'Destino A', 'Destino C'],
      );
    });

    test('accepts legacy OpenAI addresses with harmless text differences',
        () async {
      final client = MockClient((request) async {
        if (request.url.host == 'routes.googleapis.com') {
          return http.Response('gateway error', 502);
        }

        return _openAiStructuredResponse({
          'totalTime': 'Estimado 40 min',
          'totalDistance': 'Estimado 12 km',
          'stops': [
            {'address': 'rua sao joao 10 centro'},
            {'address': 'praca xv 5'},
            {'address': 'av brasil 200'},
          ],
        });
      });

      final service = _createService(client);
      final route = await service.optimizeRoute([
        'Rua São João, 10 - Centro',
        'Av. Brasil, 200',
        'Praça XV, 5',
      ]);

      expect(
        route.stops.map((stop) => stop.address).toList(),
        [
          'Rua São João, 10 - Centro',
          'Av. Brasil, 200',
          'Praça XV, 5',
        ],
      );
    });

    test('throws configuration when both API keys are missing', () async {
      final service = _createService(
        MockClient((_) async => http.Response('', 500)),
        googleMapsApiKey: '',
        openAiApiKey: '',
      );

      expect(
        () => service.optimizeRoute(['A', 'B']),
        throwsA(
          isA<AppFailure>()
              .having((f) => f.kind, 'kind', AppFailureKind.configuration),
        ),
      );
    });

    test(
        'throws addressNotFound when Google finds no route and fallback is invalid',
        () async {
      final client = MockClient((request) async {
        if (request.url.host == 'routes.googleapis.com') {
          return http.Response(
            jsonEncode({
              'routes': [],
            }),
            200,
          );
        }

        return _openAiStructuredResponse({
          'totalTime': 'Estimado 10 min',
          'totalDistance': 'Estimado 3 km',
          'stops': [
            {'address': 'Origem'},
            {'address': 'Invalido'},
          ],
        });
      });

      final service = _createService(client);

      expect(
        () => service.optimizeRoute(['Origem', 'Destino A']),
        throwsA(
          isA<AppFailure>()
              .having((f) => f.kind, 'kind', AppFailureKind.addressNotFound),
        ),
      );
    });
  });
}
