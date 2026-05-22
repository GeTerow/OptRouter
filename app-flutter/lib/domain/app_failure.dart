
enum AppFailureKind {
  validation,
  network,
  timeout,
  invalidResponse,
  server,
  addressNotFound,
  unknown,
}

/// Erro tipado que substitui exceções genéricas.
class AppFailure implements Exception {
  const AppFailure({
    required this.kind,
    required this.message,
    this.statusCode,
    this.technicalMessage,
  });

  final AppFailureKind kind;
  final String message;
  final int? statusCode;
  final String? technicalMessage;

  String get userMessage {
    return switch (kind) {
      AppFailureKind.validation => message,
      AppFailureKind.addressNotFound =>
        'Impossível otimizar. Um ou mais endereços não foram encontrados, verifique e tente novamente.',
      AppFailureKind.network =>
        'Não foi possível conectar ao servidor. Verifique sua conexão e tente novamente.',
      AppFailureKind.timeout =>
        'A conexão com o servidor demorou demais. Tente novamente.',
      AppFailureKind.invalidResponse =>
        'O servidor retornou uma resposta inválida. Tente novamente.',
      AppFailureKind.server =>
        'O servidor não conseguiu processar a solicitação. Tente novamente.',
      AppFailureKind.unknown =>
        'Não foi possível concluir a operação. Tente novamente.',
    };
  }

  // Dois erros são iguais se todos os quatro campos coincidirem. Só serve para os testes aqui.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppFailure &&
          other.kind == kind &&
          other.message == message &&
          other.statusCode == statusCode &&
          other.technicalMessage == technicalMessage;

  @override
  int get hashCode => Object.hash(kind, message, statusCode, technicalMessage);

  @override
  String toString() => technicalMessage ?? message;
}
