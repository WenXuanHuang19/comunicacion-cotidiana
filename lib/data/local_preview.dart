import 'package:sqflite/sqflite.dart';
import 'local_store.dart';

class LocalPreview {
  static const ownerId = 'local-preview';
  static const profileId = 'local-preview-profile';

  static Future<LocalStore> open() async {
    final store = await LocalStore.open(preview: true);
    try {
      await seed(store);
      return store;
    } catch (_) {
      await store.database.close();
      rethrow;
    }
  }

  static Future<void> seed(LocalStore store) async {
    await store.database.insert('profiles', {
      'id': profileId,
      'owner': ownerId,
      'name': 'Usuario de prueba',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }
}
