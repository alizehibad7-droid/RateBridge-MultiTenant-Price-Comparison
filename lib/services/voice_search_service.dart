// MVVM: Service — external API wrapper only
import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/app_exception.dart';

class VoiceSearchService {
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  String _partialResult = '';

  final StreamController<String> _partialResultController =
    StreamController<String>.broadcast();
  final StreamController<bool> _listeningStateController =
    StreamController<bool>.broadcast();

  Stream<String> get partialResults => _partialResultController.stream;
  Stream<bool> get listeningState => _listeningStateController.stream;
  bool get isListening => _isListening;

  Future<bool> requestMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> startListening(String locale) async {
    final hasPermission = await requestMicPermission();
    if (!hasPermission) {
      throw AppException('Microphone permission denied');
    }
    final available = await _speech.initialize(
      onError: (error) => _listeningStateController.add(false),
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          _isListening = false;
          _listeningStateController.add(false);
        }
      },
    );
    if (!available) throw AppException('Speech recognition not available on this device');

    await _speech.listen(
      localeId: locale, // 'ur-PK' or 'en-US'
      onResult: (result) {
        _partialResult = result.recognizedWords;
        _partialResultController.add(_partialResult);
        if (result.finalResult) {
          _isListening = false;
          _listeningStateController.add(false);
        }
      },
      listenMode: ListenMode.confirmation,
    );
    _isListening = true;
    _listeningStateController.add(true);
  }

  Future<String> stopListening() async {
    await _speech.stop();
    _isListening = false;
    _listeningStateController.add(false);
    return _partialResult;
  }

  void dispose() {
    _partialResultController.close();
    _listeningStateController.close();
  }
}
