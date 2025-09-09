import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../utils/user_service.dart';
import '../utils/theme_provider.dart';
import '../utils/profile_service.dart';
import '../utils/sound_provider.dart';
import '../utils/notification_service.dart';
import '../utils/mood_scheduler_service.dart';
import '../utils/premium_service.dart';
import '../utils/stripe_service.dart';
import '../models/user_model.dart';
import '../models/premium_model.dart';
import '../widgets/profile_picture.dart';
import 'package:flutter/foundation.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final UserService _userService = UserService();
  final ProfileService _profileService = ProfileService();
  final NotificationService _notificationService = NotificationService();
  final MoodSchedulerService _moodSchedulerService = MoodSchedulerService();
  final PremiumService _premiumService = PremiumService();
  final StripeService _stripeService = StripeService();
  UserModel? _user;
  bool _isLoading = true;
  bool _notificationsEnabled = true;
  bool _dailyMissionReminders = true;
  bool _moodCheckReminders = true;
  bool _buddyMessageNotifications = true;
  bool _streakReminders = true;
  String _moodCheckFrequency = 'Daily';
  TimeOfDay _dailyMissionTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _moodCheckTime = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _streakReminderTime = const TimeOfDay(hour: 20, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadUserTheme();
    _loadNotificationSettings();
  }

  Future<void> _loadUserTheme() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final user = await _userService.getUser(currentUser.uid);
      if (user != null) {
        final themeProvider = Provider.of<ThemeProvider>(
          context,
          listen: false,
        );
        themeProvider.loadThemeFromUser(user);
      }
    }
  }

  Future<void> _loadUserData() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final user = await _userService.getUser(currentUser.uid);
      if (user != null) {
        setState(() {
          _user = user;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadNotificationSettings() async {
    if (_user == null) return;

    final settings = await _notificationService.getNotificationSettings(
      _user!.uid,
    );
    if (settings != null) {
      setState(() {
        _notificationsEnabled = settings['notificationsEnabled'] ?? true;
        _dailyMissionReminders = settings['dailyMissionReminders'] ?? true;
        _moodCheckReminders = settings['moodCheckReminders'] ?? true;
        _buddyMessageNotifications =
            settings['buddyMessageNotifications'] ?? true;
        _streakReminders = settings['streakReminders'] ?? true;
        // Keep default times for now
      });
    }

    // Load mood check frequency
    final frequency = await _moodSchedulerService.getMoodCheckFrequency();
    setState(() {
      _moodCheckFrequency = frequency;
    });
  }

  Future<void> _saveNotificationSettings() async {
    if (_user == null) return;

    final settings = {
      'notificationsEnabled': _notificationsEnabled,
      'dailyMissionReminders': _dailyMissionReminders,
      'moodCheckReminders': _moodCheckReminders,
      'buddyMessageNotifications': _buddyMessageNotifications,
      'streakReminders': _streakReminders,
    };

    await _notificationService.saveNotificationSettings(_user!.uid, settings);

    // Schedule or cancel notifications based on settings
    if (_streakReminders) {
      await _notificationService.scheduleStreakReminder(
        hour: _streakReminderTime.hour,
        minute: _streakReminderTime.minute,
      );
    } else {
      await _notificationService.cancelNotification(
        8,
      ); // Streak notification ID
    }
  }

  void _showProfilePictureOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Change Profile Picture',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _changeProfilePicture(fromCamera: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _changeProfilePicture(fromCamera: true);
              },
            ),
            if (_user?.profilePictureUrl != null &&
                _user!.profilePictureUrl!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Remove Picture',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _removeProfilePicture();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeProfilePicture({required bool fromCamera}) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final success = await _profileService.changeProfilePicture(
        fromCamera: fromCamera,
      );

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      if (success) {
        // Reload user data to get updated profile picture
        await _loadUserData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture updated! 📸'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Upload was canceled'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      print('Profile picture error: $e');

      if (mounted) {
        String errorMessage = 'Failed to update profile picture';

        // Parse error message to show user-friendly text
        final errorString = e.toString();
        if (errorString.contains('Exception:')) {
          errorMessage = errorString.replaceFirst('Exception:', '').trim();
        } else if (errorString.contains('You don\'t have permission')) {
          errorMessage = 'Permission denied. Please check app settings.';
        } else if (errorString.contains('internet') ||
            errorString.contains('network')) {
          errorMessage =
              'Network error. Please check your internet connection.';
        } else if (errorString.contains('too large')) {
          errorMessage = 'Image is too large. Please select a smaller image.';
        } else if (errorString.contains('Authentication expired')) {
          errorMessage = 'Please log out and log back in.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _changeProfilePicture(fromCamera: fromCamera),
            ),
          ),
        );
      }
    }
  }

  Future<void> _removeProfilePicture() async {
    try {
      final success = await _profileService.removeProfilePicture();
      if (success) {
        // Reload user data to get updated profile picture
        await _loadUserData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture removed')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to remove profile picture')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_user == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: Text('User not found.')),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back, color: theme.iconTheme.color),
                  ),
                  Expanded(
                    child: Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.titleLarge?.color,
                      ),
                    ),
                  ),
                  if (_user != null)
                    ProfilePicture(
                      user: _user,
                      size: 40,
                      onTap: _showProfilePictureOptions,
                      backgroundColor: theme.colorScheme.primary,
                      textColor: theme.colorScheme.onPrimary,
                    ),
                ],
              ),
            ),

            // Settings Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User Profile Section
                    _buildSectionHeader('Profile'),
                    _buildProfileCard(),
                    const SizedBox(height: 24),

                    // Preferences Section
                    _buildSectionHeader('Preferences'),
                    _buildPreferencesSection(),
                    const SizedBox(height: 24),

                    // Notifications Section
                    _buildSectionHeader('Notifications'),
                    _buildNotificationsSection(),
                    const SizedBox(height: 24),

                    // Mood Check Section
                    _buildMoodCheckSection(),

                    // Privacy & Security Section
                    _buildSectionHeader('Privacy & Security'),
                    _buildPrivacySection(),
                    const SizedBox(height: 24),

                    // Support Section
                    _buildSectionHeader('Support'),
                    _buildSupportSection(),
                    const SizedBox(height: 24),

                    // Premium Section (show for all users)
                    _buildSectionHeader('Premium'),
                    _buildPremiumSection(),
                    const SizedBox(height: 24),

                    // Account Actions Section
                    _buildSectionHeader('Account'),
                    _buildAccountSection(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context, 3),
    );
  }

  Widget _buildSectionHeader(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: theme.textTheme.titleLarge?.color,
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    final theme = Theme.of(context);
    if (_user == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              ProfilePicture(
                user: _user,
                size: 60,
                onTap: _showProfilePictureOptions,
                backgroundColor: theme.colorScheme.primary,
                textColor: Colors.white,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _user!.username,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.titleMedium?.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Level ${_user!.level} • ${_user!.xp} XP',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(
                          0.6,
                        ),
                      ),
                    ),
                    if (_user!.premium)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Premium',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Mission Streak',
                  '${_user!.streaks['mission'] ?? 0} days',
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Chat Streak',
                  '${_user!.streaks['chat'] ?? 0} days',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesSection() {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSwitchItem(
            'Dark Mode',
            Icons.dark_mode,
            Theme.of(context).brightness == Brightness.dark,
            (value) => Provider.of<ThemeProvider>(
              context,
              listen: false,
            ).setTheme(value),
          ),
          _buildDivider(),
          if (_user?.premium == true) ...[
            _buildSettingsItem(
              'Premium Themes',
              Icons.palette,
              () => Navigator.pushNamed(context, '/premium-themes'),
            ),
            _buildDivider(),
          ],
          _buildSwitchItem(
            'Sound Effects',
            Icons.volume_up,
            Provider.of<SoundProvider>(context, listen: false).isEnabled,
            (value) => Provider.of<SoundProvider>(
              context,
              listen: false,
            ).setEnabled(value),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsSection() {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.notifications,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Notifications',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              _buildSwitchItem(
                'Push Notifications',
                Icons.notifications,
                _notificationsEnabled,
                (value) => setState(() => _notificationsEnabled = value),
              ),
              _buildDivider(),
              _buildSwitchItem(
                'Mission Reminders',
                Icons.assignment,
                _dailyMissionReminders,
                (value) => setState(() => _dailyMissionReminders = value),
              ),
              _buildDivider(),
              _buildSwitchItem(
                'Buddy Messages',
                Icons.chat,
                _buddyMessageNotifications,
                (value) {
                  setState(() => _buddyMessageNotifications = value);
                },
              ),
              _buildDivider(),
              _buildSwitchItem(
                'Streak Reminders',
                Icons.local_fire_department,
                _streakReminders,
                (value) {
                  setState(() => _streakReminders = value);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMoodCheckSection() {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mood, color: theme.colorScheme.primary, size: 24),
              const SizedBox(width: 12),
              Text(
                'Mood Check',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              _buildSwitchItem(
                'Mood Check Reminders',
                Icons.schedule,
                _moodCheckReminders,
                (value) => setState(() => _moodCheckReminders = value),
              ),
              _buildDivider(),
              _buildDropdownItem(
                'Check Frequency',
                Icons.repeat,
                _moodCheckFrequency,
                [
                  'Daily',
                  'Every 2 days',
                  'Every 3 days',
                  'Weekly',
                  'Every 2 weeks',
                  'Monthly',
                ],
                (value) async {
                  setState(() => _moodCheckFrequency = value);
                  await _moodSchedulerService.updateMoodCheckFrequency(value);
                },
              ),
              _buildDivider(),
              _buildButtonItem(
                'Check Your Mood Now',
                Icons.psychology,
                () => Navigator.pushNamed(context, '/mood-check'),
              ),
              if (_user?.premium == true) ...[
                _buildDivider(),
                _buildSettingsItem(
                  'Voice Journaling',
                  Icons.mic,
                  () => Navigator.pushNamed(context, '/voice-journaling'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacySection() {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSettingsItem(
            'Change Password',
            Icons.lock,
            () => _showChangePasswordDialog(),
          ),
          _buildDivider(),
          _buildSettingsItem(
            'Privacy Policy',
            Icons.privacy_tip,
            () => _showPrivacyPolicy(),
          ),
          _buildDivider(),
          _buildSettingsItem(
            'Terms of Service',
            Icons.description,
            () => _showTermsOfService(),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportSection() {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          if (_user?.premium == true) ...[
            _buildSettingsItem(
              'Priority Support',
              Icons.support_agent,
              () => _showPrioritySupport(),
            ),
          ] else ...[
            _buildSettingsItem(
              'Help & Support',
              Icons.help,
              () => _showHelpAndSupport(),
            ),
          ],
          _buildDivider(),
          _buildSettingsItem(
            'Feedback & Suggestions',
            Icons.feedback,
            () => Navigator.pushNamed(context, '/feedback'),
          ),
          _buildDivider(),
          _buildSettingsItem(
            'About Camarra',
            Icons.info,
            () => _showAboutCamarra(),
          ),
          _buildDivider(),
          _buildSettingsItem('Rate App', Icons.star, () => _showRateApp()),
          if (_user?.premium == true) ...[
            _buildDivider(),
            _buildSettingsItem('Mission Archive', Icons.archive, () {
              Navigator.pushNamed(context, '/mission-archive');
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildPremiumSection() {
    final theme = Theme.of(context);
    final isPremium = _user?.premium == true;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPremium
              ? [
                  const Color(0xFF10B981),
                  const Color(0xFF059669),
                ] // Green gradient for premium
              : [
                  const Color(0xFF6B46C1),
                  const Color(0xFF8B5CF6),
                ], // Purple gradient for non-premium
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:
                (isPremium ? const Color(0xFF10B981) : const Color(0xFF6B46C1))
                    .withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          if (!isPremium) ...[
            _buildPremiumSettingsItem(
              'Premium Upgrade',
              Icons.star,
              () => _showPremiumUpgrade(),
              showBadge: true,
            ),
            _buildPremiumDivider(),
            _buildPremiumSettingsItem(
              'Start Free Trial',
              Icons.play_circle,
              () => _startFreeTrial(),
            ),
          ] else ...[
            _buildPremiumSettingsItem(
              'Premium Active',
              Icons.verified,
              () => _showPremiumStatus(),
              showBadge: false,
            ),
            _buildPremiumDivider(),
            _buildPremiumSettingsItem(
              'Progress Analytics',
              Icons.analytics,
              () => Navigator.pushNamed(context, '/premium-analytics'),
            ),
            _buildPremiumDivider(),
            _buildPremiumSettingsItem(
              'Buddy+ Insights',
              Icons.people,
              () => Navigator.pushNamed(context, '/buddy-insights'),
            ),
            _buildPremiumDivider(),
          ],
          _buildPremiumDivider(),
          StreamBuilder<PremiumSubscriptionModel?>(
            stream: _premiumService.streamUserSubscription(
              FirebaseAuth.instance.currentUser?.uid ?? '',
            ),
            builder: (context, snapshot) {
              final hasActiveSubscription =
                  snapshot.hasData && snapshot.data != null;

              if (hasActiveSubscription) {
                return Column(
                  children: [
                    _buildPremiumSettingsItem(
                      'Manage Subscription',
                      Icons.settings,
                      () => _showSubscriptionManagement(),
                    ),
                    _buildPremiumDivider(),
                    _buildPremiumSettingsItem(
                      'Cancel Subscription',
                      Icons.cancel,
                      () => _showCancelSubscriptionDialog(),
                      isDestructive: true,
                    ),
                  ],
                );
              } else {
                return const SizedBox.shrink();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection() {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSettingsItem(
            'Export Data',
            Icons.download,
            () => _showExportData(),
          ),
          _buildDivider(),
          if (_user?.premium == true) ...[
            _buildSettingsItem(
              'Premium Avatars',
              Icons.face,
              () => Navigator.pushNamed(context, '/premium-avatars'),
            ),
            _buildDivider(),
            _buildSettingsItem('Premium Badge', Icons.emoji_events, () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Premium badges coming soon!'),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
              );
            }),
            _buildDivider(),
          ],
          _buildSettingsItem(
            'Delete Account',
            Icons.delete_forever,
            () => _showDeleteAccount(),
            isDestructive: true,
          ),
          _buildDivider(),
          _buildSettingsItem(
            'Logout',
            Icons.logout,
            () => _showLogoutDialog(),
            isDestructive: true,
          ),
          // Development/Testing Section
          // Removed admin functions as requested
        ],
      ),
    );
  }

  Widget _buildSwitchItem(
    String title,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                color: theme.textTheme.titleMedium?.color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: theme.colorScheme.primary,
            activeTrackColor: theme.colorScheme.primary.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildButtonItem(String title, IconData icon, VoidCallback onTap) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: theme.colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownItem(
    String title,
    IconData icon,
    String value,
    List<String> options,
    ValueChanged<String> onChanged,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                color: theme.textTheme.titleMedium?.color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          DropdownButton<String>(
            value: value,
            onChanged: (newValue) => onChanged(newValue!),
            items: options
                .map(
                  (option) => DropdownMenuItem(
                    value: option,
                    child: Text(
                      option,
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                )
                .toList(),
            underline: Container(),
            dropdownColor: theme.cardColor,
            icon: Icon(
              Icons.arrow_drop_down,
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(
    String title,
    IconData icon,
    VoidCallback onTap, {
    bool isDestructive = false,
    bool showBadge = false,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isDestructive ? Colors.red : theme.colorScheme.primary)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isDestructive ? Colors.red : theme.colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: isDestructive
                      ? Colors.red
                      : theme.textTheme.titleMedium?.color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (showBadge)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'NEW',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios,
              color: isDestructive
                  ? Colors.red
                  : theme.textTheme.bodySmall?.color,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, color: Colors.grey, indent: 56);
  }

  Widget _buildPremiumSettingsItem(
    String title,
    IconData icon,
    VoidCallback onTap, {
    bool showBadge = false,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isDestructive ? Colors.red : Colors.white).withOpacity(
                  0.2,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isDestructive ? Colors.red : Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (showBadge)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'NEW',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios,
              color: isDestructive ? Colors.red : Colors.white,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumDivider() {
    return const Divider(height: 1, color: Colors.white30, indent: 56);
  }

  // Dialog methods
  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureCurrentPassword = false;
    bool obscureNewPassword = false;
    bool obscureConfirmPassword = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                obscureText: obscureCurrentPassword,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureCurrentPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        obscureCurrentPassword = !obscureCurrentPassword;
                      });
                    },
                    tooltip: obscureCurrentPassword
                        ? 'Show password'
                        : 'Hide password',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                obscureText: obscureNewPassword,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureNewPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        obscureNewPassword = !obscureNewPassword;
                      });
                    },
                    tooltip: obscureNewPassword
                        ? 'Show password'
                        : 'Hide password',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                obscureText: obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureConfirmPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        obscureConfirmPassword = !obscureConfirmPassword;
                      });
                    },
                    tooltip: obscureConfirmPassword
                        ? 'Show password'
                        : 'Hide password',
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (newPasswordController.text !=
                    confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('New passwords do not match!'),
                    ),
                  );
                  return;
                }

                try {
                  await _userService.changePassword(
                    currentPasswordController.text,
                    newPasswordController.text,
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password changed successfully!'),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to change password: $e')),
                  );
                }
              },
              child: const Text('Change Password'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPremiumUpgrade() {
    Navigator.pushNamed(context, '/premium');
  }

  void _startFreeTrial() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start Free Trial'),
        content: const Text(
          'Start your 7-day free trial and experience all premium features! No credit card required.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/premium');
            },
            child: const Text('Start Trial'),
          ),
        ],
      ),
    );
  }

  void _showSubscriptionManagement() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Subscription Management'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Manage your premium subscription:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('• View subscription details'),
            const Text('• Update payment method'),
            const Text('• Change subscription plan'),
            const Text('• Download invoices'),
            const Text('• Cancel subscription'),
            const SizedBox(height: 16),
            const Text(
              'You can also manage your subscription through the customer portal.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Open customer portal
              final portalUrl = await _stripeService.getCustomerPortalUrl(
                _user?.uid ?? '',
                'https://your-app.com/settings',
              );
              if (portalUrl != null) {
                // In a real app, you would open this URL
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Customer portal URL: $portalUrl')),
                );
              }
            },
            child: const Text('Open Portal'),
          ),
        ],
      ),
    );
  }

  void _showCancelSubscriptionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Subscription'),
        content: const Text(
          'Are you sure you want to cancel your subscription? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_user == null) return;

              Navigator.pop(context);
              try {
                final result = await _stripeService.cancelSubscription(
                  _user!.uid,
                );
                if (result.success) {
                  // Also cancel in our local database
                  await _premiumService.cancelSubscription(_user!.uid);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(result.message)));
                } else {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(result.message)));
                }
                // Reload user data to reflect premium status
                await _loadUserData();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to cancel subscription: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Subscription'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const Text(
          'Your privacy is important to us. We collect minimal data to provide you with the best experience. Full privacy policy available on our website.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showTermsOfService() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms of Service'),
        content: const Text(
          'By using Camarra, you agree to our terms of service. Full terms available on our website.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showHelpAndSupport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How can we help you?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              '📚 FAQ & Common Questions:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              '• How do I find a buddy?\n'
              '• How do missions work?\n'
              '• How do I change my mood?\n'
              '• What are streaks?\n'
              '• How do I upgrade to Premium?',
            ),
            const SizedBox(height: 16),
            const Text(
              '📧 Contact Support:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Email us at support@camarra.app\n'
              'Or use the in-app chat with Camarra for immediate help!',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Opening email app... 📧')),
              );
            },
            child: const Text('Email Support'),
          ),
        ],
      ),
    );
  }

  void _showPrioritySupport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Priority Support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Premium Priority Support',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'As a premium user, you get:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              '⚡ 24/7 Priority Response\n'
              '🎯 Dedicated Support Team\n'
              '📞 Direct Phone Support\n'
              '💬 Live Chat Priority\n'
              '🔧 Custom Solutions',
            ),
            const SizedBox(height: 16),
            const Text(
              '📧 Priority Contact:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Email: priority@camarra.app\n'
              'Phone: +1-800-CAMARRA\n'
              'Response time: < 2 hours',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Connecting to priority support... ⚡'),
                ),
              );
            },
            child: const Text('Contact Priority Support'),
          ),
        ],
      ),
    );
  }

  void _showAboutCamarra() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Camarra'),
        content: const Text(
          'Camarra is your AI-powered companion for overcoming social anxiety. Built with love and science to help you grow and thrive.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showRateApp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rate Camarra'),
        content: const Text(
          'Enjoying Camarra? Please rate us on the App Store! Your feedback helps us improve and reach more people who need support.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Thank you for your support! ⭐')),
              );
            },
            child: const Text('Rate Now'),
          ),
        ],
      ),
    );
  }

  void _showExportData() async {
    if (_user == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Data'),
        content: const Text(
          'Export your data including conversations, progress, and settings. This may take a few moments.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final data = await _userService.exportUserData(_user!.uid);
                // Update last export timestamp
                await _userService.updateSetting(
                  _user!.uid,
                  'lastDataExport',
                  DateTime.now(),
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Data exported successfully! ${data.length} items exported.',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to export data: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This action cannot be undone. All your data, progress, and conversations will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_user == null) return;

              Navigator.pop(context);
              try {
                await _userService.deleteUserAccount(_user!.uid);
                Navigator.pushReplacementNamed(context, '/landing');
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete account: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/landing');
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showPremiumStatus() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Premium Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You have an active premium subscription!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('• Enhanced AI Generation'),
            const Text('• Advanced Progress Graphs'),
            const Text('• Personalized Feedback'),
            const Text('• Voice Journaling'),
            const Text('• Buddy+ Insights'),
            const Text('• Dark Mode Themes'),
            const Text('• Premium Icons & Avatars'),
            const Text('• Daily Mission Archive'),
            const Text('• Premium Badge'),
            const Text('• Priority Support'),
            const Text('• Early Feature Access'),
            const SizedBox(height: 16),
            const Text(
              'Thank you for supporting Camarra!',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Awesome!'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context, int currentIndex) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(context, Icons.home, 'Home', 0, currentIndex),
              _buildNavItem(
                context,
                Icons.track_changes,
                'Missions',
                1,
                currentIndex,
              ),
              _buildNavItem(
                context,
                Icons.chat_bubble,
                'Chat',
                2,
                currentIndex,
              ),
              _buildNavItem(
                context,
                Icons.settings,
                'Settings',
                3,
                currentIndex,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    IconData icon,
    String label,
    int index,
    int currentIndex,
  ) {
    final theme = Theme.of(context);
    final isSelected = index == currentIndex;
    return GestureDetector(
      onTap: () {
        switch (index) {
          case 0:
            if (ModalRoute.of(context)?.settings.name != '/home') {
              Navigator.pushNamed(context, '/home');
            }
            break;
          case 1:
            if (ModalRoute.of(context)?.settings.name != '/missions') {
              Navigator.pushNamed(context, '/missions');
            }
            break;
          case 2:
            if (ModalRoute.of(context)?.settings.name != '/buddy') {
              Navigator.pushNamed(context, '/buddy');
            }
            break;
          case 3:
            // Already on settings
            break;
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withOpacity(0.5),
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withOpacity(0.5),
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
