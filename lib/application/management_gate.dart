import '../domain/models.dart';

class ManagementGate {
  bool _unlocked = false;
  int _generation = 0;
  int get generation => _generation;
  bool get isUnlocked => _unlocked;
  void unlock() {
    _unlocked = true;
    _generation++;
  }

  void lock() {
    _unlocked = false;
    _generation++;
  }

  void requireAccess([int? generation]) {
    if (!_unlocked || (generation != null && generation != _generation)) {
      throw const AppFailure('Ingresa el PIN para abrir la administración.');
    }
  }
}
