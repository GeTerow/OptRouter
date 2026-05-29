import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/app_failure.dart';

/// Classe base abstrata para serviços de API externos.
/// Oferece infraestrutura comum para requisições HTTP, logs de depuração e conversão de erros.
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
    if (apiKey.isNotEmpty) return;

    throw AppFailure(
      kind: AppFailureKind.configuration,
      message:
          'A chave $variableName não foi configurada para $operationLabel.',
    );
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
      message: message.isEmpty
          ? 'Falha em $providerName (${response.statusCode}).'
          : message,
      technicalMessage: 'HTTP ${response.statusCode}: ${response.body}',
    );
  }

  /// Extrai e decodifica o JSON estruturado retornado pelo OpenAI no campo 'output_text'.
  @protected
  Map<String, dynamic> extractOpenAiStructuredJson(
    String body, {
    required String endpoint,
  }) {
    final decoded = decodeJsonObject(body, endpoint: endpoint);
    final output = decoded['output'];
    if (output is! List) {
      debugLog('$endpoint sem lista output: ${truncateForLog(body)}');
      throw FormatException('Resposta inválida do $endpoint.');
    }

    for (final itemValue in output) {
      if (itemValue is! Map) continue;
      final item = Map<String, dynamic>.from(itemValue);
      if (item['type'] != 'message') continue;

      final content = item['content'];
      if (content is! List) continue;

      for (final partValue in content) {
        if (partValue is! Map) continue;
        final part = Map<String, dynamic>.from(partValue);
        final type = part['type'];

        if (type == 'refusal') {
          throw const FormatException('A OpenAI recusou a solicitação.');
        }

        if (type == 'output_text') {
          final text = (part['text'] as String?)?.trim();
          if (text == null || text.isEmpty) continue;
          debugLog('$endpoint output_text: ${truncateForLog(text)}');
          return decodeJsonObject(text, endpoint: endpoint);
        }
      }
    }

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
      'Content-Type': 'application/json',
    };
  }

  /// Extrai mensagens de erro detalhadas ou genéricas a partir de respostas de erro da API.
  @protected
  String extractProviderMessage(String body) {
    if (body.trim().isEmpty) return '';

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final directMessage = decoded['message'];
        if (directMessage is String && directMessage.trim().isNotEmpty) {
          return directMessage;
        }

        final error = decoded['error'];
        if (error is String && error.trim().isNotEmpty) {
          return error;
        }

        if (error is Map) {
          final nestedMessage = error['message'];
          if (nestedMessage is String && nestedMessage.trim().isNotEmpty) {
            return nestedMessage;
          }
        }
      }
    } catch (_) {
      // Retorna o corpo original caso não seja JSON decodificável.
    }

    return body;
  }

  /// Registra logs no console apenas em ambiente de depuração.
  @protected
  void debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[ApiService] $message');
    }
  }

  /// Trunca strings excessivamente longas para não sobrecarregar os logs do console.
  @protected
  String truncateForLog(String value) {
    const maxLength = 1200;
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= maxLength) return compact;
    return '${compact.substring(0, maxLength)}...';
  }
}
