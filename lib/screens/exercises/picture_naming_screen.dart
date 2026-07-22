import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../../services/speech_grading_service.dart';
import '../../services/audio_service.dart';
import '../../services/firestore_service.dart';
import '../../models/exercise_result_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';

class PictureNamingScreen extends StatefulWidget {
  final int difficulty;
  const PictureNamingScreen({super.key, this.difficulty = AppConstants.difficultyEasy});

  @override
  State<PictureNamingScreen> createState() => _PictureNamingScreenState();
}

class _PictureNamingScreenState extends State<PictureNamingScreen> {
  final _gradingService = SpeechGradingService();
  final _audioService = AudioService();
  final _firestoreService = FirestoreService();

  int _currentIndex = 0;
  bool _isListening = false;
  bool _hasResult = false;
  bool _isProcessing = false;
  double _score = 0;
  double _accuracyScore = 0;
  double _fluencyScore = -1;
  String _feedback = '';
  String _spokenPhrase = '';
  String _liveTranscription = '';
  String? _recordingPath;
  int _correctCount = 0;
  int _totalAttempts = 0;
  StreamSubscription<String>? _transcriptionSub;

  // Timer state for Medium difficulty
  Timer? _countdownTimer;
  int _remainingSeconds = AppConstants.mediumTimerSeconds;

  /// Items list based on difficulty
  List<Map<String, String>> get _items =>
      widget.difficulty == AppConstants.difficultyHard
          ? AppConstants.pictureNamingHardItems
          : AppConstants.pictureNamingItems;

  Map<String, String> get _currentItem => _items[_currentIndex];

  @override
  void initState() {
    super.initState();
    _gradingService.loadModel();
    _transcriptionSub = _gradingService.liveTranscription.listen((text) {
      if (mounted) setState(() => _liveTranscription = text);
    });
    // Auto-process when STT engine stops on its own (silence timeout)
    _gradingService.onAutoStop = _handleAutoStop;
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _transcriptionSub?.cancel();
    _gradingService.onAutoStop = null;
    _gradingService.dispose();
    super.dispose();
  }

  /// Called when STT auto-stops (e.g. 7s silence). Triggers grading automatically.
  void _handleAutoStop() {
    if (!mounted || !_isListening) return;
    _toggleRecording(); // triggers the stop + grade path
  }

  // ─── Timer helpers (Medium difficulty) ───
  void _startCountdown() {
    _remainingSeconds = AppConstants.mediumTimerSeconds;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() => _remainingSeconds--);
      if (_remainingSeconds <= 0) {
        timer.cancel();
        // Auto-stop recording when time's up
        if (_isListening) _toggleRecording();
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
  }

  // ─── Recording toggle ───
  Future<void> _toggleRecording() async {
    if (_isListening) {
      // Stop listening and grade
      _cancelCountdown();
      await _gradingService.stopListening();
      // Stop audio recording for fluency analysis
      final path = await _audioService.stopRecording();
      setState(() {
        _isListening = false;
        _isProcessing = true;
        _recordingPath = path;
      });

      final isHardMode = widget.difficulty == AppConstants.difficultyHard;
      final result = await _gradingService.gradeSpeech(
        audioPath: _recordingPath ?? '',
        expectedPhrase: isHardMode ? _currentItem['chain']! : _currentItem['word']!,
      );

      final uid = FirebaseAuth.instance.currentUser!.uid;
      final expectedLabel = isHardMode ? _currentItem['chain']! : _currentItem['word']!;
      await _firestoreService.saveExerciseResult(ExerciseResultModel(
        id: const Uuid().v4(),
        userId: uid,
        phraseExpected: expectedLabel,
        phraseSpoken: result['spoken_phrase'] ?? '',
        clarityScore: (result['clarity_score'] as num).toDouble(),
        accuracyScore: (result['accuracy_score'] as num).toDouble(),
        fluencyScore: (result['fluency_score'] as num).toDouble(),
        feedback: result['feedback'] ?? '',
        modelConfidence: (result['model_confidence'] as num).toDouble(),
        exerciseType: AppConstants.pictureNaming,
      ));

      if (mounted) {
        final s = (result['clarity_score'] as num).toDouble();
        setState(() {
          _score = s;
          _accuracyScore = (result['accuracy_score'] as num).toDouble();
          _fluencyScore = (result['fluency_score'] as num).toDouble();
          _feedback = result['feedback'] ?? '';
          _spokenPhrase = result['spoken_phrase'] ?? '';
          _hasResult = true;
          _isProcessing = false;
          _totalAttempts++;
          if (s >= 60) _correctCount++;
        });
      }
    } else {
      // Start listening
      setState(() {
        _hasResult = false;
        _liveTranscription = '';
        _spokenPhrase = '';
        _recordingPath = null;
      });
      // ── Start STT FIRST (must acquire mic before record package) ──
      final started = await _gradingService.startListening();
      if (started && mounted) {
        setState(() => _isListening = true);
        if (widget.difficulty == AppConstants.difficultyMedium) {
          _startCountdown();
        }
        // Start WAV recording in background for fluency model.
        // Small delay lets STT settle; if record fails (mic contention),
        // fluency score will gracefully fall back to accuracy-only.
        Future.delayed(const Duration(milliseconds: 200), () async {
          try {
            await _audioService.startRecording();
          } catch (_) {
            // WAV recording failed — STT still works, fluency will be -1
          }
        });
      } else if (mounted) {
        final diagnostic = _gradingService.lastDiagnostic;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              diagnostic.isNotEmpty
                  ? diagnostic
                  : 'Microphone permission required. Please check app settings.',
            ),
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'RETRY',
              onPressed: () async {
                await _gradingService.forceReinitialize();
                if (mounted) _toggleRecording();
              },
            ),
          ),
        );
      }
    }
  }

  void _nextItem() {
    _cancelCountdown();
    setState(() {
      _currentIndex = (_currentIndex + 1) % _items.length;
      _hasResult = false;
      _score = 0;
      _accuracyScore = 0;
      _fluencyScore = -1;
      _liveTranscription = '';
      _spokenPhrase = '';
      _recordingPath = null;
    });
  }

  // ─── Difficulty badge ───
  Widget _difficultyBadge() {
    final labels = {
      AppConstants.difficultyEasy: ('Easy', AppTheme.success),
      AppConstants.difficultyMedium: ('Medium', AppTheme.warning),
      AppConstants.difficultyHard: ('Hard', AppTheme.error),
    };
    final entry = labels[widget.difficulty]!;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: entry.$2.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        entry.$1,
        style: TextStyle(
          color: entry.$2,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isHard = widget.difficulty == AppConstants.difficultyHard;
    final isMedium = widget.difficulty == AppConstants.difficultyMedium;

    final chainWords = isHard ? _currentItem['chain']!.split(' ') : <String>[];
    final chainEmojis = isHard ? _currentItem['emojis']!.split(' ') : <String>[];

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('Picture Naming'),
        backgroundColor: Colors.transparent,
        actions: [
          _difficultyBadge(),
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$_correctCount / $_totalAttempts',
              style: const TextStyle(
                color: AppTheme.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Progress
            Row(
              children: List.generate(
                _items.length,
                (i) => Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: i <= _currentIndex
                          ? AppTheme.accentColor
                          : const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Image card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Hard mode: show chain of emojis with word labels
                  if (isHard) ...[
                    // Show emojis in a row with arrows
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 4,
                      runSpacing: 8,
                      children: List.generate(chainEmojis.length * 2 - 1, (i) {
                        if (i.isOdd) {
                          return const Text('→',
                              style: TextStyle(fontSize: 28, color: Colors.black38));
                        }
                        final idx = i ~/ 2;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(chainEmojis[idx], style: const TextStyle(fontSize: 48)),
                            const SizedBox(height: 4),
                            Text(
                              chainWords[idx],
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.error.withOpacity(0.2)),
                      ),
                      child: const Text(
                        'Say all words in the correct order!',
                        style: TextStyle(
                          color: AppTheme.error,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ] else ...[
                    // Normal/easy mode: single emoji
                    Text(
                      _currentItem['emoji']!,
                      style: const TextStyle(fontSize: 100),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Name this object',
                        style: TextStyle(
                          color: AppTheme.accentColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Timer display for Medium difficulty
            if (isMedium && _isListening)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: _remainingSeconds / AppConstants.mediumTimerSeconds,
                            strokeWidth: 5,
                            backgroundColor: const Color(0xFFE5E7EB),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _remainingSeconds <= 2 ? AppTheme.error : AppTheme.warning,
                            ),
                          ),
                          Center(
                            child: Text(
                              '$_remainingSeconds',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: _remainingSeconds <= 2 ? AppTheme.error : AppTheme.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _remainingSeconds <= 2 ? 'Hurry up!' : 'Time remaining',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _remainingSeconds <= 2 ? AppTheme.error : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

            // Live transcription preview
            if (_isListening || _liveTranscription.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isListening ? AppTheme.accentColor.withOpacity(0.3) : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    if (_isListening)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentColor)),
                      ),
                    Expanded(
                      child: Text(
                        _liveTranscription.isEmpty ? 'Listening...' : _liveTranscription,
                        style: TextStyle(
                          fontSize: 15,
                          color: _liveTranscription.isEmpty ? AppTheme.textLight : AppTheme.textPrimary,
                          fontStyle: _liveTranscription.isEmpty ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Record button
            GestureDetector(
              onTap: _isProcessing ? null : _toggleRecording,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _isProcessing ? AppTheme.textLight : (_isListening ? AppTheme.error : AppTheme.accentColor),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isListening ? AppTheme.error : AppTheme.accentColor)
                          .withOpacity(0.4),
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: _isProcessing
                    ? const Padding(
                        padding: EdgeInsets.all(22),
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                      )
                    : Icon(
                        _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isProcessing ? 'Processing...' : (_isListening ? 'Listening...' : 'Tap to answer'),
              style: const TextStyle(color: AppTheme.textSecondary),
            ),

            // Result
            if (_hasResult) ...[
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _score >= 60
                      ? AppTheme.success.withOpacity(0.1)
                      : AppTheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _score >= 60
                        ? AppTheme.success.withOpacity(0.3)
                        : AppTheme.error.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _score >= 60 ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      color: _score >= 60 ? AppTheme.success : AppTheme.error,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _score >= 60 ? 'Correct! 🎉' : 'Try Again!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: _score >= 60 ? AppTheme.success : AppTheme.error,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Clarity: ${_score.toInt()}%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _score >= 60 ? AppTheme.success : AppTheme.error,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Accuracy & Fluency bars
                    _buildScoreBar('Accuracy', _accuracyScore, Icons.spellcheck_rounded),
                    const SizedBox(height: 8),
                    if (_fluencyScore >= 0) ...[
                      _buildScoreBar('Fluency', _fluencyScore, Icons.graphic_eq_rounded),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 4),
                    // Target vs Attempt
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Target:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          Text(
                            isHard ? _currentItem['chain']! : _currentItem['word']!,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          const Text('Your Attempt:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          Text(
                            _spokenPhrase.isEmpty ? 'No speech detected' : _spokenPhrase,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _spokenPhrase.isEmpty ? AppTheme.error : AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_feedback, textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.textSecondary)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _nextItem,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentColor,
                        ),
                        child: const Text('Next Picture →'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Reusable score bar widget for accuracy / fluency breakdowns.
  Widget _buildScoreBar(String label, double score, IconData icon) {
    Color barColor;
    if (score >= 75) {
      barColor = AppTheme.success;
    } else if (score >= 50) {
      barColor = AppTheme.warning;
    } else {
      barColor = AppTheme.error;
    }

    return Row(
      children: [
        Icon(icon, size: 16, color: barColor),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        const Spacer(),
        Text('${score.toInt()}%',
            style: TextStyle(fontWeight: FontWeight.w600, color: barColor, fontSize: 13)),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 8,
              backgroundColor: barColor.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
        ),
      ],
    );
  }
}
