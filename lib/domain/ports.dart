import 'models.dart';

abstract interface class CommunicationRepository {
  Future<List<UserProfile>> profiles();
  Future<void> addProfile(String name);
  Future<List<CommunicationCard>> cards(String profileId, BoardTheme theme);
  Future<void> addCard(String profileId, CommunicationCard card);
  Future<void> saveInteraction(InteractionRecord record);
  Future<List<InteractionRecord>> history(String profileId);
  Future<void> annotate(
    String profileId,
    String recordId,
    Assistance assistance,
  );
}

abstract interface class SpeechService {
  Future<void> speak(String text);
  Future<void> stop();
}

abstract interface class SuggestionService {
  Future<List<String>> suggest({
    required String input,
    required BoardTheme theme,
  });
}
