import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';
import '../domain/models.dart';
import '../domain/ports.dart';

class DeviceSpeechService implements SpeechService {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  int _generation = 0;
  Future<void> _prepare() async {
    if (_ready) return;
    final raw = await _tts.getVoices;
    final voices = (raw as List).cast<Map>();
    final available = voices
        .where(
          (v) =>
              v['locale'].toString().replaceAll('_', '-').toLowerCase() ==
                  'es-mx' &&
              (!Platform.isAndroid ||
                  const [
                    '0',
                    'false',
                  ].contains(v['network_required'].toString())),
        )
        .toList();
    if (available.isEmpty) {
      throw const AppFailure(
        'Instala una voz en español de México para usar la reproducción sin internet. El texto sigue disponible.',
      );
    }
    await _tts.setVoice({
      'name': available.first['name'].toString(),
      'locale': available.first['locale'].toString(),
    });
    await _tts.awaitSpeakCompletion(true);
    await _tts.setSpeechRate(0.45);
    _ready = true;
  }

  @override
  Future<void> speak(String text) async {
    final generation = ++_generation;
    await _prepare();
    if (generation != _generation) {
      throw const AppFailure('La reproducción se interrumpió.');
    }
    final result = await _tts.speak(text);
    if (result != 1) {
      throw const AppFailure(
        'La reproducción se interrumpió. Puedes volver a intentarlo.',
      );
    }
  }

  @override
  Future<void> stop() async {
    _generation++;
    await _tts.stop();
  }
}
