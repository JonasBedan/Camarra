import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:provider/provider.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'firebase_options.dart';
import 'utils/theme_provider.dart';
import 'utils/sound_provider.dart';
import 'utils/notification_service.dart';
import 'utils/stripe_service.dart';
import 'screens/landing_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/mission_screen.dart';
import 'screens/buddy_screen.dart';
import 'screens/missions_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/onboarding_questions_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/ai_chat_screen.dart';
import 'screens/premium_screen.dart';

import 'screens/premium_analytics_screen.dart';
import 'screens/buddy_insights_screen.dart';
import 'screens/mission_archive_screen.dart';
import 'screens/premium_avatars_screen.dart';
import 'screens/voice_journaling_screen.dart';
import 'screens/premium_themes_screen.dart';
import 'screens/mood_check_screen.dart';
import 'screens/feedback_screen.dart';
import 'screens/chapter_generation_loading_screen.dart';
import 'utils/user_service.dart';
import 'utils/daily_mission_reset_service.dart';
import 'models/user_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Firebase Analytics
  await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);

  // Initialize Stripe (with error handling for web)
  try {
    // Skip Stripe initialization on web platform
    if (!kIsWeb) {
      await StripeService.initialize();
    } else {
      print('Skipping Stripe initialization on web platform');
    }
  } catch (e) {
    print('Stripe initialization failed: $e');
    // Continue without Stripe for web platform
  }

  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.initialize();

  // Initialize daily mission reset service
  DailyMissionResetService().initialize();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Initialize theme after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      themeProvider.initializeTheme(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SoundProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Camarra',
            theme: themeProvider.currentTheme,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en', ''), // English
              Locale('es', ''), // Spanish
              Locale('fr', ''), // French
              Locale('de', ''), // German
            ],
            initialRoute: '/landing',
            routes: {
              '/landing': (context) => const LandingScreen(),
              '/login': (context) => const LoginScreen(),
              '/register': (context) => const RegisterScreen(),
              '/onboarding-questions': (context) =>
                  const OnboardingQuestionsScreen(),
              '/chapter-generation-loading': (context) {
                final args =
                    ModalRoute.of(context)!.settings.arguments
                        as Map<String, dynamic>?;
                return ChapterGenerationLoadingScreen(
                  userId: args?['userId'] ?? '',
                  onboardingData: args?['onboardingData'] as OnboardingData,
                );
              },
              '/home': (context) => const ThemeAwareHomeScreen(),
              '/mission': (context) => const MissionScreen(),
              '/buddy': (context) => const BuddyScreen(),
              '/missions': (context) => const MissionsScreen(),
              '/settings': (context) => const ThemeAwareSettingsScreen(),
              '/chat': (context) {
                final args =
                    ModalRoute.of(context)!.settings.arguments
                        as Map<String, dynamic>?;
                return ChatScreen(
                  buddyId: args?['buddyId'] ?? '',
                  buddyEmail: args?['buddyEmail'] ?? '',
                );
              },
              '/ai-chat': (context) => const AIChatScreen(),
              '/premium': (context) => const PremiumScreen(),

              '/premium-analytics': (context) => const PremiumAnalyticsScreen(),
              '/buddy-insights': (context) => const BuddyInsightsScreen(),
              '/mission-archive': (context) => const MissionArchiveScreen(),
              '/premium-avatars': (context) => const PremiumAvatarsScreen(),
              '/voice-journaling': (context) => const VoiceJournalingScreen(),
              '/premium-themes': (context) => const PremiumThemesScreen(),
              '/mood-check': (context) => const MoodCheckScreen(),
              '/feedback': (context) => const FeedbackScreen(),
            },
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

class ThemeAwareHomeScreen extends StatefulWidget {
  const ThemeAwareHomeScreen({super.key});

  @override
  State<ThemeAwareHomeScreen> createState() => _ThemeAwareHomeScreenState();
}

class _ThemeAwareHomeScreenState extends State<ThemeAwareHomeScreen> {
  @override
  void initState() {
    super.initState();
    _loadUserTheme();
  }

  Future<void> _loadUserTheme() async {
    final userService = UserService();
    final currentUser = userService.getCurrentUser();
    if (currentUser != null) {
      final userModel = await userService.getUser(currentUser.uid);
      if (userModel != null) {
        final themeProvider = Provider.of<ThemeProvider>(
          context,
          listen: false,
        );
        themeProvider.loadThemeFromUser(userModel);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}

class ThemeAwareSettingsScreen extends StatefulWidget {
  const ThemeAwareSettingsScreen({super.key});

  @override
  State<ThemeAwareSettingsScreen> createState() =>
      _ThemeAwareSettingsScreenState();
}

class _ThemeAwareSettingsScreenState extends State<ThemeAwareSettingsScreen> {
  @override
  void initState() {
    super.initState();
    _loadUserTheme();
  }

  Future<void> _loadUserTheme() async {
    final userService = UserService();
    final currentUser = userService.getCurrentUser();
    if (currentUser != null) {
      final userModel = await userService.getUser(currentUser.uid);
      if (userModel != null) {
        final themeProvider = Provider.of<ThemeProvider>(
          context,
          listen: false,
        );
        themeProvider.loadThemeFromUser(userModel);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SettingsScreen();
  }
}
