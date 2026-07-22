import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/exercise_result_model.dart';
import '../models/assignment_model.dart';
import '../models/saved_session_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ==================== USERS ====================

  Future<void> createOrUpdateUser(UserModel user) async {
    await _db
        .collection('users')
        .doc(user.uid)
        .set(user.toMap(), SetOptions(merge: true));
  }

  Future<void> updateUserFields(String uid, Map<String, dynamic> fields) async {
    await _db.collection('users').doc(uid).update(fields);
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) {
      return UserModel.fromMap(doc.data()!);
    }
    return null;
  }

  Stream<UserModel?> userStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!);
      }
      return null;
    });
  }

  // Find user by email (for patient-therapist linking)
  Future<UserModel?> findUserByEmail(String email) async {
    final query = await _db
        .collection('users')
        .where('email', isEqualTo: email.trim().toLowerCase())
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      return UserModel.fromMap(query.docs.first.data());
    }
    return null;
  }

  // Link patient to therapist
  Future<bool> linkPatientToTherapist(
    String therapistId,
    String patientEmail,
  ) async {
    final patient = await findUserByEmail(patientEmail);
    if (patient == null || patient.role != 'patient') return false;

    // Update therapist's linked patients
    await _db.collection('users').doc(therapistId).update({
      'linkedPatientIds': FieldValue.arrayUnion([patient.uid]),
    });

    // Update patient's linked therapist
    await _db.collection('users').doc(patient.uid).update({
      'linkedTherapistId': therapistId,
    });

    return true;
  }

  // Get all patients linked to a therapist
  Stream<List<UserModel>> getLinkedPatients(String therapistId) {
    return _db
        .collection('users')
        .where('linkedTherapistId', isEqualTo: therapistId)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => UserModel.fromMap(doc.data())).toList(),
        );
  }

  // ==================== EXERCISE RESULTS ====================

  Future<void> saveExerciseResult(ExerciseResultModel result) async {
    await _db.collection('exercise_results').doc(result.id).set(result.toMap());

    // Update user stats
    await _db.collection('users').doc(result.userId).update({
      'totalWordsSpoken': FieldValue.increment(1),
    });
  }

  Stream<List<ExerciseResultModel>> getExerciseResults(
    String userId, {
    int limit = 50,
  }) {
    return _db
        .collection('exercise_results')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => ExerciseResultModel.fromMap(doc.data()))
              .toList(),
        );
  }

  Future<List<ExerciseResultModel>> getExerciseResultsOnce(
    String userId, {
    int limit = 50,
  }) async {
    final snap = await _db
        .collection('exercise_results')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs
        .map((doc) => ExerciseResultModel.fromMap(doc.data()))
        .toList();
  }

  // Get results for a specific date range (for progress tracking)
  Future<List<ExerciseResultModel>> getResultsForDateRange(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    final snap = await _db
        .collection('exercise_results')
        .where('userId', isEqualTo: userId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs
        .map((doc) => ExerciseResultModel.fromMap(doc.data()))
        .toList();
  }

  // Get today's results
  Future<List<ExerciseResultModel>> getTodayResults(String userId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return getResultsForDateRange(userId, startOfDay, endOfDay);
  }

  // Get weekly average accuracy
  Future<double> getWeeklyAverageAccuracy(String userId) async {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final results = await getResultsForDateRange(userId, weekAgo, now);
    if (results.isEmpty) return 0.0;
    final total = results.fold<double>(0, (sum, r) => sum + r.clarityScore);
    return total / results.length;
  }

  // Get daily accuracy scores for the week (for chart)
  Future<List<Map<String, dynamic>>> getWeeklyDailyScores(String userId) async {
    final now = DateTime.now();
    final List<Map<String, dynamic>> dailyScores = [];

    for (int i = 6; i >= 0; i--) {
      final day = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: i));
      final nextDay = day.add(const Duration(days: 1));
      final results = await getResultsForDateRange(userId, day, nextDay);

      double avgScore = 0;
      if (results.isNotEmpty) {
        avgScore =
            results.fold<double>(0, (sum, r) => sum + r.clarityScore) /
            results.length;
      }

      dailyScores.add({
        'date': day,
        'score': avgScore,
        'count': results.length,
      });
    }
    return dailyScores;
  }

  // ==================== ASSIGNMENTS ====================

  Future<void> createAssignment(AssignmentModel assignment) async {
    await _db
        .collection('assignments')
        .doc(assignment.id)
        .set(assignment.toMap());
  }

  Stream<List<AssignmentModel>> getPatientAssignments(String patientId) {
    return _db
        .collection('assignments')
        .where('patientId', isEqualTo: patientId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => AssignmentModel.fromMap(doc.data()))
              .toList(),
        );
  }

  Future<void> updateAssignmentStatus(
    String assignmentId,
    String status,
  ) async {
    await _db.collection('assignments').doc(assignmentId).update({
      'status': status,
      'completedAt': status == 'completed'
          ? FieldValue.serverTimestamp()
          : null,
    });
  }

  // Get completed assignments for a patient (for therapist reports)
  Future<List<AssignmentModel>> getCompletedAssignments(
    String patientId,
  ) async {
    try {
      final snap = await _db
          .collection('assignments')
          .where('patientId', isEqualTo: patientId)
          .where('status', isEqualTo: 'completed')
          .limit(30)
          .get();
      final list = snap.docs
          .map((doc) => AssignmentModel.fromMap(doc.data()))
          .toList();
      // Sort client-side to avoid needing a composite index
      list.sort(
        (a, b) => (b.createdAt ?? DateTime(2000)).compareTo(
          a.createdAt ?? DateTime(2000),
        ),
      );
      return list;
    } catch (_) {
      return [];
    }
  }

  // Get therapist's assignments with patients who need attention
  Future<List<Map<String, dynamic>>> getPatientsNeedingAttention(
    String therapistId,
  ) async {
    final patients = await _db
        .collection('users')
        .where('linkedTherapistId', isEqualTo: therapistId)
        .get();

    List<Map<String, dynamic>> attentionList = [];

    for (var patientDoc in patients.docs) {
      final patient = UserModel.fromMap(patientDoc.data());
      final recentResults = await getExerciseResultsOnce(patient.uid, limit: 5);

      if (recentResults.isNotEmpty) {
        final avgScore =
            recentResults.fold<double>(0, (s, r) => s + r.clarityScore) /
            recentResults.length;
        if (avgScore < 60) {
          attentionList.add({
            'patient': patient,
            'avgScore': avgScore,
            'recentResults': recentResults,
            'streak': patient.streakDays,
          });
        }
      }
    }

    return attentionList;
  }

  // Update streak
  Future<void> updateStreak(String userId) async {
    final user = await getUser(userId);
    if (user == null) return;

    final todayResults = await getTodayResults(userId);
    if (todayResults.isNotEmpty) {
      // Check if yesterday also had results
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayStart = DateTime(
        yesterday.year,
        yesterday.month,
        yesterday.day,
      );
      final yesterdayEnd = yesterdayStart.add(const Duration(days: 1));
      final yesterdayResults = await getResultsForDateRange(
        userId,
        yesterdayStart,
        yesterdayEnd,
      );

      int newStreak = yesterdayResults.isNotEmpty ? user.streakDays + 1 : 1;
      await updateUserFields(userId, {'streakDays': newStreak});
    }
  }

  // ==================== SAVED SESSIONS ====================

  Future<void> saveSession(SavedSessionModel session) async {
    await _db.collection('saved_sessions').doc(session.id).set(session.toMap());
  }

  Stream<List<SavedSessionModel>> getSavedSessions(String userId) {
    return _db
        .collection('saved_sessions')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((doc) => SavedSessionModel.fromMap(doc.data()))
              .toList();
          list.sort(
            (a, b) => (b.createdAt ?? DateTime(2000)).compareTo(
              a.createdAt ?? DateTime(2000),
            ),
          );
          return list;
        });
  }

  Future<void> deleteSession(String sessionId) async {
    await _db.collection('saved_sessions').doc(sessionId).delete();
  }
}
