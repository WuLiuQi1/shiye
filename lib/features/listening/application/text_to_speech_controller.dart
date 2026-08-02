import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// A deliberately small boundary around the platform speech engine.
///
/// Text is passed only to iOS/Android's installed system TTS engine. It is
/// never sent to a network service by this application.
class TextToSpeechController extends ChangeNotifier {
  TextToSpeechController({FlutterTts? engine}) : _engine = engine ?? FlutterTts() {
    _engine
      ..setStartHandler(_onStarted)
      ..setCompletionHandler(_onCompleted)
      ..setPauseHandler(([dynamic _]) => _onPaused())
      ..setContinueHandler(([dynamic _]) => _onContinued())
      ..setCancelHandler(([dynamic _]) => _onStopped())
      ..setErrorHandler((_) => _onStopped());
  }

  final FlutterTts _engine;
  final StreamController<void> _chapterCompleted = StreamController<void>.broadcast();
  final List<String> _chunks = [];
  int _chunkIndex = 0;
  bool _disposed = false;
  bool _isSpeaking = false;
  bool _isPaused = false;
  double _speechRate = .5;

  Stream<void> get chapterCompleted => _chapterCompleted.stream;
  bool get isSpeaking => _isSpeaking;
  bool get isPaused => _isPaused;
  bool get isActive => _isSpeaking || _isPaused;
  double get speechRate => _speechRate;

  Future<void> configure() async {
    await _engine.awaitSpeakCompletion(true);
    if (Platform.isIOS) {
      await _engine.setSharedInstance(true);
      await _engine.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        <IosTextToSpeechAudioCategoryOptions>[
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.duckOthers,
        ],
        IosTextToSpeechAudioMode.voicePrompt,
      );
    }
    await _engine.setSpeechRate(_speechRate);
  }

  Future<void> speakChapter(String text) async {
    await stop();
    _chunks.addAll(splitForSpeech(text));
    if (_chunks.isEmpty) return;
    _chunkIndex = 0;
    _isSpeaking = true;
    _isPaused = false;
    notifyListeners();
    await _speakCurrentChunk();
  }

  Future<void> togglePause() async {
    if (_isPaused) {
      await _engine.speak(_chunks[_chunkIndex]);
      return;
    }
    await _engine.pause();
  }

  Future<void> stop() async {
    _chunks.clear();
    _chunkIndex = 0;
    _isSpeaking = false;
    _isPaused = false;
    await _engine.stop();
    if (!_disposed) notifyListeners();
  }

  Future<void> setSpeechRate(double value) async {
    _speechRate = value.clamp(.2, .8).toDouble();
    await _engine.setSpeechRate(_speechRate);
    if (!_disposed) notifyListeners();
  }

  Future<void> _speakCurrentChunk() async {
    if (!_isSpeaking || _chunkIndex >= _chunks.length) return;
    await _engine.speak(_chunks[_chunkIndex]);
  }

  void _onStarted() {
    _isSpeaking = true;
    _isPaused = false;
    if (!_disposed) notifyListeners();
  }

  void _onPaused() {
    _isPaused = true;
    if (!_disposed) notifyListeners();
  }

  void _onContinued() {
    _isSpeaking = true;
    _isPaused = false;
    if (!_disposed) notifyListeners();
  }

  void _onStopped() {
    _isSpeaking = false;
    _isPaused = false;
    if (!_disposed) notifyListeners();
  }

  void _onCompleted() {
    if (!_isSpeaking || _isPaused) return;
    _chunkIndex++;
    if (_chunkIndex < _chunks.length) {
      unawaited(_speakCurrentChunk());
      return;
    }
    _isSpeaking = false;
    _isPaused = false;
    _chapterCompleted.add(null);
    if (!_disposed) notifyListeners();
  }

  /// iOS and Android voices often have an utterance-size limit. Splitting at
  /// punctuation preserves natural pauses and prevents long chapters failing.
  @visibleForTesting
  static List<String> splitForSpeech(String text, {int maxLength = 1800}) {
    final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return const [];
    final parts = cleaned.split(RegExp(r'(?<=[。！？!?；;])'));
    final result = <String>[];
    var buffer = '';
    for (final raw in parts) {
      var part = raw.trim();
      if (part.isEmpty) continue;
      if (buffer.isNotEmpty && buffer.length + part.length + 1 > maxLength) {
        result.add(buffer);
        buffer = '';
      }
      while (part.length > maxLength) {
        if (buffer.isNotEmpty) {
          result.add(buffer);
          buffer = '';
        }
        result.add(part.substring(0, maxLength));
        part = part.substring(maxLength);
      }
      buffer = buffer.isEmpty ? part : '$buffer $part';
    }
    if (buffer.isNotEmpty) result.add(buffer);
    return result;
  }

  @override
  void dispose() {
    _disposed = true;
    _chapterCompleted.close();
    unawaited(_engine.stop());
    super.dispose();
  }
}
