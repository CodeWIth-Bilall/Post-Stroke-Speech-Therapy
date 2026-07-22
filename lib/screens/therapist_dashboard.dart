import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../models/exercise_result_model.dart';
import '../models/assignment_model.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import 'auth_screen.dart';
import 'package:uuid/uuid.dart';

class TherapistDashboard extends StatefulWidget {
  const TherapistDashboard({super.key});

  @override
  State<TherapistDashboard> createState() => _TherapistDashboardState();
}

class _TherapistDashboardState extends State<TherapistDashboard> {
  int _currentTab = 0;
  final _firestoreService = FirestoreService();
  final _authService = AuthService();
  UserModel? _therapist;
  List<UserModel> _patients = [];

  @override
  void initState() {
    super.initState();
    _loadTherapist();
  }

  Future<void> _loadTherapist() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final therapist = await _firestoreService.getUser(uid);
    if (mounted) {
      setState(() => _therapist = therapist);
    }
    // Listen for linked patients
    _firestoreService.getLinkedPatients(uid).listen((patients) {
      if (mounted) setState(() => _patients = patients);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: IndexedStack(
        index: _currentTab,
        children: [
          _buildPatientsTab(),
          _buildAssignTab(),
          _buildProfileTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5)),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTab,
          onTap: (i) => setState(() => _currentTab = i),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.people_rounded), label: 'Patients'),
            BottomNavigationBarItem(icon: Icon(Icons.assignment_rounded), label: 'Assign'),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      ),
    );
  }

  // ======== PATIENTS TAB ========
  Widget _buildPatientsTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hello, Dr. ${_therapist?.firstName ?? ''}',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      Text('${_patients.length} patients linked',
                          style: const TextStyle(color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.accentColor.withOpacity(0.1),
                  child: Text(
                    (_therapist?.firstName ?? 'T')[0].toUpperCase(),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.accentColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Overview Cards
            Row(
              children: [
                Expanded(child: _overviewCard('Total Patients', '${_patients.length}',
                    Icons.people_rounded, const Color(0xFF4ECDC4))),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: _showActivePatients,
                    child: _overviewCard('Active Today', '${_patients.where((p) => p.streakDays > 0).length}',
                        Icons.trending_up_rounded, const Color(0xFF6C63FF)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Add Patient Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showAddPatientDialog,
                icon: const Icon(Icons.person_add_rounded),
                label: const Text('Link New Patient'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Patient List
            const Text('Your Patients',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),

            if (_patients.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.people_outline_rounded, size: 48, color: AppTheme.textLight),
                    SizedBox(height: 12),
                    Text('No patients linked yet'),
                    SizedBox(height: 4),
                    Text('Link a patient by their email',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  ],
                ),
              ),

            ..._patients.map(_buildPatientCard),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _overviewCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 14),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
          Text(title, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildPatientCard(UserModel patient) {
    return GestureDetector(
      onTap: () => _showPatientDetail(patient),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
              child: Text(
                patient.firstName[0].toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor, fontSize: 18),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(patient.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department_rounded, size: 14, color: Color(0xFFFF6B6B)),
                      const SizedBox(width: 4),
                      Text('${patient.streakDays} day streak',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      const SizedBox(width: 12),
                      const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: AppTheme.primaryColor),
                      const SizedBox(width: 4),
                      Text('${patient.totalWordsSpoken} words',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textLight),
          ],
        ),
      ),
    );
  }

  void _showActivePatients() {
    final activePatients = _patients.where((p) => p.streakDays > 0).toList();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            Text('Active Patients (${activePatients.length})',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            if (activePatients.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text('No active patients today',
                    style: TextStyle(color: AppTheme.textSecondary))),
              )
            else
              ...activePatients.map((p) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  child: Text(p.firstName[0].toUpperCase(),
                      style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                ),
                title: Text(p.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${p.streakDays} day streak • ${p.totalWordsSpoken} words',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textLight),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPatientDetail(p);
                },
              )),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showAddPatientDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Link Patient'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter patient email',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final email = controller.text.trim();
              if (email.isEmpty) return;
              Navigator.pop(ctx);
              final uid = FirebaseAuth.instance.currentUser!.uid;
              final success = await _firestoreService.linkPatientToTherapist(uid, email);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(success ? 'Patient linked successfully!' : 'Patient not found'),
                  backgroundColor: success ? AppTheme.success : AppTheme.error,
                ));
              }
            },
            child: const Text('Link'),
          ),
        ],
      ),
    );
  }

  void _showPatientDetail(UserModel patient) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _PatientDetailPage(patient: patient),
    ));
  }

  // ======== ASSIGN TAB ========
  Widget _buildAssignTab() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            const Text('Assign Exercise',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Create assignments for your patients',
                style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 24),

            if (_patients.isEmpty)
              const Center(child: Text('Link patients first to create assignments'))
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _patients.length,
                  itemBuilder: (_, i) {
                    final patient = _patients[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                          child: Text(patient.firstName[0].toUpperCase(),
                              style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(patient.fullName),
                        subtitle: const Text('Tap to assign exercises'),
                        trailing: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        onTap: () {
                          Navigator.push(context,
                            MaterialPageRoute(builder: (_) => _AssignmentBuilderPage(patient: patient)));
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ======== PROFILE TAB ========
  Widget _buildProfileTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text('Profile',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppTheme.accentColor.withOpacity(0.1),
                    child: Text(
                      (_therapist?.firstName ?? 'T')[0].toUpperCase(),
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.accentColor),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dr. ${_therapist?.fullName ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
                        Text(_therapist?.specialization ?? '',
                            style: const TextStyle(color: AppTheme.textSecondary)),
                        Text(_therapist?.email ?? '',
                            style: const TextStyle(color: AppTheme.textLight, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _profileTile(Icons.medical_services_outlined, 'Specialization',
                _therapist?.specialization ?? 'Not set'),
            _profileTile(Icons.business_outlined, 'Clinic',
                _therapist?.clinicName ?? 'Not set'),
            _profileTile(Icons.people_outlined, 'Patients',
                '${_patients.length} linked'),

            const SizedBox(height: 20),

            // Edit Profile button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showTherapistEditProfile,
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await _authService.signOut();
                  if (mounted) {
                    Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (_) => const AuthScreen()));
                  }
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign Out'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showTherapistEditProfile() {
    final firstNameCtrl = TextEditingController(text: _therapist?.firstName ?? '');
    final lastNameCtrl = TextEditingController(text: _therapist?.lastName ?? '');
    final specCtrl = TextEditingController(text: _therapist?.specialization ?? '');
    final clinicCtrl = TextEditingController(text: _therapist?.clinicName ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: SingleChildScrollView(
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
                controller: specCtrl,
                decoration: const InputDecoration(labelText: 'Specialization', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: clinicCtrl,
                decoration: const InputDecoration(labelText: 'Clinic Name', border: OutlineInputBorder()),
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
                        'specialization': specCtrl.text.trim(),
                        'clinicName': clinicCtrl.text.trim(),
                      });
                      await _loadTherapist();
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
      ),
    );
  }

  Widget _profileTile(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textSecondary),
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
        ],
      ),
    );
  }
}

// ======== PATIENT DETAIL PAGE ========
class _PatientDetailPage extends StatefulWidget {
  final UserModel patient;
  const _PatientDetailPage({required this.patient});

  @override
  State<_PatientDetailPage> createState() => _PatientDetailPageState();
}

class _PatientDetailPageState extends State<_PatientDetailPage> {
  final _firestoreService = FirestoreService();
  List<ExerciseResultModel> _results = [];
  List<AssignmentModel> _completedAssignments = [];
  double _weeklyAvg = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await _firestoreService.getExerciseResultsOnce(widget.patient.uid, limit: 50);
      final avg = await _firestoreService.getWeeklyAverageAccuracy(widget.patient.uid);
      final completed = await _firestoreService.getCompletedAssignments(widget.patient.uid);
      if (mounted) {
        setState(() {
          _results = results;
          _weeklyAvg = avg;
          _completedAssignments = completed;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(widget.patient.fullName),
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Patient info card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
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
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          child: Text(
                            widget.patient.firstName[0].toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.patient.fullName,
                                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text('${widget.patient.totalWordsSpoken} words spoken',
                                  style: TextStyle(color: Colors.white.withOpacity(0.8))),
                              Text('${widget.patient.streakDays} day streak',
                                  style: TextStyle(color: Colors.white.withOpacity(0.8))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Stats row
                  Row(
                    children: [
                      _statCard('Weekly Avg', '${_weeklyAvg.toInt()}%', const Color(0xFF4ECDC4)),
                      const SizedBox(width: 12),
                      _statCard('Total Sessions', '${_results.length}', const Color(0xFF6C63FF)),
                      const SizedBox(width: 12),
                      _statCard('Streak', '${widget.patient.streakDays}d', const Color(0xFFFF6B6B)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ===== Completed Assignment Reports =====
                  if (_completedAssignments.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.assignment_turned_in_rounded,
                            color: AppTheme.success, size: 22),
                        const SizedBox(width: 8),
                        const Text('Completed Assignments',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('${_completedAssignments.length}',
                              style: const TextStyle(
                                  color: AppTheme.success,
                                  fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    ..._completedAssignments.map((a) {
                      final phraseCount = a.phrases.isNotEmpty ? a.phrases.length : 1;
                      final date = a.createdAt;
                      final dateStr = date != null
                          ? '${date.day}/${date.month}/${date.year}'
                          : '';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.success.withOpacity(0.2)),
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            leading: Container(
                              width: 42, height: 42,
                              decoration: BoxDecoration(
                                color: AppTheme.success.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.check_circle_rounded,
                                  color: AppTheme.success, size: 22),
                            ),
                            title: Text(
                              a.category.isNotEmpty ? a.category : 'Custom',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                            subtitle: Text(
                              '$phraseCount phrases • $dateStr',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                            children: [
                              if (a.notes.isNotEmpty) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F5F5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('Note: ${a.notes}',
                                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary,
                                          fontStyle: FontStyle.italic)),
                                ),
                              ],
                              ...a.phrases.map((phrase) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_rounded,
                                        size: 16, color: AppTheme.success),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(phrase,
                                          style: const TextStyle(fontSize: 13)),
                                    ),
                                  ],
                                ),
                              )),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                  ],

                  // Recent Sessions
                  const Text('Recent Sessions',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),

                  if (_results.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text('No sessions yet', textAlign: TextAlign.center),
                    ),

                  ..._results.take(20).map((r) => Container(
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
                            color: (r.clarityScore >= 75 ? AppTheme.success : AppTheme.warning).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              '${r.clarityScore.toInt()}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: r.clarityScore >= 75 ? AppTheme.success : AppTheme.warning,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.phraseExpected,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text(r.feedback,
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        if (r.audioUrl?.isNotEmpty == true)
                          const Icon(Icons.play_circle_outline_rounded,
                              color: AppTheme.primaryColor),
                      ],
                    ),
                  )),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _statCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 4),
            Text(title,
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ======== ASSIGNMENT BUILDER PAGE ========
class _AssignmentBuilderPage extends StatefulWidget {
  final UserModel patient;
  const _AssignmentBuilderPage({required this.patient});

  @override
  State<_AssignmentBuilderPage> createState() => _AssignmentBuilderPageState();
}

class _AssignmentBuilderPageState extends State<_AssignmentBuilderPage> {
  final _firestoreService = FirestoreService();
  final Set<String> _selectedPhrases = {};
  final List<String> _customPhrases = [];
  final _customController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSaving = false;

  static const _categoryColors = {
    'Common': Color(0xFF4ECDC4),
    'Food & Drink': Color(0xFFFF6B6B),
    'Feelings': Color(0xFFFFA07A),
    'Medical': Color(0xFF6C63FF),
    'Sentence Builder': Color(0xFF26A69A),
    'Sentence Chain': Color(0xFFE91E63),
    'Tongue Twisters': Color(0xFFAB47BC),
  };

  static const _categoryIcons = {
    'Common': Icons.chat_bubble_outline_rounded,
    'Food & Drink': Icons.restaurant_rounded,
    'Feelings': Icons.favorite_outline_rounded,
    'Medical': Icons.medical_services_outlined,
    'Sentence Builder': Icons.construction_rounded,
    'Sentence Chain': Icons.link_rounded,
    'Tongue Twisters': Icons.record_voice_over_rounded,
  };

  int get _totalSelected => _selectedPhrases.length + _customPhrases.length;

  void _addCustomPhrase() {
    final text = _customController.text.trim();
    if (text.isNotEmpty && !_customPhrases.contains(text)) {
      setState(() {
        _customPhrases.add(text);
        _customController.clear();
      });
    }
  }

  Future<void> _confirmAssignment() async {
    if (_totalSelected == 0) return;
    setState(() => _isSaving = true);

    final allPhrases = [..._selectedPhrases, ..._customPhrases];
    final uid = FirebaseAuth.instance.currentUser!.uid;

    await _firestoreService.createAssignment(AssignmentModel(
      id: const Uuid().v4(),
      therapistId: uid,
      patientId: widget.patient.uid,
      exerciseType: 'phrase_practice',
      phrase: allPhrases.first,
      phrases: allPhrases,
      notes: _notesController.text.trim(),
      category: 'mixed',
    ));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${allPhrases.length} phrases assigned to ${widget.patient.firstName}!'),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text('Assign to ${widget.patient.firstName}'),
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Patient header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.white.withOpacity(0.2),
                          child: Text(widget.patient.firstName[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.patient.fullName,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                              Text('Select phrases from the library below',
                                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Exercise library — categories (dropdown)
                  ...AppConstants.phraseCategories.entries.map((entry) {
                    final cat = entry.key;
                    final phrases = entry.value;
                    final color = _categoryColors[cat] ?? AppTheme.primaryColor;
                    final icon = _categoryIcons[cat] ?? Icons.category;
                    final allSelected = phrases.every((p) => _selectedPhrases.contains(p));
                    final selectedCount = phrases.where((p) => _selectedPhrases.contains(p)).length;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          leading: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(icon, color: color, size: 20),
                          ),
                          title: Text(cat,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                          subtitle: Text(
                            selectedCount > 0 ? '$selectedCount / ${phrases.length} selected' : '${phrases.length} phrases',
                            style: TextStyle(fontSize: 12, color: selectedCount > 0 ? color : AppTheme.textSecondary),
                          ),
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      if (allSelected) {
                                        _selectedPhrases.removeAll(phrases);
                                      } else {
                                        _selectedPhrases.addAll(phrases);
                                      }
                                    });
                                  },
                                  child: Text(allSelected ? 'Deselect All' : 'Select All',
                                      style: TextStyle(color: color, fontSize: 12)),
                                ),
                              ],
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: phrases.map((phrase) {
                                final selected = _selectedPhrases.contains(phrase);
                                return GestureDetector(
                                  onTap: () => setState(() {
                                    selected ? _selectedPhrases.remove(phrase) : _selectedPhrases.add(phrase);
                                  }),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: selected ? color.withOpacity(0.15) : const Color(0xFFF5F5F5),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: selected ? color : Colors.transparent, width: selected ? 2 : 1),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (selected)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 6),
                                            child: Icon(Icons.check_circle_rounded, color: color, size: 18),
                                          ),
                                        Flexible(
                                          child: Text(phrase,
                                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                                                  color: selected ? color : AppTheme.textPrimary)),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  // Custom phrases section
                  const Text('Custom Phrases',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _customController,
                          decoration: InputDecoration(
                            hintText: 'Type a custom phrase...',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          onSubmitted: (_) => _addCustomPhrase(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _addCustomPhrase,
                        icon: const Icon(Icons.add_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _customPhrases.map((p) => Chip(
                      label: Text(p, style: const TextStyle(fontSize: 13)),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => setState(() => _customPhrases.remove(p)),
                      backgroundColor: AppTheme.accentColor.withOpacity(0.1),
                      side: BorderSide(color: AppTheme.accentColor.withOpacity(0.3)),
                    )).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Notes
                  const Text('Notes (optional)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Add instructions or notes for the patient...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),

          // Bottom confirm bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _totalSelected > 0 && !_isSaving ? _confirmAssignment : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Confirm Assignment ($_totalSelected phrases)',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
