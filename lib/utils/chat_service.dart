import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_message_model.dart';
import '../models/user_model.dart';
import 'ai_router.dart';
import 'user_service.dart';
import 'notification_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();
  final NotificationService _notificationService = NotificationService();

  // Get chat ID for two users
  String getChatId(String userId1, String userId2) {
    final sortedIds = [userId1, userId2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }

  // Ensure chat room exists (creates it if it doesn't)
  Future<void> ensureChatRoomExists(String userId1, String userId2) async {
    final chatId = getChatId(userId1, userId2);

    try {
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) {
        // Create chat room if it doesn't exist
        await _firestore.collection('chats').doc(chatId).set({
          'userIds': [userId1, userId2],
          'createdAt': Timestamp.now(),
        });
        print('Chat room created: $chatId');
      }
    } catch (e) {
      print('Error ensuring chat room exists: $e');
      // Don't rethrow - this is a background operation
    }
  }

  // Stream chat messages
  Stream<List<ChatMessageModel>> streamChatMessages(
    String userId1,
    String userId2,
  ) {
    final chatId = getChatId(userId1, userId2);
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatMessageModel.fromFirestore(doc))
              .toList(),
        );
  }

  // Send a message
  Future<void> sendMessage({
    required String chatId,
    required String message,
    required String buddyId,
    required String buddyName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final chatMessage = ChatMessageModel(
      id: '',
      senderId: user.uid,
      text: message,
      timestamp: DateTime.now(),
      type: 'text',
    );

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(chatMessage.toFirestore());

    // Update chat streak only if user hasn't chatted today
    await _updateChatStreakIfNeeded(user.uid);

    // Send notification to buddy
    try {
      await _notificationService.showBuddyMessageNotification(
        buddyName: buddyName,
        message: message,
        chatId: chatId,
      );
    } catch (e) {
      // Notification failed, but don't fail the message send
      print('Failed to send notification: $e');
    }

    // Check and update streak reminder
    await _checkAndUpdateStreakReminder(user.uid);
  }

  // Check if user has sent a message today and update streak reminder
  Future<void> _checkAndUpdateStreakReminder(String userId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Check if user has sent any messages today
      final messagesQuery = await _firestore
          .collectionGroup('messages')
          .where('senderId', isEqualTo: userId)
          .where(
            'timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where('timestamp', isLessThan: Timestamp.fromDate(endOfDay))
          .limit(1)
          .get();

      if (messagesQuery.docs.isNotEmpty) {
        // User has sent a message today, cancel streak reminder
        await _notificationService.cancelNotification(8);
        print('Streak reminder cancelled - user sent message today');
      }
    } catch (e) {
      print('Error checking streak reminder: $e');
    }
  }

  // Generate icebreakers for a buddy
  Future<void> generateIcebreakers(String buddyId) async {
    try {
      // Get user data for personalization
      final users = await _getBuddyUsers(buddyId);
      if (users.length < 2) return;

      // Generate simple icebreakers without external AI
      final icebreakers = [
        "What's the most interesting thing that happened to you today?",
        "If you could have any superpower, what would it be and why?",
        "What's your favorite way to spend a weekend?",
        "What's the best piece of advice you've ever received?",
        "If you could travel anywhere in the world, where would you go?",
        "What's something you're looking forward to this week?",
        "What's your favorite book or movie and why?",
        "What's a skill you'd love to learn?",
        "What's your favorite season and why?",
        "What's something that always makes you smile?",
      ];

      // Shuffle and take 5 random icebreakers
      icebreakers.shuffle();
      final selectedIcebreakers = icebreakers.take(5).toList();

      for (final question in selectedIcebreakers) {
        final icebreaker = IcebreakerModel(
          id: '',
          buddyId: buddyId,
          question: question,
          createdAt: DateTime.now(),
          isUsed: false,
        );

        await _firestore
            .collection('icebreakers')
            .add(icebreaker.toFirestore());
      }
    } catch (e) {
      print('Error generating icebreakers: $e');
    }
  }

  // Stream icebreakers for a buddy
  Stream<List<IcebreakerModel>> streamIcebreakers(String buddyId) {
    return _firestore
        .collection('icebreakers')
        .where('buddyId', isEqualTo: buddyId)
        .where('isUsed', isEqualTo: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => IcebreakerModel.fromFirestore(doc))
              .toList(),
        );
  }

  // Use icebreaker
  Future<void> useIcebreaker(
    String fromUserId,
    String toUserId,
    String icebreakerId,
  ) async {
    try {
      final doc = await _firestore
          .collection('icebreakers')
          .doc(icebreakerId)
          .get();

      if (doc.exists) {
        final icebreaker = IcebreakerModel.fromFirestore(doc);

        // Get buddy info for notification
        final buddy = await _userService.getUser(toUserId);
        final buddyName = buddy?.username ?? 'Your buddy';
        final chatId = getChatId(fromUserId, toUserId);

        // Send as message
        await sendMessage(
          chatId: chatId,
          message: icebreaker.question,
          buddyId: toUserId,
          buddyName: buddyName,
        );
      }
    } catch (e) {
      print('Error using icebreaker: $e');
    }
  }

  // Send faith message
  Future<bool> sendFaith(
    String fromUserId,
    String toUserId,
    String message,
  ) async {
    try {
      // Check if user can send faith (free users: 3 per day)
      final user = await _userService.getUser(fromUserId);
      if (user == null) return false;

      // For now, allow unlimited faith (premium feature will be implemented later)
      final canSend = true; // user.premium || user.faithSentToday < 3;

      if (!canSend) return false;

      // Create faith message
      final faithMessage = FaithMessageModel(
        id: '',
        from: fromUserId,
        to: toUserId,
        message: message,
        timestamp: DateTime.now(),
        isDelivered: false,
      );

      await _firestore
          .collection('faith_messages')
          .add(faithMessage.toFirestore());

      // Update user's faith sent count (for free users)
      if (!user.premium) {
        // This will be implemented when we add faith tracking
        // await _userService.updateUser(fromUserId, {
        //   'faithSentToday': user.faithSentToday + 1,
        // });
      }

      return true;
    } catch (e) {
      print('Error sending faith: $e');
      return false;
    }
  }

  // Send vibe cast
  Future<void> sendVibeCast(
    String userId,
    String mood,
    String emoji,
    String? message,
  ) async {
    try {
      // Update user's mood
      await _userService.updateUser(userId, {'mood': mood});

      // Create vibe cast message
      final vibeCast = VibeCastModel(
        id: '',
        userId: userId,
        mood: mood,
        emoji: emoji,
        message: message ?? '',
        timestamp: DateTime.now(),
      );

      await _firestore.collection('vibe_casts').add(vibeCast.toFirestore());

      // Update chat streak
      await _updateChatStreak(userId);
    } catch (e) {
      print('Error sending vibe cast: $e');
    }
  }

  // Stream faith messages for a user
  Stream<List<FaithMessageModel>> streamFaithMessages(String userId) {
    return _firestore
        .collection('faith_messages')
        .where('to', isEqualTo: userId)
        .where('isDelivered', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => FaithMessageModel.fromFirestore(doc))
              .toList(),
        );
  }

  // Mark faith message as delivered
  Future<void> markFaithDelivered(String messageId) async {
    await _firestore.collection('faith_messages').doc(messageId).update({
      'isDelivered': true,
      'deliveredAt': Timestamp.now(),
    });
  }

  // Stream latest vibe cast
  Stream<VibeCastModel?> streamLatestVibeCast(String userId) {
    return _firestore
        .collection('vibe_casts')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.isNotEmpty
              ? VibeCastModel.fromFirestore(snapshot.docs.first)
              : null,
        );
  }

  // Get AI coach reply (premium feature)
  Future<String?> getAICoachReply(String userId, String message) async {
    try {
      final user = await _userService.getUser(userId);
      if (user == null) return null;

      // Check if user has premium and AI message access
      if (!user.premium) return null;

      // Create personalized prompt
      final prompt = _createAICoachPrompt(user, message);

      // Generate AI response
      final response = await AiRouter.generate(
        task: AiTaskType.feedbackCoach,
        prompt: prompt,
      );

      return response;
    } catch (e) {
      print('Error getting AI coach reply: $e');
      return null;
    }
  }

  // Send AI coach message
  Future<void> sendAICoachMessage(
    String userId,
    String toUserId,
    String message,
  ) async {
    try {
      final aiReply = await getAICoachReply(userId, message);
      if (aiReply != null) {
        // Get buddy info for notification
        final buddy = await _userService.getUser(toUserId);
        final buddyName = buddy?.username ?? 'Your buddy';
        final chatId = getChatId(userId, toUserId);

        await sendMessage(
          chatId: chatId,
          message: aiReply,
          buddyId: toUserId,
          buddyName: buddyName,
        );
      }
    } catch (e) {
      print('Error sending AI coach message: $e');
    }
  }

  // Helper methods
  Future<List<UserModel>> _getBuddyUsers(String buddyId) async {
    final users = <UserModel>[];

    // Get users who have this buddyId
    final query = await _firestore
        .collection('users')
        .where('buddyId', isEqualTo: buddyId)
        .get();

    for (final doc in query.docs) {
      users.add(UserModel.fromFirestore(doc));
    }

    return users;
  }

  String _createIcebreakerPrompt(UserModel user1, UserModel user2) {
    return '''
Generate 3 fun, engaging icebreaker questions for two users with these characteristics:

User 1:
- Level: ${user1.level}
- Goal: ${user1.onboarding.goal}
- Social comfort: ${user1.onboarding.socialComfort}

User 2:
- Level: ${user2.level}
- Goal: ${user2.onboarding.goal}
- Social comfort: ${user2.onboarding.socialComfort}

Make the questions:
1. Light and fun
2. Appropriate for their comfort levels
3. Help them get to know each other better
4. Encourage conversation

Return as a simple list:
1. [Question 1]
2. [Question 2]
3. [Question 3]
''';
  }

  List<String> _parseIcebreakerResponse(String response) {
    final lines = response.split('\n');
    final questions = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty &&
          (trimmed.startsWith('1.') ||
              trimmed.startsWith('2.') ||
              trimmed.startsWith('3.'))) {
        questions.add(trimmed.substring(trimmed.indexOf('.') + 1).trim());
      }
    }

    return questions.isNotEmpty
        ? questions
        : [
            'What\'s the most interesting thing that happened to you today?',
            'If you could have dinner with anyone, who would it be?',
            'What\'s something you\'re looking forward to this week?',
          ];
  }

  String _createAICoachPrompt(UserModel user, String message) {
    return '''
You are an AI coach helping a user with their personal growth journey.

User context:
- Level: ${user.level}
- Goal: ${user.onboarding.goal}
- Mission streak: ${user.streaks['mission']}
- Chat streak: ${user.streaks['chat']}

User message: $message

Provide a supportive, encouraging response that:
1. Acknowledges their progress
2. Offers gentle guidance if needed
3. Motivates them to continue
4. Keeps it concise and friendly

Respond as if you're a supportive friend and coach.
''';
  }

  Future<void> _updateChatStreakIfNeeded(String userId) async {
    try {
      final user = await _userService.getUser(userId);
      if (user == null) return;

      final today = DateTime.now();

      // Get the last chat date from user data
      final lastChatDate = user.streaks['lastChatDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              user.streaks['lastChatDate'] as int,
            )
          : null;

      // Only update streak if user hasn't chatted today
      if (lastChatDate == null ||
          lastChatDate.year != today.year ||
          lastChatDate.month != today.month ||
          lastChatDate.day != today.day) {
        await _userService.updateChatStreak(userId);
      }
    } catch (e) {
      print('Error checking chat streak: $e');
    }
  }

  Future<void> _updateChatStreak(String userId) async {
    try {
      final user = await _userService.getUser(userId);
      if (user == null) return;

      final today = DateTime.now();
      final lastChatDate = user.streaks['chat'] ?? 0;

      // Simple streak logic - increment if user used chat today
      final newChatStreak = lastChatDate + 1;

      await _userService.updateUser(userId, {'streaks.chat': newChatStreak});
    } catch (e) {
      print('Error updating chat streak: $e');
    }
  }
}
