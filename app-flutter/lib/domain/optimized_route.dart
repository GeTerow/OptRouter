import 'package:flutter/foundation.dart';
import 'stop.dart';


class OptimizedRoute {
  const OptimizedRoute({
    required this.stops,
    required this.totalTime,
    required this.totalDistance,
    required this.numberOfStops,
    this.mapsUrl = '',
  });

  final List<Stop> stops;
  final String totalTime;
  final String totalDistance;
  final int numberOfStops;

  /// URL de direções do Google Maps (pode vir vazia; nesse caso é gerada localmente).
  final String mapsUrl;

  factory OptimizedRoute.fromJson(Map<String, dynamic> json) {
    final rawStops = json['stops'];
    if (rawStops is! List) {
      throw const FormatException('Resposta inválida do /optimize.');
    }

    return OptimizedRoute(
      stops: rawStops
          .whereType<Map>()
          .map((stop) => Stop.fromJson(Map<String, dynamic>.from(stop)))
          .where((stop) => stop.address.isNotEmpty)
          .toList(),
      totalTime: (json['totalTime'] as String?) ?? '',
      totalDistance: (json['totalDistance'] as String?) ?? '',
      numberOfStops: (json['numberOfStops'] as num?)?.toInt() ?? 0,
      mapsUrl: (json['mapsUrl'] as String?)?.trim() ?? '',
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! OptimizedRoute) return false;

    return listEquals(stops, other.stops) &&
        totalTime == other.totalTime &&
        totalDistance == other.totalDistance &&
        numberOfStops == other.numberOfStops &&
        mapsUrl == other.mapsUrl;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(stops),
        totalTime,
        totalDistance,
        numberOfStops,
        mapsUrl,
      );
}
