import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../widgets/mood_check_popup.dart';
import 'notification_service.dart';

class MoodSchedulerService {
  static final MoodSchedulerService _instance =
      MoodSchedulerService._internal();
  factory MoodSchedulerService() => _instance;
  MoodSchedulerService._internal();

  final NotificationService _notificationService = NotificationService();

  // Key for storing last mood check date
  static const String _lastMoodCheckKey = 'last_mood_check_date';

  // Key for storing user's mood check frequency
  static const String _moodCheckFrequencyKey = 'mood_check_frequency';

  /// Initialize mood check scheduling for a user
  Future<void> initializeMoodChecks(UserModel user) async {
    // Store the user's talk frequency as mood check frequency
    await _setMoodCheckFrequency(user.onboarding.talkFrequency);

    // Schedule the first mood check
    await _scheduleNextMoodCheck(user);
  }

  /// Set the mood check frequency based on onboarding talk frequency
  Future<void> _setMoodCheckFrequency(String talkFrequency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_moodCheckFrequencyKey, talkFrequency);
  }

  /// Get the current mood check frequency
  Future<String> getMoodCheckFrequency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_moodCheckFrequencyKey) ?? 'Daily';
  }

  /// Schedule the next mood check based on frequency
  Future<void> _scheduleNextMoodCheck(UserModel user) async {
    final frequency = await getMoodCheckFrequency();
    final daysToAdd = _getDaysFromFrequency(frequency);

    final nextCheckDate = DateTime.now().add(Duration(days: daysToAdd));

    // Schedule notification
    await _notificationService.scheduleMoodCheckReminder(
      hour: 12, // Noon
      minute: 0,
    );
  }

  /// Get number of days from frequency string
  int _getDaysFromFrequency(String frequency) {
    switch (frequency.toLowerCase()) {
      case 'daily':
      case 'every day':
        return 1;
      case 'every 2 days':
      case 'every other day':
        return 2;
      case 'every 3 days':
      case 'every few days':
        return 3;
      case 'weekly':
      case 'once a week':
        return 7;
      case 'every 2 weeks':
      case 'bi-weekly':
        return 14;
      case 'monthly':
      case 'once a month':
        return 30;
      default:
        return 1; // Default to daily
    }
  }

  /// Check if it's time for a mood check
  Future<bool> shouldShowMoodCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheckDateString = prefs.getString(_lastMoodCheckKey);

    if (lastCheckDateString == null) {
      // First time, show mood check
      return true;
    }

    final lastCheckDate = DateTime.parse(lastCheckDateString);
    final frequency = await getMoodCheckFrequency();
    final daysToAdd = _getDaysFromFrequency(frequency);
    final nextCheckDate = lastCheckDate.add(Duration(days: daysToAdd));

    return DateTime.now().isAfter(nextCheckDate);
  }

  /// Mark mood check as completed
  Future<void> markMoodCheckCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastMoodCheckKey, DateTime.now().toIso8601String());

    // Schedule next mood check
    final frequency = await getMoodCheckFrequency();
    final daysToAdd = _getDaysFromFrequency(frequency);
    final nextCheckDate = DateTime.now().add(Duration(days: daysToAdd));

    // Schedule next notification
    await _notificationService.scheduleMoodCheckReminder(hour: 12, minute: 0);
  }

  /// Show mood check popup if needed
  Future<void> checkAndShowMoodCheck(BuildContext context) async {
    if (await shouldShowMoodCheck()) {
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const MoodCheckPopup(),
        ).then((_) {
          // Mark as completed when dialog is closed
          markMoodCheckCompleted();
        });
      }
    }
  }

  /// Update mood check frequency (when user changes settings)
  Future<void> updateMoodCheckFrequency(String newFrequency) async {
    await _setMoodCheckFrequency(newFrequency);

    // Cancel existing notifications and schedule new ones
    await _notificationService.cancelNotification(
      7,
    ); // Mood check notification ID

    // Schedule new mood check
    final daysToAdd = _getDaysFromFrequency(newFrequency);
    final nextCheckDate = DateTime.now().add(Duration(days: daysToAdd));

    await _notificationService.scheduleMoodCheckReminder(hour: 12, minute: 0);
  }

  /// Get the next mood check date
  Future<DateTime?> getNextMoodCheckDate() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheckDateString = prefs.getString(_lastMoodCheckKey);

    if (lastCheckDateString == null) {
      return DateTime.now();
    }

    final lastCheckDate = DateTime.parse(lastCheckDateString);
    final frequency = await getMoodCheckFrequency();
    final daysToAdd = _getDaysFromFrequency(frequency);

    return lastCheckDate.add(Duration(days: daysToAdd));
  }

  /// Reset mood check scheduling (for testing or user preference changes)
  Future<void> resetMoodCheckScheduling() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastMoodCheckKey);

    // Cancel existing notifications
    await _notificationService.cancelNotification(7);
  }
}
