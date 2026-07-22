import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io' show Platform;
import 'dart:math';
import 'dart:ui';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'fluency_model_service.dart';

class SpeechGradingService {
  SpeechToText _stt = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;

  /// Timestamp when listening started — used to suppress spurious
  /// 'done' status callbacks that some Android OEMs fire immediately
  /// after the recognizer begins (before any speech is captured).
  DateTime? _listenStartTime;
  static const _minListenDuration = Duration(milliseconds: 1500);

  String _transcription = '';
  double _sttConfidence = 0.0;

  /// Diagnostic message for UI to display when STT fails on restrictive OEMs.
  String _lastDiagnostic = '';
  String get lastDiagnostic => _lastDiagnostic;

  // ─── Fluency model ────────────────────────────────────────────────────
  final FluencyModelService _fluencyService = FluencyModelService();
  bool get isFluencyModelLoaded => _fluencyService.isLoaded;

  /// Weight given to text accuracy in the combined clarity score.
  /// Fluency weight = 1 - accuracyWeight.
  static const double accuracyWeight = 0.6;
  static const double fluencyWeight = 0.4;

  // Stream controller so screens can show live transcription
  final StreamController<String> _liveTranscriptionController =
      StreamController<String>.broadcast();
  Stream<String> get liveTranscription => _liveTranscriptionController.stream;

  // Callback fired when STT engine auto-stops (e.g. pauseFor silence timeout).
  // Screens should set this to auto-process results without waiting for user tap.
  VoidCallback? onAutoStop;

  bool get isListening => _isListening;
  bool get isAvailable => _isInitialized;

  /// Initialize STT engine **and** load the fluency model.
  ///
  /// On restrictive OEMs (Xiaomi/MIUI, Huawei EMUI) the SpeechRecognizer
  /// service may take several seconds to become available after a fresh
  /// install/permission grant.  We retry up to 3 times with increasing
  /// back-off to handle this.
  Future<void> loadModel() async {
    if (_isInitialized) return;

    // ── STT initialization with retry (critical for MIUI/Xiaomi) ──
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        dev.log(
          'STT init attempt $attempt/$maxAttempts',
          name: 'SpeechGradingService',
        );
        _isInitialized = await _stt.initialize(
          onStatus: (status) {
            dev.log('STT status: $status', name: 'SpeechGradingService');
            if (status == 'done' || status == 'notListening') {
              final wasListening = _isListening;
              _isListening = false;
              // Guard: suppress auto-stop if we haven't been listening
              // long enough — many Android OEMs (Xiaomi, Samsung budget
              // phones) fire a spurious 'done' right after listen() begins,
              // causing "no speech detected" when there was no time to speak.
              if (wasListening && onAutoStop != null) {
                final elapsed = _listenStartTime != null
                    ? DateTime.now().difference(_listenStartTime!)
                    : Duration.zero;
                if (elapsed >= _minListenDuration && _transcription.isNotEmpty) {
                  // Legitimate auto-stop: user spoke and silence timeout fired
                  onAutoStop!();
                } else if (elapsed >= _minListenDuration) {
                  // Enough time passed but nothing was said — still auto-stop
                  // so the screen can show "no speech detected" feedback.
                  onAutoStop!();
                } else {
                  dev.log(
                    'Suppressed spurious auto-stop (elapsed: ${elapsed.inMilliseconds}ms)',
                    name: 'SpeechGradingService',
                  );
                  // Try to restart listening automatically — the engine
                  // may have died prematurely on this device.
                  _restartListeningQuietly();
                }
              }
            }
          },
          onError: (error) {
            dev.log(
              'STT error: ${error.errorMsg} (permanent: ${error.permanent})',
              name: 'SpeechGradingService',
            );
            _isListening = false;
            // On Xiaomi, error_speech_timeout fires even when mic is blocked.
            // Store diagnostic so the UI can advise the user.
            if (error.permanent) {
              _lastDiagnostic =
                  'Speech engine error: ${error.errorMsg}. '
                  'Please check your device settings.';
            }
          },
        );
      } catch (e) {
        dev.log(
          'STT init exception on attempt $attempt: $e',
          name: 'SpeechGradingService',
        );
        _isInitialized = false;
      }

      if (_isInitialized) {
        dev.log(
          'STT initialized successfully on attempt $attempt',
          name: 'SpeechGradingService',
        );
        _lastDiagnostic = '';
        break;
      }

      // Wait before retrying — MIUI may need time to release the recognizer
      if (attempt < maxAttempts) {
        final delayMs = 500 * attempt; // 500ms, 1000ms
        dev.log(
          'STT init failed, retrying in ${delayMs}ms…',
          name: 'SpeechGradingService',
        );
        await Future.delayed(Duration(milliseconds: delayMs));
        // Create a fresh instance — some OEMs corrupt the previous one
        _stt = SpeechToText();
      }
    }

    if (!_isInitialized) {
      _lastDiagnostic =
          'Speech recognition unavailable. '
          'On Xiaomi/MIUI: go to Settings → Apps → Manage apps → '
          'this app → Permissions → enable Microphone, '
          'then Autostart → enable. '
          'Also ensure Google app is installed and updated.';
      dev.log(_lastDiagnostic, name: 'SpeechGradingService');
    }

    // Load fluency model in parallel — if it fails the app still works
    // (fluency score will be -1 and the screen shows only accuracy).
    try {
      await _fluencyService.loadModel();
      dev.log(
        'Fluency model loaded: ${_fluencyService.isLoaded}',
        name: 'SpeechGradingService',
      );
    } catch (e) {
      dev.log(
        'Fluency model failed to load (will use accuracy-only): $e',
        name: 'SpeechGradingService',
        error: e,
      );
    }
  }

  /// Force re-initialization of STT. Useful when the user has just changed
  /// device permissions and wants to retry without restarting the app.
  Future<void> forceReinitialize() async {
    _isInitialized = false;
    _isListening = false;
    _stt = SpeechToText();
    await loadModel();
  }

  /// Start listening for speech. Call this when the mic button is tapped.
  Future<bool> startListening() async {
    if (!_isInitialized) {
      await loadModel();
    }
    if (!_isInitialized) return false;

    _transcription = '';
    _sttConfidence = 0.0;
    _listenStartTime = DateTime.now();

    // Use a longer pauseFor on Android — Xiaomi/MIUI audio pipeline has
    // higher latency and may misinterpret brief silence as end-of-speech.
    final pauseDuration = Platform.isAndroid
        ? const Duration(seconds: 5)
        : const Duration(seconds: 3);

    try {
      await _stt.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 30),
        pauseFor: pauseDuration,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          listenMode: ListenMode.dictation,
          cancelOnError: false,   // Don't cancel on transient errors
          autoPunctuation: true,  // Better transcription quality
        ),
        localeId: 'en_US',
      );
      _isListening = true;
      dev.log('STT listening started', name: 'SpeechGradingService');
      return true;
    } catch (e) {
      dev.log('STT listen failed: $e', name: 'SpeechGradingService');
      _isListening = false;
      // Try one re-init + retry for MIUI edge cases where the recognizer
      // was initialized successfully but becomes stale between taps.
      try {
        dev.log('Attempting STT re-init + retry…', name: 'SpeechGradingService');
        _isInitialized = false;
        _stt = SpeechToText();
        await loadModel();
        if (_isInitialized) {
          await _stt.listen(
            onResult: _onSpeechResult,
            listenFor: const Duration(seconds: 30),
            pauseFor: pauseDuration,
            listenOptions: SpeechListenOptions(
              partialResults: true,
              listenMode: ListenMode.dictation,
              cancelOnError: false,
              autoPunctuation: true,
            ),
            localeId: 'en_US',
          );
          _isListening = true;
          dev.log('STT retry succeeded', name: 'SpeechGradingService');
          return true;
        }
      } catch (_) {}
      return false;
    }
  }

  /// Stop listening. Call this when the mic button is tapped again.
  Future<void> stopListening() async {
    _listenStartTime = null; // prevent spurious restart after intentional stop
    try {
      await _stt.stop();
    } catch (_) {}
    _isListening = false;
  }

  /// Silently restart STT after a spurious 'done' status.
  /// This is called when the engine dies prematurely on some Android OEMs
  /// (within [_minListenDuration] of starting). We wait a brief moment
  /// then try to listen again.
  void _restartListeningQuietly() async {
    dev.log(
      'Attempting quiet STT restart…',
      name: 'SpeechGradingService',
    );
    // Brief pause to let the engine fully release
    await Future.delayed(const Duration(milliseconds: 300));
    if (_listenStartTime == null) return; // user already stopped manually

    try {
      final pauseDuration = Platform.isAndroid
          ? const Duration(seconds: 5)
          : const Duration(seconds: 3);

      await _stt.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 30),
        pauseFor: pauseDuration,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          listenMode: ListenMode.dictation,
          cancelOnError: false,
          autoPunctuation: true,
        ),
        localeId: 'en_US',
      );
      _isListening = true;
      _listenStartTime = DateTime.now(); // reset the guard timer
      dev.log('Quiet restart succeeded', name: 'SpeechGradingService');
    } catch (e) {
      dev.log(
        'Quiet restart failed: $e — will let auto-stop fire normally next time',
        name: 'SpeechGradingService',
      );
      // If restart fails, force auto-stop so user gets feedback
      _isListening = false;
      if (onAutoStop != null) onAutoStop!();
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (result.recognizedWords.isNotEmpty) {
      _transcription = result.recognizedWords;
    }
    // Only update confidence if it's > 0 or we don't have one yet
    if (result.confidence > 0) {
      _sttConfidence = result.confidence;
    }
    _liveTranscriptionController.add(_transcription);
  }

  // ─────────────────────────────────────────────────────────────────────
  //  DUAL-SCORING PIPELINE
  // ─────────────────────────────────────────────────────────────────────

  /// Grade the speech by comparing transcription against expected phrase
  /// **and** running the fluency model on the recorded audio.
  ///
  /// Returns:
  /// ```
  /// {
  ///   'clarity_score':     double,   // combined (weighted) score
  ///   'accuracy_score':    double,   // LCS text-based score (0–100)
  ///   'fluency_score':     double,   // GRU model score (0–100), -1 = n/a
  ///   'expected_phrase':   String,
  ///   'spoken_phrase':     String,
  ///   'feedback':          String,
  ///   'model_confidence':  double,
  /// }
  /// ```
  Future<Map<String, dynamic>> gradeSpeech({
    required String audioPath,
    required String expectedPhrase,
  }) async {
    final spokenPhrase = _transcription.trim();

    // If nothing was spoken at all
    if (spokenPhrase.isEmpty) {
      return {
        'clarity_score': 0.0,
        'accuracy_score': 0.0,
        'fluency_score': -1.0,
        'expected_phrase': expectedPhrase,
        'spoken_phrase': '',
        'feedback':
            'No speech detected. Please tap the mic and speak the phrase clearly.',
        'model_confidence': 0.0,
      };
    }

    // ── 1. Text accuracy (LCS) ──────────────────────────────────────
    final expectedWords = _normalizeText(expectedPhrase).split(' ');
    final spokenWords = _normalizeText(spokenPhrase).split(' ');
    final matchResult = _calculateWordAccuracy(expectedWords, spokenWords);
    final accuracyScore =
        double.parse((matchResult * 100).clamp(0.0, 100.0).toStringAsFixed(1));

    // ── 2. Fluency score (GRU model) ────────────────────────────────
    double fluencyScore = -1.0;
    try {
      if (_fluencyService.isLoaded && audioPath.isNotEmpty) {
        fluencyScore = await _fluencyService.runInference(audioPath);
        if (fluencyScore >= 0) {
          fluencyScore =
              double.parse(fluencyScore.clamp(0.0, 100.0).toStringAsFixed(1));
        }
        dev.log(
          'Fluency inference result: $fluencyScore',
          name: 'SpeechGradingService',
        );
      }
    } catch (e) {
      dev.log(
        'Fluency inference failed: $e',
        name: 'SpeechGradingService',
        error: e,
      );
      fluencyScore = -1.0;
    }

    // ── 3. Combined clarity score ───────────────────────────────────
    double clarityScore;
    if (fluencyScore >= 0) {
      // Weighted combination: 60 % accuracy + 40 % fluency
      clarityScore = (accuracyScore * accuracyWeight) +
          (fluencyScore * fluencyWeight);
    } else {
      // Fluency unavailable — fall back to accuracy only
      clarityScore = accuracyScore;
    }
    clarityScore =
        double.parse(clarityScore.clamp(0.0, 100.0).toStringAsFixed(1));

    final confidence =
        _sttConfidence > 0 ? _sttConfidence : (clarityScore / 100.0);

    return {
      'clarity_score': clarityScore,
      'accuracy_score': accuracyScore,
      'fluency_score': fluencyScore,
      'expected_phrase': expectedPhrase,
      'spoken_phrase': spokenPhrase,
      'feedback': _getFeedbackForScore(clarityScore, fluencyScore),
      'model_confidence': double.parse(confidence.toStringAsFixed(2)),
    };
  }

  // ─────────────────────────────────────────────────────────────────────
  //  TEXT MATCHING UTILITIES  (unchanged)
  // ─────────────────────────────────────────────────────────────────────

  /// Normalize text for comparison: lowercase, remove punctuation
  String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // remove punctuation
        .replaceAll(RegExp(r'\s+'), ' ')    // collapse whitespace
        .trim();
  }

  /// Calculate word-level accuracy between expected and spoken.
  /// Uses longest common subsequence (LCS) for flexible matching.
  double _calculateWordAccuracy(List<String> expected, List<String> spoken) {
    if (expected.isEmpty) return spoken.isEmpty ? 1.0 : 0.0;
    if (spoken.isEmpty) return 0.0;

    // Compute LCS length using dynamic programming
    final m = expected.length;
    final n = spoken.length;
    final dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));

    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        if (_wordsMatch(expected[i - 1], spoken[j - 1])) {
          dp[i][j] = dp[i - 1][j - 1] + 1;
        } else {
          dp[i][j] = max(dp[i - 1][j], dp[i][j - 1]);
        }
      }
    }

    final lcsLength = dp[m][n];
    // Score = matched words / total expected words
    // Penalize extra words slightly (if spoken more words than expected)
    final matchRatio = lcsLength / m;
    final lengthPenalty = spoken.length > m
        ? 1.0 - ((spoken.length - m) / (m * 4)).clamp(0.0, 0.2)
        : 1.0;

    return (matchRatio * lengthPenalty).clamp(0.0, 1.0);
  }

  /// Fuzzy word matching — allows minor differences (e.g., plural forms)
  bool _wordsMatch(String word1, String word2) {
    if (word1 == word2) return true;
    // Allow if one is a substring of the other (handles plurals, tense)
    if (word1.length > 2 && word2.length > 2) {
      if (word1.startsWith(word2) || word2.startsWith(word1)) return true;
    }
    // Allow 1-character difference for words > 3 chars
    if (word1.length > 3 && word2.length > 3) {
      return _editDistance(word1, word2) <= 1;
    }
    return false;
  }

  /// Simple edit distance (Levenshtein)
  int _editDistance(String a, String b) {
    final m = a.length;
    final n = b.length;
    final dp = List.generate(m + 1, (i) => List.generate(n + 1, (j) => i == 0 ? j : (j == 0 ? i : 0)));
    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        if (a[i - 1] == b[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1];
        } else {
          dp[i][j] = 1 + [dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]].reduce(min);
        }
      }
    }
    return dp[m][n];
  }

  // ─────────────────────────────────────────────────────────────────────
  //  FEEDBACK
  // ─────────────────────────────────────────────────────────────────────

  /// Generate human-friendly feedback based on combined clarity and fluency.
  String _getFeedbackForScore(double clarityScore, double fluencyScore) {
    // Base feedback on clarity score
    String base;
    if (clarityScore >= 90) {
      base = 'Excellent! Your pronunciation is very clear and accurate.';
    } else if (clarityScore >= 75) {
      base = 'Great job! Most words matched. Keep practicing for perfection.';
    } else if (clarityScore >= 60) {
      base = 'Good effort! Try speaking a bit slower and more clearly.';
    } else if (clarityScore >= 40) {
      base = 'Nice try! Focus on each word individually for better accuracy.';
    } else if (clarityScore >= 10) {
      base = 'Keep practicing! Listen to the example and try to match each word.';
    } else {
      base = 'No speech detected. Please tap the mic and speak the phrase clearly.';
    }

    // Add fluency-specific hint when the model was able to score
    if (fluencyScore >= 0 && fluencyScore < 50) {
      base += ' Try to speak more smoothly without pauses between words.';
    }

    return base;
  }

  void dispose() {
    _stt.stop();
    _liveTranscriptionController.close();
    _fluencyService.dispose();
  }
}
