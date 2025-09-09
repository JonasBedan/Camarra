import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../models/ai_chat_model.dart';
import '../models/user_model.dart';
import '../models/mission_model.dart';
import 'ai_router.dart';
import 'user_service.dart';

class AIChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserService _userService = UserService();

  // Send a message to AI therapist and get response
  Future<AIChatModel> sendMessageToAI(String userId, String message) async {
    try {
      print('Sending message to AI therapist: $message');

      // Get user profile for context
      final user = await _userService.getUser(userId);
      if (user == null) throw Exception('User not found');

      // Get recent conversation history for context
      final recentMessages = await _getRecentMessages(userId, limit: 10);

      // Analyze user message for mood and triggers
      final analysis = await _analyzeUserMessage(message, user);

      // Create therapeutic prompt
      final prompt = await _createTherapeuticPrompt(
        message,
        user,
        recentMessages,
        analysis,
      );

      // Generate AI response
      final aiResponse = await AiRouter.generate(
        task: AiTaskType
            .feedbackCoach, // Using feedback coach for therapeutic responses
        prompt: prompt,
      );

      // Parse and save AI response
      final aiMessage = AIChatModel(
        id: '',
        userId: userId,
        message: aiResponse,
        sender: 'ai',
        timestamp: DateTime.now(),
        metadata: {
          'therapeuticFocus': analysis['therapeuticFocus'],
          'responseType': _determineResponseType(analysis),
        },
      );

      // Save AI message
      final aiDocRef = await _firestore
          .collection('users')
          .doc(userId)
          .collection('aiChat')
          .add(aiMessage.toFirestore());

      // Update user communication profile
      await _updateCommunicationProfile(userId, message, analysis);

      // Update chat streak only if user hasn't chatted today
      await _updateChatStreakIfNeeded(userId);

      return aiMessage.copyWith(id: aiDocRef.id);
    } catch (e) {
      print('Error sending message to AI: $e');
      // Return fallback response
      return _createFallbackResponse(userId);
    }
  }

  // Generate mission completion feedback directly in AI chat
  Future<void> generateMissionCompletionFeedback(
    String userId,
    MainMissionModel mission,
    UserModel user,
  ) async {
    try {
      print(
        'Generating mission completion feedback in AI chat: ${mission.title}',
      );

      // Get recent conversation context
      final recentMessages = await _getRecentMessages(userId, limit: 5);

      // Create personalized mission completion prompt
      final prompt = await _createMissionCompletionPrompt(
        mission,
        user,
        recentMessages,
      );

      // Generate AI response
      final aiResponse = await AiRouter.generate(
        task: AiTaskType.feedbackCoach,
        prompt: prompt,
      );

      // Save AI feedback message
      final aiMessage = AIChatModel(
        id: '',
        userId: userId,
        message: aiResponse,
        sender: 'ai',
        timestamp: DateTime.now(),
        metadata: {
          'therapeuticFocus': 'celebration',
          'responseType': 'mission_completion',
          'missionId': mission.id,
          'missionTitle': mission.title,
        },
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('aiChat')
          .add(aiMessage.toFirestore());

      print('Mission completion feedback generated in AI chat');
    } catch (e) {
      print('Error generating mission completion feedback: $e');
      // Create fallback celebration message
      await _createFallbackMissionFeedback(userId, mission);
    }
  }

  // Create mission completion prompt for AI chat
  Future<String> _createMissionCompletionPrompt(
    MainMissionModel mission,
    UserModel user,
    List<AIChatModel> recentMessages,
  ) async {
    final recentContext = recentMessages
        .take(3) // Last 3 messages for context
        .map((msg) => '${msg.sender}: ${msg.message}')
        .join('\n');

    // Get comprehensive user context
    final userProfile = await getUserProfile(user.uid);
    final userStats = await _getUserStats(user.uid);
    final recentMissions = await _getRecentMissions(user.uid);

    return '''
You are Camarra, a friendly and wise octopus therapist who has been supporting this user with social anxiety. They just completed a mission and you want to celebrate their achievement with genuine enthusiasm!

COMPREHENSIVE USER CONTEXT:
- Goal: ${user.onboarding.goal}
- Custom Goal: ${user.onboarding.customGoal ?? 'None'}
- Current Level: ${user.level}
- Total XP: ${user.xp}
- Mission Streak: ${user.streaks['mission'] ?? 0} days
- Total Messages: ${userStats['totalMessages'] ?? 0}
- Common Moods: ${userProfile?.moodHistory.keys.join(', ') ?? 'None'}
- Recent Missions: ${recentMissions.join(', ')}

Completed Mission:
- Title: ${mission.title}
- Description: ${mission.description}
- Difficulty: ${mission.difficulty}
- Book: ${mission.book} - Chapter ${mission.chapter}
- XP Earned: ${mission.xpReward}

Recent conversation context:
$recentContext

Respond as Camarra with:
1. Celebrate their achievement with genuine enthusiasm and warmth
2. Acknowledge the specific challenge they overcame
3. Connect this success to their overall journey and goals
4. Reference their progress, level, or recent achievements when relevant
5. Offer encouragement for their next steps
6. Use your friendly, supportive personality
7. Optional: Use a gentle ocean/octopus metaphor if it fits naturally

Keep it very short and direct (under 50 words). Write like a quick, excited message from a friend - brief but warm. No long explanations, just genuine celebration and encouragement.
''';
  }

  // Create fallback mission feedback
  Future<void> _createFallbackMissionFeedback(
    String userId,
    MainMissionModel mission,
  ) async {
    final fallbackMessages = [
      "🎉 Wow! You completed '${mission.title}' - amazing progress! I'm so proud of you!",
      "🐙 Fantastic work on '${mission.title}'! You're building real strength with each step!",
      "🎊 Congratulations on finishing '${mission.title}'! You're doing incredible work!",
    ];

    final randomIndex =
        DateTime.now().millisecondsSinceEpoch % fallbackMessages.length;
    final message = fallbackMessages[randomIndex];

    final aiMessage = AIChatModel(
      id: '',
      userId: userId,
      message: message,
      sender: 'ai',
      timestamp: DateTime.now(),
      metadata: {
        'therapeuticFocus': 'celebration',
        'responseType': 'mission_completion',
        'missionId': mission.id,
        'missionTitle': mission.title,
      },
    );

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('aiChat')
        .add(aiMessage.toFirestore());
  }

  // Analyze user message for mood, triggers, and therapeutic focus
  Future<Map<String, dynamic>> _analyzeUserMessage(
    String message,
    UserModel user,
  ) async {
    try {
      final analysisPrompt =
          '''
Analyze this user message for therapeutic insights. The user has social anxiety and their goal is: ${user.onboarding.goal}

User message: "$message"

Please analyze and return JSON with:
1. mood: "anxious", "calm", "excited", "frustrated", "hopeful", "overwhelmed", "confident", "uncertain"
2. anxietyTriggers: array of identified triggers (e.g., ["social situations", "uncertainty", "judgment"])
3. therapeuticFocus: "cbt", "exposure", "mindfulness", "coping", "validation", "goal-setting", "crisis"
4. urgency: "low", "medium", "high" (for crisis detection)
5. communicationStyle: "direct", "hesitant", "detailed", "brief", "emotional"

Return only valid JSON.
''';

      final analysisResponse = await AiRouter.generate(
        task: AiTaskType.feedbackCoach,
        prompt: analysisPrompt,
      );

      // Parse analysis response
      try {
        final analysis = json.decode(analysisResponse);
        return {
          'mood': analysis['mood'] ?? 'neutral',
          'anxietyTriggers': analysis['anxietyTriggers'] ?? [],
          'therapeuticFocus': analysis['therapeuticFocus'] ?? 'cbt',
          'urgency': analysis['urgency'] ?? 'low',
          'communicationStyle': analysis['communicationStyle'] ?? 'balanced',
        };
      } catch (e) {
        print('Failed to parse analysis: $e');
        return _getDefaultAnalysis();
      }
    } catch (e) {
      print('Error analyzing message: $e');
      return _getDefaultAnalysis();
    }
  }

  // Create therapeutic prompt for AI response
  Future<String> _createTherapeuticPrompt(
    String userMessage,
    UserModel user,
    List<AIChatModel> recentMessages,
    Map<String, dynamic> analysis,
  ) async {
    final recentContext = recentMessages
        .take(6) // Last 6 messages for context
        .map((msg) => '${msg.sender}: ${msg.message}')
        .join('\n');

    // Get comprehensive user context
    final userProfile = await getUserProfile(user.uid);
    final userStats = await _getUserStats(user.uid);
    final recentMissions = await _getRecentMissions(user.uid);
    final recentReflections = await _getRecentReflections(user.uid);

    return '''
You are Camarra, a friendly and wise octopus therapist who specializes in helping people with social anxiety. You have a warm, encouraging personality and often use gentle humor and ocean-themed metaphors.

COMPREHENSIVE USER CONTEXT:
- Goal: ${user.onboarding.goal}
- Custom Goal: ${user.onboarding.customGoal ?? 'None'}
- Mood: ${user.onboarding.mood}
- Social Comfort: ${user.onboarding.socialComfort}
- Talk Frequency: ${user.onboarding.talkFrequency}
- Current Level: ${user.level}
- Total XP: ${user.xp}
- Mission Streak: ${user.streaks['mission'] ?? 0} days
- Chat Streak: ${user.streaks['chat'] ?? 0} days
- Daily Mission Completed: ${user.dailyMissionCompleted}
- Premium: ${user.premium}
- Buddy ID: ${user.buddyId ?? 'None'}

USER PROGRESS:
- Total Messages: ${userStats['totalMessages'] ?? 0}
- Common Moods: ${userProfile?.moodHistory.keys.join(', ') ?? 'None'}
- Common Triggers: ${userProfile?.commonTriggers.join(', ') ?? 'None'}
- Communication Style: ${userProfile?.communicationStyle ?? 'Unknown'}
- Recent Missions: ${recentMissions.join(', ')}
- Recent Reflections: ${recentReflections.join(', ')}

Recent conversation context:
$recentContext

Current user message: "$userMessage"

Analysis:
- Mood: ${analysis['mood']}
- Triggers: ${analysis['anxietyTriggers'].join(', ')}
- Focus: ${analysis['therapeuticFocus']}
- Urgency: ${analysis['urgency']}

Respond as Camarra with:
1. Warm, friendly tone with gentle encouragement
2. Acknowledge their feelings and validate their experience
3. Use appropriate therapeutic techniques based on the focus area
4. Offer practical coping strategies or insights
5. Reference their specific goals, progress, and patterns when relevant
6. Use occasional ocean/octopus metaphors when appropriate (but don't overdo it)
7. Maintain your friendly, supportive personality

Keep response concise (under 100 words) and conversational. Write in a flowing, natural style without paragraph breaks - like you're chatting with a friend. Make it feel warm and comforting.
''';
  }

  // Get recent conversation messages
  Future<List<AIChatModel>> _getRecentMessages(
    String userId, {
    int limit = 10,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('aiChat')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => AIChatModel.fromFirestore(doc))
          .toList()
          .reversed
          .toList(); // Reverse to get chronological order
    } catch (e) {
      print('Error getting recent messages: $e');
      return [];
    }
  }

  // Update user communication profile
  Future<void> _updateCommunicationProfile(
    String userId,
    String message,
    Map<String, dynamic> analysis,
  ) async {
    try {
      final profileRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('communicationProfile')
          .doc('profile');

      await _firestore.runTransaction((transaction) async {
        final profileDoc = await transaction.get(profileRef);

        Map<String, int> moodHistory = {};
        List<String> commonTriggers = [];
        List<String> copingStrategies = [];
        Map<String, dynamic> progressMetrics = {};

        if (profileDoc.exists) {
          final data = profileDoc.data()!;
          moodHistory = Map<String, int>.from(data['moodHistory'] ?? {});
          commonTriggers = List<String>.from(data['commonTriggers'] ?? []);
          copingStrategies = List<String>.from(data['copingStrategies'] ?? []);
          progressMetrics = Map<String, dynamic>.from(
            data['progressMetrics'] ?? {},
          );
        }

        // Update mood history
        final mood = analysis['mood'];
        moodHistory[mood] = (moodHistory[mood] ?? 0) + 1;

        // Update triggers
        final triggers = analysis['anxietyTriggers'] as List<String>;
        for (final trigger in triggers) {
          if (!commonTriggers.contains(trigger)) {
            commonTriggers.add(trigger);
          }
        }

        // Update progress metrics
        progressMetrics['totalMessages'] =
            (progressMetrics['totalMessages'] ?? 0) + 1;
        progressMetrics['lastActive'] = DateTime.now().toIso8601String();

        final updatedProfile = {
          'moodHistory': moodHistory,
          'commonTriggers': commonTriggers,
          'communicationStyle': analysis['communicationStyle'],
          'copingStrategies': copingStrategies,
          'progressMetrics': progressMetrics,
          'lastUpdated': Timestamp.now(),
        };

        transaction.set(profileRef, updatedProfile);
      });
    } catch (e) {
      print('Error updating communication profile: $e');
    }
  }

  // Add user message to AI chat
  Future<void> addUserMessage(String userId, String message) async {
    try {
      final userMessage = AIChatModel(
        id: '',
        userId: userId,
        message: message,
        sender: 'user',
        timestamp: DateTime.now(),
        metadata: {'messageType': 'user_input'},
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('aiChat')
          .add(userMessage.toFirestore());

      print('User message added to AI chat: $message');
    } catch (e) {
      print('Error adding user message: $e');
      rethrow;
    }
  }

  // Stream AI chat messages
  Stream<List<AIChatModel>> streamAIChat(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('aiChat')
        .orderBy('timestamp')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AIChatModel.fromFirestore(doc))
              .toList(),
        );
  }

  // Get user communication profile
  Future<UserCommunicationProfile?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('communicationProfile')
          .doc('profile')
          .get();

      if (doc.exists) {
        return UserCommunicationProfile.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  // Get user stats from communication profile
  Future<Map<String, dynamic>> _getUserStats(String userId) async {
    try {
      final profile = await getUserProfile(userId);
      if (profile != null) {
        return profile.progressMetrics;
      }
      return {};
    } catch (e) {
      print('Error getting user stats: $e');
      return {};
    }
  }

  // Get recent completed missions
  Future<List<String>> _getRecentMissions(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('mainMissions')
          .where('completed', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      return snapshot.docs
          .map((doc) => doc.data()['title'] as String? ?? 'Unknown Mission')
          .toList();
    } catch (e) {
      print('Error getting recent missions: $e');
      return [];
    }
  }

  // Get recent reflections
  Future<List<String>> _getRecentReflections(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('reflections')
          .orderBy('timestamp', descending: true)
          .limit(3)
          .get();

      return snapshot.docs
          .map((doc) => doc.data()['title'] as String? ?? 'Unknown Reflection')
          .toList();
    } catch (e) {
      print('Error getting recent reflections: $e');
      return [];
    }
  }

  // Helper methods
  Map<String, dynamic> _getDefaultAnalysis() {
    return {
      'mood': 'neutral',
      'anxietyTriggers': [],
      'therapeuticFocus': 'cbt',
      'urgency': 'low',
      'communicationStyle': 'balanced',
    };
  }

  String _determineResponseType(Map<String, dynamic> analysis) {
    final urgency = analysis['urgency'];
    final focus = analysis['therapeuticFocus'];

    if (urgency == 'high') return 'crisis_support';
    if (focus == 'cbt') return 'cognitive_restructuring';
    if (focus == 'exposure') return 'gradual_exposure';
    if (focus == 'mindfulness') return 'mindfulness_technique';
    return 'general_support';
  }

  AIChatModel _createFallbackResponse(String userId) {
    return AIChatModel(
      id: '',
      userId: userId,
      message:
          "Hi there! I'm here to support you on your journey. How are you feeling today? Remember, it's okay to take things one step at a time.",
      sender: 'ai',
      timestamp: DateTime.now(),
      metadata: {
        'therapeuticFocus': 'validation',
        'responseType': 'general_support',
      },
    );
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
}
