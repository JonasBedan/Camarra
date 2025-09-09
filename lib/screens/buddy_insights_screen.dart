import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../models/chat_message_model.dart';
import '../utils/premium_service.dart';
import '../utils/premium_features_impl.dart';
import '../utils/theme_provider.dart';
import '../utils/sound_service.dart';
import '../utils/buddy_service.dart';
import '../utils/chat_service.dart';
import '../utils/user_service.dart';
import 'dart:math' as math;

class BuddyInsightsScreen extends StatefulWidget {
  const BuddyInsightsScreen({super.key});

  @override
  State<BuddyInsightsScreen> createState() => _BuddyInsightsScreenState();
}

class _BuddyInsightsScreenState extends State<BuddyInsightsScreen>
    with TickerProviderStateMixin {
  final PremiumService _premiumService = PremiumService();
  final PremiumFeaturesImpl _premiumFeatures = PremiumFeaturesImpl();
  final BuddyService _buddyService = BuddyService();
  final ChatService _chatService = ChatService();
  final UserService _userService = UserService();
  final SoundService _soundService = SoundService();

  UserModel? _currentUser;
  UserModel? _buddy;
  Map<String, dynamic>? _buddyInsights;
  bool _isLoading = true;
  String? _errorMessage;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutBack,
          ),
        );
    _animationController.forward();
    _loadBuddyInsights();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadBuddyInsights() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          _errorMessage = 'User not authenticated';
          _isLoading = false;
        });
        return;
      }

      // Check if user has premium access
      final hasPremium = await _premiumService.hasPremiumAccess(
        currentUser.uid,
      );
      if (!hasPremium) {
        setState(() {
          _errorMessage = 'Premium feature - upgrade to access buddy insights';
          _isLoading = false;
        });
        return;
      }

      // Load current user
      final user = await _userService.getUser(currentUser.uid);
      if (user == null) {
        setState(() {
          _errorMessage = 'Failed to load user data';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _currentUser = user;
      });

      // Check if user has a buddy
      if (user.buddyId == null) {
        setState(() {
          _errorMessage =
              'You don\'t have a buddy yet. Connect with someone to see insights!';
          _isLoading = false;
        });
        return;
      }

      // Load buddy data
      final buddy = await _userService.getUser(user.buddyId!);
      if (buddy == null) {
        setState(() {
          _errorMessage = 'Failed to load buddy data';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _buddy = buddy;
      });

      // Load buddy insights
      final insights = await _premiumFeatures.getBuddyInsights(
        currentUser.uid,
        user.buddyId!,
      );

      setState(() {
        _buddyInsights = insights;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load buddy insights: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final theme = themeProvider.currentTheme;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary.withOpacity(0.1),
                  theme.colorScheme.secondary.withOpacity(0.1),
                  theme.scaffoldBackgroundColor,
                ],
              ),
            ),
            child: SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    children: [
                      // Header
                      _buildHeader(theme),

                      // Content
                      Expanded(child: _buildContent(theme)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),
              Expanded(
                child: Text(
                  'Buddy Insights',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Deep analytics about your buddy connection',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _buildErrorMessage(theme);
    }

    if (_buddy == null) {
      return _buildNoBuddyState(theme);
    }

    if (_buddyInsights == null) {
      return _buildNoInsightsState(theme);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Buddy Info
          _buildBuddyInfo(theme),

          const SizedBox(height: 24),

          // Connection Stats
          _buildConnectionStats(theme),

          const SizedBox(height: 24),

          // Activity Analysis
          _buildActivityAnalysis(theme),

          const SizedBox(height: 24),

          // Communication Insights
          _buildCommunicationInsights(theme),

          const SizedBox(height: 24),

          // Mood Trends
          _buildMoodTrends(theme),

          const SizedBox(height: 24),

          // Recommendations
          _buildRecommendations(theme),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(ThemeData theme) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[700]),
            const SizedBox(height: 16),
            Text(
              'Error Loading Insights',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.red[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.red[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadBuddyInsights,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoBuddyState(ThemeData theme) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: theme.colorScheme.primary.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'No Buddy Connected',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect with a buddy to see detailed insights about your relationship!',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/buddy'),
              child: const Text('Find a Buddy'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoInsightsState(ThemeData theme) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 64,
              color: theme.colorScheme.primary.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'No Insights Available',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start chatting with your buddy to generate insights!',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/chat'),
              child: const Text('Start Chatting'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuddyInfo(ThemeData theme) {
    if (_buddy == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
            child: Text(
              _buddy!.username.isNotEmpty
                  ? _buddy!.username[0].toUpperCase()
                  : '?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _buddy!.username.isNotEmpty
                      ? _buddy!.username
                      : 'Anonymous User',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Connected since ${_formatDate(_buddy!.createdAt)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.favorite,
                      size: 16,
                      color: Colors.red.withOpacity(0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_buddyInsights?['total_interactions'] ?? 0} interactions',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.insights, color: theme.colorScheme.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStats(ThemeData theme) {
    final insights = _buddyInsights!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                'Connection Stats',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  theme,
                  'Days Connected',
                  '${insights['days_connected'] ?? 0}',
                  Icons.calendar_today,
                  theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  theme,
                  'Total Messages',
                  '${insights['total_messages'] ?? 0}',
                  Icons.chat_bubble,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  theme,
                  'Response Rate',
                  '${insights['response_rate']?.toStringAsFixed(1) ?? 0}%',
                  Icons.speed,
                  Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityAnalysis(ThemeData theme) {
    final insights = _buddyInsights!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: theme.colorScheme.secondary),
              const SizedBox(width: 12),
              Text(
                'Activity Analysis',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildActivityMetric(
            theme,
            'Most Active Time',
            insights['most_active_time'] ?? 'Unknown',
            Icons.access_time,
          ),
          const SizedBox(height: 16),
          _buildActivityMetric(
            theme,
            'Average Message Length',
            '${insights['avg_message_length']?.toStringAsFixed(0) ?? 0} chars',
            Icons.text_fields,
          ),
          const SizedBox(height: 16),
          _buildActivityMetric(
            theme,
            'Engagement Score',
            '${insights['engagement_score']?.toStringAsFixed(1) ?? 0}/100',
            Icons.trending_up,
          ),
        ],
      ),
    );
  }

  Widget _buildCommunicationInsights(ThemeData theme) {
    final insights = _buddyInsights!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.chat, color: Colors.purple),
              const SizedBox(width: 12),
              Text(
                'Communication Insights',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildCommunicationMetric(
            theme,
            'Conversation Balance',
            insights['conversation_balance'] != null
                ? '${(insights['conversation_balance'] * 100).toStringAsFixed(0)}%'
                : 'Unknown',
            Icons.balance,
            insights['conversation_balance'] ?? 0,
          ),
          const SizedBox(height: 16),
          _buildCommunicationMetric(
            theme,
            'Questions Asked',
            '${insights['questions_percentage']?.toStringAsFixed(1) ?? 0}%',
            Icons.help_outline,
            (insights['questions_percentage'] ?? 0) / 100,
          ),
          const SizedBox(height: 16),
          _buildCommunicationMetric(
            theme,
            'Long Messages',
            '${insights['long_messages_percentage']?.toStringAsFixed(1) ?? 0}%',
            Icons.subject,
            (insights['long_messages_percentage'] ?? 0) / 100,
          ),
        ],
      ),
    );
  }

  Widget _buildMoodTrends(ThemeData theme) {
    final insights = _buddyInsights!;
    final moodTrend = insights['mood_trend'] ?? {};

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mood, color: Colors.orange),
              const SizedBox(width: 12),
              Text(
                'Mood Trends',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (moodTrend['trend'] != null &&
              moodTrend['trend'] != 'no_data') ...[
            _buildMoodMetric(
              theme,
              'Overall Trend',
              moodTrend['trend'] == 'improving'
                  ? 'Improving 📈'
                  : 'Declining 📉',
              moodTrend['trend'] == 'improving' ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 16),
            if (moodTrend['current_avg_mood'] != null) ...[
              _buildMoodMetric(
                theme,
                'Current Average Mood',
                '${moodTrend['current_avg_mood'].toStringAsFixed(1)}/10',
                theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
            ],
          ] else ...[
            Text(
              'Not enough mood data available yet',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecommendations(ThemeData theme) {
    final insights = _buddyInsights!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.amber),
              const SizedBox(width: 12),
              Text(
                'Recommendations',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildRecommendation(
            theme,
            'Keep the conversation flowing!',
            'Your buddy responds well to your messages. Try asking more questions to deepen your connection.',
            Icons.chat_bubble_outline,
            Colors.blue,
          ),
          const SizedBox(height: 16),
          _buildRecommendation(
            theme,
            'Share your feelings',
            'Your buddy appreciates emotional openness. Don\'t hesitate to share how you\'re feeling.',
            Icons.favorite_border,
            Colors.red,
          ),
          const SizedBox(height: 16),
          _buildRecommendation(
            theme,
            'Plan activities together',
            'Consider suggesting shared challenges or activities to strengthen your bond.',
            Icons.group_work,
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityMetric(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCommunicationMetric(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
    double percentage,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.purple, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.purple,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: percentage.clamp(0.0, 1.0),
          backgroundColor: Colors.purple.withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
        ),
      ],
    );
  }

  Widget _buildMoodMetric(
    ThemeData theme,
    String label,
    String value,
    Color color,
  ) {
    return Row(
      children: [
        Icon(Icons.mood, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendation(
    ThemeData theme,
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return '$difference days ago';
    } else if (difference < 30) {
      final weeks = (difference / 7).floor();
      return '$weeks week${weeks == 1 ? '' : 's'} ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}



