import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Initialize analytics for a user
  static Future<void> setUserProperties(String userId) async {
    await _analytics.setUserId(id: userId);

    // Set user properties for better segmentation
    await _analytics.setUserProperty(name: 'user_type', value: 'regular');
    await _analytics.setUserProperty(name: 'app_version', value: '1.0.0');
  }

  // Track user registration
  static Future<void> logUserRegistration({
    required String method,
    String? email,
  }) async {
    await _analytics.logEvent(
      name: 'user_registration',
      parameters: {
        'method': method,
        'email_provided': email != null,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  // Track user login
  static Future<void> logUserLogin({
    required String method,
    String? email,
  }) async {
    await _analytics.logEvent(
      name: 'user_login',
      parameters: {
        'method': method,
        'email_provided': email != null,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  // Track mission completion
  static Future<void> logMissionCompleted({
    required String missionType,
    required int difficulty,
    required int completionTime,
    required bool isPremium,
  }) async {
    await _analytics.logEvent(
      name: 'mission_completed',
      parameters: {
        'mission_type': missionType,
        'difficulty': difficulty,
        'completion_time_seconds': completionTime,
        'is_premium': isPremium,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  // Track mission started
  static Future<void> logMissionStarted({
    required String missionType,
    required int difficulty,
    required bool isPremium,
  }) async {
    await _analytics.logEvent(
      name: 'mission_started',
      parameters: {
        'mission_type': missionType,
        'difficulty': difficulty,
        'is_premium': isPremium,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  // Track buddy connection
  static Future<void> logBuddyConnection({
    required String
    connectionType, // 'request_sent', 'request_accepted', 'chat_started'
    required bool isPremium,
  }) async {
    await _analytics.logEvent(
      name: 'buddy_connection',
      parameters: {
        'connection_type': connectionType,
        'is_premium': isPremium,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  // Track chat messages
  static Future<void> logChatMessage({
    required String chatType, // 'buddy', 'ai'
    required int messageLength,
    required bool isPremium,
  }) async {
    await _analytics.logEvent(
      name: 'chat_message',
      parameters: {
        'chat_type': chatType,
        'message_length': messageLength,
        'is_premium': isPremium,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  // Track mood check-ins
  static Future<void> logMoodCheckIn({
    required String mood,
    required int moodScore,
    required bool isPremium,
  }) async {
    await _analytics.logEvent(
      name: 'mood_check_in',
      parameters: {
        'mood': mood,
        'mood_score': moodScore,
        'is_premium': isPremium,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  // Track premium subscription
  static Future<void> logPremiumSubscription({
    required String planType,
    required double price,
    required String currency,
    required String paymentMethod,
  }) async {
    await _analytics.logEvent(
      name: 'premium_subscription',
      parameters: {
        'plan_type': planType,
        'price': price,
        'currency': currency,
        'payment_method': paymentMethod,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  // Track app feature usage
  static Future<void> logFeatureUsage({
    required String featureName,
    required bool isPremium,
    Map<String, dynamic>? additionalParams,
  }) async {
    final parameters = <String, Object>{
      'feature_name': featureName,
      'is_premium': isPremium,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    if (additionalParams != null) {
      parameters.addAll(additionalParams.cast<String, Object>());
    }

    await _analytics.logEvent(name: 'feature_usage', parameters: parameters);
  }

  // Track app performance
  static Future<void> logAppPerformance({
    required String metric,
    required double value,
    String? unit,
  }) async {
    await _analytics.logEvent(
      name: 'app_performance',
      parameters: {
        'metric': metric,
        'value': value,
        'unit': unit ?? 'ms',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  // Track user engagement
  static Future<void> logUserEngagement({
    required String engagementType,
    required int duration,
    required bool isPremium,
  }) async {
    await _analytics.logEvent(
      name: 'user_engagement',
      parameters: {
        'engagement_type': engagementType,
        'duration_seconds': duration,
        'is_premium': isPremium,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  // Track error events
  static Future<void> logError({
    required String errorType,
    required String errorMessage,
    String? stackTrace,
    Map<String, dynamic>? additionalParams,
  }) async {
    final parameters = <String, Object>{
      'error_type': errorType,
      'error_message': errorMessage,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    if (stackTrace != null) {
      parameters['stack_trace'] = stackTrace;
    }

    if (additionalParams != null) {
      parameters.addAll(additionalParams.cast<String, Object>());
    }

    await _analytics.logEvent(name: 'app_error', parameters: parameters);
  }

  // Track screen views
  static Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    await _analytics.logScreenView(
      screenName: screenName,
      screenClass: screenClass,
    );
  }

  // Set user premium status
  static Future<void> setPremiumStatus(bool isPremium) async {
    await _analytics.setUserProperty(
      name: 'is_premium',
      value: isPremium.toString(),
    );
  }

  // Set user streak information
  static Future<void> setUserStreaks({
    required int missionStreak,
    required int chatStreak,
    required int longestMissionStreak,
    required int longestChatStreak,
  }) async {
    await _analytics.setUserProperty(
      name: 'mission_streak',
      value: missionStreak.toString(),
    );
    await _analytics.setUserProperty(
      name: 'chat_streak',
      value: chatStreak.toString(),
    );
    await _analytics.setUserProperty(
      name: 'longest_mission_streak',
      value: longestMissionStreak.toString(),
    );
    await _analytics.setUserProperty(
      name: 'longest_chat_streak',
      value: longestChatStreak.toString(),
    );
  }

  // Track user onboarding completion
  static Future<void> logOnboardingCompleted({
    required int totalSteps,
    required int completedSteps,
    required int timeSpent,
  }) async {
    await _analytics.logEvent(
      name: 'onboarding_completed',
      parameters: {
        'total_steps': totalSteps,
        'completed_steps': completedSteps,
        'time_spent_seconds': timeSpent,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  // Track app session start
  static Future<void> logAppSessionStart() async {
    await _analytics.logEvent(
      name: 'app_session_start',
      parameters: {'timestamp': DateTime.now().millisecondsSinceEpoch},
    );
  }

  // Track app session end
  static Future<void> logAppSessionEnd({
    required int sessionDuration,
    required int screensViewed,
  }) async {
    await _analytics.logEvent(
      name: 'app_session_end',
      parameters: {
        'session_duration_seconds': sessionDuration,
        'screens_viewed': screensViewed,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }
}
