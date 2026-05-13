import 'package:flutter_test/flutter_test.dart';
import 'package:rotaotimizada/domain/app_failure.dart';

void main() {
  group('AppFailure', () {
    test('userMessage returns custom message for validation kind', () {
      const failure = AppFailure(
        kind: AppFailureKind.validation,
        message: 'Custom validation message',
      );
      expect(failure.userMessage, 'Custom validation message');
    });

    test('userMessage returns fixed message for addressNotFound kind', () {
      const failure = AppFailure(
        kind: AppFailureKind.addressNotFound,
        message: 'ignored',
      );
      expect(
        failure.userMessage,
        contains('Impossível otimizar'),
      );
    });

    test('userMessage returns fixed message for network kind', () {
      const failure = AppFailure(
        kind: AppFailureKind.network,
        message: 'ignored',
      );
      expect(failure.userMessage, contains('conexão'));
    });

    test('userMessage returns fixed message for timeout kind', () {
      const failure = AppFailure(
        kind: AppFailureKind.timeout,
        message: 'ignored',
      );
      expect(failure.userMessage, contains('demorou'));
    });

    test('userMessage returns fixed message for invalidResponse kind', () {
      const failure = AppFailure(
        kind: AppFailureKind.invalidResponse,
        message: 'ignored',
      );
      expect(failure.userMessage, contains('resposta inválida'));
    });

    test('userMessage returns fixed message for server kind', () {
      const failure = AppFailure(
        kind: AppFailureKind.server,
        message: 'ignored',
      );
      expect(failure.userMessage, contains('processar'));
    });

    test('userMessage returns fixed message for unknown kind', () {
      const failure = AppFailure(
        kind: AppFailureKind.unknown,
        message: 'ignored',
      );
      expect(failure.userMessage, contains('concluir'));
    });

    test('toString prefers technicalMessage when available', () {
      const failure = AppFailure(
        kind: AppFailureKind.server,
        message: 'user-facing',
        technicalMessage: 'HTTP 500: internal',
      );
      expect(failure.toString(), 'HTTP 500: internal');
    });

    test('toString falls back to message when no technicalMessage', () {
      const failure = AppFailure(
        kind: AppFailureKind.server,
        message: 'user-facing',
      );
      expect(failure.toString(), 'user-facing');
    });

    test('equality works by value', () {
      const a = AppFailure(
        kind: AppFailureKind.server,
        message: 'msg',
        statusCode: 500,
      );
      const b = AppFailure(
        kind: AppFailureKind.server,
        message: 'msg',
        statusCode: 500,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  });
}
