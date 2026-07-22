import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';
import '../utils/app_theme.dart';
import 'therapist_dashboard.dart';

class TherapistProfileSetup extends StatefulWidget {
  const TherapistProfileSetup({super.key});

  @override
  State<TherapistProfileSetup> createState() => _TherapistProfileSetupState();
}

class _TherapistProfileSetupState extends State<TherapistProfileSetup> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _clinicController = TextEditingController();
  final _patientEmailController = TextEditingController();
  final _firestoreService = FirestoreService();

  String _specialization = 'Speech Pathologist';
  bool _isLoading = false;
  bool _isLinking = false;
  String _linkMessage = '';
  bool _linkSuccess = false;
  int _currentStep = 0;

  final List<String> _specializations = [
    'Speech Pathologist',
    'Speech-Language Pathologist',
    'Neurological Rehabilitation',
    'Occupational Therapist',
    'Physical Therapist',
    'Other',
  ];

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _clinicController.dispose();
    _patientEmailController.dispose();
    super.dispose();
  }

  Future<void> _linkPatient() async {
    final email = _patientEmailController.text.trim();
    if (email.isEmpty) return;

    setState(() {
      _isLinking = true;
      _linkMessage = '';
    });

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final success = await _firestoreService.linkPatientToTherapist(uid, email);

      setState(() {
        _linkSuccess = success;
        _linkMessage = success
            ? 'Patient linked successfully!'
            : 'Patient not found. They may not have registered yet.';
        if (success) _patientEmailController.clear();
      });
    } catch (e) {
      setState(() {
        _linkSuccess = false;
        _linkMessage = 'Error linking patient. Try again.';
      });
    } finally {
      setState(() => _isLinking = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final email = FirebaseAuth.instance.currentUser!.email ?? '';

      await _firestoreService.createOrUpdateUser(UserModel(
        uid: uid,
        email: email,
        role: 'therapist',
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        specialization: _specialization,
        clinic: _clinicController.text.trim(),
      ));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const TherapistDashboard()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('Therapist Profile'),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress
              Row(
                children: List.generate(2, (i) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i <= _currentStep
                            ? AppTheme.accentColor
                            : AppTheme.accentColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),

              // Step 1: Professional Details
              if (_currentStep == 0) ...[
                const Text(
                  'Professional Details',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tell us about your practice',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(
                    labelText: 'First Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(
                    labelText: 'Last Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _specialization,
                  decoration: const InputDecoration(
                    labelText: 'Specialization',
                    prefixIcon: Icon(Icons.medical_services_outlined),
                  ),
                  items: _specializations
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _specialization = v!),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _clinicController,
                  decoration: const InputDecoration(
                    labelText: 'Clinic / Hospital',
                    prefixIcon: Icon(Icons.local_hospital_outlined),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
              ],

              // Step 2: Link Patient
              if (_currentStep == 1) ...[
                const Text(
                  'Add Your First Patient',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Link a patient by their registered email',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                ),
                const SizedBox(height: 28),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_add_rounded,
                          color: AppTheme.accentColor,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _patientEmailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Patient Email',
                          prefixIcon: Icon(Icons.email_outlined),
                          hintText: 'Enter patient\'s registered email',
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _isLinking ? null : _linkPatient,
                          icon: _isLinking
                              ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.link),
                          label: Text(_isLinking ? 'Linking...' : 'Link Patient'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentColor,
                          ),
                        ),
                      ),
                      if (_linkMessage.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _linkSuccess
                                ? AppTheme.success.withOpacity(0.1)
                                : AppTheme.warning.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _linkSuccess ? Icons.check_circle : Icons.info_outline,
                                color: _linkSuccess ? AppTheme.success : AppTheme.warning,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _linkMessage,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _linkSuccess ? AppTheme.success : AppTheme.warning,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'You can add more patients later from your dashboard.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textLight,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],

              const SizedBox(height: 36),

              // Navigation
              Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _currentStep--),
                        child: const Text('Back'),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : _currentStep == 0
                                ? () {
                                    if (!_formKey.currentState!.validate()) return;
                                    setState(() => _currentStep++);
                                  }
                                : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _currentStep == 1
                              ? AppTheme.accentColor
                              : AppTheme.primaryColor,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24, height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5),
                              )
                            : Text(_currentStep == 0 ? 'Next' : 'Get Started'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
