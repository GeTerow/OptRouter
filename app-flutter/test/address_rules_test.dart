import 'package:flutter_test/flutter_test.dart';
import 'package:rotaotimizada/domain/address_rules.dart';

void main() {
  group('AddressRules', () {
    test('parseLines trims values and removes empty lines', () {
      expect(
        AddressRules.parseLines(' Rua A \n\nRua B\n  '),
        ['Rua A', 'Rua B'],
      );
    });

    test('parseLines returns empty list for blank input', () {
      expect(AddressRules.parseLines('   \n  \n  '), isEmpty);
    });

    test('buildRouteAddresses uses explicit start and removes it from stops',
        () {
      expect(
        AddressRules.buildRouteAddresses(
          addressesText: 'Rua A\nRua B\nRua C',
          startAddress: 'Rua B',
        ),
        ['Rua B', 'Rua A', 'Rua C'],
      );
    });

    test('buildRouteAddresses uses first stop when start is empty', () {
      expect(
        AddressRules.buildRouteAddresses(
          addressesText: 'Rua A\nRua B',
          startAddress: '',
        ),
        ['Rua A', 'Rua B'],
      );
    });

    test('buildRouteAddresses returns empty list for blank input', () {
      expect(
        AddressRules.buildRouteAddresses(
          addressesText: '',
          startAddress: '',
        ),
        isEmpty,
      );
    });

    test('buildRouteAddresses returns empty list for single whitespace-only address', () {
      expect(
        AddressRules.buildRouteAddresses(
          addressesText: '   ',
          startAddress: '',
        ),
        isEmpty,
      );
    });

    test('buildRouteAddresses with single address and no start returns that address', () {
      expect(
        AddressRules.buildRouteAddresses(
          addressesText: 'Rua A',
          startAddress: '',
        ),
        ['Rua A'],
      );
    });

    test('buildRouteAddresses removes start case-insensitively', () {
      expect(
        AddressRules.buildRouteAddresses(
          addressesText: 'rua b\nRua C',
          startAddress: 'Rua B',
        ),
        ['Rua B', 'Rua C'],
      );
    });

    test('mergeUnique trims values and preserves first occurrence order', () {
      expect(
        AddressRules.mergeUnique([' Rua A ', 'Rua B'], ['Rua B', ' Rua C ']),
        ['Rua A', 'Rua B', 'Rua C'],
      );
    });

    test('mergeUnique deduplicates case-insensitively preserving first casing',
        () {
      expect(
        AddressRules.mergeUnique(['Rua A'], ['rua a', 'Rua B']),
        ['Rua A', 'Rua B'],
      );
    });

    test('mergeUnique returns empty for two empty iterables', () {
      expect(AddressRules.mergeUnique([], []), isEmpty);
    });

    test('normalize trims and removes empty strings', () {
      expect(
        AddressRules.normalize([' Rua A ', '', '  ', 'Rua B']),
        ['Rua A', 'Rua B'],
      );
    });
  });
}
