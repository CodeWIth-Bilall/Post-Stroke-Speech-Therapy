import 'package:cloud_firestore/cloud_firestore.dart';

class SavedSessionModel {
  final String id;
  final String userId;
  final String name;
  final List<String> phrases;
  final int repetitions;
  final DateTime? createdAt;

  SavedSessionModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.phrases,
    this.repetitions = 1,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'phrases': phrases,
      'repetitions': repetitions,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  factory SavedSessionModel.fromMap(Map<String, dynamic> map) {
    return SavedSessionModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      phrases: List<String>.from(map['phrases'] ?? []),
      repetitions: map['repetitions'] ?? 1,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
