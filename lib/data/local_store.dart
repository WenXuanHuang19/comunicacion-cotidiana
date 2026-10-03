import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../domain/models.dart';

class LocalStore {
  LocalStore(this.database, this.directory, this.installationId);
  final Database database;
  final Directory directory;
  final String installationId;
  static Future<LocalStore> open({bool preview = false}) async {
    final support = await getApplicationSupportDirectory();
    final root = await Directory(
      p.join(support.path, preview ? 'communication_preview' : 'communication'),
    ).create(recursive: true);
    if (Platform.isIOS) {
      await const MethodChannel(
        'mx.edu.comunicacion/local_storage',
      ).invokeMethod<void>('excludeFromBackup', {'path': root.path});
    }
    final marker = File(p.join(root.path, 'installation'));
    if (!await marker.exists()) {
      await marker.writeAsString(newId(), flush: true);
    }
    final db = await openDatabase(
      p.join(root.path, 'communication.db'),
      version: 1,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: createSchema,
    );
    return LocalStore(db, root, await marker.readAsString());
  }

  static Future<void> createSchema(Database db, int version) async {
    await db.execute(
      'CREATE TABLE profiles (id TEXT PRIMARY KEY, owner TEXT NOT NULL, name TEXT NOT NULL)',
    );
    await db.execute('CREATE INDEX profile_owner ON profiles(owner)');
    await db.execute(
      'CREATE TABLE cards (id TEXT PRIMARY KEY, profile_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE, theme TEXT NOT NULL, label TEXT NOT NULL, spoken TEXT NOT NULL, symbol TEXT NOT NULL, photo TEXT)',
    );
    await db.execute(
      'CREATE INDEX card_profile_theme ON cards(profile_id,theme)',
    );
    await db.execute(
      'CREATE TABLE interactions (id TEXT PRIMARY KEY, profile_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE, created_at TEXT NOT NULL, payload TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE INDEX interaction_profile_time ON interactions(profile_id,created_at)',
    );
  }

  Future<String> importPhoto(String source) async {
    final extension = p.extension(source).toLowerCase();
    if (!['.jpg', '.jpeg', '.png', '.webp', '.heic'].contains(extension)) {
      throw const AppFailure('Elige una imagen JPG, PNG, WebP o HEIC.');
    }
    final file = File(source);
    if (await file.length() > 10 * 1024 * 1024) {
      throw const AppFailure('Elige una imagen de menos de 10 MB.');
    }
    final folder = await Directory(
      p.join(directory.path, 'photos'),
    ).create(recursive: true);
    final name = '${newId()}$extension';
    await file.copy(p.join(folder.path, name));
    return name;
  }

  String photoPath(String name) =>
      p.join(directory.path, 'photos', p.basename(name));
}
