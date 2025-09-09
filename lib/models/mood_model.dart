import 'package:cloud_firestore/cloud_firestore.dart';

class MoodEntry {
  final String id;
  final String userId;
  final int moodLevel; // 1-10 scale
  final String moodDescription;
  final String? notes;
  final DateTime timestamp;
  final Map<String, dynamic>? activities; // Activities that might affect mood

  MoodEntry({
    required this.id,
    required this.userId,
    required this.moodLevel,
    required this.moodDescription,
    this.notes,
    required this.timestamp,
    this.activities,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'moodLevel': moodLevel,
      'moodDescription': moodDescription,
      'notes': notes,
      'timestamp': timestamp,
      'activities': activities,
    };
  }

  factory MoodEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MoodEntry(
      id: doc.id,
      userId: data['userId'] ?? '',
      moodLevel: data['moodLevel'] ?? 5,
      moodDescription: data['moodDescription'] ?? '',
      notes: data['notes'],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      activities: data['activities'],
    );
  }

  MoodEntry copyWith({
    String? id,
    String? userId,
    int? moodLevel,
    String? moodDescription,
    String? notes,
    DateTime? timestamp,
    Map<String, dynamic>? activities,
  }) {
    return MoodEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      moodLevel: moodLevel ?? this.moodLevel,
      moodDescription: moodDescription ?? this.moodDescription,
      notes: notes ?? this.notes,
      timestamp: timestamp ?? this.timestamp,
      activities: activities ?? this.activities,
    );
  }
}

class MoodStats {
  final double averageMood;
  final int totalEntries;
  final Map<String, int> moodDistribution;
  final List<MoodEntry> recentEntries;

  MoodStats({
    required this.averageMood,
    required this.totalEntries,
    required this.moodDistribution,
    required this.recentEntries,
  });
}
