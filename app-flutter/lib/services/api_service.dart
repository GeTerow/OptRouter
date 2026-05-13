import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/app_config.dart';
import '../domain/app_failure.dart';
import '../domain/optimized_route.dart';

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<String>> scanAddressImage(String imagePath) {
    return _safeCall(
      operationLabel: 'escanear imagem',
      action: () async {
        return _sendScanRequest(
          await http.MultipartFile.fromPath(
            'image',
            imagePath,
            filename: 'capture.jpg',
            contentType: _inferMediaType(imagePath),
          ),
        );
      },
    );
  }

  Future<List<String>> scanAddressImageBytes(
    Uint8List bytes, {
    required String filename,
  }) {
    return _safeCall(
      operationLabel: 'escanear imagem',
      action: () {
        return _sendScanRequest(
          http.MultipartFile.fromBytes(
            'image',
            bytes,
            filename: filename.isEmpty ? 'capture.jpg' : filename,
            contentType: _inferMediaType(filename),
          ),
        );
      },
    );
  }

  Future<OptimizedRoute> optimizeRoute(List<String> addresses) {
    return _safeCall(
      operationLabel: 'otimizar rota',
      action: () async {
        final response = await _client
            .post(
              AppConfig.apiUri('/api/optimize'),
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode({'addresses': addresses}),
            )
            .timeout(AppConfig.apiTimeout);

        _throwIfFailed(response);

        final decoded = _decodeJsonObject(
          response.body,
          endpoint: '/api/optimize',
        );
        return OptimizedRoute.fromJson(decoded);
      },
    );
  }

  void dispose() {
    _client.close();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<List<String>> _sendScanRequest(http.MultipartFile file) async {
    final request = http.MultipartRequest(
      'POST',
      AppConfig.apiUri('/api/scan'),
    );

    request.files.add(file);

    final streamed = await _client.send(request).timeout(AppConfig.scanTimeout);
    final response = await http.Response.fromStream(streamed);
    _throwIfFailed(response);

    final decoded = _decodeJsonObject(response.body, endpoint: '/api/scan');
    final rawAddresses = decoded['addresses'];
    if (rawAddresses is! List) {
      throw const FormatException('Resposta inválida do /scan.');
    }

    return rawAddresses
        .whereType<String>()
        .map((address) => address.trim())
        .where((address) => address.isNotEmpty)
        .toList();
  }

  Future<T> _safeCall<T>({
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
        message: 'Resposta inválida do servidor.',
        technicalMessage: error.message,
      );
    } on http.ClientException catch (error) {
      throw AppFailure(
        kind: AppFailureKind.network,
        message: 'Falha de conexão com o servidor.',
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

  static MediaType _inferMediaType(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'png' => MediaType('image', 'png'),
      'heic' || 'heif' => MediaType('image', 'heic'),
      'webp' => MediaType('image', 'webp'),
      'gif' => MediaType('image', 'gif'),
      _ => MediaType('image', 'jpeg'),
    };
  }

  Map<String, dynamic> _decodeJsonObject(String body,
      {required String endpoint}) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw FormatException('Resposta inválida do $endpoint.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  void _throwIfFailed(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    final backendMessage = _extractBackendMessage(response.body);
    final kind = _isAddressNotFound(backendMessage)
        ? AppFailureKind.addressNotFound
        : AppFailureKind.server;

    throw AppFailure(
      kind: kind,
      statusCode: response.statusCode,
      message: backendMessage.isEmpty
          ? 'Falha no servidor (${response.statusCode}).'
          : backendMessage,
      technicalMessage: 'HTTP ${response.statusCode}: ${response.body}',
    );
  }

  String _extractBackendMessage(String body) {
    if (body.trim().isEmpty) return '';

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final message = decoded['message'] ?? decoded['error'];
        if (message is String) return message;
      }
    } catch (_) {
      // Non-JSON backend errors are still useful as technical context.
    }

    return body;
  }

  bool _isAddressNotFound(String message) {
    return message
        .contains('Nenhum resultado retornado pela API do Google Maps');
  }
}
