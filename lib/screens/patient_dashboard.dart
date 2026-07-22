import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../models/exercise_result_model.dart';
import '../models/assignment_model.dart';
import '../models/saved_session_model.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import 'exercises/phrase_selection_screen.dart';
import 'exercises/create_session_screen.dart';
import 'exercises/session_practice_screen.dart';
import 'exercises/word_repeat_screen.dart';
import 'exercises/picture_naming_screen.dart';
import 'exercises/difficulty_selection_dialog.dart';
import 'progress/daily_report_screen.dart';
import 'progress/progress_tracker_screen.dart';
import 'auth_screen.dart';
import 'package:fl_chart/fl_chart.dart';

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  int _currentTab = 0;
  final _firestoreService = FirestoreService();
  final _authService = AuthService();
  UserModel? _user;
  List<Map<String, dynamic>> _weeklyScores = [];
  List<ExerciseResultModel> _recentResults = [];
  List<AssignmentModel> _assignments = [];
  List<SavedSessionModel> _savedSessions = [];
  bool _dailyReminders = true;
  bool _progressAlerts = true;
  bool _therapistUpdates = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final user = await _firestoreService.getUser(uid);
    final weekly = await _firestoreService.getWeeklyDailyScores(uid);
    final results = await _firestoreService.getExerciseResultsOnce(uid, limit: 20);

    // Listen for assignments
    _firestoreService.getPatientAssignments(uid).listen((assignments) {
      if (mounted) setState(() => _assignments = assignments);
    });

    // Listen for saved sessions
    _firestoreService.getSavedSessions(uid).listen((sessions) {
      if (mounted) setState(() => _savedSessions = sessions);
    });

    if (mounted) {
      setState(() {
        _user = user;
        _weeklyScores = weekly;
        _recentResults = results;
        if (user != null) {
          _dailyReminders = user.dailyReminders;
          _progressAlerts = user.progressAlerts;
          _therapistUpdates = user.therapistUpdates;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: IndexedStack(
        index: _currentTab,
        children: [
          _buildHomeTab(),
          _buildExercisesTab(),
          _buildProgressTab(),
          _buildSettingsTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTab,
          onTap: (i) => setState(() => _currentTab = i),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.fitness_center_rounded), label: 'Exercises'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Progress'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Settings'),
          ],
        ),
      ),
    );
  }

  // ======== HOME TAB ========
  Widget _buildHomeTab() {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top bar
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome back,',
                            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                        Text(_user?.firstName ?? 'User',
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _currentTab = 3),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                      child: Text(
                        (_user?.firstName ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Active Session Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 6)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('🔥 Active Session',
                              style: TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                        const Spacer(),
                        Text('${_user?.streakDays ?? 0} day streak',
                            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Continue your therapy',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
                    const SizedBox(height: 6),
                    Text('${_recentResults.length} exercises completed today',
                        style: TextStyle(color: Colors.white.withOpacity(0.85))),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const CreateSessionScreen()));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.primaryColor,
                        ),
                        child: const Text('Create Session'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Saved Sessions
              if (_savedSessions.isNotEmpty) ...[
                const Text('Saved Sessions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                const SizedBox(height: 12),
                ..._savedSessions.map((s) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.bookmark_rounded, color: AppTheme.primaryColor),
                    ),
                    title: Text(s.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${s.phrases.length} phrases • ${s.repetitions}x',
                        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    trailing: const Icon(Icons.play_circle_filled_rounded, color: AppTheme.primaryColor, size: 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => SessionPracticeScreen(
                          phrases: s.phrases,
                          category: s.name,
                          repetitions: s.repetitions,
                        ),
                      ));
                    },
                    onLongPress: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Session?'),
                          content: Text('Delete "${s.name}"?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                            ElevatedButton(
                              onPressed: () async {
                                Navigator.pop(ctx);
                                await _firestoreService.deleteSession(s.id);
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                )),
                const SizedBox(height: 16),
              ],

              // Assigned Exercises
              if (_assignments.isNotEmpty) ...[
                const Text('Assigned by Therapist',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                const SizedBox(height: 12),
                ..._assignments.map((a) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.accentColor.withOpacity(0.3)),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.assignment_rounded, color: AppTheme.accentColor),
                    ),
                    title: Text('${a.phrases.length} phrases assigned',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(a.notes.isNotEmpty ? a.notes : a.phrases.take(2).join(', '),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    trailing: const Icon(Icons.play_circle_filled_rounded, color: AppTheme.primaryColor, size: 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => SessionPracticeScreen(
                          phrases: a.phrases.isNotEmpty ? a.phrases : [a.phrase],
                          category: 'Therapist Assigned',
                          assignmentId: a.id,
                        ),
                      ));
                    },
                  ),
                )),
                const SizedBox(height: 16),
              ],

              // Weekly Progress Chart
              const Text('Weekly Progress',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              const SizedBox(height: 12),
              Container(
                height: 180,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
                ),
                child: _weeklyScores.isEmpty
                    ? const Center(child: Text('Start practicing to see your progress!'))
                    : LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 1,
                                getTitlesWidget: (value, meta) {
                                  final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                                  final idx = value.toInt();
                                  if (idx >= 0 && idx < _weeklyScores.length && idx == value) {
                                    final date = _weeklyScores[idx]['date'] as DateTime;
                                    final dayName = dayLabels[date.weekday - 1];
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(dayName,
                                          style: const TextStyle(fontSize: 11, color: AppTheme.textLight)),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          minY: 0, maxY: 100,
                          lineBarsData: [
                            LineChartBarData(
                              spots: List.generate(
                                _weeklyScores.length,
                                (i) => FlSpot(i.toDouble(), _weeklyScores[i]['score'] as double),
                              ),
                              isCurved: true,
                              color: AppTheme.primaryColor,
                              barWidth: 3,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                                  radius: 4, color: Colors.white, strokeWidth: 2.5, strokeColor: AppTheme.primaryColor,
                                ),
                              ),
                              belowBarData: BarAreaData(show: true, color: AppTheme.primaryColor.withOpacity(0.1)),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 24),



              // Games Grid
              const Text('Games',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildGameCard('Word Repeat', Icons.replay_rounded, const Color(0xFF2BCDEE), () async {
                      final difficulty = await showDifficultySelection(context, 'Word Repeat');
                      if (difficulty != null && mounted) {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => WordRepeatScreen(difficulty: difficulty),
                        ));
                      }
                    }),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildGameCard('Picture Naming', Icons.image_rounded, const Color(0xFF6C63FF), () async {
                      final difficulty = await showDifficultySelection(context, 'Picture Naming');
                      if (difficulty != null && mounted) {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => PictureNamingScreen(difficulty: difficulty),
                        ));
                      }
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Achievements
              const Text('Achievements',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: AppConstants.achievements.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) {
                    final a = AppConstants.achievements[i];
                    final unlocked = _isAchievementUnlocked(a);
                    return Container(
                      width: 100,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: unlocked ? AppTheme.primaryColor.withOpacity(0.1) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: unlocked ? AppTheme.primaryColor : const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(a['icon'] as String, style: TextStyle(fontSize: unlocked ? 28 : 24)),
                          const SizedBox(height: 6),
                          Text(a['title'] as String,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                  color: unlocked ? AppTheme.primaryColor : AppTheme.textLight),
                              textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  bool _isAchievementUnlocked(Map<String, dynamic> achievement) {
    if (_user == null) return false;
    final id = achievement['id'] as String;
    final req = achievement['requirement'] as int;
    if (id.startsWith('streak')) return _user!.streakDays >= req;
    if (id.startsWith('words')) return _user!.totalWordsSpoken >= req;
    if (id == 'first_word') return _user!.totalWordsSpoken >= 1;
    return false;
  }

  Widget _buildExerciseCard(String title, IconData icon, Color color, String subtitle) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const PhraseSelectionScreen()));
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 24),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color, color.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 2),
            Text('Play now →', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // ======== EXERCISES TAB ========
  Widget _buildExercisesTab() {
    return const PhraseSelectionScreen(embedded: true);
  }

  // ======== PROGRESS TAB ========
  Widget _buildProgressTab() {
    return const DailyReportScreen(embedded: true);
  }

  // ======== SETTINGS TAB ========
  Widget _buildSettingsTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text('Settings',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 28),

            // Profile card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    child: Text((_user?.firstName ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_user?.fullName ?? 'User',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        Text(_user?.email ?? '',
                            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _settingsTile(Icons.person_outline, 'Edit Profile', _showEditProfile),
            _settingsTile(Icons.notifications_outlined, 'Notifications', _showNotifications),
            _settingsTile(Icons.help_outline, 'Help & Support', _showHelpSupport),
            _settingsTile(Icons.info_outline, 'About', _showAbout),
            const SizedBox(height: 16),
            _settingsTile(Icons.logout_rounded, 'Sign Out', () async {
              await _authService.signOut();
              if (mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
              }
            }, isDestructive: true),
          ],
        ),
      ),
    );
  }

  // ======== EDIT PROFILE ========
  void _showEditProfile() {
    final firstNameCtrl = TextEditingController(text: _user?.firstName ?? '');
    final lastNameCtrl = TextEditingController(text: _user?.lastName ?? '');
    final ageCtrl = TextEditingController(text: _user?.age?.toString() ?? '');
    final goalCtrl = TextEditingController(text: _user?.primaryGoal ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            const Text('Edit Profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            TextField(
              controller: firstNameCtrl,
              decoration: const InputDecoration(labelText: 'First Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: lastNameCtrl,
              decoration: const InputDecoration(labelText: 'Last Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ageCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Age', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: goalCtrl,
              decoration: const InputDecoration(labelText: 'Primary Goal', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid != null) {
                    await _firestoreService.updateUserFields(uid, {
                      'firstName': firstNameCtrl.text.trim(),
                      'lastName': lastNameCtrl.text.trim(),
                      'age': int.tryParse(ageCtrl.text.trim()),
                      'primaryGoal': goalCtrl.text.trim(),
                    });
                    await _loadData();
                    if (mounted) Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profile updated!'), backgroundColor: AppTheme.success),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ======== NOTIFICATIONS ========
  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                const Text('Notifications', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                _notifToggle('Daily Reminders', 'Remind to practice daily', _dailyReminders, (v) {
                  setSheetState(() => _dailyReminders = v);
                  setState(() {});
                  _saveNotificationPrefs();
                }),
                _notifToggle('Progress Alerts', 'Notify on achievements', _progressAlerts, (v) {
                  setSheetState(() => _progressAlerts = v);
                  setState(() {});
                  _saveNotificationPrefs();
                }),
                _notifToggle('Therapist Updates', 'New assignments from therapist', _therapistUpdates, (v) {
                  setSheetState(() => _therapistUpdates = v);
                  setState(() {});
                  _saveNotificationPrefs();
                }),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveNotificationPrefs() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _firestoreService.updateUserFields(uid, {
      'dailyReminders': _dailyReminders,
      'progressAlerts': _progressAlerts,
      'therapistUpdates': _therapistUpdates,
    });
  }

  Widget _notifToggle(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.scaffoldBg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: AppTheme.primaryColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  // ======== HELP & SUPPORT ========
  void _showHelpSupport() {
    final now = DateTime.now();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text('Help & Support', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.record_voice_over_rounded, size: 48, color: AppTheme.primaryColor),
                  const SizedBox(height: 12),
                  const Text('Vocal Therapy', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.primaryColor)),
                  const SizedBox(height: 4),
                  const Text('Version 1.0.0', style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _helpItem(Icons.phone_rounded, 'Call Us', '+92 343 6026971', onTap: () {
              final uri = Uri.parse('tel:+923436026971');
              launchUrl(uri);
            }),
            _helpItem(Icons.email_rounded, 'Email Us', 'mailrehman90527300@gmail.com', onTap: () {
              final uri = Uri.parse('mailto:mailrehman90527300@gmail.com');
              launchUrl(uri);
            }),
            _helpItem(Icons.calendar_today_rounded, 'Date & Time',
                '${now.day}/${now.month}/${now.year}  ${now.hour}:${now.minute.toString().padLeft(2, '0')}'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _helpItem(IconData icon, String title, String value, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryColor),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right, color: AppTheme.textLight, size: 20),
          ],
        ),
      ),
    );
  }

  // ======== ABOUT ========
  void _showAbout() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              const Text('About', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.record_voice_over_rounded, size: 48, color: AppTheme.primaryColor),
                    SizedBox(height: 12),
                    Text('Vocal Therapy', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.primaryColor)),
                    SizedBox(height: 12),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'Vocal Therapy is a mobile application specifically designed to assist '
                        'speech impairment patients in their recovery journey. Our AI-driven '
                        'platform provides interactive exercises, real-time speech recognition '
                        'feedback, and personalized therapy plans — enabling patients to practice '
                        'privately, affordably, and at their own pace from the comfort of their homes.',
                        style: TextStyle(fontSize: 15, height: 1.6, color: Color(0xFF444444)),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('Development Team', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              _teamMember('1', 'Abdur Rehman'),
              _teamMember('2', 'Muhammad Bilal'),
              _teamMember('3', 'Ahmad Waseem'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse('https://wa.me/9203436026971');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.chat_rounded),
                  label: const Text('Contact Us on WhatsApp',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _teamMember(String num, String name) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
            child: Text(num, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
          ),
          const SizedBox(width: 14),
          Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _settingsTile(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: isDestructive ? AppTheme.error : AppTheme.textSecondary),
        title: Text(title,
            style: TextStyle(fontWeight: FontWeight.w500,
                color: isDestructive ? AppTheme.error : AppTheme.textPrimary)),
        trailing: Icon(Icons.chevron_right, color: isDestructive ? AppTheme.error : AppTheme.textLight),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
