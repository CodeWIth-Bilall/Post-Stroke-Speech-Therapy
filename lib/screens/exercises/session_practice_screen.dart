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

class SessionPracticeScreen extends StatefulWidget {
  final List<String> phrases;
  final String category;
  final int repetitions;
  final String? assignmentId;

  const SessionPracticeScreen({
    super.key,
    required this.phrases,
    this.category = 'Custom',
    this.repetitions = 1,
    this.assignmentId,
  });

  @override
  State<SessionPracticeScreen> createState() => _SessionPracticeScreenState();
}

class _SessionPracticeScreenState extends State<SessionPracticeScreen>
    with SingleTickerProviderStateMixin {
  final _audioService = AudioService();
  final _gradingService = SpeechGradingService();
  final _storageService = StorageService();
  final _firestoreService = FirestoreService();

  late List<String> _allPhrases; // expanded with repetitions
  int _currentIndex = 0;
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _hasResult = false;
  bool _sessionComplete = false;
  Map<String, dynamic>? _result;
  String? _recordingPath;
  List<double> _amplitudes = [];
  late AnimationController _pulseController;

  // Session stats
  final List<Map<String, dynamic>> _sessionResults = [];
  double _totalScore = 0;
  String _liveText = '';

  @override
  void initState() {
    super.initState();
    // Expand phrases with repetitions
    _allPhrases = [];
    for (int r = 0; r < widget.repetitions; r++) {
      _allPhrases.addAll(widget.phrases);
    }
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
    _pulseController.dispose();
    super.dispose();
  }

  /// Called when STT auto-stops (e.g. 7s silence). Triggers stop+grading automatically.
  void _handleAutoStop() {
    if (!mounted || !_isRecording) return;
    _stopRecording(); // triggers the stop + grade path
  }

  String get _currentPhrase => _allPhrases[_currentIndex];

  Future<void> _startRecording() async {
    _amplitudes.clear();
    _hasResult = false;
    _result = null;
    _liveText = '';
    // ── Start STT FIRST (must acquire mic before record package) ──
    final sttStarted = await _gradingService.startListening();
    if (sttStarted) {
      setState(() {
        _isRecording = true;
      });
      _pulseController.repeat();
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
                if (mounted) _startRecording();
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    // Stop STT listening
    await _gradingService.stopListening();
    // Stop audio recording for fluency analysis
    final audioPath = await _audioService.stopRecording();
    _pulseController.stop();
    setState(() {
      _isRecording = false;
      _isProcessing = true;
      _recordingPath = audioPath;
    });

    final result = await _gradingService.gradeSpeech(
      audioPath: _recordingPath ?? '',
      expectedPhrase: _currentPhrase,
    );

    // Save result
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    final exerciseResult = ExerciseResultModel(
      id: const Uuid().v4(),
      userId: uid,
      exerciseType: 'phrase_practice',
      phraseExpected: _currentPhrase,
      phraseSpoken: result['spoken_phrase'] ?? '',
      clarityScore: (result['clarity_score'] as num?)?.toDouble() ?? 0,
      accuracyScore: (result['accuracy_score'] as num?)?.toDouble() ?? 0,
      fluencyScore: (result['fluency_score'] as num?)?.toDouble() ?? 0,
      feedback: result['feedback'] ?? '',
      modelConfidence: (result['model_confidence'] as num?)?.toDouble() ?? 0,
    );

    await _firestoreService.saveExerciseResult(exerciseResult);
    await _firestoreService.updateStreak(uid);

    _sessionResults.add({
      'phrase': _currentPhrase,
      'score': exerciseResult.clarityScore,
      'accuracy': exerciseResult.accuracyScore,
      'fluency': exerciseResult.fluencyScore,
      'feedback': exerciseResult.feedback,
      'spoken': result['spoken_phrase'] ?? '',
    });
    _totalScore += exerciseResult.clarityScore;

    setState(() {
      _isProcessing = false;
      _hasResult = true;
      _result = result;
    });
  }

  void _nextPhrase() {
    if (_currentIndex < _allPhrases.length - 1) {
      setState(() {
        _currentIndex++;
        _hasResult = false;
        _result = null;
        _amplitudes.clear();
      });
    } else {
      // Mark assignment as completed if applicable
      if (widget.assignmentId != null) {
        _firestoreService.updateAssignmentStatus(widget.assignmentId!, 'completed');
      }
      setState(() => _sessionComplete = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sessionComplete) return _buildSummary();

    final progress = (_currentIndex + 1) / _allPhrases.length;
    final score = (_result?['clarity_score'] as num?)?.toDouble() ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text('${_currentIndex + 1} of ${_allPhrases.length}'),
        backgroundColor: Colors.transparent,
        actions: [
          if (_hasResult && _currentIndex < _allPhrases.length - 1)
            TextButton(
              onPressed: _nextPhrase,
              child: const Text('Skip →'),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFE5E7EB),
                  valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
                ),
              ),
              const SizedBox(height: 8),
              Text('${_currentIndex + 1} / ${_allPhrases.length} phrases',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              const SizedBox(height: 24),

              // Phrase card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15),
                  ],
                ),
                child: Column(
                  children: [
                    const Text('Say this phrase:',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                    const SizedBox(height: 12),
                    Text('"$_currentPhrase"',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => _audioService.speak(_currentPhrase),
                      icon: const Icon(Icons.volume_up_rounded),
                      label: const Text('Listen'),
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Result card
              if (_hasResult && _result != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: (score >= 75 ? AppTheme.success : score >= 50 ? AppTheme.warning : AppTheme.error)
                        .withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (score >= 75 ? AppTheme.success : score >= 50 ? AppTheme.warning : AppTheme.error)
                          .withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${score.toInt()}%',
                          style: TextStyle(
                              fontSize: 32, fontWeight: FontWeight.w800,
                              color: score >= 75 ? AppTheme.success : score >= 50 ? AppTheme.warning : AppTheme.error)),
                      const Text('Clarity', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      const SizedBox(height: 10),
                      // Accuracy & Fluency score bars
                      _buildScoreBar('Accuracy',
                          (_result!['accuracy_score'] as num?)?.toDouble() ?? 0, Icons.spellcheck_rounded),
                      const SizedBox(height: 6),
                      if ((_result!['fluency_score'] as num?)?.toDouble() != null &&
                          (_result!['fluency_score'] as num).toDouble() >= 0) ...[
                        _buildScoreBar('Fluency',
                            (_result!['fluency_score'] as num).toDouble(), Icons.graphic_eq_rounded),
                        const SizedBox(height: 6),
                      ],
                      const SizedBox(height: 4),
                      Text(AppConstants.getFeedback(score),
                          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 10),
                      // Target Phrase
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.track_changes_rounded, size: 14, color: AppTheme.primaryColor),
                              const SizedBox(width: 4),
                              Text('Target', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
                            ]),
                            const SizedBox(height: 4),
                            Text(_currentPhrase, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Your Attempt
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (score >= 75 ? AppTheme.success : AppTheme.error).withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.record_voice_over_rounded, size: 14,
                                  color: score >= 75 ? AppTheme.success : AppTheme.error),
                              const SizedBox(width: 4),
                              Text('Your Attempt',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                      color: score >= 75 ? AppTheme.success : AppTheme.error)),
                            ]),
                            const SizedBox(height: 4),
                            Text(
                              (_result!['spoken_phrase'] as String?)?.isNotEmpty == true
                                  ? _result!['spoken_phrase'] as String
                                  : '(no speech detected)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                fontStyle: (_result!['spoken_phrase'] as String?)?.isNotEmpty == true
                                    ? FontStyle.normal : FontStyle.italic,
                                color: (_result!['spoken_phrase'] as String?)?.isNotEmpty == true
                                    ? AppTheme.textPrimary : AppTheme.textLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Processing
              if (_isProcessing)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 8),
                      Text('Analyzing...', style: TextStyle(color: AppTheme.textSecondary)),
                    ],
                  ),
                ),

              // Mic / controls
              if (!_isProcessing && !_hasResult) ...[
                // Live transcription preview
                if (_isRecording && _liveText.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                    ),
                    child: Text(
                      _liveText,
                      style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: AppTheme.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                GestureDetector(
                  onTap: _isRecording ? _stopRecording : _startRecording,
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final scale = _isRecording ? 1.0 + _pulseController.value * 0.15 : 1.0;
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 72,
                          height: 72,
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
                            size: 32,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isRecording ? 'Tap to stop' : 'Tap to record',
                  style: TextStyle(
                    color: _isRecording ? AppTheme.error : AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],

              // After result: Retry / Next buttons
              if (!_isProcessing && _hasResult)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _startRecording,
                        icon: const Icon(Icons.replay_rounded),
                        label: const Text('Retry'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _nextPhrase,
                        icon: Icon(_currentIndex < _allPhrases.length - 1
                            ? Icons.arrow_forward_rounded
                            : Icons.check_circle_rounded),
                        label: Text(_currentIndex < _allPhrases.length - 1 ? 'Next' : 'Finish'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final avgScore = _sessionResults.isEmpty ? 0.0 : _totalScore / _sessionResults.length;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    Icon(
                      avgScore >= 75 ? Icons.emoji_events_rounded : Icons.sports_score_rounded,
                      size: 56,
                      color: avgScore >= 75 ? const Color(0xFFFFD700) : AppTheme.primaryColor,
                    ),
                    const SizedBox(height: 12),
                    const Text('Session Complete!',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text('${_sessionResults.length} phrases practiced',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
                    const SizedBox(height: 20),

                    // Average score card — fixed: Column layout to avoid overflow
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Text('${avgScore.toInt()}%',
                              style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: Colors.white)),
                          const SizedBox(height: 4),
                          const Text('Average Score',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text(AppConstants.getFeedback(avgScore),
                              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
                              textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Phrase results list
                    ..._sessionResults.map((r) {
                      final s = (r['score'] as num).toDouble();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color: (s >= 75 ? AppTheme.success : AppTheme.warning).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text('${s.toInt()}',
                                    style: TextStyle(fontWeight: FontWeight.w700,
                                        color: s >= 75 ? AppTheme.success : AppTheme.warning)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(r['phrase'] as String,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Done', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
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
