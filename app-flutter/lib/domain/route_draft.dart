class RouteDraft {
  const RouteDraft({
    required this.origin,
    required this.destination,
    required this.stops,
  });

  final String origin;
  final String destination;
  final List<String> stops;

  List<String> get orderedAddresses => [
        origin,
        ...stops,
        destination,
      ];

  String get title {
    if (destination.isEmpty) return 'Nova rota';
    return destination;
  }
}
