import 'package:cloud_firestore/cloud_firestore.dart';

class ReflectionModel {
  final String id;
  final String title;
  final String content;
  final String mood;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  ReflectionModel({
    required this.id,
    required this.title,
    required this.content,
    required this.mood,
    required this.timestamp,
    this.metadata,
  });

  // Create from Firestore document
  factory ReflectionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReflectionModel(
      id: doc.id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      mood: data['mood'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'content': content,
      'mood': mood,
      'timestamp': Timestamp.fromDate(timestamp),
      'metadata': metadata,
    };
  }

  // Create a copy with updated fields
  ReflectionModel copyWith({
    String? id,
    String? title,
    String? content,
    String? mood,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return ReflectionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      mood: mood ?? this.mood,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }
}
