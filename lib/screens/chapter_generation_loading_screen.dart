import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../utils/user_service.dart';
import '../utils/mission_service.dart';
import '../utils/mood_scheduler_service.dart';

class ChapterGenerationLoadingScreen extends StatefulWidget {
  final String userId;
  final OnboardingData onboardingData;

  const ChapterGenerationLoadingScreen({
    super.key,
    required this.userId,
    required this.onboardingData,
  });

  @override
  State<ChapterGenerationLoadingScreen> createState() =>
      _ChapterGenerationLoadingScreenState();
}

class _ChapterGenerationLoadingScreenState
    extends State<ChapterGenerationLoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  final UserService _userService = UserService();
  final MissionService _missionService = MissionService();
  final MoodSchedulerService _moodSchedulerService = MoodSchedulerService();

  String _currentStep = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startChapterGeneration();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _animationController.forward();
    _pulseController.repeat(reverse: true);
  }

  Future<void> _startChapterGeneration() async {
    try {
      // Step 1: Generate personalized books
      setState(() {
        _currentStep = 'Generating personalized chapters...';
      });
      await Future.delayed(const Duration(seconds: 1));

      await _missionService.initializeUserLearningJourneyWithOnboarding(
        widget.userId,
        widget.onboardingData,
      );

      setState(() {
        _currentStep = 'Adding experience points...';
      });
      await Future.delayed(const Duration(seconds: 1));

      // Step 2: Add XP for onboarding completion
      await _userService.addXP(widget.userId, 0, 'Completed onboarding');

      setState(() {
        _currentStep = 'Setting up mood check scheduling...';
      });
      await Future.delayed(const Duration(seconds: 1));

      // Step 3: Initialize mood check scheduling
      final userModel = await _userService.getUser(widget.userId);
      if (userModel != null) {
        await _moodSchedulerService.initializeMoodChecks(userModel);
      }

      setState(() {
        _currentStep = 'Finalizing setup...';
      });
      await Future.delayed(const Duration(seconds: 1));

      // Navigate to home screen
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      print('Error during chapter generation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        // Navigate to home screen even if there's an error
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated logo/icon
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.primary.withOpacity(0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(60),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.psychology,
                        size: 60,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Title
                  Text(
                    'Creating Your Journey',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Subtitle
                  Text(
                    'We\'re personalizing your experience based on your answers',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(
                        0.7,
                      ),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // Current step
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _currentStep,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
