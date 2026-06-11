import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/app_failure.dart';

/// Classe base abstrata para serviços de API externos.
/// Oferece infraestrutura comum para requisições HTTP e tratamento de erros.
abstract class BaseApiService {
  BaseApiService({
    required http.Client client,
  }) : _client = client;

  final http.Client _client;

  /// Cliente HTTP subjacente compartilhado pelos serviços.
  @protected
  http.Client get client => _client;

  /// Executa chamadas assíncronas tratando erros comuns e mapeando-os para [AppFailure].
  @protected
  Future<T> safeCall<T>({
    required String operationLabel,
    required Future<T> Function() action,
  }) async {
    try {
      return await action();
    } on AppFailure {
      rethrow;
    } on TimeoutException catch (error) {
      throw AppFailure(
        kind: AppFailureKind.timeout,
        message: 'Tempo esgotado ao $operationLabel.',
        technicalMessage: error.toString(),
      );
    } on FormatException catch (error) {
      throw AppFailure(
        kind: AppFailureKind.invalidResponse,
        message: 'Resposta inválida de um serviço externo.',
        technicalMessage: error.message,
      );
    } on http.ClientException catch (error) {
      throw AppFailure(
        kind: AppFailureKind.network,
        message: 'Falha de conexão durante $operationLabel.',
        technicalMessage: error.message,
      );
    } catch (error) {
      throw AppFailure(
        kind: AppFailureKind.unknown,
        message: 'Falha ao $operationLabel.',
        technicalMessage: error.toString(),
      );
    }
  }

  /// Valida se uma determinada chave de API do OpenAI está configurada.
  @protected
  void requireOpenAiKey({
    required String apiKey,
    required String operationLabel,
    required String variableName,
  }) {
    if (apiKey.isEmpty) {
      throw AppFailure(
        kind: AppFailureKind.configuration,
        message:
            'A chave $variableName não foi configurada para $operationLabel.',
      );
    }
  }

  /// Lança um [AppFailure] caso a resposta HTTP indique erro.
  @protected
  void throwIfFailed(
    http.Response response, {
    required String providerName,
  }) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    final message = extractProviderMessage(response.body);
    throw AppFailure(
      kind: AppFailureKind.server,
      statusCode: response.statusCode,
      message: message.isNotEmpty
          ? message
          : 'Falha em $providerName (${response.statusCode}).',
      technicalMessage: 'HTTP ${response.statusCode}: ${response.body}',
    );
  }

  /// Extrai e decodifica o JSON estruturado retornado pelo OpenAI no campo 'output_text'.
  @protected
  Map<String, dynamic> extractOpenAiStructuredJson(
    String body, {
    required String endpoint,
  }) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final output = decoded['output'] as List;

      for (final item in output.cast<Map<String, dynamic>>()) {
        if (item['type'] != 'message') continue;
        final content = item['content'] as List;

        for (final part in content.cast<Map<String, dynamic>>()) {
          if (part['type'] == 'refusal') {
            throw const FormatException('A OpenAI recusou a solicitação.');
          }
          if (part['type'] == 'output_text') {
            final text = (part['text'] as String?)?.trim();
            if (text != null && text.isNotEmpty) {
              return jsonDecode(text) as Map<String, dynamic>;
            }
          }
        }
      }
    } catch (_) {}
    throw FormatException('Resposta inválida do $endpoint.');
  }

  /// Decodifica uma string de corpo de resposta em um objeto [Map].
  @protected
  Map<String, dynamic> decodeJsonObject(
    String body, {
    required String endpoint,
  }) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw FormatException('Resposta inválida do $endpoint.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  /// Constrói os cabeçalhos padrão HTTP para chamadas do OpenAI.
  @protected
  Map<String, String> jsonHeaders({required String bearerToken}) {
    return {
      'Authorization': 'Bearer $bearerToken',
      'Content-Type': 'application/json; charset=utf-8',
    };
  }

  /// Extrai mensagens de erro detalhadas ou genéricas a partir de respostas de erro da API.
  @protected
  String extractProviderMessage(String body) {
    if (body.trim().isEmpty) return '';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final message = decoded['message'] ??
            decoded['error']?['message'] ??
            decoded['error'];
        if (message is String && message.trim().isNotEmpty) {
          return message;
        }
      }
    } catch (_) {}
    return body;
  }
}


