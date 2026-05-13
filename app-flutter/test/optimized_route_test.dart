import 'package:flutter_test/flutter_test.dart';
import 'package:rotaotimizada/domain/optimized_route.dart';

void main() {
  group('OptimizedRoute', () {
    test('fromJson maps backend contract and removes empty stops', () {
      final route = OptimizedRoute.fromJson({
        'stops': [
          {'address': ' Rua A '},
          {'address': ''},
          {'address': 'Rua B'},
        ],
        'totalTime': '20 min',
        'totalDistance': '8 km',
        'numberOfStops': 2,
        'mapsUrl': 'https://www.google.com/maps/dir/?api=1',
      });

      expect(
        route.stops.map((stop) => stop.address).toList(),
        ['Rua A', 'Rua B'],
      );
      expect(route.totalTime, '20 min');
      expect(route.totalDistance, '8 km');
      expect(route.numberOfStops, 2);
      expect(route.mapsUrl, 'https://www.google.com/maps/dir/?api=1');
    });

    test('fromJson rejects invalid stops contract', () {
      expect(
        () => OptimizedRoute.fromJson({'stops': null}),
        throwsFormatException,
      );
    });
  });
}
