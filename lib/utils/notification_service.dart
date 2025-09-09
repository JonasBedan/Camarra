import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

enum NotificationType {
  buddyMessage,
  buddyRequest,
  dailyMission,
  moodCheck,
  missionReminder,
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  // Notification channels
  static const String _buddyChannelId = 'buddy_notifications';
  static const String _missionChannelId = 'mission_notifications';
  static const String _moodChannelId = 'mood_notifications';
  static const String _streakChannelId = 'streak_notifications';

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize timezone
    tz.initializeTimeZones();

    // Initialize notifications
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels
    await _createNotificationChannels();

    _isInitialized = true;
  }

  Future<void> _createNotificationChannels() async {
    // Buddy notifications channel
    const buddyChannel = AndroidNotificationChannel(
      _buddyChannelId,
      'Buddy Notifications',
      description: 'Notifications for buddy messages and requests',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    // Mission notifications channel
    const missionChannel = AndroidNotificationChannel(
      _missionChannelId,
      'Mission Notifications',
      description: 'Notifications for daily missions and reminders',
      importance: Importance.defaultImportance,
      playSound: true,
      enableVibration: true,
    );

    // Mood check notifications channel
    const moodChannel = AndroidNotificationChannel(
      _moodChannelId,
      'Mood Check Notifications',
      description: 'Notifications for mood check reminders',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    );

    // Streak notifications channel
    const streakChannel = AndroidNotificationChannel(
      _streakChannelId,
      'Streak Notifications',
      description: 'Notifications for maintaining streaks',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(buddyChannel);

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(missionChannel);

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(moodChannel);

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(streakChannel);
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap based on payload
    if (kDebugMode) {
      print('Notification tapped: ${response.payload}');
    }
    // You can add navigation logic here based on the notification type
  }

  // Show buddy message notification
  Future<void> showBuddyMessageNotification({
    required String buddyName,
    required String message,
    required String chatId,
  }) async {
    await _showNotification(
      id: 1,
      title: 'New message from $buddyName',
      body: message,
      channelId: _buddyChannelId,
      payload: 'chat:$chatId',
    );
  }

  // Show buddy request notification
  Future<void> showBuddyRequestNotification({
    required String requesterName,
    required String requestId,
  }) async {
    await _showNotification(
      id: 2,
      title: 'New buddy request',
      body: '$requesterName wants to be your buddy!',
      channelId: _buddyChannelId,
      payload: 'buddy_request:$requestId',
    );
  }

  // Show daily mission reminder
  Future<void> showDailyMissionReminder({required String missionTitle}) async {
    await _showNotification(
      id: 3,
      title: 'Daily Mission Reminder',
      body: 'Complete your mission: $missionTitle',
      channelId: _missionChannelId,
      payload: 'daily_mission',
    );
  }

  // Show mood check reminder
  Future<void> showMoodCheckReminder() async {
    await _showNotification(
      id: 4,
      title: 'How are you feeling?',
      body: 'Take a moment to check in with yourself',
      channelId: _moodChannelId,
      payload: 'mood_check',
    );
  }

  // Show mission completion reminder
  Future<void> showMissionCompletionReminder() async {
    await _showNotification(
      id: 5,
      title: 'Mission Progress',
      body: 'You have missions waiting to be completed!',
      channelId: _missionChannelId,
      payload: 'mission_reminder',
    );
  }

  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    required String channelId,
    String? payload,
  }) async {
    if (!_isInitialized) await initialize();

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId == _buddyChannelId
          ? 'Buddy Notifications'
          : channelId == _missionChannelId
          ? 'Mission Notifications'
          : 'Mood Check Notifications',
      channelDescription: 'Notifications for the Camarra app',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(id, title, body, details, payload: payload);
  }

  // Schedule daily mission reminder
  Future<void> scheduleDailyMissionReminder({
    required String missionTitle,
    required int hour,
    required int minute,
  }) async {
    if (!_isInitialized) await initialize();

    final androidDetails = AndroidNotificationDetails(
      _missionChannelId,
      'Mission Notifications',
      channelDescription: 'Notifications for daily missions',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const iosDetails = DarwinNotificationDetails();

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Schedule for today at the specified time
    final scheduledDate = _nextInstanceOfTime(hour, minute);

    await _notifications.zonedSchedule(
      6, // Unique ID for scheduled notifications
      'Daily Mission Reminder',
      'Complete your mission: $missionTitle',
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'daily_mission',
    );
  }

  // Schedule mood check reminder
  Future<void> scheduleMoodCheckReminder({
    required int hour,
    required int minute,
    int frequency = 1, // Days between mood checks
  }) async {
    if (!_isInitialized) await initialize();

    final androidDetails = AndroidNotificationDetails(
      _moodChannelId,
      'Mood Check Notifications',
      channelDescription: 'Notifications for mood checks',
      importance: Importance.low,
      priority: Priority.low,
    );

    const iosDetails = DarwinNotificationDetails();

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Schedule for today at the specified time
    final scheduledDate = _nextInstanceOfTime(hour, minute);

    await _notifications.zonedSchedule(
      7, // Unique ID for mood check notifications
      'How are you feeling?',
      'Take a moment to check in with yourself',
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'mood_check',
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // Schedule streak reminder notification
  Future<void> scheduleStreakReminder({
    required int hour,
    required int minute,
  }) async {
    if (!_isInitialized) await initialize();

    final androidDetails = AndroidNotificationDetails(
      _streakChannelId,
      'Streak Notifications',
      channelDescription: 'Notifications for maintaining streaks',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Schedule for today at the specified time
    final scheduledDate = _nextInstanceOfTime(hour, minute);

    await _notifications.zonedSchedule(
      8, // Unique ID for streak notifications
      '🔥 Don\'t Break Your Streak!',
      'Send a message to your buddy to keep your chat streak alive',
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'streak_reminder',
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  // Cancel specific notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  // Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  // Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final androidImplementation = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImplementation != null) {
      return await androidImplementation.areNotificationsEnabled() ?? false;
    }

    return true; // Default to true for other platforms
  }

  // Request notification permissions
  Future<bool> requestPermissions() async {
    final androidImplementation = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImplementation != null) {
      return await androidImplementation.requestNotificationsPermission() ??
          false;
    }

    return true; // Default to true for other platforms
  }

  // Save notification settings
  Future<void> saveNotificationSettings(
    String userId,
    Map<String, dynamic> settings,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'notification_settings_$userId';
      await prefs.setString(key, settings.toString());
    } catch (e) {
      if (kDebugMode) {
        print('Error saving notification settings: $e');
      }
    }
  }

  // Get notification settings
  Future<Map<String, dynamic>?> getNotificationSettings(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'notification_settings_$userId';
      final settingsString = prefs.getString(key);

      if (settingsString != null) {
        // Simple parsing - in a real app you'd use JSON
        final settings = <String, dynamic>{
          'notificationsEnabled': true,
          'dailyMissionReminders': true,
          'moodCheckReminders': true,
          'buddyMessageNotifications': true,
          'streakReminders': true,
        };
        return settings;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting notification settings: $e');
      }
      return null;
    }
  }
}
