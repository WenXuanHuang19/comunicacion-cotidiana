import '../application/add_card.dart';
import '../application/board_view_model.dart';
import '../application/management_gate.dart';
import '../data/device_speech_service.dart';
import '../data/http_suggestion_service.dart';
import '../data/local_communication_repository.dart';
import '../data/local_store.dart';
import '../data/pin_vault.dart';
import 'config.dart';

class AccountDependencies {
  AccountDependencies({
    required String ownerId,
    required LocalStore store,
    required Future<String?> Function() idToken,
    bool allowOnlineSuggestions = true,
  }) {
    repository = LocalCommunicationRepository(
      store: store,
      ownerId: ownerId,
      gate: gate,
    );
    ai = HttpSuggestionService(
      endpoint: !allowOnlineSuggestions || AppConfig.suggestionUrl.isEmpty
          ? null
          : Uri.tryParse(AppConfig.suggestionUrl),
      idToken: idToken,
    );
    vault = PinVault(
      owner: ownerId,
      installationId: store.installationId,
      gate: gate,
    );
    board = BoardViewModel(
      repository: repository,
      speech: DeviceSpeechService(),
      ai: ai,
    );
    addCard = AddCard(repository, store, gate);
  }
  final gate = ManagementGate();
  late final LocalCommunicationRepository repository;
  late final HttpSuggestionService ai;
  late final PinVault vault;
  late final BoardViewModel board;
  late final AddCard addCard;
  void dispose() {
    gate.lock();
    board.dispose();
    ai.dispose();
  }
}
