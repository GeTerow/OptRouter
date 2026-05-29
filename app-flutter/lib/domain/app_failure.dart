
enum AppFailureKind {
  validation,
  configuration,
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
      AppFailureKind.configuration =>
        'A configuração da demonstração está incompleta. Verifique as chaves da API e tente novamente.',
      AppFailureKind.addressNotFound =>
        'Impossível otimizar. Um ou mais endereços não foram encontrados, verifique e tente novamente.',
      AppFailureKind.network =>
        'Não foi possível conectar aos serviços necessários. Verifique sua conexão e tente novamente.',
      AppFailureKind.timeout =>
        'Os serviços necessários demoraram demais para responder. Tente novamente.',
      AppFailureKind.invalidResponse =>
        'Um serviço externo retornou uma resposta inválida. Tente novamente.',
      AppFailureKind.server =>
        'Um serviço externo não conseguiu processar a solicitação. Tente novamente.',
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
