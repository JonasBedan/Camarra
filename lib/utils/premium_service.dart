import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/premium_model.dart';
import 'user_service.dart';

class PremiumService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserService _userService = UserService();

  // Get user's current subscription
  Stream<PremiumSubscriptionModel?> streamUserSubscription(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('subscriptions')
        .where('status', whereIn: ['active', 'trial'])
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return PremiumSubscriptionModel.fromFirestore(snapshot.docs.first);
        });
  }

  // Get all available premium plans
  Stream<List<PremiumPlanModel>> streamPremiumPlans() {
    return _firestore
        .collection('premiumPlans')
        .where('isAvailable', isEqualTo: true)
        .orderBy('price')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PremiumPlanModel.fromFirestore(doc))
              .toList(),
        );
  }

  // Get premium features
  Stream<List<PremiumFeatureModel>> streamPremiumFeatures() {
    return _firestore
        .collection('premiumFeatures')
        .where('isAvailable', isEqualTo: true)
        .orderBy('category')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PremiumFeatureModel.fromFirestore(doc))
              .toList(),
        );
  }

  // Check if user has premium access
  Future<bool> hasPremiumAccess(String userId) async {
    try {
      print('hasPremiumAccess called for user: $userId');

      final user = await _userService.getUser(userId);
      print('User data retrieved: ${user?.premium}');

      if (user?.premium == true) {
        print('User has premium flag set to true');
        return true;
      }

      print('Checking subscriptions collection...');
      final subscription = await _firestore
          .collection('users')
          .doc(userId)
          .collection('subscriptions')
          .where('status', whereIn: ['active', 'trial'])
          .limit(1)
          .get();

      print('Found ${subscription.docs.length} active/trial subscriptions');

      if (subscription.docs.isNotEmpty) {
        final sub = PremiumSubscriptionModel.fromFirestore(
          subscription.docs.first,
        );
        final isActive = sub.isActive || sub.isInTrial;
        print(
          'Subscription status - isActive: ${sub.isActive}, isInTrial: ${sub.isInTrial}, final result: $isActive',
        );
        return isActive;
      }

      print('No active subscriptions found');
      return false;
    } catch (e) {
      print('Error checking premium access: $e');
      return false;
    }
  }

  // Create a new subscription (simulated for now)
  Future<bool> createSubscription({
    required String userId,
    required PremiumPlanModel plan,
    bool isTrial = false,
  }) async {
    try {
      final now = DateTime.now();
      final endDate = isTrial
          ? now.add(const Duration(days: 7)) // 7-day trial
          : now.add(Duration(days: plan.durationDays));

      final subscription = PremiumSubscriptionModel(
        id: '', // Will be set by Firestore
        userId: userId,
        plan: plan.plan,
        status: isTrial ? SubscriptionStatus.trial : SubscriptionStatus.active,
        startDate: now,
        endDate: endDate,
        price: plan.price,
        currency: plan.currency,
        isTrial: isTrial,
        trialEndDate: isTrial ? endDate : null,
      );

      // Add subscription to user's collection
      final docRef = await _firestore
          .collection('users')
          .doc(userId)
          .collection('subscriptions')
          .add(subscription.toFirestore());

      // Update user's premium status
      await _userService.updateUser(userId, {'premium': true});

      print('Subscription created: ${docRef.id}');
      return true;
    } catch (e) {
      print('Error creating subscription: $e');
      return false;
    }
  }

  // Cancel subscription
  Future<bool> cancelSubscription(String userId) async {
    try {
      final subscription = await _firestore
          .collection('users')
          .doc(userId)
          .collection('subscriptions')
          .where('status', whereIn: ['active', 'trial'])
          .limit(1)
          .get();

      if (subscription.docs.isNotEmpty) {
        await subscription.docs.first.reference.update({
          'status': 'cancelled',
          'cancelledAt': Timestamp.now(),
        });
      }

      return true;
    } catch (e) {
      print('Error cancelling subscription: $e');
      return false;
    }
  }

  // Get premium features by category
  Future<List<PremiumFeatureModel>> getFeaturesByCategory(
    String category,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('premiumFeatures')
          .where('category', isEqualTo: category)
          .where('isAvailable', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => PremiumFeatureModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting features by category: $e');
      return [];
    }
  }

  // Create test premium plans (for development)
  Future<void> createTestPremiumPlans() async {
    try {
      final plans = [
        PremiumPlanModel(
          id: 'monthly',
          name: 'Monthly Premium',
          description: 'Perfect for trying out premium features',
          price: 4.99,
          currency: 'USD',
          plan: SubscriptionPlan.monthly,
          durationDays: 30,
          features: [
            'Enhanced AI Generation',
            'Advanced Progress Graphs',
            'Personalized Feedback',
            'Voice Journaling',
            'Buddy+ Insights',
            'Dark Mode Themes',
            'Premium Icons & Avatars',
            'Daily Mission Archive',
            'Premium Badge',
            'Priority Support',
          ],
        ),
        PremiumPlanModel(
          id: 'yearly',
          name: 'Yearly Premium',
          description: 'Best value - Save 40%',
          price: 39.99,
          currency: 'USD',
          plan: SubscriptionPlan.yearly,
          durationDays: 365,
          features: [
            'Everything in Monthly',
            'Exclusive Yearly Rewards',
            'Enhanced AI Personalization',
            'Advanced Analytics Dashboard',
            'Priority Feature Requests',
          ],
          isPopular: true,
          originalPrice: 99.99,
          discountText: 'Save 40%',
        ),
        PremiumPlanModel(
          id: 'lifetime',
          name: 'Lifetime Premium',
          description: 'One-time payment, forever access',
          price: 199.99,
          currency: 'USD',
          plan: SubscriptionPlan.lifetime,
          durationDays: 36500, // 100 years
          features: [
            'Everything in Yearly',
            'Lifetime Updates',
            'VIP Support',
            'Custom Features',
            'Exclusive Content',
            'Founder Status',
          ],
          isLifetime: true,
        ),
      ];

      for (final plan in plans) {
        await _firestore
            .collection('premiumPlans')
            .doc(plan.id)
            .set(plan.toFirestore());
      }

      print('Test premium plans created successfully');
    } catch (e) {
      print('Error creating test premium plans: $e');
    }
  }

  // Create test premium features (for development)
  Future<void> createTestPremiumFeatures() async {
    try {
      final features = [
        // AI & Mission Features
        PremiumFeatureModel(
          id: 'enhanced_ai_generation',
          name: 'Enhanced AI Generation',
          description:
              'Get significantly better AI-generated missions, feedback, and insights based on your emotional state and long-term progress.',
          icon: '🤖',
          isAvailable: true,
          category: 'ai_missions',
        ),
        PremiumFeatureModel(
          id: 'advanced_progress_graphs',
          name: 'Advanced Progress Graphs',
          description:
              'Access detailed graphs showing your daily progress, mission consistency, XP growth, and emotional trends.',
          icon: '📊',
          isAvailable: true,
          category: 'analytics',
        ),
        PremiumFeatureModel(
          id: 'personalized_feedback',
          name: 'Personalized Feedback',
          description:
              'Receive weekly feedback and suggestions from the app based on your activity and mental health journey.',
          icon: '💡',
          isAvailable: true,
          category: 'ai_missions',
        ),
        PremiumFeatureModel(
          id: 'voice_journaling',
          name: 'Voice Journaling',
          description:
              'Record and analyze voice journals with optional AI sentiment analysis.',
          icon: '🎤',
          isAvailable: true,
          category: 'journaling',
        ),

        // Buddy Features
        PremiumFeatureModel(
          id: 'buddy_plus_insights',
          name: 'Buddy+ Insights',
          description:
              'See detailed analytics and trends about each buddy\'s activity, progress, and streaks. Includes insights like weekly mission completion rate, average response time, and emotional consistency.',
          icon: '👥',
          isAvailable: true,
          category: 'buddies',
        ),

        // Customization Features
        PremiumFeatureModel(
          id: 'dark_mode_themes',
          name: 'Dark Mode Themes',
          description:
              'Exclusive access to premium dark mode themes and visual customizations.',
          icon: '🌙',
          isAvailable: true,
          category: 'customization',
        ),
        PremiumFeatureModel(
          id: 'premium_icons_avatars',
          name: 'Premium Icons & Avatars',
          description:
              'Unlock exclusive profile icons, XP effects, and avatars.',
          icon: '✨',
          isAvailable: true,
          category: 'customization',
        ),

        // Mission Features
        PremiumFeatureModel(
          id: 'daily_mission_archive',
          name: 'Daily Mission Archive',
          description: 'Access and redo missions from the past 7 days.',
          icon: '📚',
          isAvailable: true,
          category: 'missions',
        ),

        // Community Features
        PremiumFeatureModel(
          id: 'premium_badge',
          name: 'Premium Badge',
          description:
              'A badge that highlights you as a premium user in community features (optional visibility).',
          icon: '🏆',
          isAvailable: true,
          category: 'community',
        ),

        // Support Features
        PremiumFeatureModel(
          id: 'priority_support',
          name: 'Priority Support',
          description:
              'Faster responses from the Camarra team via email or in-app help center.',
          icon: '🎧',
          isAvailable: true,
          category: 'support',
        ),
      ];

      for (final feature in features) {
        await _firestore
            .collection('premiumFeatures')
            .doc(feature.id)
            .set(feature.toFirestore());
      }

      print('Test premium features created successfully');
    } catch (e) {
      print('Error creating test premium features: $e');
    }
  }

  // Check if user can access a specific premium feature
  Future<bool> canAccessFeature(String userId, String featureId) async {
    try {
      print('canAccessFeature called for user: $userId, feature: $featureId');

      final hasPremium = await hasPremiumAccess(userId);
      print('User has premium access: $hasPremium');

      if (!hasPremium) {
        print('Access denied: user does not have premium');
        return false;
      }

      // Feature-specific access control
      switch (featureId) {
        case 'enhanced_ai_generation':
        case 'advanced_progress_graphs':
        case 'personalized_feedback':
        case 'voice_journaling':
        case 'buddy_plus_insights':
        case 'dark_mode_themes':
        case 'premium_icons_avatars':
        case 'daily_mission_archive':
        case 'premium_badge':
        case 'priority_support':
          print('Feature access granted: $featureId');
          return true;
        default:
          print('Feature access denied: $featureId (unknown feature)');
          return false;
      }
    } catch (e) {
      print('Error checking feature access: $e');
      return false;
    }
  }

  // Get premium feature status for current user
  Future<Map<String, bool>> getPremiumFeatureStatus(String userId) async {
    try {
      final hasPremium = await hasPremiumAccess(userId);
      if (!hasPremium) {
        return {
          'enhanced_ai_generation': false,
          'advanced_progress_graphs': false,
          'personalized_feedback': false,
          'voice_journaling': false,
          'buddy_plus_insights': false,
          'dark_mode_themes': false,
          'premium_icons_avatars': false,
          'daily_mission_archive': false,
          'premium_badge': false,
          'priority_support': false,
        };
      }

      return {
        'enhanced_ai_generation': true,
        'advanced_progress_graphs': true,
        'personalized_feedback': true,
        'voice_journaling': true,
        'buddy_plus_insights': true,
        'dark_mode_themes': true,
        'premium_icons_avatars': true,
        'daily_mission_archive': true,
        'premium_badge': true,
        'priority_support': true,
      };
    } catch (e) {
      print('Error getting premium feature status: $e');
      return {};
    }
  }

  // Check if user has premium badge
  Future<bool> hasPremiumBadge(String userId) async {
    return await canAccessFeature(userId, 'premium_badge');
  }

  // Check if user can access enhanced AI
  Future<bool> canAccessEnhancedAI(String userId) async {
    return await canAccessFeature(userId, 'enhanced_ai_generation');
  }

  // Check if user can access advanced analytics
  Future<bool> canAccessAdvancedAnalytics(String userId) async {
    return await canAccessFeature(userId, 'advanced_progress_graphs');
  }

  // Check if user can access voice journaling
  Future<bool> canAccessVoiceJournaling(String userId) async {
    return await canAccessFeature(userId, 'voice_journaling');
  }

  // Check if user can access buddy insights
  Future<bool> canAccessBuddyInsights(String userId) async {
    return await canAccessFeature(userId, 'buddy_plus_insights');
  }

  // Check if user can access mission archive
  Future<bool> canAccessMissionArchive(String userId) async {
    return await canAccessFeature(userId, 'daily_mission_archive');
  }

  // Check if user can access premium themes
  Future<bool> canAccessPremiumThemes(String userId) async {
    return await canAccessFeature(userId, 'dark_mode_themes');
  }

  // Check if user can access premium icons
  Future<bool> canAccessPremiumIcons(String userId) async {
    return await canAccessFeature(userId, 'premium_icons_avatars');
  }

  // Get user's premium usage statistics
  Future<Map<String, dynamic>> getPremiumUsageStats(String userId) async {
    try {
      final subscription = await _firestore
          .collection('users')
          .doc(userId)
          .collection('subscriptions')
          .where('status', whereIn: ['active', 'trial'])
          .limit(1)
          .get();

      if (subscription.docs.isEmpty) {
        return {
          'hasSubscription': false,
          'daysRemaining': 0,
          'featuresUsed': 0,
          'totalValue': 0.0,
        };
      }

      final sub = PremiumSubscriptionModel.fromFirestore(
        subscription.docs.first,
      );

      return {
        'hasSubscription': true,
        'daysRemaining': sub.daysRemaining,
        'plan': sub.plan.toString().split('.').last,
        'isTrial': sub.isInTrial,
        'featuresUsed': 12, // Mock data
        'totalValue': sub.price,
      };
    } catch (e) {
      print('Error getting premium usage stats: $e');
      return {
        'hasSubscription': false,
        'daysRemaining': 0,
        'featuresUsed': 0,
        'totalValue': 0.0,
      };
    }
  }

  // Set user premium status for testing (development only)
  Future<bool> setPremiumStatus(String userId, bool isPremium) async {
    try {
      await _userService.updateUser(userId, {'premium': isPremium});
      print('Premium status set to $isPremium for user $userId');
      return true;
    } catch (e) {
      print('Error setting premium status: $e');
      return false;
    }
  }

  // Create a test subscription for development
  Future<bool> createTestSubscription(String userId) async {
    try {
      final now = DateTime.now();
      final endDate = now.add(const Duration(days: 365)); // 1 year

      final subscription = PremiumSubscriptionModel(
        id: 'test_sub_${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        plan: SubscriptionPlan.yearly,
        status: SubscriptionStatus.active,
        startDate: now,
        endDate: endDate,
        price: 99.99,
        currency: 'USD',
        isTrial: false,
      );

      // Add subscription to user's collection
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('subscriptions')
          .doc(subscription.id)
          .set(subscription.toFirestore());

      // Update user's premium status
      await _userService.updateUser(userId, {'premium': true});

      print('Test subscription created for user $userId');
      return true;
    } catch (e) {
      print('Error creating test subscription: $e');
      return false;
    }
  }
}
