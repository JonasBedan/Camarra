import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/premium_model.dart';

class PaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Bank account details (you should store these securely)
  static const String _bankAccountNumber = '1234567890';
  static const String _bankRoutingNumber = '987654321';
  static const String _bankName = 'Camarra Bank';
  static const String _accountHolderName = 'Camarra Inc.';

  // Process payment via bank transfer
  Future<PaymentResult> processBankTransfer({
    required PremiumPlanModel plan,
    required String userId,
    required String userEmail,
  }) async {
    try {
      // Create payment record
      final paymentId = await _createPaymentRecord(plan, userId, userEmail);

      // Simulate bank transfer processing
      await _simulateBankTransfer(plan, paymentId);

      // Update payment status
      await _updatePaymentStatus(paymentId, 'completed');

      return PaymentResult(
        success: true,
        paymentId: paymentId,
        message: 'Payment processed successfully',
      );
    } catch (e) {
      return PaymentResult(
        success: false,
        error: e.toString(),
        message: 'Payment failed: $e',
      );
    }
  }

  // Create payment record in Firestore
  Future<String> _createPaymentRecord(
    PremiumPlanModel plan,
    String userId,
    String userEmail,
  ) async {
    final paymentData = {
      'userId': userId,
      'userEmail': userEmail,
      'planId': plan.id,
      'planName': plan.name,
      'amount': plan.price,
      'currency': plan.currency,
      'status': 'pending',
      'paymentMethod': 'bank_transfer',
      'bankAccountNumber': _bankAccountNumber,
      'bankRoutingNumber': _bankRoutingNumber,
      'bankName': _bankName,
      'accountHolderName': _accountHolderName,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    };

    final docRef = await _firestore.collection('payments').add(paymentData);

    return docRef.id;
  }

  // Simulate bank transfer processing
  Future<void> _simulateBankTransfer(
    PremiumPlanModel plan,
    String paymentId,
  ) async {
    // In a real implementation, you would integrate with a bank API
    // For now, we'll simulate the process

    // Simulate processing time
    await Future.delayed(const Duration(seconds: 2));

    // Simulate success (in real implementation, check bank response)
    final success = true; // This would come from bank API

    if (!success) {
      throw Exception('Bank transfer failed');
    }
  }

  // Update payment status
  Future<void> _updatePaymentStatus(String paymentId, String status) async {
    await _firestore.collection('payments').doc(paymentId).update({
      'status': status,
      'updatedAt': Timestamp.now(),
    });
  }

  // Get payment history for user
  Stream<List<PaymentRecord>> getPaymentHistory(String userId) {
    return _firestore
        .collection('payments')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PaymentRecord.fromFirestore(doc))
              .toList(),
        );
  }

  // Get bank transfer instructions
  Map<String, String> getBankTransferInstructions() {
    return {
      'bankName': _bankName,
      'accountHolderName': _accountHolderName,
      'accountNumber': _bankAccountNumber,
      'routingNumber': _bankRoutingNumber,
      'instructions':
          'Please include your email address as the payment reference.',
    };
  }

  // Verify payment status
  Future<bool> verifyPayment(String paymentId) async {
    try {
      final doc = await _firestore.collection('payments').doc(paymentId).get();

      if (doc.exists) {
        final data = doc.data();
        return data?['status'] == 'completed';
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}

// Payment result model
class PaymentResult {
  final bool success;
  final String? paymentId;
  final String? error;
  final String message;

  PaymentResult({
    required this.success,
    this.paymentId,
    this.error,
    required this.message,
  });
}

// Payment record model
class PaymentRecord {
  final String id;
  final String userId;
  final String userEmail;
  final String planId;
  final String planName;
  final double amount;
  final String currency;
  final String status;
  final String paymentMethod;
  final DateTime createdAt;
  final DateTime updatedAt;

  PaymentRecord({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.planId,
    required this.planName,
    required this.amount,
    required this.currency,
    required this.status,
    required this.paymentMethod,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PaymentRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PaymentRecord(
      id: doc.id,
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'] ?? '',
      planId: data['planId'] ?? '',
      planName: data['planName'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      currency: data['currency'] ?? 'USD',
      status: data['status'] ?? 'pending',
      paymentMethod: data['paymentMethod'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }
}
