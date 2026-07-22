import 'dart:async';
import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioService {
  final FlutterTts _tts = FlutterTts();
  final AudioRecorder _recorder = AudioRecorder();
  String? _currentRecordingPath;
  bool _isRecording = false;
  
  // Stream controller for audio amplitude (for waveform)
  final StreamController<double> _amplitudeController = StreamController<double>.broadcast();
  Stream<double> get amplitudeStream => _amplitudeController.stream;
  Timer? _amplitudeTimer;

  bool get isRecording => _isRecording;
  String? get currentRecordingPath => _currentRecordingPath;

  // Initialize TTS
  Future<void> initTTS() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.4); // Slow for therapy
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  // Speak text (for "Listen to Example")
  Future<void> speak(String text) async {
    await _tts.speak(text);
  }

  // Stop speaking
  Future<void> stopSpeaking() async {
    await _tts.stop();
  }

  // Request microphone permission
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  // Start recording
  Future<String?> startRecording() async {
    final hasPermission = await requestPermission();
    if (!hasPermission) return null;

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _currentRecordingPath = '${dir.path}/recording_$timestamp.wav';

    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: _currentRecordingPath!,
      );
      _isRecording = true;

      // Start amplitude monitoring for waveform
      _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
        try {
          final amplitude = await _recorder.getAmplitude();
          final normalized = ((amplitude.current + 50) / 50).clamp(0.0, 1.0);
          _amplitudeController.add(normalized);
        } catch (_) {}
      });

      return _currentRecordingPath;
    } catch (e) {
      _isRecording = false;
      return null;
    }
  }

  // Stop recording
  Future<String?> stopRecording() async {
    _amplitudeTimer?.cancel();
    _isRecording = false;

    try {
      final path = await _recorder.stop();
      return path ?? _currentRecordingPath;
    } catch (e) {
      return _currentRecordingPath;
    }
  }

  // Cancel recording
  Future<void> cancelRecording() async {
    _amplitudeTimer?.cancel();
    _isRecording = false;
    try {
      await _recorder.cancel();
      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (_) {}
  }

  // Dispose
  void dispose() {
    _amplitudeTimer?.cancel();
    _amplitudeController.close();
    _recorder.dispose();
    _tts.stop();
  }
}
