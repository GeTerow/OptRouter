import 'package:flutter_test/flutter_test.dart';
import 'package:rotaotimizada/domain/optimized_route.dart';
import 'package:rotaotimizada/domain/stop.dart';
import 'package:rotaotimizada/services/maps_link_builder.dart';

void main() {
  group('MapsLinkBuilder', () {
    test('builds Google Maps directions URL with origin destination and waypoints', () {
      const route = OptimizedRoute(
        stops: [
          Stop(address: 'Rua A, São Paulo'),
          Stop(address: 'Rua B, São Paulo'),
          Stop(address: 'Rua C, São Paulo'),
        ],
        totalTime: '10 min',
        totalDistance: '3 km',
        numberOfStops: 3,
      );

      final uri = Uri.parse(MapsLinkBuilder.googleDirectionsUrl(route));

      expect(uri.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/dir/');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['origin'], 'Rua A, São Paulo');
      expect(uri.queryParameters['destination'], 'Rua C, São Paulo');
      expect(uri.queryParameters['waypoints'], 'Rua B, São Paulo');
    });

    test('returns generic Maps URL when route has no stops', () {
      const route = OptimizedRoute(
        stops: [],
        totalTime: '',
        totalDistance: '',
        numberOfStops: 0,
      );

      expect(
        MapsLinkBuilder.googleDirectionsUrl(route),
        'https://www.google.com/maps',
      );
    });

    test('uses backend mapsUrl when available', () {
      const route = OptimizedRoute(
        stops: [
          Stop(address: 'Rua A, São Paulo'),
          Stop(address: 'Rua B, São Paulo'),
        ],
        totalTime: '10 min',
        totalDistance: '3 km',
        numberOfStops: 2,
        mapsUrl: 'https://www.google.com/maps/dir/?api=1&origin=A',
      );

      expect(
        MapsLinkBuilder.googleDirectionsUrl(route),
        'https://www.google.com/maps/dir/?api=1&origin=A',
      );
    });
  });
}
