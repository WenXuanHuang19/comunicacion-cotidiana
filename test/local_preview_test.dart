import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:comunicacion_cotidiana/app/app.dart';
import 'package:comunicacion_cotidiana/application/management_gate.dart';
import 'package:comunicacion_cotidiana/data/local_preview.dart';
import 'package:comunicacion_cotidiana/data/local_store.dart';
import 'package:comunicacion_cotidiana/data/local_communication_repository.dart';

void main() {
  testWidgets(
    'preview works without initializing Firebase and reports local open failures',
    (tester) async {
      var requested = false;
      await tester.pumpWidget(
        CommunicationApp(
          startupIssue: 'Login pendiente',
          openPreviewStore: () async {
            requested = true;
            throw StateError('Local storage unavailable');
          },
        ),
      );
      await tester.tap(find.text('Probar sin iniciar sesión'));
      await tester.pumpAndSettle();
      expect(requested, isTrue);
      expect(
        find.text(
          'No se pudo abrir la vista previa local. Vuelve a intentarlo.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('no preview entry is offered when the opener is disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CommunicationApp(startupIssue: 'Login pendiente'),
    );
    expect(find.text('Probar sin iniciar sesión'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
  });

  test(
    'seeding is idempotent and leaves real account profiles untouched',
    () async {
      sqfliteFfiInit();
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: LocalStore.createSchema,
        ),
      );
      final store = LocalStore(
        db,
        Directory.systemTemp,
        'preview-test-installation',
      );
      final gate = ManagementGate()..unlock();
      final actual = LocalCommunicationRepository(
        store: store,
        ownerId: 'real-owner',
        gate: gate,
      );
      final preview = LocalCommunicationRepository(
        store: store,
        ownerId: LocalPreview.ownerId,
        gate: gate,
      );
      try {
        await actual.addProfile('Mi perfil');
        await LocalPreview.seed(store);
        await LocalPreview.seed(store);
        expect((await actual.profiles()).single.name, 'Mi perfil');
        expect((await preview.profiles()).single.name, 'Usuario de prueba');
        expect((await preview.profiles()).single.id, LocalPreview.profileId);
        expect(gate.isUnlocked, isTrue);
      } finally {
        await db.close();
      }
    },
  );
}
