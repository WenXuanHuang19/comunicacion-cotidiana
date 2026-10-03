import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../application/management_gate.dart';
import '../domain/models.dart';

class PinVault {
  PinVault({
    required String owner,
    required String installationId,
    required this.gate,
  }) : _key = 'pin_${installationId}_$owner';
  final String _key;
  final ManagementGate gate;
  final _storage = const FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  final _algorithm = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 210000,
    bits: 256,
  );
  Future<bool> exists() async => await _storage.read(key: _key) != null;
  Future<List<int>> _hash(String pin, List<int> salt) async =>
      (await _algorithm.deriveKey(
        secretKey: SecretKey(utf8.encode(pin)),
        nonce: salt,
      )).extractBytes();
  Future<void> create(String pin) async {
    final generation = gate.generation;
    if (await exists()) throw const AppFailure('El PIN ya está configurado.');
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      throw const AppFailure('Usa un PIN de seis números.');
    }
    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    await _storage.write(
      key: _key,
      value: jsonEncode({
        'salt': base64Encode(salt),
        'hash': base64Encode(await _hash(pin, salt)),
      }),
    );
    _unlockIfCurrent(generation);
  }

  Future<void> unlock(String pin) async {
    final generation = gate.generation;
    final raw = await _storage.read(key: _key);
    if (raw == null) throw const AppFailure('Primero configura un PIN.');
    final lockKey = '${_key}_attempts';
    final attempts =
        jsonDecode(await _storage.read(key: lockKey) ?? '{"count":0,"until":0}')
            as Map<String, dynamic>;
    if (DateTime.now().millisecondsSinceEpoch < (attempts['until'] as int)) {
      throw const AppFailure('Espera un minuto antes de volver a intentar.');
    }
    final saved = jsonDecode(raw) as Map<String, dynamic>;
    final actual = await _hash(pin, base64Decode(saved['salt']));
    final expected = base64Decode(saved['hash']);
    var difference = actual.length ^ expected.length;
    for (var i = 0; i < actual.length && i < expected.length; i++) {
      difference |= actual[i] ^ expected[i];
    }
    if (difference != 0) {
      final count = (attempts['count'] as int) + 1;
      await _storage.write(
        key: lockKey,
        value: jsonEncode({
          'count': count % 5,
          'until': count >= 5
              ? DateTime.now()
                    .add(const Duration(minutes: 1))
                    .millisecondsSinceEpoch
              : 0,
        }),
      );
      throw const AppFailure('El PIN no coincide.');
    }
    await _storage.delete(key: lockKey);
    _unlockIfCurrent(generation);
  }

  void _unlockIfCurrent(int generation) {
    if (gate.generation != generation) {
      throw const AppFailure(
        'Ingresa el PIN otra vez para abrir la administración.',
      );
    }
    gate.unlock();
  }
}
