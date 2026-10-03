import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:comunicacion_cotidiana/application/board_view_model.dart';
import 'package:comunicacion_cotidiana/domain/models.dart';
import 'package:comunicacion_cotidiana/domain/ports.dart';

class MemoryRepository implements CommunicationRepository {
  final saved = <InteractionRecord>[];
  @override
  Future<List<UserProfile>> profiles() async => const [
    UserProfile(id: 'a', name: 'Ana'),
    UserProfile(id: 'b', name: 'Luis'),
  ];
  @override
  Future<List<CommunicationCard>> cards(String id, BoardTheme theme) async =>
      [];
  @override
  Future<void> saveInteraction(InteractionRecord record) async {
    saved.add(record);
  }

  @override
  Future<void> addProfile(String name) async {}
  @override
  Future<void> addCard(String id, CommunicationCard card) async {}
  @override
  Future<List<InteractionRecord>> history(String id) async =>
      saved.where((r) => r.profileId == id).toList();
  @override
  Future<void> annotate(
    String profileId,
    String recordId,
    Assistance assistance,
  ) async {}
}

class RecordingSpeech implements SpeechService {
  final spoken = <String>[];
  Completer<void>? pending;
  @override
  Future<void> speak(String text) async {
    spoken.add(text);
    await pending?.future;
  }

  @override
  Future<void> stop() async {}
}

class ControlledSuggestions implements SuggestionService {
  final response = Completer<List<String>>();
  @override
  Future<List<String>> suggest({
    required String input,
    required BoardTheme theme,
  }) => response.future;
}

void main() {
  late MemoryRepository repository;
  late RecordingSpeech speech;
  late ControlledSuggestions ai;
  late BoardViewModel vm;
  setUp(() async {
    repository = MemoryRepository();
    speech = RecordingSpeech();
    ai = ControlledSuggestions();
    vm = BoardViewModel(repository: repository, speech: speech, ai: ai);
    await vm.load();
  });
  tearDown(() => vm.dispose());
  test(
    'ordinary card speaks immediately and appends to the original input',
    () async {
      const card = CommunicationCard(
        id: 'water',
        theme: BoardTheme.food,
        label: 'Agua',
        spokenText: 'Quiero agua',
        symbol: '💧',
      );
      await vm.tapCard(card);
      expect(speech.spoken, ['Quiero agua']);
      expect(vm.originalInput, 'Agua');
      expect(repository.saved.single.kind, 'card');
      expect(repository.saved.single.usedSuggestion, false);
    },
  );
  test('choosing AI preserves input and only speaks after Play', () async {
    vm.editInput('yo agua');
    final request = vm.requestSuggestions();
    ai.response.complete(['Quiero agua.']);
    await request;
    vm.chooseSuggestion('Quiero agua.');
    expect(speech.spoken, isEmpty);
    expect(vm.originalInput, 'yo agua');
    await vm.play();
    expect(speech.spoken, ['Quiero agua.']);
    final record = repository.saved.single;
    expect(record.originalInput, 'yo agua');
    expect(record.suggestions, ['Quiero agua.']);
    expect(record.usedSuggestion, true);
    expect(record.assistance, Assistance.unrecorded);
  });
  for (final change in ['input', 'theme', 'profile']) {
    test('late AI result is discarded after changing $change', () async {
      vm.editInput('agua');
      final request = vm.requestSuggestions();
      if (change == 'input') vm.editInput('comida');
      if (change == 'theme') await vm.changeTheme(BoardTheme.care);
      if (change == 'profile') await vm.selectProfile(vm.profiles.last);
      ai.response.complete(['Quiero agua.']);
      await request;
      expect(vm.suggestions, isEmpty);
      expect(vm.loadingSuggestions, false);
    });
  }
  test('offline failure keeps the original message available', () async {
    vm.editInput('Quiero salir');
    final request = vm.requestSuggestions();
    ai.response.completeError(const AppFailure('Sin conexión'));
    await request;
    expect(vm.output, 'Quiero salir');
    expect(vm.notice, 'Sin conexión');
    await vm.play();
    expect(speech.spoken, ['Quiero salir']);
  });
  test('switching profiles suppresses a cancelled playback record', () async {
    speech.pending = Completer<void>();
    vm.editInput('Hola');
    final playback = vm.play();
    await vm.selectProfile(vm.profiles.last);
    speech.pending!.complete();
    await playback;
    expect(repository.saved, isEmpty);
    expect(vm.originalInput, isEmpty);
  });
  test('AI remains optional for a complete message', () async {
    vm.editInput('Necesito ayuda');
    await vm.play();
    expect(repository.saved.single.finalText, 'Necesito ayuda');
    expect(repository.saved.single.suggestions, isEmpty);
  });
}
