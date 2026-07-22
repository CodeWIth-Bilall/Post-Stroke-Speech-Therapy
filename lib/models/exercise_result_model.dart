import 'package:cloud_firestore/cloud_firestore.dart';

class ExerciseResultModel {
  final String id;
  final String userId;
  final String sessionId;
  final String phraseExpected;
  final String phraseSpoken;
  final double clarityScore;
  final double accuracyScore;   // LCS-based text accuracy (0–100)
  final double fluencyScore;    // GRU model fluency score (0–100), -1 = unavailable
  final String feedback;
  final double modelConfidence;
  final String? audioUrl;
  final String exerciseType; // 'phrase_practice', 'word_repeat', 'picture_naming'
  final DateTime? createdAt;

  DateTime get timestamp => createdAt ?? DateTime.now();

  /// True when the fluency model returned a valid score.
  bool get hasFluencyScore => fluencyScore >= 0;

  ExerciseResultModel({
    required this.id,
    required this.userId,
    this.sessionId = '',
    required this.phraseExpected,
    this.phraseSpoken = '',
    this.clarityScore = 0.0,
    this.accuracyScore = 0.0,
    this.fluencyScore = -1.0,
    this.feedback = '',
    this.modelConfidence = 0.0,
    this.audioUrl,
    required this.exerciseType,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'sessionId': sessionId,
      'phraseExpected': phraseExpected,
      'phraseSpoken': phraseSpoken,
      'clarityScore': clarityScore,
      'accuracyScore': accuracyScore,
      'fluencyScore': fluencyScore,
      'feedback': feedback,
      'modelConfidence': modelConfidence,
      'audioUrl': audioUrl,
      'exerciseType': exerciseType,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  factory ExerciseResultModel.fromMap(Map<String, dynamic> map) {
    return ExerciseResultModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      sessionId: map['sessionId'] ?? '',
      phraseExpected: map['phraseExpected'] ?? '',
      phraseSpoken: map['phraseSpoken'] ?? '',
      clarityScore: (map['clarityScore'] ?? 0.0).toDouble(),
      accuracyScore: (map['accuracyScore'] ?? 0.0).toDouble(),
      fluencyScore: (map['fluencyScore'] ?? -1.0).toDouble(),
      feedback: map['feedback'] ?? '',
      modelConfidence: (map['modelConfidence'] ?? 0.0).toDouble(),
      audioUrl: map['audioUrl'],
      exerciseType: map['exerciseType'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
