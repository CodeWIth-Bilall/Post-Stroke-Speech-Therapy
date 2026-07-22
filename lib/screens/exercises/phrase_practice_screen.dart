import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../../services/audio_service.dart';
import '../../services/speech_grading_service.dart';
import '../../services/storage_service.dart';
import '../../services/firestore_service.dart';
import '../../models/exercise_result_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';

class PhrasePracticeScreen extends StatefulWidget {
  final String phrase;
  final String category;

  const PhrasePracticeScreen({
    super.key,
    required this.phrase,
    required this.category,
  });

  @override
  State<PhrasePracticeScreen> createState() => _PhrasePracticeScreenState();
}

class _PhrasePracticeScreenState extends State<PhrasePracticeScreen>
    with SingleTickerProviderStateMixin {
  final _audioService = AudioService();
  final _gradingService = SpeechGradingService();
  final _storageService = StorageService();
  final _firestoreService = FirestoreService();

  bool _isRecording = false;
  bool _isProcessing = false;
  bool _hasResult = false;
  Map<String, dynamic>? _result;
  String? _recordingPath;
  List<double> _amplitudes = [];
  late AnimationController _pulseController;

  String _liveText = '';

  @override
  void initState() {
    super.initState();
    _audioService.initTTS();
    _gradingService.loadModel();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _audioService.amplitudeStream.listen((amp) {
      if (mounted && _isRecording) {
        setState(() => _amplitudes.add(amp));
      }
    });

    // Listen for live transcription updates
    _gradingService.liveTranscription.listen((text) {
      if (mounted) setState(() => _liveText = text);
    });
    // Auto-process when STT engine stops on its own (silence timeout)
    _gradingService.onAutoStop = _handleAutoStop;
  }

  @override
  void dispose() {
    _audioService.dispose();
    _gradingService.onAutoStop = null;
    _gradingService.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  /// Called when STT auto-stops (e.g. 7s silence). Triggers grading automatically.
  void _handleAutoStop() {
    if (!mounted || !_isRecording) return;
    _toggleRecording(); // triggers the stop + grade path
  }

  Future<void> _listenToExample() async {
    await _audioService.speak(widget.phrase);
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      _pulseController.stop();
      // Stop STT listening
      await _gradingService.stopListening();
      // Stop audio recording for fluency analysis
      final path = await _audioService.stopRecording();
      _recordingPath = path;
      setState(() {
        _isRecording = false;
      });
      await _processRecording();
    } else {
      setState(() {
        _hasResult = false;
        _result = null;
        _amplitudes = [];
        _liveText = '';
        _recordingPath = null;
      });
      // ── Start STT FIRST (must acquire mic before record package) ──
      final sttStarted = await _gradingService.startListening();
      if (sttStarted) {
        _pulseController.repeat(reverse: true);
        setState(() => _isRecording = true);
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
      } else {
        if (mounted) {
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
  }

  Future<void> _processRecording() async {
    setState(() => _isProcessing = true);

    try {
      // Grade speech using STT transcription + fluency model on recorded audio
      final result = await _gradingService.gradeSpeech(
        audioPath: _recordingPath ?? '',
        expectedPhrase: widget.phrase,
      );

      // Save result to Firestore
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final sessionId = const Uuid().v4();

      final exerciseResult = ExerciseResultModel(
        id: const Uuid().v4(),
        userId: uid,
        sessionId: sessionId,
        phraseExpected: widget.phrase,
        phraseSpoken: result['spoken_phrase'] ?? '',
        clarityScore: (result['clarity_score'] as num).toDouble(),
        accuracyScore: (result['accuracy_score'] as num).toDouble(),
        fluencyScore: (result['fluency_score'] as num).toDouble(),
        feedback: result['feedback'] ?? '',
        modelConfidence: (result['model_confidence'] as num).toDouble(),
        exerciseType: AppConstants.phraseExercise,
      );
      await _firestoreService.saveExerciseResult(exerciseResult);
      await _firestoreService.updateStreak(uid);

      if (mounted) {
        setState(() {
          _result = result;
          _hasResult = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(widget.category),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Target Phrase Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Say this phrase:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '"${widget.phrase}"',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: _listenToExample,
                    icon: const Icon(Icons.volume_up_rounded, color: Colors.white),
                    label: const Text('Listen to Example',
                        style: TextStyle(color: Colors.white)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white54),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Waveform / Recording visualization
            if (_isRecording || _amplitudes.isNotEmpty)
              Container(
                height: 80,
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: CustomPaint(
                  painter: _WaveformPainter(
                    amplitudes: _amplitudes,
                    color: _isRecording ? AppTheme.error : AppTheme.primaryColor,
                  ),
                  size: Size.infinite,
                ),
              ),

            // Record Button
            GestureDetector(
              onTap: _isProcessing ? null : _toggleRecording,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = _isRecording ? 1.0 + _pulseController.value * 0.15 : 1.0;
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: _isRecording ? AppTheme.error : AppTheme.primaryColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_isRecording ? AppTheme.error : AppTheme.primaryColor)
                                .withOpacity(0.4),
                            blurRadius: _isRecording ? 25 : 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isRecording ? 'Tap to stop' : (_isProcessing ? 'Processing...' : 'Tap to record'),
              style: TextStyle(
                color: _isRecording ? AppTheme.error : AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),

            // Live transcription preview
            if (_isRecording && _liveText.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                ),
                child: Text(
                  _liveText,
                  style: const TextStyle(fontSize: 15, fontStyle: FontStyle.italic, color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            // Processing indicator
            if (_isProcessing) ...[
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              const Text('Analyzing your speech...'),
            ],

            // Results
            if (_hasResult && _result != null) ...[
              const SizedBox(height: 32),
              _buildResultCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final clarityScore = (_result!['clarity_score'] as num).toDouble();
    final accuracyScore = (_result!['accuracy_score'] as num).toDouble();
    final fluencyScore = (_result!['fluency_score'] as num).toDouble();
    final hasFluency = fluencyScore >= 0;
    final feedback = _result!['feedback'] as String;
    final confidence = (_result!['model_confidence'] as num).toDouble();
    final spokenPhrase = (_result!['spoken_phrase'] as String?) ?? '';
    final expectedPhrase = (_result!['expected_phrase'] as String?) ?? widget.phrase;

    Color scoreColor;
    if (clarityScore >= 75) {
      scoreColor = AppTheme.success;
    } else if (clarityScore >= 50) {
      scoreColor = AppTheme.warning;
    } else {
      scoreColor = AppTheme.error;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Your Score',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),

          // Combined clarity score circle
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: clarityScore / 100,
                    strokeWidth: 10,
                    backgroundColor: scoreColor.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation(scoreColor),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${clarityScore.toInt()}%',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: scoreColor,
                      ),
                    ),
                    const Text(
                      'Clarity',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Target Phrase
          _phraseComparisonRow(
            label: 'Target Phrase',
            icon: Icons.track_changes_rounded,
            text: expectedPhrase,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(height: 10),

          // Your Attempt
          _phraseComparisonRow(
            label: 'Your Attempt',
            icon: Icons.record_voice_over_rounded,
            text: spokenPhrase.isEmpty ? '(no speech detected)' : spokenPhrase,
            color: scoreColor,
          ),
          const SizedBox(height: 16),

          // Accuracy bar
          _buildScoreBar(
            label: 'Accuracy',
            score: accuracyScore,
            icon: Icons.spellcheck_rounded,
          ),
          const SizedBox(height: 12),

          // Fluency bar (only shown when model produced a score)
          if (hasFluency) ...[
            _buildScoreBar(
              label: 'Fluency',
              score: fluencyScore,
              icon: Icons.graphic_eq_rounded,
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),

          // Feedback
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scoreColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  clarityScore >= 75 ? Icons.emoji_events_rounded : Icons.lightbulb_outline_rounded,
                  color: scoreColor,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    feedback,
                    style: TextStyle(
                      fontSize: 14,
                      color: scoreColor,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Confidence
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.analytics_outlined, size: 16, color: AppTheme.textLight),
              const SizedBox(width: 4),
              Text(
                'Confidence: ${(confidence * 100).toInt()}%',
                style: const TextStyle(fontSize: 12, color: AppTheme.textLight),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Try Again button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _hasResult = false;
                  _result = null;
                  _amplitudes = [];
                  _liveText = '';
                });
              },
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Try Again'),
            ),
          ),
        ],
      ),
    );
  }

  /// Reusable score bar widget for accuracy / fluency breakdowns.
  Widget _buildScoreBar({required String label, required double score, required IconData icon}) {
    Color barColor;
    if (score >= 75) {
      barColor = AppTheme.success;
    } else if (score >= 50) {
      barColor = AppTheme.warning;
    } else {
      barColor = AppTheme.error;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: barColor),
                const SizedBox(width: 6),
                Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
            Text('${score.toInt()}%',
                style: TextStyle(fontWeight: FontWeight.w600, color: barColor)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: score / 100,
            minHeight: 8,
            backgroundColor: barColor.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation(barColor),
          ),
        ),
      ],
    );
  }

  Widget _phraseComparisonRow({
    required String label,
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: text == '(no speech detected)' ? AppTheme.textLight : AppTheme.textPrimary,
              fontStyle: text == '(no speech detected)' ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }
}

// Custom waveform painter
class _WaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final Color color;

  _WaveformPainter({required this.amplitudes, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final barWidth = 4.0;
    final spacing = 2.0;
    final maxBars = (size.width / (barWidth + spacing)).floor();
    final startIdx = amplitudes.length > maxBars ? amplitudes.length - maxBars : 0;
    final subset = amplitudes.sublist(startIdx);

    for (int i = 0; i < subset.length; i++) {
      final x = i * (barWidth + spacing) + barWidth / 2;
      final barHeight = subset[i] * size.height * 0.8;
      final y1 = (size.height - barHeight) / 2;
      final y2 = y1 + barHeight;

      canvas.drawLine(
        Offset(x, y1.clamp(0, size.height)),
        Offset(x, y2.clamp(0, size.height)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) => true;
}
