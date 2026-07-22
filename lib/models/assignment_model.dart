import 'package:cloud_firestore/cloud_firestore.dart';

class AssignmentModel {
  final String id;
  final String therapistId;
  final String patientId;
  final String exerciseType; // 'phrase_practice', 'word_repeat', 'picture_naming'
  final String phrase; // target phrase or word
  final String notes;
  final List<String> phrases;
  final String category;
  final String status; // 'pending', 'in_progress', 'completed'
  final DateTime? createdAt;

  AssignmentModel({
    required this.id,
    required this.therapistId,
    required this.patientId,
    this.exerciseType = 'phrase_practice',
    this.phrase = '',
    this.notes = '',
    this.phrases = const [],
    this.category = '',
    this.status = 'pending',
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'therapistId': therapistId,
      'patientId': patientId,
      'exerciseType': exerciseType,
      'phrase': phrase,
      'notes': notes,
      'phrases': phrases,
      'category': category,
      'status': status,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  factory AssignmentModel.fromMap(Map<String, dynamic> map) {
    return AssignmentModel(
      id: map['id'] ?? '',
      therapistId: map['therapistId'] ?? '',
      patientId: map['patientId'] ?? '',
      exerciseType: map['exerciseType'] ?? 'phrase_practice',
      phrase: map['phrase'] ?? '',
      notes: map['notes'] ?? '',
      phrases: List<String>.from(map['phrases'] ?? []),
      category: map['category'] ?? '',
      status: map['status'] ?? 'pending',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
