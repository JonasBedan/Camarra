import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/buddy_request_model.dart';
import '../models/user_model.dart';
import 'sound_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BuddyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SoundService _soundService = SoundService();

  // Send buddy request
  Future<void> sendBuddyRequest(String fromUid, String toUid) async {
    if (fromUid == toUid) {
      throw Exception('Cannot send request to yourself');
    }

    // Prevent requests if either user already has a buddy
    final fromDoc = await _firestore.collection('users').doc(fromUid).get();
    final toDoc = await _firestore.collection('users').doc(toUid).get();
    if (!fromDoc.exists || !toDoc.exists) {
      throw Exception('User not found');
    }
    if ((fromDoc.data()!['buddyId']) != null ||
        (toDoc.data()!['buddyId']) != null) {
      throw Exception('Users are already paired with a buddy');
    }

    // Block duplicates in either direction
    final dupA = await _firestore
        .collection('buddyRequests')
        .where('fromUserId', isEqualTo: fromUid)
        .where('toUserId', isEqualTo: toUid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    final dupB = await _firestore
        .collection('buddyRequests')
        .where('fromUserId', isEqualTo: toUid)
        .where('toUserId', isEqualTo: fromUid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (dupA.docs.isNotEmpty || dupB.docs.isNotEmpty) {
      throw Exception('There is already a pending request between you two');
    }

    final request = BuddyRequestModel(
      requestId: '', // Will be set by Firestore
      fromUserId: fromUid,
      toUserId: toUid,
      status: BuddyRequestStatus.pending,
      timestamp: DateTime.now(),
    );

    await _firestore.collection('buddyRequests').add(request.toFirestore());
  }

  // Accept buddy request atomically; pairs both users if permissions allow.
  Future<void> acceptBuddyRequest(String requestId) async {
    final requestRef = _firestore.collection('buddyRequests').doc(requestId);

    await _firestore.runTransaction((txn) async {
      final requestSnap = await txn.get(requestRef);
      if (!requestSnap.exists) throw Exception('Request not found');

      final requestData = requestSnap.data() as Map<String, dynamic>;
      final fromUid = requestData['fromUserId'] as String;
      final toUid = requestData['toUserId'] as String;

      // Mark request accepted
      txn.update(requestRef, {'status': 'accepted'});

      // Set buddyId only for the current user (the one accepting)
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final userRef = _firestore.collection('users').doc(currentUser.uid);
        final otherUserId = currentUser.uid == fromUid ? toUid : fromUid;
        txn.update(userRef, {'buddyId': otherUserId});
        print(
          'Updated current user ${currentUser.uid} with buddyId: $otherUserId',
        );
      }
    });

    print('Buddy relationship established for current user');

    // Note: The other user will need to refresh their app or restart to see the buddy
    // This is a limitation of client-side security rules
    // In a production app, you would use a Cloud Function to update both users
  }

  // Decline buddy request
  Future<void> declineBuddyRequest(String requestId) async {
    await _firestore.collection('buddyRequests').doc(requestId).update({
      'status': 'declined',
    });
  }

  // Get pending requests for a user
  Stream<List<BuddyRequestModel>> getPendingRequests(String uid) {
    return _firestore
        .collection('buddyRequests')
        .where('toUserId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => BuddyRequestModel.fromFirestore(doc))
                  .toList()
                ..sort((a, b) => b.timestamp.compareTo(a.timestamp)),
        );
  }

  // Get sent requests by a user
  Stream<List<BuddyRequestModel>> getSentRequests(String uid) {
    return _firestore
        .collection('buddyRequests')
        .where('fromUserId', isEqualTo: uid)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => BuddyRequestModel.fromFirestore(doc))
                  .toList()
                ..sort((a, b) => b.timestamp.compareTo(a.timestamp)),
        );
  }

  // Get user's buddy
  Future<UserModel?> getBuddy(String uid) async {
    // First check if user has a buddyId
    final userDoc = await _firestore.collection('users').doc(uid).get();
    if (!userDoc.exists) return null;

    final buddyId = userDoc.data()!['buddyId'];
    if (buddyId != null) {
      // User has a buddyId, get the buddy
      final buddyDoc = await _firestore.collection('users').doc(buddyId).get();
      if (buddyDoc.exists) {
        return UserModel.fromFirestore(buddyDoc);
      }
    }

    // If no buddyId or buddy not found, check buddy relationships
    final relationshipsQuery = await _firestore
        .collection('buddyRelationships')
        .where('user1', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .get();

    if (relationshipsQuery.docs.isNotEmpty) {
      final relationship = relationshipsQuery.docs.first.data();
      final otherUserId = relationship['user2'] as String;
      final otherUserDoc = await _firestore
          .collection('users')
          .doc(otherUserId)
          .get();
      if (otherUserDoc.exists) {
        return UserModel.fromFirestore(otherUserDoc);
      }
    }

    return null;
  }

  // Check if user has a buddy
  Future<bool> hasBuddy(String uid) async {
    final buddy = await getBuddy(uid);
    return buddy != null;
  }

  // Manually sync buddy relationship by searching all users
  Future<void> syncBuddyRelationship(String userId) async {
    print('Starting buddy sync for user: $userId');

    try {
      // Search through all users to find who has this user as their buddy
      final allUsersQuery = await _firestore
          .collection('users')
          .where('buddyId', isEqualTo: userId)
          .limit(1)
          .get();

      if (allUsersQuery.docs.isNotEmpty) {
        final buddyDoc = allUsersQuery.docs.first;
        final buddyId = buddyDoc.id;

        print('Found user $buddyId who has $userId as their buddy');

        // Update current user's buddyId to point to the buddy
        await _firestore.collection('users').doc(userId).update({
          'buddyId': buddyId,
        });

        print('Successfully synced buddy relationship: $userId <-> $buddyId');
      } else {
        print('No buddy found for user $userId');

        // Alternative: Check accepted requests as fallback
        final acceptedRequests = await _firestore
            .collection('buddyRequests')
            .where('status', isEqualTo: 'accepted')
            .where('toUserId', isEqualTo: userId)
            .get();

        if (acceptedRequests.docs.isNotEmpty) {
          final request = acceptedRequests.docs.first.data();
          final fromUid = request['fromUserId'] as String;

          print('Found accepted request from $fromUid, syncing...');

          // Update the user's buddyId
          await _firestore.collection('users').doc(userId).update({
            'buddyId': fromUid,
          });
          print(
            'Synced buddy relationship from requests: $userId <-> $fromUid',
          );
        } else {
          print('No accepted requests found for user $userId');
        }
      }
    } catch (e) {
      print('Error syncing buddy relationship: $e');
      rethrow;
    }
  }

  // Remove buddy relationship
  Future<void> removeBuddy(String uid) async {
    final userRef = _firestore.collection('users').doc(uid);

    await _firestore.runTransaction((transaction) async {
      final userDoc = await transaction.get(userRef);
      if (!userDoc.exists) throw Exception('User not found');

      final buddyId = userDoc.data()!['buddyId'];
      if (buddyId != null) {
        // Remove buddyId from both users
        transaction.update(userRef, {'buddyId': null});
        transaction.update(_firestore.collection('users').doc(buddyId), {
          'buddyId': null,
        });
      }
    });
  }

  // Check if users are buddies
  Future<bool> areBuddies(String uid1, String uid2) async {
    // Check direct buddyId relationships
    final user1Doc = await _firestore.collection('users').doc(uid1).get();
    final user2Doc = await _firestore.collection('users').doc(uid2).get();

    if (!user1Doc.exists || !user2Doc.exists) return false;

    final buddyId1 = user1Doc.data()!['buddyId'];
    final buddyId2 = user2Doc.data()!['buddyId'];

    if (buddyId1 == uid2 && buddyId2 == uid1) return true;

    // Check buddy relationships collection
    final sortedIds = [uid1, uid2]..sort();
    final relationshipId = '${sortedIds[0]}_${sortedIds[1]}';

    final relationshipDoc = await _firestore
        .collection('buddyRelationships')
        .doc(relationshipId)
        .get();

    if (relationshipDoc.exists) {
      final data = relationshipDoc.data()!;
      return data['status'] == 'active' &&
          ((data['user1'] == uid1 && data['user2'] == uid2) ||
              (data['user1'] == uid2 && data['user2'] == uid1));
    }

    return false;
  }
}
