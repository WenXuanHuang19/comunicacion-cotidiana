import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:comunicacion_cotidiana/data/http_suggestion_service.dart';
import 'package:comunicacion_cotidiana/domain/models.dart';

void main() {
  test(
    'sends only current input and context and bounds the response',
    () async {
      final client = MockClient((request) async {
        expect(request.url.scheme, 'https');
        expect(request.headers['Authorization'], 'Bearer test-token');
        expect(jsonDecode(request.body), {
          'input': 'agua',
          'theme': 'food',
          'language': 'es-MX',
          'maxSuggestions': 3,
        });
        return http.Response(
          jsonEncode({
            'suggestions': [
              'Quiero agua',
              'Quiero agua',
              'Agua, por favor',
              '',
              'Tengo sed',
              'Otra opción',
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final service = HttpSuggestionService(
        endpoint: Uri.parse('https://example.invalid/suggestions'),
        idToken: () async => 'test-token',
        client: client,
      );
      expect(await service.suggest(input: 'agua', theme: BoardTheme.food), [
        'Quiero agua',
        'Agua, por favor',
        'Tengo sed',
      ]);
      service.dispose();
    },
  );
  test('unconfigured service makes no network request', () async {
    final service = HttpSuggestionService(
      endpoint: null,
      idToken: () async => throw StateError('should not request token'),
      client: MockClient((_) async => throw StateError('should not send')),
    );
    await expectLater(
      service.suggest(input: 'agua', theme: BoardTheme.food),
      throwsA(isA<AppFailure>()),
    );
    service.dispose();
  });
  test('rejects non-HTTPS endpoints before sending text', () async {
    final service = HttpSuggestionService(
      endpoint: Uri.parse('http://example.invalid'),
      idToken: () async => null,
    );
    await expectLater(
      service.suggest(input: 'agua', theme: BoardTheme.food),
      throwsA(isA<AppFailure>()),
    );
    service.dispose();
  });
}
