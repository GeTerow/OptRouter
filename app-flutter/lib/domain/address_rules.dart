class AddressRules {
  const AddressRules._();

  static List<String> parseLines(String value) {
    return value
        .split('\n')
        .map((address) => address.trim())
        .where((address) => address.isNotEmpty)
        .toList();
  }

  static List<String> buildRouteAddresses({
    required String addressesText,
    required String startAddress,
  }) {
    final normalizedStart = startAddress.trim();
    final stopAddresses = parseLines(addressesText)
        .where((a) => a.toLowerCase() != normalizedStart.toLowerCase())
        .toList();

    final String finalStart;
    final List<String> finalStops;

    if (normalizedStart.isNotEmpty) {
      finalStart = normalizedStart;
      finalStops = stopAddresses;
    } else if (stopAddresses.isNotEmpty) {
      finalStart = stopAddresses.first;
      finalStops = stopAddresses.sublist(1);
    } else {
      return [];
    }

    return [finalStart, ...finalStops]
        .map((address) => address.trim())
        .where((address) => address.isNotEmpty)
        .toList();
  }

  static List<String> mergeUnique(
    Iterable<String> current,
    Iterable<String> incoming,
  ) {
    final seen = <String>{};
    return [
      for (final a in _normalize(current))
        if (seen.add(a.toLowerCase())) a,
      for (final a in _normalize(incoming))
        if (seen.add(a.toLowerCase())) a,
    ];
  }

  static List<String> normalize(Iterable<String> addresses) {
    return _normalize(addresses).toList();
  }

  static Iterable<String> _normalize(Iterable<String> addresses) {
    return addresses
        .map((address) => address.trim())
        .where((address) => address.isNotEmpty);
  }
}
