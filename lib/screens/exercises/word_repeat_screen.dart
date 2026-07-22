import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../../services/speech_grading_service.dart';
import '../../services/firestore_service.dart';
import '../../services/audio_service.dart';
import '../../models/exercise_result_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';

class WordRepeatScreen extends StatefulWidget {
  final int difficulty;
  const WordRepeatScreen({super.key, this.difficulty = AppConstants.difficultyEasy});

  @override
  State<WordRepeatScreen> createState() => _WordRepeatScreenState();
}

class _WordRepeatScreenState extends State<WordRepeatScreen> {
  final _gradingService = SpeechGradingService();
  final _firestoreService = FirestoreService();
  final _audioService = AudioService();

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
  StreamSubscription<String>? _transcriptionSub;

  // Timer state for Medium difficulty
  Timer? _countdownTimer;
  int _remainingSeconds = AppConstants.mediumTimerSeconds;

  /// Whether we're in Hard mode
  bool get _isHard => widget.difficulty == AppConstants.difficultyHard;
  bool get _isMedium => widget.difficulty == AppConstants.difficultyMedium;

  /// Current word or chain depending on difficulty
  String get _currentWord {
    if (_isHard) {
      return AppConstants.wordRepeatHardItems[_currentIndex]['chain']!;
    }
    return AppConstants.wordRepeatItems[_currentIndex];
  }

  /// Individual words in the chain (for display with arrows)
  List<String> get _chainWords =>
      _isHard ? _currentWord.split(' ') : [_currentWord];

  /// Total item count
  int get _itemCount => _isHard
      ? AppConstants.wordRepeatHardItems.length
      : AppConstants.wordRepeatItems.length;

  @override
  void initState() {
    super.initState();
    _audioService.initTTS();
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
    _audioService.dispose();
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
        if (_isListening) _toggleRecording();
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
  }

  Future<void> _listenToWord() async {
    await _audioService.speak(_currentWord);
  }

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

      final result = await _gradingService.gradeSpeech(
        audioPath: _recordingPath ?? '',
        expectedPhrase: _currentWord,
      );

      final uid = FirebaseAuth.instance.currentUser!.uid;
      await _firestoreService.saveExerciseResult(ExerciseResultModel(
        id: const Uuid().v4(),
        userId: uid,
        phraseExpected: _currentWord,
        phraseSpoken: result['spoken_phrase'] ?? '',
        clarityScore: (result['clarity_score'] as num).toDouble(),
        accuracyScore: (result['accuracy_score'] as num).toDouble(),
        fluencyScore: (result['fluency_score'] as num).toDouble(),
        feedback: result['feedback'] ?? '',
        modelConfidence: (result['model_confidence'] as num).toDouble(),
        exerciseType: AppConstants.wordRepeat,
      ));

      if (mounted) {
        setState(() {
          _score = (result['clarity_score'] as num).toDouble();
          _accuracyScore = (result['accuracy_score'] as num).toDouble();
          _fluencyScore = (result['fluency_score'] as num).toDouble();
          _feedback = result['feedback'] ?? '';
          _spokenPhrase = result['spoken_phrase'] ?? '';
          _hasResult = true;
          _isProcessing = false;
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
        if (_isMedium) {
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

  void _nextWord() {
    _cancelCountdown();
    setState(() {
      _currentIndex = (_currentIndex + 1) % _itemCount;
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
      margin: const EdgeInsets.only(right: 16),
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
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('Word Repeat Challenge'),
        backgroundColor: Colors.transparent,
        actions: [_difficultyBadge()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Word display card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2BCDEE), Color(0xFF4ECDC4)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2BCDEE).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text('Say this word:', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  // Hard mode: show chain of words with arrows
                  if (_isHard) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Repeat this sequence in order:',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      runSpacing: 8,
                      children: List.generate(_chainWords.length * 2 - 1, (i) {
                        if (i.isOdd) {
                          return const Text('→',
                              style: TextStyle(color: Colors.white70, fontSize: 20, fontWeight: FontWeight.w600));
                        }
                        final wordIndex = i ~/ 2;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _chainWords[wordIndex],
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                        );
                      }),
                    ),
                  ] else ...[
                    Text(
                      _currentWord,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _listenToWord,
                        icon: const Icon(Icons.volume_up, color: Colors.white, size: 18),
                        label: const Text('Listen', style: TextStyle(color: Colors.white)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white54),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _nextWord,
                        icon: const Icon(Icons.skip_next, color: Colors.white, size: 18),
                        label: const Text('Next', style: TextStyle(color: Colors.white)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white54),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Timer display for Medium difficulty
            if (_isMedium && _isListening)
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
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _isListening ? AppTheme.primaryColor.withOpacity(0.3) : Colors.transparent,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Your Speech', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        if (_isListening) ...[
                          const SizedBox(width: 8),
                          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _liveTranscription.isEmpty ? 'Listening...' : _liveTranscription,
                      style: TextStyle(
                        fontSize: 16,
                        color: _liveTranscription.isEmpty ? AppTheme.textLight : AppTheme.textPrimary,
                        fontStyle: _liveTranscription.isEmpty ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 28),

            // Record button
            GestureDetector(
              onTap: _isProcessing ? null : _toggleRecording,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _isProcessing ? AppTheme.textLight : (_isListening ? AppTheme.error : AppTheme.primaryColor),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isListening ? AppTheme.error : AppTheme.primaryColor)
                          .withOpacity(0.4),
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: _isProcessing
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                      )
                    : Icon(
                        _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isProcessing ? 'Processing...' : (_isListening ? 'Listening...' : 'Tap to record'),
              style: const TextStyle(color: AppTheme.textSecondary),
            ),

            // Result
            if (_hasResult) ...[
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      '${_score.toInt()}%',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: _score >= 75 ? AppTheme.success : AppTheme.warning,
                      ),
                    ),
                    const Text('Clarity', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 12),
                    // Accuracy bar
                    _buildScoreBar('Accuracy', _accuracyScore, Icons.spellcheck_rounded),
                    const SizedBox(height: 8),
                    // Fluency bar (only if model produced a score)
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
                        color: AppTheme.scaffoldBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Target:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          Text(_currentWord, style: const TextStyle(fontWeight: FontWeight.w600)),
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
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _hasResult = false;
                                _liveTranscription = '';
                                _spokenPhrase = '';
                              });
                            },
                            child: const Text('Try Again'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _nextWord,
                            child: const Text('Next Word'),
                          ),
                        ),
                      ],
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
