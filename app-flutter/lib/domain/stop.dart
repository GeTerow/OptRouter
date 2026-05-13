class Stop {
  const Stop({required this.address});

  final String address;

  factory Stop.fromJson(Map<String, dynamic> json) {
    return Stop(address: (json['address'] as String?)?.trim() ?? '');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Stop && other.address == address;

  @override
  int get hashCode => address.hashCode;
}
