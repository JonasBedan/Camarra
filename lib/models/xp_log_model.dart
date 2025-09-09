import 'package:cloud_firestore/cloud_firestore.dart';

class XPLogModel {
  final String id;
  final String uid;
  final int value;
  final String reason;
  final DateTime timestamp;

  XPLogModel({
    required this.id,
    required this.uid,
    required this.value,
    required this.reason,
    required this.timestamp,
  });

  factory XPLogModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return XPLogModel(
      id: doc.id,
      uid: data['uid'] ?? '',
      value: data['value'] ?? 0,
      reason: data['reason'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'value': value,
      'reason': reason,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
