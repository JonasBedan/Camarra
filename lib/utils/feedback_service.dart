import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/feedback_model.dart';

class FeedbackService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create new feedback
  Future<void> createFeedback({
    required String title,
    required String description,
    required String category,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data();

    final feedback = FeedbackModel(
      id: _firestore.collection('feedback').doc().id,
      userId: user.uid,
      userDisplayName: userData?['displayName'] ?? 'Anonymous',
      userProfilePicture: userData?['profilePicture'] ?? '',
      title: title,
      description: description,
      category: category,
      createdAt: DateTime.now(),
      upvotes: 0,
      downvotes: 0,
      upvotedBy: [],
      downvotedBy: [],
      status: 'pending',
    );

    try {
      await _firestore
          .collection('feedback')
          .doc(feedback.id)
          .set(feedback.toMap());
    } catch (e) {
      // If the collection doesn't exist, try creating it with a sample document first
      if (e.toString().contains('insufficient permissions') ||
          e.toString().contains('not found')) {
        // Create a sample document to initialize the collection
        await _firestore.collection('feedback').doc('init').set({
          'id': 'init',
          'userId': 'system',
          'userDisplayName': 'System',
          'userProfilePicture': '',
          'title': 'Collection Initialized',
          'description': 'This document initializes the feedback collection.',
          'category': 'System',
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'upvotes': 0,
          'downvotes': 0,
          'upvotedBy': [],
          'downvotedBy': [],
          'status': 'completed',
        });

        // Now try to create the actual feedback
        await _firestore
            .collection('feedback')
            .doc(feedback.id)
            .set(feedback.toMap());
      } else {
        rethrow;
      }
    }
  }

  // Get all feedback sorted by score (upvotes - downvotes)
  // TODO: Once indexes are built, switch back to:
  // .orderBy('upvotes', descending: true)
  // .orderBy('createdAt', descending: true)
  Stream<List<FeedbackModel>> getFeedbackStream() {
    return _firestore
        .collection('feedback')
        .orderBy('createdAt', descending: true) // Use single orderBy for now
        .snapshots()
        .map((snapshot) {
          final feedbackList = snapshot.docs
              .map((doc) => FeedbackModel.fromMap(doc.data()))
              .toList();

          // Sort by upvotes in memory while index is building
          feedbackList.sort((a, b) => b.upvotes.compareTo(a.upvotes));
          return feedbackList;
        });
  }

  // Get feedback by category
  // TODO: Once indexes are built, switch back to:
  // .orderBy('upvotes', descending: true)
  // .orderBy('createdAt', descending: true)
  Stream<List<FeedbackModel>> getFeedbackByCategory(String category) {
    return _firestore
        .collection('feedback')
        .where('category', isEqualTo: category)
        .orderBy('createdAt', descending: true) // Use single orderBy for now
        .snapshots()
        .map((snapshot) {
          final feedbackList = snapshot.docs
              .map((doc) => FeedbackModel.fromMap(doc.data()))
              .toList();

          // Sort by upvotes in memory while index is building
          feedbackList.sort((a, b) => b.upvotes.compareTo(a.upvotes));
          return feedbackList;
        });
  }

  // Get user's feedback
  Stream<List<FeedbackModel>> getUserFeedback(String userId) {
    return _firestore
        .collection('feedback')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => FeedbackModel.fromMap(doc.data()))
              .toList();
        });
  }

  // Upvote feedback
  Future<void> upvoteFeedback(String feedbackId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final feedbackRef = _firestore.collection('feedback').doc(feedbackId);

    await _firestore.runTransaction((transaction) async {
      final feedbackDoc = await transaction.get(feedbackRef);
      if (!feedbackDoc.exists) throw Exception('Feedback not found');

      final feedback = FeedbackModel.fromMap(feedbackDoc.data()!);

      // Remove from downvotes if user had downvoted
      List<String> downvotedBy = List.from(feedback.downvotedBy);
      if (downvotedBy.contains(user.uid)) {
        downvotedBy.remove(user.uid);
      }

      // Add to upvotes if not already upvoted
      List<String> upvotedBy = List.from(feedback.upvotedBy);
      if (!upvotedBy.contains(user.uid)) {
        upvotedBy.add(user.uid);
      } else {
        // Remove upvote if already upvoted (toggle)
        upvotedBy.remove(user.uid);
      }

      final newUpvotes = upvotedBy.length;
      final newDownvotes = downvotedBy.length;

      transaction.update(feedbackRef, {
        'upvotes': newUpvotes,
        'downvotes': newDownvotes,
        'upvotedBy': upvotedBy,
        'downvotedBy': downvotedBy,
      });
    });
  }

  // Downvote feedback
  Future<void> downvoteFeedback(String feedbackId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final feedbackRef = _firestore.collection('feedback').doc(feedbackId);

    await _firestore.runTransaction((transaction) async {
      final feedbackDoc = await transaction.get(feedbackRef);
      if (!feedbackDoc.exists) throw Exception('Feedback not found');

      final feedback = FeedbackModel.fromMap(feedbackDoc.data()!);

      // Remove from upvotes if user had upvoted
      List<String> upvotedBy = List.from(feedback.upvotedBy);
      if (upvotedBy.contains(user.uid)) {
        upvotedBy.remove(user.uid);
      }

      // Add to downvotes if not already downvoted
      List<String> downvotedBy = List.from(feedback.downvotedBy);
      if (!downvotedBy.contains(user.uid)) {
        downvotedBy.add(user.uid);
      } else {
        // Remove downvote if already downvoted (toggle)
        downvotedBy.remove(user.uid);
      }

      final newUpvotes = upvotedBy.length;
      final newDownvotes = downvotedBy.length;

      transaction.update(feedbackRef, {
        'upvotes': newUpvotes,
        'downvotes': newDownvotes,
        'upvotedBy': upvotedBy,
        'downvotedBy': downvotedBy,
      });
    });
  }

  // Delete feedback (only by the author)
  Future<void> deleteFeedback(String feedbackId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final feedbackDoc = await _firestore
        .collection('feedback')
        .doc(feedbackId)
        .get();
    if (!feedbackDoc.exists) throw Exception('Feedback not found');

    final feedback = FeedbackModel.fromMap(feedbackDoc.data()!);
    if (feedback.userId != user.uid) {
      throw Exception('You can only delete your own feedback');
    }

    await _firestore.collection('feedback').doc(feedbackId).delete();
  }

  // Get feedback categories
  List<String> getFeedbackCategories() {
    return [
      'Feature Request',
      'Bug Report',
      'UI/UX Improvement',
      'Performance',
      'Content Suggestion',
      'General Feedback',
      'Other',
    ];
  }

  // Get status badges
  Map<String, Map<String, dynamic>> getStatusBadges() {
    return {
      'pending': {
        'label': 'Pending',
        'color': Colors.orange,
        'icon': Icons.schedule,
      },
      'in_progress': {
        'label': 'In Progress',
        'color': Colors.blue,
        'icon': Icons.engineering,
      },
      'completed': {
        'label': 'Completed',
        'color': Colors.green,
        'icon': Icons.check_circle,
      },
      'declined': {
        'label': 'Declined',
        'color': Colors.red,
        'icon': Icons.cancel,
      },
    };
  }
}
