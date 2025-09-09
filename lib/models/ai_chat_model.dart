import 'package:cloud_firestore/cloud_firestore.dart';

class AIChatModel {
  final String id;
  final String userId;
  final String message;
  final String sender; // 'user' or 'ai'
  final DateTime timestamp;
  final Map<String, dynamic>? metadata; // For AI analysis data
  final String? mood; // Detected mood from user message
  final List<String>? anxietyTriggers; // Identified triggers
  final String? therapeuticFocus; // CBT focus area

  AIChatModel({
    required this.id,
    required this.userId,
    required this.message,
    required this.sender,
    required this.timestamp,
    this.metadata,
    this.mood,
    this.anxietyTriggers,
    this.therapeuticFocus,
  });

  // Create from Firestore document
  factory AIChatModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AIChatModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      message: data['message'] ?? '',
      sender: data['sender'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      metadata: data['metadata'] as Map<String, dynamic>?,
      mood: data['mood'],
      anxietyTriggers: data['anxietyTriggers'] != null
          ? List<String>.from(data['anxietyTriggers'])
          : null,
      therapeuticFocus: data['therapeuticFocus'],
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'message': message,
      'sender': sender,
      'timestamp': Timestamp.fromDate(timestamp),
      'metadata': metadata,
      'mood': mood,
      'anxietyTriggers': anxietyTriggers,
      'therapeuticFocus': therapeuticFocus,
    };
  }

  // Create a copy with updated fields
  AIChatModel copyWith({
    String? id,
    String? userId,
    String? message,
    String? sender,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
    String? mood,
    List<String>? anxietyTriggers,
    String? therapeuticFocus,
  }) {
    return AIChatModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      message: message ?? this.message,
      sender: sender ?? this.sender,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
      mood: mood ?? this.mood,
      anxietyTriggers: anxietyTriggers ?? this.anxietyTriggers,
      therapeuticFocus: therapeuticFocus ?? this.therapeuticFocus,
    );
  }
}

class UserCommunicationProfile {
  final String userId;
  final Map<String, int> moodHistory; // mood -> count
  final List<String> commonTriggers;
  final String communicationStyle; // 'direct', 'hesitant', 'detailed', etc.
  final List<String> copingStrategies;
  final Map<String, dynamic> progressMetrics;
  final DateTime lastUpdated;

  UserCommunicationProfile({
    required this.userId,
    required this.moodHistory,
    required this.commonTriggers,
    required this.communicationStyle,
    required this.copingStrategies,
    required this.progressMetrics,
    required this.lastUpdated,
  });

  // Create from Firestore document
  factory UserCommunicationProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserCommunicationProfile(
      userId: doc.id,
      moodHistory: Map<String, int>.from(data['moodHistory'] ?? {}),
      commonTriggers: List<String>.from(data['commonTriggers'] ?? []),
      communicationStyle: data['communicationStyle'] ?? 'balanced',
      copingStrategies: List<String>.from(data['copingStrategies'] ?? []),
      progressMetrics: Map<String, dynamic>.from(data['progressMetrics'] ?? {}),
      lastUpdated: (data['lastUpdated'] as Timestamp).toDate(),
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'moodHistory': moodHistory,
      'commonTriggers': commonTriggers,
      'communicationStyle': communicationStyle,
      'copingStrategies': copingStrategies,
      'progressMetrics': progressMetrics,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }
}
