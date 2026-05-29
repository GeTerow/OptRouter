import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/app_config.dart';
import 'base_api_service.dart';

/// Serviço especializado em extrair endereços textuais legíveis a partir de imagens.
/// Utiliza a API do OpenAI com Structured Outputs/JSON Schema.
class AddressScanService extends BaseApiService {
  AddressScanService({
    required super.client,
    required String openAiApiKey,
    required String openAiScanModel,
    required Uri openAiResponsesUri,
  })  : _openAiApiKey = openAiApiKey,
        _openAiScanModel = openAiScanModel,
        _openAiResponsesUri = openAiResponsesUri;

  final String _openAiApiKey;
  final String _openAiScanModel;
  final Uri _openAiResponsesUri;

  /// Lê uma imagem do arquivo local no caminho [imagePath] e extrai os endereços nela contidos.
  Future<List<String>> scanAddressImage(String imagePath) async {
    final file = await http.MultipartFile.fromPath(
      'image',
      imagePath,
      filename: 'capture.jpg',
      contentType: _inferMediaType(imagePath),
    );

    final bytes = await file.finalize().toBytes();
    return scanAddressImageBytes(
      bytes,
      filename: imagePath,
    );
  }

  /// Processa os bytes de imagem fornecidos e invoca a API do OpenAI para extrair endereços.
  Future<List<String>> scanAddressImageBytes(
    Uint8List bytes, {
    required String filename,
  }) {
    return safeCall(
      operationLabel: 'escanear imagem',
      action: () async {
        requireOpenAiKey(
          apiKey: _openAiApiKey,
          operationLabel: 'escanear imagem',
          variableName: 'OPENAI_API_KEY',
        );

        final mediaType = _inferMediaType(filename);
        final response = await client
            .post(
              _openAiResponsesUri,
              headers: jsonHeaders(bearerToken: _openAiApiKey),
              body: jsonEncode(
                _buildScanRequest(
                  bytes: bytes,
                  mediaType: mediaType,
                ),
              ),
            )
            .timeout(AppConfig.scanTimeout);

        throwIfFailed(
          response,
          providerName: 'OpenAI',
        );

        final decoded = extractOpenAiStructuredJson(
          response.body,
          endpoint: 'OpenAI scan',
        );
        final rawAddresses = decoded['addresses'];
        if (rawAddresses is! List) {
          throw const FormatException('Resposta inválida da OpenAI para scan.');
        }

        return rawAddresses
            .whereType<String>()
            .map((address) => address.trim())
            .where((address) => address.isNotEmpty)
            .toList();
      },
    );
  }

  /// Infere o tipo de mídia (MIME type) a partir da extensão do arquivo de imagem.
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

  /// Monta o payload de requisição estruturada para o OpenAI.
  Map<String, dynamic> _buildScanRequest({
    required Uint8List bytes,
    required MediaType mediaType,
  }) {
    return {
      'model': _openAiScanModel,
      'instructions': [
        'Extraia somente enderecos de entrega visiveis na imagem.',
        'Nao invente enderecos.',
        'Se nao houver endereco legivel, retorne a lista vazia.',
      ].join(' '),
      'input': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'input_text',
              'text':
                  'Analise a imagem e retorne apenas os enderecos identificados.',
            },
            {
              'type': 'input_image',
              'image_url':
                  'data:${mediaType.type}/${mediaType.subtype};base64,${base64Encode(bytes)}',
            },
          ],
        },
      ],
      'text': {
        'format': _jsonSchemaFormat(
          name: 'address_scan',
          schema: {
            'type': 'object',
            'additionalProperties': false,
            'properties': {
              'addresses': {
                'type': 'array',
                'items': {'type': 'string'},
              },
            },
            'required': ['addresses'],
          },
        ),
      },
    };
  }

  /// Formata a definição do JSON Schema exigida pela API do OpenAI.
  Map<String, dynamic> _jsonSchemaFormat({
    required String name,
    required Map<String, dynamic> schema,
  }) {
    return {
      'type': 'json_schema',
      'name': name,
      'strict': true,
      'schema': schema,
    };
  }
}
