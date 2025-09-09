import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'mission_service.dart';
import 'user_service.dart';

class DailyMissionResetService {
  static final DailyMissionResetService _instance =
      DailyMissionResetService._internal();
  factory DailyMissionResetService() => _instance;
  DailyMissionResetService._internal();

  final MissionService _missionService = MissionService();
  Timer? _resetTimer;
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Initialize the reset service
  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;

    // Check for reset every 30 seconds for more precise timing
    _resetTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkAndResetDailyMissions();
    });

    print(
      'Daily mission reset service initialized - checking every 30 seconds',
    );
  }

  // Dispose the service
  void dispose() {
    _resetTimer?.cancel();
    _resetTimer = null;
    _isInitialized = false;
    print('Daily mission reset service disposed');
  }

  // Check and reset daily missions for all active users
  Future<void> _checkAndResetDailyMissions() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        print('Checking daily mission reset for user: ${currentUser.uid}');
        await _missionService.checkAndResetDailyMissions(currentUser.uid);

        // Also ensure there's an uncompleted mission available
        await _missionService.ensureDailyMissionExists(currentUser.uid);
      } else {
        print('No current user found for daily mission reset check');
      }
    } catch (e) {
      print('Error in daily mission reset check: $e');
    }
  }

  // Force reset daily missions for testing
  Future<void> forceResetDailyMissions(String userId) async {
    try {
      print('Force resetting daily missions for user: $userId');
      await _missionService.resetDailyMissionsAtMidnight(userId);
      print('Forced daily mission reset completed for user $userId');
    } catch (e) {
      print('Error forcing daily mission reset: $e');
    }
  }

  // Manual reset that also resets user completion status
  Future<void> manualResetDailyMissions(String userId) async {
    try {
      print('Manually resetting daily missions for user: $userId');
      await _missionService.manualResetDailyMissions(userId);
      print('Manual daily mission reset completed for user $userId');
    } catch (e) {
      print('Error manually resetting daily missions: $e');
    }
  }

  // Check current status without resetting
  Future<Map<String, dynamic>> checkResetStatus(String userId) async {
    try {
      final now = DateTime.now();
      final userService = UserService();
      final user = await userService.getUser(userId);
      if (user == null) return {'error': 'User not found'};

      final userTimezone = user.timezone ?? 'UTC';
      final userLocalTime = _getUserLocalTime(now, userTimezone);

      // Check if there are any completed missions
      final firestore = FirebaseFirestore.instance;
      final completedMissionsQuery = await firestore
          .collection('users')
          .doc(userId)
          .collection('daily_missions')
          .where('isCompleted', isEqualTo: true)
          .get();

      return {
        'userTimezone': userTimezone,
        'localTime':
            '${userLocalTime.hour}:${userLocalTime.minute.toString().padLeft(2, '0')}',
        'isResetTime':
            userLocalTime.hour == 1 &&
            userLocalTime.minute >= 0 &&
            userLocalTime.minute <= 4,
        'completedMissionsCount': completedMissionsQuery.docs.length,
        'serviceInitialized': _isInitialized,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // Get user's local time based on their timezone (copied from MissionService)
  DateTime _getUserLocalTime(DateTime utcTime, String timezone) {
    try {
      final offsets = {
        'UTC': 0,
        'EST': -5,
        'CST': -6,
        'MST': -7,
        'PST': -8,
        'GMT': 0,
        'CET': 1,
        'CEST': 2,
        'EET': 2,
        'EEST': 3,
        'JST': 9,
        'AEST': 10,
        'AEDT': 11,
      };
      final offset = offsets[timezone.toUpperCase()] ?? 0;
      return utcTime.add(Duration(hours: offset));
    } catch (e) {
      return utcTime;
    }
  }
}
