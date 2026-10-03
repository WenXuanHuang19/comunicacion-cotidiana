import 'package:flutter/foundation.dart';
import '../domain/models.dart';
import '../domain/ports.dart';

class BoardViewModel extends ChangeNotifier {
  BoardViewModel({
    required this.repository,
    required this.speech,
    required this.ai,
  });
  final CommunicationRepository repository;
  final SpeechService speech;
  final SuggestionService ai;
  List<UserProfile> profiles = [];
  UserProfile? profile;
  List<CommunicationCard> cards = [];
  BoardTheme theme = BoardTheme.home;
  String originalInput = '';
  String? selectedSuggestion;
  List<String> suggestions = [];
  String? notice;
  bool loadingSuggestions = false;
  bool speaking = false;
  bool _disposed = false;
  int _epoch = 0;
  int _cardLoad = 0;
  int _playback = 0;
  String get output => selectedSuggestion ?? originalInput;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    profiles = await repository.profiles();
    if (_disposed) return;
    if (profile == null && profiles.isNotEmpty) {
      await selectProfile(profiles.first);
    }
    _emit();
  }

  Future<void> selectProfile(UserProfile value) async {
    _invalidate();
    _playback++;
    speaking = false;
    profile = value;
    originalInput = '';
    cards = [];
    await speech.stop();
    if (_disposed) return;
    speaking = false;
    await _loadCards();
  }

  Future<void> changeTheme(BoardTheme value) async {
    theme = value;
    _invalidate();
    await _loadCards();
  }

  Future<void> refreshCards() => _loadCards();
  Future<void> _loadCards() async {
    final current = profile;
    final token = ++_cardLoad;
    if (current == null) return;
    final loaded = await repository.cards(current.id, theme);
    if (!_disposed && token == _cardLoad) {
      cards = loaded;
      _emit();
    }
  }

  void _invalidate() {
    _epoch++;
    suggestions = [];
    selectedSuggestion = null;
    loadingSuggestions = false;
    notice = null;
  }

  void editInput(String value) {
    _invalidate();
    originalInput = value;
    _emit();
  }

  void clear() => editInput('');
  Future<void> tapCard(CommunicationCard card) async {
    if (speaking) return;
    editInput(
      [originalInput.trim(), card.label].where((s) => s.isNotEmpty).join(' '),
    );
    await _speakAndRecord(
      card.spokenText,
      kind: 'card',
      input: card.label,
      candidates: [],
      used: false,
    );
  }

  void chooseSuggestion(String value) {
    if (!suggestions.contains(value)) return;
    selectedSuggestion = value;
    _emit();
  }

  void useOriginal() {
    selectedSuggestion = null;
    _emit();
  }

  Future<void> requestSuggestions() async {
    if (originalInput.trim().isEmpty || profile == null || loadingSuggestions) {
      return;
    }
    final token = ++_epoch;
    suggestions = [];
    selectedSuggestion = null;
    loadingSuggestions = true;
    notice = null;
    _emit();
    try {
      final values = await ai.suggest(
        input: originalInput.trim(),
        theme: theme,
      );
      if (!_disposed && token == _epoch) {
        suggestions = List.unmodifiable(values);
      }
    } catch (error) {
      if (!_disposed && token == _epoch) {
        notice = error is AppFailure
            ? error.message
            : 'No se pudieron obtener sugerencias. Puedes seguir usando el tablero.';
      }
    } finally {
      if (!_disposed && token == _epoch) {
        loadingSuggestions = false;
        _emit();
      }
    }
  }

  Future<void> play() async {
    if (output.trim().isEmpty || speaking) return;
    await _speakAndRecord(
      output,
      kind: 'message',
      input: originalInput,
      candidates: List.of(suggestions),
      used: selectedSuggestion != null,
    );
  }

  Future<void> _speakAndRecord(
    String text, {
    required String kind,
    required String input,
    required List<String> candidates,
    required bool used,
  }) async {
    final current = profile;
    if (current == null) return;
    final record = InteractionRecord(
      id: newId(),
      profileId: current.id,
      createdAt: DateTime.now(),
      theme: theme,
      originalInput: input,
      suggestions: candidates,
      finalText: text,
      usedSuggestion: used,
      kind: kind,
    );
    final token = _epoch;
    final playback = ++_playback;
    speaking = true;
    notice = null;
    _emit();
    try {
      await speech.speak(text);
      if (!_disposed && profile?.id == current.id && playback == _playback) {
        await repository.saveInteraction(record);
      }
    } catch (error) {
      if (!_disposed && token == _epoch) {
        notice = error is AppFailure
            ? error.message
            : 'No se pudo completar la reproducción o guardar el registro.';
      }
    } finally {
      if (!_disposed && playback == _playback) {
        speaking = false;
        _emit();
      }
    }
  }

  Future<void> suspend() async {
    _invalidate();
    _playback++;
    speaking = false;
    await speech.stop();
    _emit();
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _cardLoad++;
    _playback++;
    speech.stop();
    super.dispose();
  }
}
