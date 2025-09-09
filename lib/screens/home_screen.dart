import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../utils/user_service.dart';
import '../utils/mission_service.dart';
import '../utils/theme_provider.dart';
import '../utils/profile_service.dart';
import '../utils/mood_scheduler_service.dart';
import '../utils/notification_service.dart'; // Added import for NotificationService
import '../utils/premium_service.dart';
import '../models/user_model.dart';
import '../models/mission_model.dart';
import '../widgets/profile_picture.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MissionService _missionService = MissionService();
  final UserService _userService = UserService();
  final ProfileService _profileService = ProfileService();
  final MoodSchedulerService _moodSchedulerService = MoodSchedulerService();
  final NotificationService _notificationService =
      NotificationService(); // Added NotificationService instance
  final PremiumService _premiumService = PremiumService();
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    _loadUserTheme();
    _checkMoodCheck();
    _initializeStreakReminder();
    _checkDailyMissionReset();
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

  Future<void> _completeDailyMission() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() {
      _isCompleting = true;
    });

    try {
      await _missionService.completeDailyMission(currentUser.uid);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Daily mission completed! 🎉')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to complete mission: $e')));
    } finally {
      setState(() {
        _isCompleting = false;
      });
    }
  }

  Future<void> _checkMoodCheck() async {
    // Wait a bit for the screen to load, then check for mood check
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      await _moodSchedulerService.checkAndShowMoodCheck(context);
    }
  }

  Future<void> _initializeStreakReminder() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Get user's notification settings
      final settings = await _notificationService.getNotificationSettings(
        currentUser.uid,
      );
      if (settings != null && settings['streakReminders'] == true) {
        // Schedule streak reminder for 8 PM (20:00) if not already scheduled
        await _notificationService.scheduleStreakReminder(hour: 20, minute: 0);
        print('Streak reminder initialized');
      }
    } catch (e) {
      print('Error initializing streak reminder: $e');
    }
  }

  Future<void> _checkDailyMissionReset() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Check and reset daily missions if needed
      await _missionService.checkAndResetDailyMissions(currentUser.uid);
    } catch (e) {
      print('Error checking daily mission reset: $e');
    }
  }

  void _showProfilePictureOptions() {
    final theme = Theme.of(context);
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
            StreamBuilder<UserModel?>(
              stream: _userService.streamUser(
                FirebaseAuth.instance.currentUser!.uid,
              ),
              builder: (context, snapshot) {
                final hasProfilePicture =
                    snapshot.hasData &&
                    snapshot.data?.profilePictureUrl != null &&
                    snapshot.data!.profilePictureUrl!.isNotEmpty;

                if (hasProfilePicture) {
                  return ListTile(
                    leading: Icon(Icons.delete, color: theme.colorScheme.error),
                    title: Text(
                      'Remove Picture',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _removeProfilePicture();
                    },
                  );
                }
                return const SizedBox.shrink();
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
                  StreamBuilder<UserModel?>(
                    stream: _userService.streamUser(
                      FirebaseAuth.instance.currentUser!.uid,
                    ),
                    builder: (context, snapshot) {
                      return ProfilePicture(
                        user: snapshot.data,
                        size: 40,
                        onTap: _showProfilePictureOptions,
                        backgroundColor: const Color(0xFF6B46C1),
                        textColor: Colors.white,
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StreamBuilder<UserModel?>(
                          stream: _userService.streamUser(
                            FirebaseAuth.instance.currentUser!.uid,
                          ),
                          builder: (context, snapshot) {
                            String username = 'User';
                            if (snapshot.hasData && snapshot.data != null) {
                              username = snapshot.data!.username;
                            }
                            return Text(
                              'Welcome back, $username!',
                              style: TextStyle(
                                fontSize: 16,
                                color: theme.textTheme.bodyMedium?.color
                                    ?.withOpacity(0.7),
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          },
                        ),
                        StreamBuilder<UserModel?>(
                          stream: _userService.streamUser(
                            FirebaseAuth.instance.currentUser!.uid,
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data != null) {
                              return Text(
                                'Level ${snapshot.data!.level} • ${snapshot.data!.xp} XP',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: theme.textTheme.titleMedium?.color,
                                ),
                              );
                            }
                            return Text(
                              'Loading...',
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pushNamed(context, '/settings'),
                    icon: Icon(Icons.settings, color: theme.iconTheme.color),
                  ),
                ],
              ),
            ),

            // XP Progress Bar at Top
            _buildXPProgressBar(),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats Cards
                    StreamBuilder<UserModel?>(
                      stream: _userService.streamUser(
                        FirebaseAuth.instance.currentUser!.uid,
                      ),
                      builder: (context, snapshot) {
                        final missionStreak =
                            snapshot.hasData && snapshot.data != null
                            ? (snapshot.data!.streaks['mission'] ?? 0)
                                  .toString()
                            : '0';
                        final chatStreak =
                            snapshot.hasData && snapshot.data != null
                            ? (snapshot.data!.streaks['chat'] ?? 0).toString()
                            : '0';

                        return Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                'Mission Streak',
                                missionStreak,
                                Icons.local_fire_department,
                                const Color(0xFFFF6B6B),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildStatCard(
                                'Chat Streak',
                                chatStreak,
                                Icons.chat_bubble,
                                const Color(0xFF4ECDC4),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Daily Mission Card
                    _buildDailyMissionCard(),
                    const SizedBox(height: 24),

                    // User Analytics Button
                    _buildUserAnalyticsButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context, 0),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
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
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.titleLarge?.color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyMissionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => Navigator.pushNamed(
              context,
              '/buddy',
              arguments: {'initialTab': 1},
            ),
            child: Row(
              children: [
                Image.asset('assets/images/octopus.png', width: 40, height: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Challenge',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                      ),
                      StreamBuilder<DailyMissionModel?>(
                        stream: _missionService.streamDailyMission(
                          FirebaseAuth.instance.currentUser!.uid,
                        ),
                        builder: (context, missionSnapshot) {
                          if (missionSnapshot.hasData &&
                              missionSnapshot.data != null) {
                            return Text(
                              missionSnapshot.data!.content,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.color,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            );
                          }
                          return Text(
                            'Loading your personalized challenge...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).textTheme.bodySmall?.color,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<DailyMissionModel?>(
            stream: _missionService.streamDailyMission(
              FirebaseAuth.instance.currentUser!.uid,
            ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  child: const Text(
                    'Error loading daily mission. Please try again.',
                    style: TextStyle(color: Colors.red),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasData && snapshot.data != null) {
                final mission = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mission.content,
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6B46C1).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${mission.xpReward} XP',
                            style: const TextStyle(
                              color: Color(0xFF6B46C1),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getDifficultyColor(
                              mission.difficulty,
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            mission.difficulty,
                            style: TextStyle(
                              color: _getDifficultyColor(mission.difficulty),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<UserModel?>(
                      stream: _userService.streamUser(
                        FirebaseAuth.instance.currentUser!.uid,
                      ),
                      builder: (context, userSnapshot) {
                        // Check if the mission is completed (more reliable than user's dailyMissionCompleted field)
                        final isCompleted = mission.isCompleted;

                        return SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isCompleted
                                ? null
                                : _completeDailyMission,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isCompleted
                                  ? Colors.grey
                                  : const Color(0xFF6B46C1),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              isCompleted ? 'Completed!' : 'Complete',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              }

              // Fallback when no data is available
              return Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No daily mission available',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Check back later for new challenges!',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildXPProgressBar() {
    return StreamBuilder<UserModel?>(
      stream: _userService.streamUser(FirebaseAuth.instance.currentUser!.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data!;
        final currentLevel = user.level;
        final currentXP = user.xp;

        // Calculate XP needed for current level and next level
        final xpForCurrentLevel = _calculateXPForLevel(currentLevel);
        final xpForNextLevel = _calculateXPForLevel(currentLevel + 1);
        final xpProgress = currentXP - xpForCurrentLevel;
        final xpNeeded = xpForNextLevel - xpForCurrentLevel;
        final progressPercentage = xpProgress / xpNeeded;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              // Level text centered above the bar
              Text(
                'Level $currentLevel',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
              const SizedBox(height: 12),
              // Simple progress bar
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progressPercentage.clamp(0.0, 1.0),
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                    minHeight: 12,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // XP text centered below the bar
              Text(
                '$xpProgress/$xpNeeded XP',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  int _calculateXPForLevel(int level) {
    // XP formula: each level requires more XP than the previous
    // Level 1: 0 XP, Level 2: 100 XP, Level 3: 250 XP, etc.
    if (level <= 1) return 0;
    return ((level - 1) * 100) + ((level - 2) * 50);
  }

  Color _getDifficultyColor(String difficulty) {
    final theme = Theme.of(context);
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return theme.colorScheme.primary;
      case 'medium':
        return theme.colorScheme.secondary;
      case 'hard':
        return theme.colorScheme.error;
      default:
        return theme.colorScheme.onSurface.withOpacity(0.5);
    }
  }

  Widget _buildBottomNavigationBar(BuildContext context, int currentIndex) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, -8),
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
    final isSelected = index == currentIndex;
    return GestureDetector(
      onTap: () {
        switch (index) {
          case 0:
            // Already on home
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
            if (ModalRoute.of(context)?.settings.name != '/settings') {
              Navigator.pushNamed(context, '/settings');
            }
            break;
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? const Color(0xFF6B46C1) : Colors.grey,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFF6B46C1) : Colors.grey,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAnalyticsButton() {
    return FutureBuilder<bool>(
      future: _premiumService.hasPremiumAccess(
        FirebaseAuth.instance.currentUser?.uid ?? '',
      ),
      builder: (context, snapshot) {
        // Only show for premium users
        if (!snapshot.hasData || !snapshot.data!) {
          return const SizedBox.shrink(); // Hide for non-premium users
        }

        final theme = Theme.of(context);
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF667eea), const Color(0xFF764ba2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF667eea).withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.pushNamed(context, '/premium-analytics'),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.analytics,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'User Analytics',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'View your progress insights and detailed analytics',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
