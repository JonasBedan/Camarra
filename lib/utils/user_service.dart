import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/xp_log_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create a new user document
  Future<void> createUser(
    String email,
    String username, {
    bool? darkModeEnabled,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Normalize username for consistent storage
    final normalizedUsername = username.trim().toLowerCase();

    final userData = UserModel(
      uid: user.uid,
      email: email,
      username: normalizedUsername,
      createdAt: DateTime.now(),
      level: 1,
      xp: 0,
      premium: false,
      dailyMissionCompleted: false,
      streaks: {'mission': 0, 'chat': 0},
      mood: null,
      buddyId: null,
      onboarding: OnboardingData(
        goal: '',
        customGoal: null,
        mood: '',
        mode: '',
        socialComfort: '',
        talkFrequency: '',
      ),
      settings: UserSettings(darkModeEnabled: darkModeEnabled ?? false),
    );

    // Only create user document here. Username doc is created in reserveUsername
    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(userData.toFirestore());
  }

  // Get user data
  Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  // Update onboarding data
  Future<void> updateOnboarding(String uid, OnboardingData onboarding) async {
    await _firestore.collection('users').doc(uid).update({
      'onboarding': onboarding.toMap(),
    });
  }

  // Update user settings
  Future<void> updateSettings(String uid, UserSettings settings) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'settings': settings.toMap(),
      });
    } catch (e) {
      print('Error updating settings: $e');
      rethrow;
    }
  }

  // Update specific setting
  Future<void> updateSetting(
    String uid,
    String settingKey,
    dynamic value,
  ) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'settings.$settingKey': value,
      });
    } catch (e) {
      print('Error updating setting $settingKey: $e');
      rethrow;
    }
  }

  // Update multiple settings at once
  Future<void> updateMultipleSettings(
    String uid,
    Map<String, dynamic> settings,
  ) async {
    try {
      final settingsMap = <String, dynamic>{};
      for (final entry in settings.entries) {
        settingsMap['settings.${entry.key}'] = entry.value;
      }
      await _firestore.collection('users').doc(uid).update(settingsMap);
    } catch (e) {
      print('Error updating multiple settings: $e');
      rethrow;
    }
  }

  // Get user settings
  Future<UserSettings?> getUserSettings(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final settingsData = data['settings'] as Map<String, dynamic>? ?? {};
        return UserSettings.fromMap(settingsData);
      }
      return null;
    } catch (e) {
      print('Error getting user settings: $e');
      return null;
    }
  }

  // Export user data
  Future<Map<String, dynamic>> exportUserData(String uid) async {
    try {
      final user = await getUser(uid);
      if (user == null) throw Exception('User not found');

      // Get XP logs
      final xpLogsSnapshot = await _firestore
          .collection('xp_logs')
          .where('uid', isEqualTo: uid)
          .get();
      final xpLogs = xpLogsSnapshot.docs.map((doc) => doc.data()).toList();

      // Get main missions
      final missionsSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('mainMissions')
          .get();
      final missions = missionsSnapshot.docs.map((doc) => doc.data()).toList();

      // Get reflections
      final reflectionsSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('reflections')
          .get();
      final reflections = reflectionsSnapshot.docs
          .map((doc) => doc.data())
          .toList();

      // Get AI chat messages
      final aiChatSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('aiChat')
          .get();
      final aiChat = aiChatSnapshot.docs.map((doc) => doc.data()).toList();

      // Get communication profile
      final profileSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('communicationProfile')
          .doc('profile')
          .get();
      final profile = profileSnapshot.exists ? profileSnapshot.data() : null;

      return {
        'user': user.toFirestore(),
        'xpLogs': xpLogs,
        'missions': missions,
        'reflections': reflections,
        'aiChat': aiChat,
        'communicationProfile': profile,
        'exportedAt': Timestamp.now(),
      };
    } catch (e) {
      print('Error exporting user data: $e');
      rethrow;
    }
  }

  // Delete user account and all data
  Future<void> deleteUserAccount(String uid) async {
    try {
      // Delete user document and all subcollections
      await _firestore.collection('users').doc(uid).delete();

      // Delete XP logs
      final xpLogsSnapshot = await _firestore
          .collection('xp_logs')
          .where('uid', isEqualTo: uid)
          .get();
      for (final doc in xpLogsSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete buddy requests
      final buddyRequestsSnapshot = await _firestore
          .collection('buddyRequests')
          .where('fromUserId', isEqualTo: uid)
          .get();
      for (final doc in buddyRequestsSnapshot.docs) {
        await doc.reference.delete();
      }

      final buddyRequestsToSnapshot = await _firestore
          .collection('buddyRequests')
          .where('toUserId', isEqualTo: uid)
          .get();
      for (final doc in buddyRequestsToSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete chat messages
      final chatsSnapshot = await _firestore
          .collection('chats')
          .where('userIds', arrayContains: uid)
          .get();
      for (final chatDoc in chatsSnapshot.docs) {
        final messagesSnapshot = await chatDoc.reference
            .collection('messages')
            .get();
        for (final messageDoc in messagesSnapshot.docs) {
          await messageDoc.reference.delete();
        }
        await chatDoc.reference.delete();
      }

      // Delete Firebase Auth user
      final user = _auth.currentUser;
      if (user != null && user.uid == uid) {
        await user.delete();
      }
    } catch (e) {
      print('Error deleting user account: $e');
      rethrow;
    }
  }

  // Change user password
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Re-authenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // Change password
      await user.updatePassword(newPassword);

      // Update last password change timestamp
      await updateSetting(user.uid, 'lastPasswordChange', Timestamp.now());
    } catch (e) {
      print('Error changing password: $e');
      rethrow;
    }
  }

  // Add XP to user
  Future<void> addXP(String uid, int xpValue, String reason) async {
    try {
      // Get current user data
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) throw Exception('User not found');

      final currentXP = userDoc.data()!['xp'] ?? 0;
      final newXP = currentXP + xpValue;
      final newLevel = (newXP ~/ 100) + 1;

      // Update user XP and level
      await _firestore.collection('users').doc(uid).update({
        'xp': newXP,
        'level': newLevel,
      });

      // Log XP gain (separate operation to avoid transaction issues)
      try {
        final xpLog = XPLogModel(
          id: '', // Will be set by Firestore
          uid: uid,
          value: xpValue,
          reason: reason,
          timestamp: DateTime.now(),
        );
        await _firestore.collection('xp_logs').add(xpLog.toFirestore());
      } catch (e) {
        print('Warning: Could not log XP gain: $e');
        // Don't fail the whole operation if XP logging fails
      }
    } catch (e) {
      print('Error adding XP: $e');
      rethrow;
    }
  }

  // Mark daily mission as completed
  Future<void> markDailyMissionCompleted(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'dailyMissionCompleted': true,
    });
  }

  // Reset daily mission completion (call this daily)
  Future<void> resetDailyMission(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'dailyMissionCompleted': false,
    });
  }

  // Update buddy ID
  Future<void> updateBuddyId(String uid, String? buddyId) async {
    await _firestore.collection('users').doc(uid).update({'buddyId': buddyId});
  }

  // Get user's XP logs
  Stream<List<XPLogModel>> getUserXPLogs(String uid) {
    return _firestore
        .collection('xp_logs')
        .where('uid', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => XPLogModel.fromFirestore(doc))
              .toList(),
        );
  }

  // Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Stream user data
  Stream<UserModel?> streamUser(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }

  // Search users by email (partial match)
  Future<List<UserModel>> getUserByEmail(String email) async {
    try {
      final query = _firestore
          .collection('users')
          .where('email', isGreaterThanOrEqualTo: email)
          .where('email', isLessThan: '$email\uf8ff')
          .limit(10);

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  // Check if username already exists using `usernames` collection
  Future<bool> isUsernameTaken(String username) async {
    try {
      print('Checking if username "$username" is taken...');

      // Normalize username for consistent checking
      final normalizedUsername = username.trim().toLowerCase();

      final doc = await _firestore
          .collection('usernames')
          .doc(normalizedUsername)
          .get();
      final isTaken = doc.exists;

      print(
        'Username "$normalizedUsername" is ${isTaken ? "taken" : "available"}',
      );
      return isTaken;
    } catch (e) {
      print('Error checking username: $e');
      return false;
    }
  }

  // Checks users collection (requires auth). Useful after auth during registration to
  // prevent duplicates if legacy users don't have an entry in `usernames`.
  Future<bool> doesUserExistWithUsername(String username) async {
    final normalized = username.trim().toLowerCase();
    final snapshot = await _firestore
        .collection('users')
        .where('username', isEqualTo: normalized)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  // Reserve username atomically; used during registration
  Future<void> reserveUsername(String username, String uid) async {
    final normalized = username.trim().toLowerCase();
    final usernameRef = _firestore.collection('usernames').doc(normalized);
    await _firestore.runTransaction((txn) async {
      final existing = await txn.get(usernameRef);
      if (existing.exists) {
        throw Exception('Username "$normalized" is already taken');
      }
      txn.set(usernameRef, {
        'uid': uid,
        'username': normalized,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // Get all users (for debugging)
  Future<List<UserModel>> getAllUsers() async {
    try {
      final query = _firestore.collection('users').limit(20);
      final snapshot = await query.get();
      final users = snapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();
      print('Total users in database: ${users.length}');
      print('Usernames: ${users.map((u) => u.username).toList()}');
      return users;
    } catch (e) {
      print('Error getting all users: $e');
      return [];
    }
  }

  // Search users by username (partial match)
  Future<List<UserModel>> getUserByUsername(String username) async {
    try {
      // Simple case-insensitive search with better performance
      final lowerUsername = username.toLowerCase();
      final query = _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: lowerUsername)
          .where('username', isLessThan: '$lowerUsername\uf8ff')
          .limit(20); // Increased limit for better results

      final snapshot = await query.get();
      final results = snapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();

      // Filter results to ensure they contain the search term (case-insensitive)
      final filteredResults = results
          .where((user) => user.username.toLowerCase().contains(lowerUsername))
          .take(15) // Increased limit for better UX
          .toList();

      return filteredResults;
    } catch (e) {
      print('Error searching users by username: $e');
      return [];
    }
  }

  // Prefetch a chunk of users ordered by username for instant local filtering
  Future<List<UserModel>> getUsersAlphabetical({int limit = 200}) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .orderBy('username')
          .limit(limit)
          .get();
      return snapshot.docs.map((d) => UserModel.fromFirestore(d)).toList();
    } catch (e) {
      print('Error preloading users: $e');
      return [];
    }
  }

  // Update user data
  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(userId).update(data);
    } catch (e) {
      print('Error updating user: $e');
      rethrow;
    }
  }

  // Update mission streak
  Future<void> updateMissionStreak(String userId) async {
    try {
      final user = await getUser(userId);
      if (user == null) return;

      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));

      // Get the last mission completion date from user data
      final lastMissionDate = user.streaks['lastMissionDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              user.streaks['lastMissionDate'] as int,
            )
          : null;

      int currentStreak = (user.streaks['mission'] as int?) ?? 0;
      int longestStreak = (user.streaks['longestMission'] as int?) ?? 0;

      // Check if user completed a mission today
      if (lastMissionDate == null ||
          lastMissionDate.year != today.year ||
          lastMissionDate.month != today.month ||
          lastMissionDate.day != today.day) {
        // Check if it's consecutive (yesterday)
        if (lastMissionDate != null &&
            lastMissionDate.year == yesterday.year &&
            lastMissionDate.month == yesterday.month &&
            lastMissionDate.day == yesterday.day) {
          // Consecutive day - increment streak
          currentStreak++;
        } else {
          // Not consecutive - reset streak to 1
          currentStreak = 1;
        }

        // Update longest streak if current streak is longer
        if (currentStreak > longestStreak) {
          longestStreak = currentStreak;
        }

        // Update user streaks
        await updateUser(userId, {
          'streaks.mission': currentStreak,
          'streaks.longestMission': longestStreak,
          'streaks.lastMissionDate': today.millisecondsSinceEpoch,
        });
      }
    } catch (e) {
      print('Error updating mission streak: $e');
    }
  }

  // Update chat streak
  Future<void> updateChatStreak(String userId) async {
    try {
      final user = await getUser(userId);
      if (user == null) return;

      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));

      // Get the last chat date from user data
      final lastChatDate = user.streaks['lastChatDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              user.streaks['lastChatDate'] as int,
            )
          : null;

      int currentStreak = (user.streaks['chat'] as int?) ?? 0;
      int longestStreak = (user.streaks['longestChat'] as int?) ?? 0;

      // Check if user chatted today
      if (lastChatDate == null ||
          lastChatDate.year != today.year ||
          lastChatDate.month != today.month ||
          lastChatDate.day != today.day) {
        // Check if it's consecutive (yesterday)
        if (lastChatDate != null &&
            lastChatDate.year == yesterday.year &&
            lastChatDate.month == yesterday.month &&
            lastChatDate.day == yesterday.day) {
          // Consecutive day - increment streak
          currentStreak++;
        } else {
          // Not consecutive - reset streak to 1
          currentStreak = 1;
        }

        // Update longest streak if current streak is longer
        if (currentStreak > longestStreak) {
          longestStreak = currentStreak;
        }

        // Update user streaks
        await updateUser(userId, {
          'streaks.chat': currentStreak,
          'streaks.longestChat': longestStreak,
          'streaks.lastChatDate': today.millisecondsSinceEpoch,
        });
      }
    } catch (e) {
      print('Error updating chat streak: $e');
    }
  }

  // Create a test completed mission for debugging
  Future<void> createCompletedMission(
    String userId,
    DateTime completedAt,
  ) async {
    try {
      final missionId = 'test_mission_${DateTime.now().millisecondsSinceEpoch}';
      final testMission = {
        'id': missionId,
        'userId': userId,
        'content': 'Test completed mission for reset testing',
        'difficulty': 'easy',
        'xpReward': 10,
        'isCompleted': true,
        'completedAt': completedAt,
        'createdAt': completedAt.subtract(const Duration(hours: 1)),
      };

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_missions')
          .doc(missionId)
          .set(testMission);

      print('Created test completed mission for user $userId');
    } catch (e) {
      print('Error creating test completed mission: $e');
      rethrow;
    }
  }
}
