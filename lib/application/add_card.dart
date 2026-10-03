import 'dart:io';
import '../data/local_store.dart';
import '../domain/models.dart';
import '../domain/ports.dart';
import 'management_gate.dart';

class AddCard {
  const AddCard(this.repository, this.store, this.gate);
  final CommunicationRepository repository;
  final LocalStore store;
  final ManagementGate gate;
  Future<void> call({
    required String profileId,
    required BoardTheme theme,
    required String label,
    required String spoken,
    String? photoSource,
  }) async {
    gate.requireAccess();
    final generation = gate.generation;
    String? photo;
    try {
      photo = photoSource == null ? null : await store.importPhoto(photoSource);
      gate.requireAccess(generation);
      await repository.addCard(
        profileId,
        CommunicationCard(
          id: newId(),
          theme: theme,
          label: label,
          spokenText: spoken,
          symbol: '💬',
          photoPath: photo,
        ),
      );
    } catch (_) {
      if (photo != null) {
        final file = File(store.photoPath(photo));
        if (await file.exists()) await file.delete();
      }
      rethrow;
    }
  }
}
