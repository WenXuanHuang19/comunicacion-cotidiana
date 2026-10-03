import 'dart:convert';
import 'dart:math';

String newId() => base64Url
    .encode(List<int>.generate(18, (_) => Random.secure().nextInt(256)))
    .replaceAll('=', '');

enum BoardTheme {
  home('En casa'),
  leisure('Tiempo libre'),
  food('Comida'),
  care('Cuidado diario');

  const BoardTheme(this.label);
  final String label;
}

class UserProfile {
  const UserProfile({required this.id, required this.name});
  final String id;
  final String name;
}

class CommunicationCard {
  const CommunicationCard({
    required this.id,
    required this.theme,
    required this.label,
    required this.spokenText,
    required this.symbol,
    this.photoPath,
    this.isPreset = false,
  });
  final String id;
  final BoardTheme theme;
  final String label;
  final String spokenText;
  final String symbol;
  final String? photoPath;
  final bool isPreset;
}

enum Assistance { unrecorded, independent, supported }

class InteractionRecord {
  const InteractionRecord({
    required this.id,
    required this.profileId,
    required this.createdAt,
    required this.theme,
    required this.originalInput,
    required this.suggestions,
    required this.finalText,
    required this.usedSuggestion,
    required this.kind,
    this.assistance = Assistance.unrecorded,
  });
  final String id;
  final String profileId;
  final DateTime createdAt;
  final BoardTheme theme;
  final String originalInput;
  final List<String> suggestions;
  final String finalText;
  final bool usedSuggestion;
  final String kind;
  final Assistance assistance;

  Map<String, Object?> toJson() => {
    'id': id,
    'profileId': profileId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'theme': theme.name,
    'originalInput': originalInput,
    'suggestions': suggestions,
    'finalText': finalText,
    'usedSuggestion': usedSuggestion,
    'kind': kind,
    'assistance': assistance.name,
  };
  factory InteractionRecord.fromJson(Map<String, dynamic> j) =>
      InteractionRecord(
        id: j['id'],
        profileId: j['profileId'],
        createdAt: DateTime.parse(j['createdAt']),
        theme: BoardTheme.values.byName(j['theme']),
        originalInput: j['originalInput'],
        suggestions: List<String>.from(j['suggestions']),
        finalText: j['finalText'],
        usedSuggestion: j['usedSuggestion'],
        kind: j['kind'],
        assistance: Assistance.values.byName(j['assistance']),
      );
}

class AppFailure implements Exception {
  const AppFailure(this.message);
  final String message;
  @override
  String toString() => message;
}
