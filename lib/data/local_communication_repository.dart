import 'dart:convert';
import '../application/management_gate.dart';
import '../domain/models.dart';
import '../domain/ports.dart';
import 'local_store.dart';
import 'preset_catalog.dart';

class LocalCommunicationRepository implements CommunicationRepository {
  LocalCommunicationRepository({
    required this.store,
    required this.ownerId,
    required this.gate,
  });
  final LocalStore store;
  final String ownerId;
  final ManagementGate gate;
  Future<void> _requireProfile(String id) async {
    final rows = await store.database.query(
      'profiles',
      columns: ['id'],
      where: 'id = ? AND owner = ?',
      whereArgs: [id, ownerId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const AppFailure(
        'Este perfil no está disponible en esta cuenta y dispositivo.',
      );
    }
  }

  @override
  Future<List<UserProfile>> profiles() async {
    final rows = await store.database.query(
      'profiles',
      where: 'owner = ?',
      whereArgs: [ownerId],
      orderBy: 'name',
    );
    return rows
        .map(
          (r) => UserProfile(id: r['id'] as String, name: r['name'] as String),
        )
        .toList();
  }

  @override
  Future<void> addProfile(String name) async {
    gate.requireAccess();
    final value = name.trim();
    if (value.isEmpty || value.length > 60) {
      throw const AppFailure('Escribe un nombre de hasta 60 caracteres.');
    }
    await store.database.insert('profiles', {
      'id': newId(),
      'owner': ownerId,
      'name': value,
    });
  }

  @override
  Future<List<CommunicationCard>> cards(
    String profileId,
    BoardTheme theme,
  ) async {
    await _requireProfile(profileId);
    final rows = await store.database.query(
      'cards',
      where: 'profile_id = ? AND theme = ?',
      whereArgs: [profileId, theme.name],
      orderBy: 'label',
    );
    return [
      ...presetCards.where((c) => c.theme == theme),
      ...rows.map(
        (r) => CommunicationCard(
          id: r['id'] as String,
          theme: theme,
          label: r['label'] as String,
          spokenText: r['spoken'] as String,
          symbol: r['symbol'] as String,
          photoPath: r['photo'] == null
              ? null
              : store.photoPath(r['photo'] as String),
        ),
      ),
    ];
  }

  @override
  Future<void> addCard(String profileId, CommunicationCard card) async {
    gate.requireAccess();
    final generation = gate.generation;
    await _requireProfile(profileId);
    if (card.isPreset || presetCards.any((c) => c.id == card.id)) {
      throw const AppFailure('Las tarjetas incluidas no se pueden modificar.');
    }
    if (card.label.trim().isEmpty ||
        card.label.length > 100 ||
        card.spokenText.trim().isEmpty ||
        card.spokenText.length > 500) {
      throw const AppFailure(
        'Escribe una etiqueta de hasta 100 caracteres y un texto de voz de hasta 500.',
      );
    }
    gate.requireAccess(generation);
    await store.database.insert('cards', {
      'id': card.id,
      'profile_id': profileId,
      'theme': card.theme.name,
      'label': card.label.trim(),
      'spoken': card.spokenText.trim(),
      'symbol': card.symbol,
      'photo': card.photoPath,
    });
  }

  @override
  Future<void> saveInteraction(InteractionRecord record) async {
    await _requireProfile(record.profileId);
    await store.database.insert('interactions', {
      'id': record.id,
      'profile_id': record.profileId,
      'created_at': record.createdAt.toUtc().toIso8601String(),
      'payload': jsonEncode(record.toJson()),
    });
  }

  @override
  Future<List<InteractionRecord>> history(String profileId) async {
    gate.requireAccess();
    final generation = gate.generation;
    await _requireProfile(profileId);
    final rows = await store.database.query(
      'interactions',
      where: 'profile_id = ?',
      whereArgs: [profileId],
      orderBy: 'created_at DESC',
      limit: 100,
    );
    gate.requireAccess(generation);
    return rows
        .map(
          (r) => InteractionRecord.fromJson(jsonDecode(r['payload'] as String)),
        )
        .toList();
  }

  @override
  Future<void> annotate(
    String profileId,
    String recordId,
    Assistance assistance,
  ) async {
    gate.requireAccess();
    final generation = gate.generation;
    await _requireProfile(profileId);
    final rows = await store.database.query(
      'interactions',
      where: 'id = ? AND profile_id = ?',
      whereArgs: [recordId, profileId],
      limit: 1,
    );
    if (rows.isEmpty) throw const AppFailure('No se encontró el registro.');
    final payload =
        jsonDecode(rows.first['payload'] as String) as Map<String, dynamic>;
    payload['assistance'] = assistance.name;
    gate.requireAccess(generation);
    await store.database.update(
      'interactions',
      {'payload': jsonEncode(payload)},
      where: 'id = ? AND profile_id = ?',
      whereArgs: [recordId, profileId],
    );
  }
}
