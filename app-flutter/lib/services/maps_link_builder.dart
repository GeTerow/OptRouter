import '../domain/optimized_route.dart';

class MapsLinkBuilder {
  const MapsLinkBuilder._();

  static String googleDirectionsUrl(OptimizedRoute route) {
    if (route.mapsUrl.isNotEmpty) return route.mapsUrl;

    final stops = route.stops;
    if (stops.isEmpty) return 'https://www.google.com/maps';

    final query = <String, String>{
      'api': '1',
      'origin': stops.first.address,
      'destination': stops.last.address,
    };

    if (stops.length > 2) {
      query['waypoints'] = stops
          .sublist(1, stops.length - 1)
          .map((stop) => stop.address)
          .join('|');
    }

    return Uri.https('www.google.com', '/maps/dir/', query).toString();
  }
}
