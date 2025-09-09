import 'package:cloud_firestore/cloud_firestore.dart';

enum BuddyRequestStatus { pending, accepted, declined }

class BuddyRequestModel {
  final String requestId;
  final String fromUserId;
  final String toUserId;
  final BuddyRequestStatus status;
  final DateTime timestamp;

  BuddyRequestModel({
    required this.requestId,
    required this.fromUserId,
    required this.toUserId,
    required this.status,
    required this.timestamp,
  });

  factory BuddyRequestModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return BuddyRequestModel(
      requestId: doc.id,
      fromUserId: data['fromUserId'] ?? '',
      toUserId: data['toUserId'] ?? '',
      status: BuddyRequestStatus.values.firstWhere(
        (e) => e.toString().split('.').last == data['status'],
        orElse: () => BuddyRequestStatus.pending,
      ),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'status': status.toString().split('.').last,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  BuddyRequestModel copyWith({
    String? requestId,
    String? fromUserId,
    String? toUserId,
    BuddyRequestStatus? status,
    DateTime? timestamp,
  }) {
    return BuddyRequestModel(
      requestId: requestId ?? this.requestId,
      fromUserId: fromUserId ?? this.fromUserId,
      toUserId: toUserId ?? this.toUserId,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
