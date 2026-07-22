import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String role; // 'patient' or 'therapist'
  final String firstName;
  final String lastName;
  final int? age;
  final String? specialization;
  final String? clinic;
  final bool managedByCaregiver;
  final String? practiceFrequency;
  final String? primaryGoal;
  final String? linkedTherapistId;
  final List<String> linkedPatientIds;
  final int streakDays;
  final int totalWordsSpoken;
  final DateTime? createdAt;
  final bool dailyReminders;
  final bool progressAlerts;
  final bool therapistUpdates;

  UserModel({
    required this.uid,
    required this.email,
    this.role = '',
    this.firstName = '',
    this.lastName = '',
    this.age,
    this.specialization,
    this.clinic,
    this.managedByCaregiver = false,
    this.practiceFrequency,
    this.primaryGoal,
    this.linkedTherapistId,
    this.linkedPatientIds = const [],
    this.streakDays = 0,
    this.totalWordsSpoken = 0,
    this.createdAt,
    this.dailyReminders = true,
    this.progressAlerts = true,
    this.therapistUpdates = true,
  });

  String get fullName => '$firstName $lastName'.trim();
  String get clinicName => clinic ?? '';

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'role': role,
      'firstName': firstName,
      'lastName': lastName,
      'age': age,
      'specialization': specialization,
      'clinic': clinic,
      'managedByCaregiver': managedByCaregiver,
      'practiceFrequency': practiceFrequency,
      'primaryGoal': primaryGoal,
      'linkedTherapistId': linkedTherapistId,
      'linkedPatientIds': linkedPatientIds,
      'streakDays': streakDays,
      'totalWordsSpoken': totalWordsSpoken,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'dailyReminders': dailyReminders,
      'progressAlerts': progressAlerts,
      'therapistUpdates': therapistUpdates,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? '',
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      age: map['age'],
      specialization: map['specialization'],
      clinic: map['clinic'],
      managedByCaregiver: map['managedByCaregiver'] ?? false,
      practiceFrequency: map['practiceFrequency'],
      primaryGoal: map['primaryGoal'],
      linkedTherapistId: map['linkedTherapistId'],
      linkedPatientIds: List<String>.from(map['linkedPatientIds'] ?? []),
      streakDays: map['streakDays'] ?? 0,
      totalWordsSpoken: map['totalWordsSpoken'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      dailyReminders: map['dailyReminders'] ?? true,
      progressAlerts: map['progressAlerts'] ?? true,
      therapistUpdates: map['therapistUpdates'] ?? true,
    );
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? role,
    String? firstName,
    String? lastName,
    int? age,
    String? specialization,
    String? clinic,
    bool? managedByCaregiver,
    String? practiceFrequency,
    String? primaryGoal,
    String? linkedTherapistId,
    List<String>? linkedPatientIds,
    int? streakDays,
    int? totalWordsSpoken,
    DateTime? createdAt,
    bool? dailyReminders,
    bool? progressAlerts,
    bool? therapistUpdates,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      role: role ?? this.role,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      age: age ?? this.age,
      specialization: specialization ?? this.specialization,
      clinic: clinic ?? this.clinic,
      managedByCaregiver: managedByCaregiver ?? this.managedByCaregiver,
      practiceFrequency: practiceFrequency ?? this.practiceFrequency,
      primaryGoal: primaryGoal ?? this.primaryGoal,
      linkedTherapistId: linkedTherapistId ?? this.linkedTherapistId,
      linkedPatientIds: linkedPatientIds ?? this.linkedPatientIds,
      streakDays: streakDays ?? this.streakDays,
      totalWordsSpoken: totalWordsSpoken ?? this.totalWordsSpoken,
      createdAt: createdAt ?? this.createdAt,
      dailyReminders: dailyReminders ?? this.dailyReminders,
      progressAlerts: progressAlerts ?? this.progressAlerts,
      therapistUpdates: therapistUpdates ?? this.therapistUpdates,
    );
  }
}
