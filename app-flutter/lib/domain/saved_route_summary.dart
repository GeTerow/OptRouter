class SavedRouteSummary {
  const SavedRouteSummary({
    required this.id,
    required this.title,
    required this.origin,
    required this.destination,
    required this.addressOrder,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String origin;
  final String destination;
  final List<String> addressOrder;
  final DateTime? updatedAt;

  int get stopCount => addressOrder.length;
}
