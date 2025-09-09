import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/reflection_model.dart';

class ReflectionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a new reflection
  Future<void> createReflection(ReflectionModel reflection) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('reflections')
          .add(reflection.toFirestore());
    } catch (e) {
      print('Error creating reflection: $e');
      rethrow;
    }
  }

  // Get user's reflections
  Stream<List<ReflectionModel>> streamUserReflections(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('reflections')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ReflectionModel.fromFirestore(doc))
              .toList(),
        );
  }

  // Update a reflection
  Future<void> updateReflection(
    String reflectionId,
    ReflectionModel reflection,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('reflections')
          .doc(reflectionId)
          .update(reflection.toFirestore());
    } catch (e) {
      print('Error updating reflection: $e');
      rethrow;
    }
  }

  // Delete a reflection
  Future<void> deleteReflection(String reflectionId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('reflections')
          .doc(reflectionId)
          .delete();
    } catch (e) {
      print('Error deleting reflection: $e');
      rethrow;
    }
  }
}
