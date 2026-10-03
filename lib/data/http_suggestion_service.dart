import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/models.dart';
import '../domain/ports.dart';

class HttpSuggestionService implements SuggestionService {
  HttpSuggestionService({
    required this.endpoint,
    required this.idToken,
    http.Client? client,
  }) : _client = client ?? http.Client();
  final Uri? endpoint;
  final Future<String?> Function() idToken;
  final http.Client _client;
  @override
  Future<List<String>> suggest({
    required String input,
    required BoardTheme theme,
  }) async {
    final target = endpoint;
    if (target == null) {
      throw const AppFailure(
        'Las sugerencias en línea todavía no están configuradas.',
      );
    }
    if (target.scheme != 'https' || target.host.isEmpty) {
      throw const AppFailure(
        'El servicio de sugerencias necesita una dirección HTTPS válida.',
      );
    }
    if (input.length > 500) {
      throw const AppFailure(
        'Usa hasta 500 caracteres para pedir sugerencias.',
      );
    }
    try {
      final token = await idToken().timeout(const Duration(seconds: 10));
      if (token == null) {
        throw const AppFailure(
          'Vuelve a iniciar sesión para pedir sugerencias.',
        );
      }
      final response = await _client
          .post(
            target,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'input': input,
              'theme': theme.name,
              'language': 'es-MX',
              'maxSuggestions': 3,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 401) {
        throw const AppFailure(
          'Vuelve a iniciar sesión para pedir sugerencias.',
        );
      }
      if (response.statusCode != 200) {
        throw const AppFailure(
          'El servicio no está disponible. Puedes seguir usando el tablero.',
        );
      }
      if (response.bodyBytes.length > 16000) {
        throw const AppFailure(
          'El servicio envió una respuesta que no se puede mostrar.',
        );
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final values = data['suggestions'];
      if (values is! List || values.any((v) => v is! String)) {
        throw const FormatException();
      }
      return values
          .cast<String>()
          .map((v) => v.trim())
          .where((v) => v.isNotEmpty && v.length <= 500)
          .toSet()
          .take(3)
          .toList();
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure(
        'No se pudieron obtener sugerencias. Revisa la conexión o continúa con tus tarjetas y texto.',
      );
    }
  }

  void dispose() => _client.close();
}
