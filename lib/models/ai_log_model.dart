import 'package:cloud_firestore/cloud_firestore.dart';

class AILogModel {
  final String id;
  final String type;
  final String prompt;
  final String response;
  final String model;
  final DateTime timestamp;

  AILogModel({
    required this.id,
    required this.type,
    required this.prompt,
    required this.response,
    required this.model,
    required this.timestamp,
  });

  // Create from Firestore document
  factory AILogModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AILogModel(
      id: doc.id,
      type: data['type'] ?? '',
      prompt: data['prompt'] ?? '',
      response: data['response'] ?? '',
      model: data['model'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'type': type,
      'prompt': prompt,
      'response': response,
      'model': model,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  // Create a copy with updated fields
  AILogModel copyWith({
    String? id,
    String? type,
    String? prompt,
    String? response,
    String? model,
    DateTime? timestamp,
  }) {
    return AILogModel(
      id: id ?? this.id,
      type: type ?? this.type,
      prompt: prompt ?? this.prompt,
      response: response ?? this.response,
      model: model ?? this.model,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
