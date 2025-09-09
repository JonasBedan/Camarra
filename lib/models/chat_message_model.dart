import 'package:cloud_firestore/cloud_firestore.dart';

// Chat Room
class ChatRoomModel {
  final String id;
  final List<String> userIds;
  final DateTime createdAt;

  const ChatRoomModel({
    required this.id,
    required this.userIds,
    required this.createdAt,
  });

  factory ChatRoomModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatRoomModel(
      id: doc.id,
      userIds: List<String>.from(data['userIds'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {'userIds': userIds, 'createdAt': Timestamp.fromDate(createdAt)};
  }

  ChatRoomModel copyWith({
    String? id,
    List<String>? userIds,
    DateTime? createdAt,
  }) {
    return ChatRoomModel(
      id: id ?? this.id,
      userIds: userIds ?? this.userIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// Chat Message
class ChatMessageModel {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final String type;
  final Map<String, dynamic>? metadata;

  const ChatMessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.type,
    this.metadata,
  });

  factory ChatMessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessageModel(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      type: data['type'] ?? 'text',
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': type,
      'metadata': metadata,
    };
  }

  ChatMessageModel copyWith({
    String? id,
    String? senderId,
    String? text,
    DateTime? timestamp,
    String? type,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      metadata: metadata ?? this.metadata,
    );
  }
}

// Buddy Request
class BuddyRequestModel {
  final String id;
  final String fromUserId;
  final String toUserId;
  final String status; // "pending", "accepted", "declined"
  final DateTime createdAt;

  const BuddyRequestModel({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.status,
    required this.createdAt,
  });

  factory BuddyRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BuddyRequestModel(
      id: doc.id,
      fromUserId: data['fromUserId'] ?? '',
      toUserId: data['toUserId'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  BuddyRequestModel copyWith({
    String? id,
    String? fromUserId,
    String? toUserId,
    String? status,
    DateTime? createdAt,
  }) {
    return BuddyRequestModel(
      id: id ?? this.id,
      fromUserId: fromUserId ?? this.fromUserId,
      toUserId: toUserId ?? this.toUserId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// Reflection
class ReflectionModel {
  final String id;
  final String text;
  final String mood;
  final DateTime timestamp;

  const ReflectionModel({
    required this.id,
    required this.text,
    required this.mood,
    required this.timestamp,
  });

  factory ReflectionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReflectionModel(
      id: doc.id,
      text: data['text'] ?? '',
      mood: data['mood'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'text': text,
      'mood': mood,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  ReflectionModel copyWith({
    String? id,
    String? text,
    String? mood,
    DateTime? timestamp,
  }) {
    return ReflectionModel(
      id: id ?? this.id,
      text: text ?? this.text,
      mood: mood ?? this.mood,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

// AI Log
class AILogModel {
  final String id;
  final String type;
  final String prompt;
  final String response;
  final String model;
  final DateTime timestamp;

  const AILogModel({
    required this.id,
    required this.type,
    required this.prompt,
    required this.response,
    required this.model,
    required this.timestamp,
  });

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

  Map<String, dynamic> toFirestore() {
    return {
      'type': type,
      'prompt': prompt,
      'response': response,
      'model': model,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

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

// Legacy models for backward compatibility
enum MessageType { text, icebreak, faith, vibeCast }

class IcebreakerModel {
  final String id;
  final String buddyId;
  final String question;
  final DateTime createdAt;
  final bool isUsed;
  final DateTime? usedAt;
  final String? usedBy;
  final Map<String, dynamic>? aiMetadata;

  const IcebreakerModel({
    required this.id,
    required this.buddyId,
    required this.question,
    required this.createdAt,
    required this.isUsed,
    this.usedAt,
    this.usedBy,
    this.aiMetadata,
  });

  factory IcebreakerModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return IcebreakerModel(
      id: doc.id,
      buddyId: data['buddyId'] ?? '',
      question: data['question'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isUsed: data['isUsed'] ?? false,
      usedAt: data['usedAt'] != null
          ? (data['usedAt'] as Timestamp).toDate()
          : null,
      usedBy: data['usedBy'],
      aiMetadata: data['aiMetadata'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'buddyId': buddyId,
      'question': question,
      'createdAt': Timestamp.fromDate(createdAt),
      'isUsed': isUsed,
      'usedAt': usedAt != null ? Timestamp.fromDate(usedAt!) : null,
      'usedBy': usedBy,
      'aiMetadata': aiMetadata,
    };
  }

  IcebreakerModel copyWith({
    String? id,
    String? buddyId,
    String? question,
    DateTime? createdAt,
    bool? isUsed,
    DateTime? usedAt,
    String? usedBy,
    Map<String, dynamic>? aiMetadata,
  }) {
    return IcebreakerModel(
      id: id ?? this.id,
      buddyId: buddyId ?? this.buddyId,
      question: question ?? this.question,
      createdAt: createdAt ?? this.createdAt,
      isUsed: isUsed ?? this.isUsed,
      usedAt: usedAt ?? this.usedAt,
      usedBy: usedBy ?? this.usedBy,
      aiMetadata: aiMetadata ?? this.aiMetadata,
    );
  }
}

class VibeCastModel {
  final String id;
  final String userId;
  final String mood;
  final String emoji;
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  const VibeCastModel({
    required this.id,
    required this.userId,
    required this.mood,
    required this.emoji,
    required this.message,
    required this.timestamp,
    this.metadata,
  });

  factory VibeCastModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VibeCastModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      mood: data['mood'] ?? '',
      emoji: data['emoji'] ?? '',
      message: data['message'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'mood': mood,
      'emoji': emoji,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'metadata': metadata,
    };
  }

  VibeCastModel copyWith({
    String? id,
    String? userId,
    String? mood,
    String? emoji,
    String? message,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return VibeCastModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      mood: mood ?? this.mood,
      emoji: emoji ?? this.emoji,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }
}

class FaithMessageModel {
  final String id;
  final String from;
  final String to;
  final String message;
  final DateTime timestamp;
  final bool isDelivered;
  final DateTime? deliveredAt;
  final Map<String, dynamic>? metadata;

  const FaithMessageModel({
    required this.id,
    required this.from,
    required this.to,
    required this.message,
    required this.timestamp,
    required this.isDelivered,
    this.deliveredAt,
    this.metadata,
  });

  factory FaithMessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FaithMessageModel(
      id: doc.id,
      from: data['from'] ?? '',
      to: data['to'] ?? '',
      message: data['message'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isDelivered: data['isDelivered'] ?? false,
      deliveredAt: data['deliveredAt'] != null
          ? (data['deliveredAt'] as Timestamp).toDate()
          : null,
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'from': from,
      'to': to,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'isDelivered': isDelivered,
      'deliveredAt': deliveredAt != null
          ? Timestamp.fromDate(deliveredAt!)
          : null,
      'metadata': metadata,
    };
  }

  FaithMessageModel copyWith({
    String? id,
    String? from,
    String? to,
    String? message,
    DateTime? timestamp,
    bool? isDelivered,
    DateTime? deliveredAt,
    Map<String, dynamic>? metadata,
  }) {
    return FaithMessageModel(
      id: id ?? this.id,
      from: from ?? this.from,
      to: to ?? this.to,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isDelivered: isDelivered ?? this.isDelivered,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      metadata: metadata ?? this.metadata,
    );
  }
}
