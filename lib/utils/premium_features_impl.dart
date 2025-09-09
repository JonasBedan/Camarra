import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/mission_model.dart';
import '../models/mood_model.dart';
import '../models/chat_message_model.dart';
import 'premium_service.dart';
import 'ai_router.dart';
import 'user_service.dart';

class PremiumFeaturesImpl {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PremiumService _premiumService = PremiumService();
  final UserService _userService = UserService();

  // Enhanced AI Generation for Premium Users
  Future<String> generateEnhancedMission({
    required String userId,
    required String missionType,
    required Map<String, dynamic> userContext,
  }) async {
    final canAccess = await _premiumService.canAccessEnhancedAI(userId);
    if (!canAccess) {
      return _generateBasicMission(missionType, userContext);
    }

    // Enhanced AI prompt for premium users - SHORT AND DIRECT
    final enhancedPrompt =
        '''
You are a social confidence coach. Generate a SHORT, DIRECT daily mission for a premium user.

User Context: $userContext
Mission Type: $missionType

Requirements:
- Keep it under 2 sentences
- Be specific and actionable
- Focus on one clear social interaction
- Make it challenging but achievable
- No long explanations or steps

Example format: "Ask a coworker about their weekend plans during lunch break."

Generate a short, direct mission:
''';

    try {
      final response = await AiRouter.generate(
        task: AiTaskType.mainMission,
        prompt: enhancedPrompt,
      );

      // Ensure the response is short and direct
      String cleanResponse = response.trim();
      if (cleanResponse.startsWith('"') && cleanResponse.endsWith('"')) {
        cleanResponse = cleanResponse.substring(1, cleanResponse.length - 1);
      }
      if (cleanResponse.startsWith("'") && cleanResponse.endsWith("'")) {
        cleanResponse = cleanResponse.substring(1, cleanResponse.length - 1);
      }
      cleanResponse = cleanResponse.trim();

      // If response is too long, truncate it
      if (cleanResponse.length > 200) {
        cleanResponse = cleanResponse.substring(0, 200).trim();
        if (cleanResponse.endsWith(',')) {
          cleanResponse = cleanResponse.substring(0, cleanResponse.length - 1);
        }
      }

      return cleanResponse;
    } catch (e) {
      // Error handling for enhanced mission generation
      return _generateBasicMission(missionType, userContext);
    }
  }

  Future<String> _generateBasicMission(
    String missionType,
    Map<String, dynamic> userContext,
  ) async {
    final basicPrompt =
        '''
Generate a SHORT, DIRECT daily mission for social confidence.

Mission Type: $missionType
User Context: $userContext

Requirements:
- Keep it under 2 sentences
- Be specific and actionable
- Focus on one clear social interaction

Example: "Smile and say hello to 3 people today."

Generate a short, direct mission:
''';

    try {
      final response = await AiRouter.generate(
        task: AiTaskType.mainMission,
        prompt: basicPrompt,
      );

      // Ensure the response is short and direct
      String cleanResponse = response.trim();
      if (cleanResponse.startsWith('"') && cleanResponse.endsWith('"')) {
        cleanResponse = cleanResponse.substring(1, cleanResponse.length - 1);
      }
      if (cleanResponse.startsWith("'") && cleanResponse.endsWith("'")) {
        cleanResponse = cleanResponse.substring(1, cleanResponse.length - 1);
      }
      cleanResponse = cleanResponse.trim();

      // If response is too long, truncate it
      if (cleanResponse.length > 200) {
        cleanResponse = cleanResponse.substring(0, 200).trim();
        if (cleanResponse.endsWith(',')) {
          cleanResponse = cleanResponse.substring(0, cleanResponse.length - 1);
        }
      }

      return cleanResponse;
    } catch (e) {
      return 'Have a conversation with a stranger today.';
    }
  }

  // Advanced Progress Analytics
  Future<Map<String, dynamic>> getAdvancedAnalytics(String userId) async {
    final canAccess = await _premiumService.canAccessAdvancedAnalytics(userId);
    if (!canAccess) {
      return {'error': 'Premium feature required'};
    }

    try {
      // Get user's completed daily missions
      final missionsQuery = await _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_missions')
          .where('isCompleted', isEqualTo: true)
          .orderBy('completedAt', descending: true)
          .limit(100)
          .get();

      final missions = missionsQuery.docs.map((doc) => doc.data()).toList();

      // Get mood entries
      final moodQuery = await _firestore
          .collection('users')
          .doc(userId)
          .collection('mood_entries')
          .orderBy('timestamp', descending: true)
          .limit(30)
          .get();

      final moodEntries = moodQuery.docs
          .map((doc) => MoodEntry.fromFirestore(doc))
          .toList();

      // Calculate advanced analytics
      final analytics = {
        'missionCompletionRate': _calculateMissionCompletionRate(missions),
        'averageMoodScore': _calculateAverageMoodScore(moodEntries),
        'progressTrend': _calculateProgressTrend(missions),
        'streakAnalysis': _calculateStreakAnalysis(missions),
        'difficultyProgression': _calculateDifficultyProgression(missions),
        'weeklyPerformance': _calculateWeeklyPerformance(missions),
        'monthlyComparison': _calculateMonthlyComparison(missions),
        'anxietyReductionMetrics': _calculateAnxietyReduction(moodEntries),
      };

      return analytics;
    } catch (e) {
      print('Error loading analytics: $e');
      // Error handling for analytics generation
      return {'error': 'Failed to load analytics'};
    }
  }

  double _calculateMissionCompletionRate(List<Map<String, dynamic>> missions) {
    if (missions.isEmpty) return 0.0;
    // Since these are completed missions, all are completed
    return 100.0;
  }

  double _calculateAverageMoodScore(List<MoodEntry> moodEntries) {
    if (moodEntries.isEmpty) return 5.0;
    final total = moodEntries.fold(
      0,
      (total, entry) => total + entry.moodLevel,
    );
    return total / moodEntries.length;
  }

  Map<String, dynamic> _calculateProgressTrend(
    List<Map<String, dynamic>> missions,
  ) {
    // Calculate trend over time
    final recentMissions = missions.take(10).toList();
    final olderMissions = missions.skip(10).take(10).toList();

    if (recentMissions.isEmpty || olderMissions.isEmpty) {
      return {'trend': 'insufficient_data'};
    }

    // Use difficulty as a proxy for progress
    final recentAvg =
        recentMissions.fold(0.0, (total, m) {
          final difficulty = m['difficulty'] ?? 'medium';
          return total + _getDifficultyValue(difficulty);
        }) /
        recentMissions.length;

    final olderAvg =
        olderMissions.fold(0.0, (total, m) {
          final difficulty = m['difficulty'] ?? 'medium';
          return total + _getDifficultyValue(difficulty);
        }) /
        olderMissions.length;

    final improvement = olderAvg > 0
        ? ((recentAvg - olderAvg) / olderAvg) * 100
        : 0;

    return {
      'trend': improvement > 0 ? 'improving' : 'declining',
      'improvement_percentage': improvement,
      'recent_average_difficulty': recentAvg,
      'older_average_difficulty': olderAvg,
    };
  }

  Map<String, dynamic> _calculateStreakAnalysis(
    List<Map<String, dynamic>> missions,
  ) {
    int currentStreak = 0;
    int longestStreak = 0;
    int tempStreak = 0;

    final sortedMissions = missions.toList()
      ..sort((a, b) {
        final aDate = (a['completedAt'] as Timestamp).toDate();
        final bDate = (b['completedAt'] as Timestamp).toDate();
        return aDate.compareTo(bDate);
      });

    for (int i = 0; i < sortedMissions.length; i++) {
      final currentDate = (sortedMissions[i]['completedAt'] as Timestamp)
          .toDate();

      if (i == 0 ||
          _isConsecutiveDay(
            (sortedMissions[i - 1]['completedAt'] as Timestamp).toDate(),
            currentDate,
          )) {
        tempStreak++;
        if (i == sortedMissions.length - 1) {
          currentStreak = tempStreak;
        }
      } else {
        if (tempStreak > longestStreak) {
          longestStreak = tempStreak;
        }
        tempStreak = 1;
      }
    }

    return {
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'total_completed': sortedMissions.length,
    };
  }

  bool _isConsecutiveDay(DateTime date1, DateTime date2) {
    final difference = date2.difference(date1).inDays;
    return difference == 1;
  }

  Map<String, dynamic> _calculateDifficultyProgression(
    List<Map<String, dynamic>> missions,
  ) {
    if (missions.length < 5) {
      return {'progression': 'insufficient_data'};
    }

    final recentMissions = missions.take(5).toList();
    final olderMissions = missions.skip(5).take(5).toList();

    // Convert difficulty strings to numeric values
    final recentAvgDifficulty =
        recentMissions.fold(0.0, (total, m) {
          final difficulty = m['difficulty'] ?? 'medium';
          final difficultyValue = _getDifficultyValue(difficulty);
          return total + difficultyValue;
        }) /
        recentMissions.length;

    final olderAvgDifficulty =
        olderMissions.fold(0.0, (total, m) {
          final difficulty = m['difficulty'] ?? 'medium';
          final difficultyValue = _getDifficultyValue(difficulty);
          return total + difficultyValue;
        }) /
        olderMissions.length;

    return {
      'progression': recentAvgDifficulty > olderAvgDifficulty
          ? 'increasing'
          : 'stable',
      'current_difficulty': recentAvgDifficulty,
      'previous_difficulty': olderAvgDifficulty,
    };
  }

  double _getDifficultyValue(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return 1.0;
      case 'medium':
        return 2.0;
      case 'hard':
        return 3.0;
      default:
        return 2.0;
    }
  }

  Map<String, dynamic> _calculateWeeklyPerformance(
    List<Map<String, dynamic>> missions,
  ) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final lastWeekStart = weekStart.subtract(const Duration(days: 7));

    final thisWeekMissions = missions.where((m) {
      final completedAt = (m['completedAt'] as Timestamp).toDate();
      return completedAt.isAfter(weekStart);
    }).toList();

    final lastWeekMissions = missions.where((m) {
      final completedAt = (m['completedAt'] as Timestamp).toDate();
      return completedAt.isAfter(lastWeekStart) &&
          completedAt.isBefore(weekStart);
    }).toList();

    return {
      'this_week_count': thisWeekMissions.length,
      'last_week_count': lastWeekMissions.length,
      'this_week_difficulty': thisWeekMissions.fold(0.0, (total, m) {
        final difficulty = m['difficulty'] ?? 'medium';
        return total + _getDifficultyValue(difficulty);
      }),
      'last_week_difficulty': lastWeekMissions.fold(0.0, (total, m) {
        final difficulty = m['difficulty'] ?? 'medium';
        return total + _getDifficultyValue(difficulty);
      }),
    };
  }

  Map<String, dynamic> _calculateMonthlyComparison(
    List<Map<String, dynamic>> missions,
  ) {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    final lastMonth = DateTime(now.year, now.month - 1);

    final thisMonthMissions = missions.where((m) {
      final completedAt = (m['completedAt'] as Timestamp).toDate();
      return completedAt.isAfter(thisMonth);
    }).toList();

    final lastMonthMissions = missions.where((m) {
      final completedAt = (m['completedAt'] as Timestamp).toDate();
      return completedAt.isAfter(lastMonth) && completedAt.isBefore(thisMonth);
    }).toList();

    return {
      'this_month_count': thisMonthMissions.length,
      'last_month_count': lastMonthMissions.length,
      'this_month_difficulty': thisMonthMissions.fold(0.0, (total, m) {
        final difficulty = m['difficulty'] ?? 'medium';
        return total + _getDifficultyValue(difficulty);
      }),
      'last_month_difficulty': lastMonthMissions.fold(0.0, (total, m) {
        final difficulty = m['difficulty'] ?? 'medium';
        return total + _getDifficultyValue(difficulty);
      }),
    };
  }

  Map<String, dynamic> _calculateAnxietyReduction(List<MoodEntry> moodEntries) {
    if (moodEntries.length < 7) {
      return {'reduction': 'insufficient_data'};
    }

    final recentMoods = moodEntries.take(7).toList();
    final olderMoods = moodEntries.skip(7).take(7).toList();

    if (olderMoods.isEmpty) {
      return {'reduction': 'insufficient_data'};
    }

    final recentAvg =
        recentMoods.fold(0.0, (total, m) => total + m.moodLevel) /
        recentMoods.length;
    final olderAvg =
        olderMoods.fold(0.0, (total, m) => total + m.moodLevel) /
        olderMoods.length;

    final improvement = recentAvg - olderAvg;

    return {
      'reduction': improvement > 0 ? 'improving' : 'stable',
      'improvement_score': improvement,
      'recent_average_mood': recentAvg,
      'older_average_mood': olderAvg,
    };
  }

  // Buddy+ Insights
  Future<Map<String, dynamic>> getBuddyInsights(
    String userId,
    String buddyId,
  ) async {
    final canAccess = await _premiumService.canAccessBuddyInsights(userId);
    if (!canAccess) {
      return {'error': 'Premium feature required'};
    }

    try {
      // Get chat messages between users
      final chatId = _getChatId(userId, buddyId);
      final messagesQuery = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      final messages = messagesQuery.docs
          .map((doc) => ChatMessageModel.fromFirestore(doc))
          .toList();

      // Get buddy's mood entries (if they allow sharing)
      final buddyMoodQuery = await _firestore
          .collection('users')
          .doc(buddyId)
          .collection('mood_entries')
          .orderBy('timestamp', descending: true)
          .limit(30)
          .get();

      final buddyMoods = buddyMoodQuery.docs
          .map((doc) => MoodEntry.fromFirestore(doc))
          .toList();

      // Calculate buddy insights
      final insights = {
        'response_time_avg': _calculateAverageResponseTime(messages, userId),
        'message_frequency': _calculateMessageFrequency(messages),
        'conversation_quality': _analyzeConversationQuality(messages),
        'buddy_mood_trend': _analyzeBuddyMoodTrend(buddyMoods),
        'interaction_patterns': _analyzeInteractionPatterns(messages, userId),
        'engagement_score': _calculateEngagementScore(messages, userId),
      };

      return insights;
    } catch (e) {
      // Error handling for buddy insights
      return {'error': 'Failed to load buddy insights'};
    }
  }

  String _getChatId(String userId1, String userId2) {
    final sortedIds = [userId1, userId2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }

  double _calculateAverageResponseTime(
    List<ChatMessageModel> messages,
    String userId,
  ) {
    // Calculate average time between messages
    double totalTime = 0;
    int responseCount = 0;

    for (int i = 1; i < messages.length; i++) {
      if (messages[i].senderId != messages[i - 1].senderId) {
        final timeDiff = messages[i - 1].timestamp
            .difference(messages[i].timestamp)
            .inMinutes;
        totalTime += timeDiff.abs();
        responseCount++;
      }
    }

    return responseCount > 0 ? totalTime / responseCount : 0;
  }

  Map<String, dynamic> _calculateMessageFrequency(
    List<ChatMessageModel> messages,
  ) {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final monthAgo = now.subtract(const Duration(days: 30));

    final weekMessages = messages
        .where((m) => m.timestamp.isAfter(weekAgo))
        .length;
    final monthMessages = messages
        .where((m) => m.timestamp.isAfter(monthAgo))
        .length;

    return {
      'messages_this_week': weekMessages,
      'messages_this_month': monthMessages,
      'daily_average': monthMessages / 30,
    };
  }

  Map<String, dynamic> _analyzeConversationQuality(
    List<ChatMessageModel> messages,
  ) {
    if (messages.isEmpty) {
      return {
        'long_messages_percentage': 0,
        'questions_percentage': 0,
        'engagement_percentage': 0,
      };
    }

    int longMessages = 0;
    int questions = 0;
    int responses = 0;

    for (final message in messages) {
      if (message.text.length > 50) longMessages++;
      if (message.text.contains('?')) questions++;
      if (message.text.length > 10) responses++;
    }

    return {
      'long_messages_percentage': (longMessages / messages.length) * 100,
      'questions_percentage': (questions / messages.length) * 100,
      'engagement_percentage': (responses / messages.length) * 100,
    };
  }

  Map<String, dynamic> _analyzeBuddyMoodTrend(List<MoodEntry> moodEntries) {
    if (moodEntries.isEmpty) {
      return {'trend': 'no_data'};
    }

    final recentMoods = moodEntries.take(7).toList();
    final olderMoods = moodEntries.skip(7).take(7).toList();

    if (recentMoods.isEmpty || olderMoods.isEmpty) {
      return {'trend': 'insufficient_data'};
    }

    final recentAvg =
        recentMoods.fold(0, (total, m) => total + m.moodLevel) /
        recentMoods.length;
    final olderAvg =
        olderMoods.fold(0, (total, m) => total + m.moodLevel) /
        olderMoods.length;

    return {
      'trend': recentAvg > olderAvg ? 'improving' : 'declining',
      'current_avg_mood': recentAvg,
      'previous_avg_mood': olderAvg,
    };
  }

  Map<String, dynamic> _analyzeInteractionPatterns(
    List<ChatMessageModel> messages,
    String userId,
  ) {
    final userMessages = messages.where((m) => m.senderId == userId).toList();
    final buddyMessages = messages.where((m) => m.senderId != userId).toList();

    return {
      'user_message_count': userMessages.length,
      'buddy_message_count': buddyMessages.length,
      'conversation_balance': userMessages.isNotEmpty
          ? buddyMessages.length / userMessages.length
          : 0,
      'user_initiated_conversations': _countUserInitiatedConversations(
        messages,
        userId,
      ),
    };
  }

  int _countUserInitiatedConversations(
    List<ChatMessageModel> messages,
    String userId,
  ) {
    int count = 0;
    for (int i = 1; i < messages.length; i++) {
      if (messages[i].senderId == userId &&
          messages[i - 1].senderId != userId &&
          messages[i].timestamp.difference(messages[i - 1].timestamp).inHours >
              2) {
        count++;
      }
    }
    return count;
  }

  double _calculateEngagementScore(
    List<ChatMessageModel> messages,
    String userId,
  ) {
    if (messages.isEmpty) return 0;

    final userMessages = messages.where((m) => m.senderId == userId).toList();
    final totalMessages = messages.length;
    final userMessagePercentage = userMessages.length / totalMessages;

    // Calculate response rate
    double responseRate = 0;
    for (int i = 1; i < messages.length; i++) {
      if (messages[i].senderId != messages[i - 1].senderId) {
        responseRate++;
      }
    }
    responseRate = responseRate / (totalMessages - 1);

    // Calculate average message length
    final avgMessageLength = userMessages.isNotEmpty
        ? userMessages.fold(0, (total, m) => total + m.text.length) /
              userMessages.length
        : 0;

    // Calculate engagement score (0-100)
    final score =
        (userMessagePercentage * 30) +
        (responseRate * 40) +
        (avgMessageLength / 10 * 30);
    return score.clamp(0, 100);
  }

  // Mission Archive
  Future<List<DailyMissionModel>> getMissionArchive(String userId) async {
    final canAccess = await _premiumService.canAccessMissionArchive(userId);
    if (!canAccess) {
      return [];
    }

    try {
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));

      final archiveQuery = await _firestore
          .collection('users')
          .doc(userId)
          .collection('dailyMissions')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(weekAgo))
          .orderBy('createdAt', descending: true)
          .get();

      return archiveQuery.docs
          .map((doc) => DailyMissionModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      // Error handling for mission archive
      return [];
    }
  }

  // Personalized Feedback
  Future<String> generatePersonalizedFeedback(String userId) async {
    final canAccess = await _premiumService.canAccessFeature(
      userId,
      'personalized_feedback',
    );
    if (!canAccess) {
      return 'Upgrade to Premium to receive personalized feedback!';
    }

    try {
      // Get user's recent activity
      final analytics = await getAdvancedAnalytics(userId);
      final user = await _userService.getUser(userId);

      final feedbackPrompt =
          '''
Generate personalized weekly feedback for a user with the following data:

User: ${user?.username ?? 'User'}
Analytics: $analytics

Provide specific, actionable feedback that includes:
1. Progress recognition
2. Areas for improvement
3. Personalized recommendations
4. Motivation and encouragement
5. Next week's goals

Make it personal, encouraging, and actionable.
''';

      final response = await AiRouter.generate(
        task: AiTaskType.feedbackCoach,
        prompt: feedbackPrompt,
      );

      return response;
    } catch (e) {
      // Error handling for personalized feedback
      return 'Great job this week! Keep up the good work!';
    }
  }

  // Voice Journaling
  Future<Map<String, dynamic>> startVoiceJournaling(String userId) async {
    final canAccess = await _premiumService.canAccessFeature(
      userId,
      'voice_journaling',
    );
    if (!canAccess) {
      return {'error': 'Premium feature required'};
    }

    try {
      // Simple mock implementation for now
      return {
        'status': 'recording_started',
        'session_id': 'voice_session_${DateTime.now().millisecondsSinceEpoch}',
        'duration': 0,
        'transcription': '',
      };
    } catch (e) {
      return {'error': 'Failed to start voice journaling: $e'};
    }
  }

  Future<Map<String, dynamic>> stopVoiceJournaling(
    String userId,
    String sessionId,
  ) async {
    final canAccess = await _premiumService.canAccessFeature(
      userId,
      'voice_journaling',
    );
    if (!canAccess) {
      return {'error': 'Premium feature required'};
    }

    try {
      // Mock transcription for demonstration
      final transcription =
          'Today I felt more confident in social situations. I noticed that when I maintain eye contact and smile, people respond more positively. I want to continue practicing these skills.';

      // Simple mock analysis without AI dependency
      final analysis = '''
🎯 **Progress Analysis:**
• You're showing increased self-awareness
• Positive attitude toward social interactions
• Clear identification of effective strategies

💡 **Key Insights:**
• Eye contact and smiling are working well
• You're actively reflecting on your experiences
• Good foundation for continued growth

🚀 **Recommendations:**
• Keep practicing the techniques that work
• Try extending conversations gradually
• Celebrate small wins like today's insights

🌟 **Positive Reinforcement:**
You're making excellent progress! Your self-reflection shows real growth mindset.
''';

      // Save to Firestore (optional - can be disabled if causing issues)
      try {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('voice_journals')
            .doc(sessionId)
            .set({
              'sessionId': sessionId,
              'transcription': transcription,
              'analysis': analysis,
              'duration': 120, // Mock duration in seconds
              'createdAt': DateTime.now().millisecondsSinceEpoch,
            });
      } catch (firestoreError) {
        // If Firestore fails, still return the analysis
        print('Firestore save failed, but continuing: $firestoreError');
      }

      return {
        'status': 'completed',
        'transcription': transcription,
        'analysis': analysis,
        'duration': 120,
      };
    } catch (e) {
      return {'error': 'Failed to process voice journal: $e'};
    }
  }

  // Dark Mode Themes
  Future<List<Map<String, dynamic>>> getPremiumThemes(String userId) async {
    print('getPremiumThemes called for user: $userId');

    final canAccess = await _premiumService.canAccessFeature(
      userId,
      'dark_mode_themes',
    );
    print('User can access premium themes: $canAccess');

    if (!canAccess) {
      print('Access denied for premium themes');
      return [];
    }

    print('Access granted, returning themes');
    return [
      {
        'id': 'midnight_purple',
        'name': 'Midnight Purple',
        'primaryColor': '#6B46C1',
        'secondaryColor': '#9F7AEA',
        'backgroundColor': '#1A202C',
        'surfaceColor': '#2D3748',
        'textColor': '#F7FAFC',
      },
      {
        'id': 'ocean_blue',
        'name': 'Ocean Blue',
        'primaryColor': '#3182CE',
        'secondaryColor': '#63B3ED',
        'backgroundColor': '#1A365D',
        'surfaceColor': '#2A4365',
        'textColor': '#F7FAFC',
      },
      {
        'id': 'forest_green',
        'name': 'Forest Green',
        'primaryColor': '#38A169',
        'secondaryColor': '#68D391',
        'backgroundColor': '#1A202C',
        'surfaceColor': '#2D3748',
        'textColor': '#F7FAFC',
      },
      {
        'id': 'sunset_orange',
        'name': 'Sunset Orange',
        'primaryColor': '#DD6B20',
        'secondaryColor': '#F6AD55',
        'backgroundColor': '#2D3748',
        'surfaceColor': '#4A5568',
        'textColor': '#F7FAFC',
      },
    ];
  }

  // Premium Icons & Avatars
  Future<List<Map<String, dynamic>>> getPremiumAvatars(String userId) async {
    final canAccess = await _premiumService.canAccessFeature(
      userId,
      'premium_icons_avatars',
    );
    if (!canAccess) {
      return [];
    }

    return [
      {
        'id': 'premium_1',
        'name': 'Crown',
        'icon': '👑',
        'description': 'Royal confidence',
        'unlocked': true,
      },
      {
        'id': 'premium_2',
        'name': 'Dragon',
        'icon': '🐉',
        'description': 'Inner strength',
        'unlocked': true,
      },
      {
        'id': 'premium_3',
        'name': 'Phoenix',
        'icon': '🦅',
        'description': 'Rising above',
        'unlocked': true,
      },
      {
        'id': 'premium_4',
        'name': 'Lion',
        'icon': '🦁',
        'description': 'Natural leader',
        'unlocked': true,
      },
      {
        'id': 'premium_5',
        'name': 'Diamond',
        'icon': '💎',
        'description': 'Unbreakable',
        'unlocked': true,
      },
      {
        'id': 'premium_6',
        'name': 'Star',
        'icon': '⭐',
        'description': 'Shining bright',
        'unlocked': true,
      },
    ];
  }

  // Premium Badge
  Future<Map<String, dynamic>> getPremiumBadge(String userId) async {
    final canAccess = await _premiumService.canAccessFeature(
      userId,
      'premium_badge',
    );
    if (!canAccess) {
      return {'error': 'Premium feature required'};
    }

    try {
      final user = await _userService.getUser(userId);
      final analytics = await getAdvancedAnalytics(userId);

      // Calculate badge level based on user activity
      final completedMissions =
          analytics['streakAnalysis']?['total_completed'] ?? 0;
      final currentStreak = analytics['streakAnalysis']?['current_streak'] ?? 0;
      final longestStreak = analytics['streakAnalysis']?['longest_streak'] ?? 0;

      String badgeLevel = 'Bronze';
      String badgeIcon = '🥉';

      if (completedMissions >= 50 && longestStreak >= 7) {
        badgeLevel = 'Gold';
        badgeIcon = '🥇';
      } else if (completedMissions >= 25 && longestStreak >= 5) {
        badgeLevel = 'Silver';
        badgeIcon = '🥈';
      }

      return {
        'badge_level': badgeLevel,
        'badge_icon': badgeIcon,
        'completed_missions': completedMissions,
        'current_streak': currentStreak,
        'longest_streak': longestStreak,
        'next_level_requirement': _getNextLevelRequirement(badgeLevel),
      };
    } catch (e) {
      return {'error': 'Failed to load premium badge'};
    }
  }

  String _getNextLevelRequirement(String currentLevel) {
    switch (currentLevel) {
      case 'Bronze':
        return 'Complete 25 missions and maintain a 5-day streak for Silver';
      case 'Silver':
        return 'Complete 50 missions and maintain a 7-day streak for Gold';
      case 'Gold':
        return 'You\'ve reached the highest level!';
      default:
        return 'Complete 10 missions for Bronze';
    }
  }

  // Priority Support
  Future<Map<String, dynamic>> getPrioritySupport(String userId) async {
    final canAccess = await _premiumService.canAccessFeature(
      userId,
      'priority_support',
    );
    if (!canAccess) {
      return {'error': 'Premium feature required'};
    }

    return {
      'support_level': 'Priority',
      'response_time': 'Within 2 hours',
      'available_channels': [
        'In-app chat',
        'Email support',
        'Video call (scheduled)',
      ],
      'features': [
        'Direct access to senior support team',
        'Extended support hours',
        'Custom solutions for your needs',
        'Proactive issue resolution',
      ],
      'contact_info': {
        'email': 'premium-support@camarra.com',
        'response_time': '2 hours',
        'availability': '24/7',
      },
    };
  }

  // Early Feature Access
  Future<List<Map<String, dynamic>>> getEarlyFeatures(String userId) async {
    final canAccess = await _premiumService.canAccessFeature(
      userId,
      'early_feature_access',
    );
    if (!canAccess) {
      return [];
    }

    return [
      {
        'id': 'ai_coach_plus',
        'name': 'AI Coach Plus',
        'description': 'Advanced AI coaching with personalized strategies',
        'status': 'beta',
        'available': true,
        'release_date': '2024-01-15',
      },
      {
        'id': 'group_challenges',
        'name': 'Group Challenges',
        'description':
            'Compete with other users in social confidence challenges',
        'status': 'alpha',
        'available': true,
        'release_date': '2024-02-01',
      },
      {
        'id': 'voice_analytics',
        'name': 'Voice Analytics',
        'description': 'Analyze your voice patterns for confidence improvement',
        'status': 'beta',
        'available': true,
        'release_date': '2024-01-20',
      },
      {
        'id': 'ar_social_practice',
        'name': 'AR Social Practice',
        'description': 'Practice social interactions in augmented reality',
        'status': 'development',
        'available': false,
        'release_date': '2024-03-01',
      },
      {
        'id': 'mood_prediction',
        'name': 'Mood Prediction',
        'description': 'AI-powered mood forecasting and prevention',
        'status': 'alpha',
        'available': true,
        'release_date': '2024-01-25',
      },
    ];
  }

  // Get all premium features status
  Future<Map<String, dynamic>> getAllPremiumFeatures(String userId) async {
    final features = {
      'enhanced_ai_generation': await _premiumService.canAccessEnhancedAI(
        userId,
      ),
      'advanced_progress_graphs': await _premiumService
          .canAccessAdvancedAnalytics(userId),
      'personalized_feedback': await _premiumService.canAccessFeature(
        userId,
        'personalized_feedback',
      ),
      'voice_journaling': await _premiumService.canAccessFeature(
        userId,
        'voice_journaling',
      ),
      'buddy_insights': await _premiumService.canAccessBuddyInsights(userId),
      'dark_mode_themes': await _premiumService.canAccessFeature(
        userId,
        'dark_mode_themes',
      ),
      'premium_avatars': await _premiumService.canAccessFeature(
        userId,
        'premium_icons_avatars',
      ),
      'daily_mission_archive': await _premiumService.canAccessMissionArchive(
        userId,
      ),
      'premium_badge': await _premiumService.canAccessFeature(
        userId,
        'premium_badge',
      ),
      'priority_support': await _premiumService.canAccessFeature(
        userId,
        'priority_support',
      ),
      'early_feature_access': await _premiumService.canAccessFeature(
        userId,
        'early_feature_access',
      ),
    };

    return features;
  }
}
