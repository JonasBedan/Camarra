import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/mood_model.dart';
import 'user_service.dart';

class MoodService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();

  // Add a new mood entry
  Future<void> addMoodEntry({
    required int moodLevel,
    required String moodDescription,
    String? notes,
    Map<String, dynamic>? activities,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final moodEntry = MoodEntry(
      id: '', // Will be set by Firestore
      userId: user.uid,
      moodLevel: moodLevel,
      moodDescription: moodDescription,
      notes: notes,
      timestamp: DateTime.now(),
      activities: activities,
    );

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('mood_entries')
        .add(moodEntry.toFirestore());

    // Also update the user's mood field for quick access
    await _userService.updateUser(user.uid, {'mood': moodDescription});
  }

  // Get user's mood entries
  Stream<List<MoodEntry>> getMoodEntries() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('mood_entries')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => MoodEntry.fromFirestore(doc)).toList(),
        );
  }

  // Get mood entries for a specific date range
  Future<List<MoodEntry>> getMoodEntriesForDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('mood_entries')
        .where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        )
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs.map((doc) => MoodEntry.fromFirestore(doc)).toList();
  }

  // Get mood statistics
  Future<MoodStats> getMoodStats({int days = 30}) async {
    final user = _auth.currentUser;
    if (user == null) {
      return MoodStats(
        averageMood: 0,
        totalEntries: 0,
        moodDistribution: {},
        recentEntries: [],
      );
    }

    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days));

    final entries = await getMoodEntriesForDateRange(
      startDate: startDate,
      endDate: endDate,
    );

    if (entries.isEmpty) {
      return MoodStats(
        averageMood: 0,
        totalEntries: 0,
        moodDistribution: {},
        recentEntries: [],
      );
    }

    // Calculate average mood
    final totalMood = entries.fold<int>(
      0,
      (sum, entry) => sum + entry.moodLevel,
    );
    final averageMood = totalMood / entries.length;

    // Calculate mood distribution
    final moodDistribution = <String, int>{};
    for (final entry in entries) {
      final moodKey = _getMoodKey(entry.moodLevel);
      moodDistribution[moodKey] = (moodDistribution[moodKey] ?? 0) + 1;
    }

    return MoodStats(
      averageMood: averageMood,
      totalEntries: entries.length,
      moodDistribution: moodDistribution,
      recentEntries: entries.take(10).toList(),
    );
  }

  String _getMoodKey(int moodLevel) {
    if (moodLevel <= 2) return 'Very Low';
    if (moodLevel <= 4) return 'Low';
    if (moodLevel <= 6) return 'Neutral';
    if (moodLevel <= 8) return 'Good';
    return 'Excellent';
  }

  // Get today's mood entry
  Future<MoodEntry?> getTodayMoodEntry() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('mood_entries')
        .where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where('timestamp', isLessThan: Timestamp.fromDate(endOfDay))
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    return MoodEntry.fromFirestore(snapshot.docs.first);
  }

  // Update a mood entry
  Future<void> updateMoodEntry({
    required String entryId,
    int? moodLevel,
    String? moodDescription,
    String? notes,
    Map<String, dynamic>? activities,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final updates = <String, dynamic>{};
    if (moodLevel != null) updates['moodLevel'] = moodLevel;
    if (moodDescription != null) updates['moodDescription'] = moodDescription;
    if (notes != null) updates['notes'] = notes;
    if (activities != null) updates['activities'] = activities;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('mood_entries')
        .doc(entryId)
        .update(updates);

    // Also update the user's mood field if moodDescription was updated
    if (moodDescription != null) {
      await _userService.updateUser(user.uid, {'mood': moodDescription});
    }
  }

  // Delete a mood entry
  Future<void> deleteMoodEntry(String entryId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('mood_entries')
        .doc(entryId)
        .delete();
  }
}
