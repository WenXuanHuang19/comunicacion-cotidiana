import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:comunicacion_cotidiana/application/management_gate.dart';
import 'package:comunicacion_cotidiana/data/local_store.dart';
import 'package:comunicacion_cotidiana/data/local_communication_repository.dart';
import 'package:comunicacion_cotidiana/data/preset_catalog.dart';
import 'package:comunicacion_cotidiana/domain/models.dart';

void main() {
  sqfliteFfiInit();
  late Database db;
  late LocalCommunicationRepository one;
  late LocalCommunicationRepository two;
  late ManagementGate gate;
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
        onCreate: LocalStore.createSchema,
      ),
    );
    final store = LocalStore(db, Directory.systemTemp, 'test-installation');
    gate = ManagementGate()..unlock();
    one = LocalCommunicationRepository(
      store: store,
      ownerId: 'owner-one',
      gate: gate,
    );
    two = LocalCommunicationRepository(
      store: store,
      ownerId: 'owner-two',
      gate: gate,
    );
    await one.addProfile('Ana');
    await two.addProfile('Luis');
  });
  tearDown(() async => db.close());
  test('accounts cannot read or write another account profile', () async {
    final profile = (await one.profiles()).single;
    expect((await two.profiles()).single.name, 'Luis');
    await expectLater(
      two.cards(profile.id, BoardTheme.home),
      throwsA(isA<AppFailure>()),
    );
    await expectLater(two.history(profile.id), throwsA(isA<AppFailure>()));
    await expectLater(
      two.addCard(
        profile.id,
        const CommunicationCard(
          id: 'x',
          theme: BoardTheme.home,
          label: 'X',
          spokenText: 'X',
          symbol: 'X',
        ),
      ),
      throwsA(isA<AppFailure>()),
    );
  });
  test(
    'management requires PIN while reading communication cards stays available',
    () async {
      final id = (await one.profiles()).single.id;
      gate.lock();
      await expectLater(
        one.addProfile('Otra persona'),
        throwsA(isA<AppFailure>()),
      );
      await expectLater(one.history(id), throwsA(isA<AppFailure>()));
      expect(await one.cards(id, BoardTheme.home), isNotEmpty);
    },
  );
  test(
    'presets are immutable and custom cards remain profile-specific',
    () async {
      final id = (await one.profiles()).single.id;
      await expectLater(
        one.addCard(id, presetCards.first),
        throwsA(isA<AppFailure>()),
      );
      await one.addCard(
        id,
        const CommunicationCard(
          id: 'mine',
          theme: BoardTheme.home,
          label: 'Mi casa',
          spokenText: 'Mi casa',
          symbol: '🏠',
        ),
      );
      expect(
        (await one.cards(id, BoardTheme.home)).any((c) => c.id == 'mine'),
        true,
      );
      final other = (await two.profiles()).single.id;
      expect(
        (await two.cards(other, BoardTheme.home)).any((c) => c.id == 'mine'),
        false,
      );
    },
  );
  test(
    'history keeps input, AI alternatives and manually annotated support separately',
    () async {
      final id = (await one.profiles()).single.id;
      final r = InteractionRecord(
        id: 'r',
        profileId: id,
        createdAt: DateTime.utc(2026),
        theme: BoardTheme.food,
        originalInput: 'yo agua',
        suggestions: ['Quiero agua'],
        finalText: 'Quiero agua',
        usedSuggestion: true,
        kind: 'message',
      );
      await one.saveInteraction(r);
      await one.annotate(id, 'r', Assistance.supported);
      final saved = (await one.history(id)).single;
      expect(saved.originalInput, 'yo agua');
      expect(saved.suggestions, ['Quiero agua']);
      expect(saved.finalText, 'Quiero agua');
      expect(saved.assistance, Assistance.supported);
    },
  );
}
