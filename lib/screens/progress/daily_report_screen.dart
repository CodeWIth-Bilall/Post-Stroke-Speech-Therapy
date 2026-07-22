import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/firestore_service.dart';
import '../../models/exercise_result_model.dart';
import '../../utils/app_theme.dart';

class DailyReportScreen extends StatefulWidget {
  final bool embedded;
  const DailyReportScreen({super.key, this.embedded = false});

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
  final _firestoreService = FirestoreService();
  List<ExerciseResultModel> _todayResults = [];
  List<Map<String, dynamic>> _weeklyScores = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final results = await _firestoreService.getExerciseResultsOnce(uid, limit: 100);
    final weekly = await _firestoreService.getWeeklyDailyScores(uid);

    // Filter today's results
    final now = DateTime.now();
    final today = results.where((r) =>
        r.timestamp.year == now.year &&
        r.timestamp.month == now.month &&
        r.timestamp.day == now.day).toList();

    if (mounted) {
      setState(() {
        _todayResults = today;
        _weeklyScores = weekly;
        _isLoading = false;
      });
    }
  }

  double get _averageScore {
    if (_todayResults.isEmpty) return 0;
    return _todayResults.map((r) => r.clarityScore).reduce((a, b) => a + b) /
        _todayResults.length;
  }

  int get _practiceMinutes {
    int totalSeconds = 0;
    for (final r in _todayResults) {
      if (r.exerciseType == 'phrase_practice') {
        totalSeconds += 180; // ~3 min per phrase session
      } else {
        totalSeconds += 60; // ~1 min per game exercise
      }
    }
    return (totalSeconds / 60).round().clamp(0, 120);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) return _buildContent();
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('Daily Report'),
        backgroundColor: Colors.transparent,
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.embedded) ...[
                const SizedBox(height: 20),
                const Text(
                  'Progress',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Today's progress and weekly trends",
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                ),
                const SizedBox(height: 20),
              ],

              // Today summary cards row
              Row(
                children: [
                  Expanded(child: _buildStatCard(
                    'Practice Time',
                    '$_practiceMinutes min',
                    Icons.timer_rounded,
                    const Color(0xFF4ECDC4),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatCard(
                    'Accuracy',
                    '${_averageScore.toInt()}%',
                    Icons.analytics_rounded,
                    const Color(0xFF6C63FF),
                  )),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildStatCard(
                    'Exercises',
                    '${_todayResults.length}',
                    Icons.fitness_center_rounded,
                    const Color(0xFFFF6B6B),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatCard(
                    'Best Score',
                    '${_todayResults.isEmpty ? 0 : _todayResults.map((r) => r.clarityScore).reduce((a, b) => a > b ? a : b).toInt()}%',
                    Icons.emoji_events_rounded,
                    const Color(0xFFFFA07A),
                  )),
                ],
              ),
              const SizedBox(height: 24),

              // 7-Day Trend Chart
              const Text(
                '7-Day Trend',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 200,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: _weeklyScores.isEmpty
                    ? const Center(child: Text('Complete exercises to see trends'))
                    : BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: 100,
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, _) {
                                  final dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                                  final idx = value.toInt();
                                  if (idx >= 0 && idx < _weeklyScores.length) {
                                    final date = _weeklyScores[idx]['date'] as DateTime;
                                    final label = dayLabels[date.weekday - 1];
                                    return Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textLight));
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                          ),
                          barGroups: List.generate(
                            _weeklyScores.length,
                            (i) => BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: _weeklyScores[i]['score'] as double,
                                  color: AppTheme.primaryColor,
                                  width: 20,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(6),
                                    topRight: Radius.circular(6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 24),

              // Activity Breakdown
              const Text(
                'Activity Breakdown',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _buildActivityBreakdown(),
              const SizedBox(height: 24),

              // Recent Activity
              const Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              ..._todayResults.take(10).map((r) => _buildActivityItem(r)),
              if (_todayResults.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.trending_up_rounded, size: 48, color: AppTheme.textLight),
                      SizedBox(height: 12),
                      Text('No activity today',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text('Start an exercise to see your daily report',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityBreakdown() {
    final phraseCount = _todayResults.where((r) => r.exerciseType == 'phrase_practice').length;
    final wordCount = _todayResults.where((r) => r.exerciseType == 'word_repeat').length;
    final pictureCount = _todayResults.where((r) => r.exerciseType == 'picture_naming').length;
    final total = _todayResults.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildBreakdownRow('Phrase Practice', phraseCount, total, const Color(0xFF4ECDC4)),
          const SizedBox(height: 12),
          _buildBreakdownRow('Word Repeat', wordCount, total, const Color(0xFF2BCDEE)),
          const SizedBox(height: 12),
          _buildBreakdownRow('Picture Naming', pictureCount, total, const Color(0xFF6C63FF)),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(String title, int count, int total, Color color) {
    final pct = total == 0 ? 0.0 : count / total;
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14))),
        Text('$count', style: TextStyle(fontWeight: FontWeight.w600, color: color)),
        const SizedBox(width: 12),
        SizedBox(
          width: 60,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: color.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem(ExerciseResultModel result) {
    final typeNames = {
      'phrase_practice': 'Phrase Practice',
      'word_repeat': 'Word Repeat',
      'picture_naming': 'Picture Naming',
    };
    final typeColors = {
      'phrase_practice': const Color(0xFF4ECDC4),
      'word_repeat': const Color(0xFF2BCDEE),
      'picture_naming': const Color(0xFF6C63FF),
    };
    final color = typeColors[result.exerciseType] ?? AppTheme.primaryColor;

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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '${result.clarityScore.toInt()}',
                style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.phraseExpected,
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  typeNames[result.exerciseType] ?? result.exerciseType,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: result.clarityScore >= 75
                  ? AppTheme.success.withOpacity(0.1)
                  : result.clarityScore >= 50
                      ? AppTheme.warning.withOpacity(0.1)
                      : AppTheme.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${result.clarityScore.toInt()}%',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: result.clarityScore >= 75
                    ? AppTheme.success
                    : result.clarityScore >= 50
                        ? AppTheme.warning
                        : AppTheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
