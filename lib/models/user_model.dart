import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String username;
  final DateTime createdAt;
  final int level;
  final int xp;
  final bool premium;
  final bool dailyMissionCompleted;
  final Map<String, int> streaks;
  final String? mood;
  final String? buddyId;
  final String? profilePictureUrl;
  final String? timezone;
  final OnboardingData onboarding;
  final UserSettings settings;

  const UserModel({
    required this.uid,
    required this.email,
    required this.username,
    required this.createdAt,
    required this.level,
    required this.xp,
    required this.premium,
    required this.dailyMissionCompleted,
    required this.streaks,
    this.mood,
    this.buddyId,
    this.profilePictureUrl,
    this.timezone,
    required this.onboarding,
    required this.settings,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      username: data['username'] ?? data['email']?.split('@')[0] ?? 'User',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      level: data['level'] ?? 1,
      xp: data['xp'] ?? 0,
      premium: data['premium'] ?? false,
      dailyMissionCompleted: data['dailyMissionCompleted'] ?? false,
      streaks:
          Map<String, dynamic>.from(
            data['streaks'] ?? {'mission': 0, 'chat': 0, 'xp': 0},
          ).map(
            (key, value) => MapEntry(
              key,
              value is int ? value : int.tryParse(value.toString()) ?? 0,
            ),
          ),
      mood: data['mood'],
      buddyId: data['buddyId'],
      profilePictureUrl: data['profilePictureUrl'],
      timezone: data['timezone'],
      // Handle both nested onboarding and flat structure
      onboarding: data['onboarding'] != null
          ? OnboardingData.fromMap(data['onboarding'])
          : OnboardingData.fromMap({
              'goal': data['goal'] ?? '',
              'customGoal': data['customGoal'],
              'mood': data['mood'] ?? '',
              'mode': data['mode'] ?? '',
              'socialComfort': data['socialComfort'] ?? '',
              'talkFrequency': data['talkFrequency'] ?? '',
            }),
      settings: UserSettings.fromMap(data['settings'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'username': username,
      'createdAt': Timestamp.fromDate(createdAt),
      'level': level,
      'xp': xp,
      'premium': premium,
      'dailyMissionCompleted': dailyMissionCompleted,
      'streaks': streaks,
      'mood': mood,
      'buddyId': buddyId,
      'profilePictureUrl': profilePictureUrl,
      'timezone': timezone,
      // Keep the flat structure for backward compatibility
      'goal': onboarding.goal,
      'customGoal': onboarding.customGoal,
      'mode': onboarding.mode,
      'socialComfort': onboarding.socialComfort,
      'talkFrequency': onboarding.talkFrequency,
      'settings': settings.toMap(),
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? username,
    DateTime? createdAt,
    int? level,
    int? xp,
    bool? premium,
    bool? dailyMissionCompleted,
    Map<String, int>? streaks,
    String? mood,
    String? buddyId,
    String? profilePictureUrl,
    String? timezone,
    OnboardingData? onboarding,
    UserSettings? settings,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      username: username ?? this.username,
      createdAt: createdAt ?? this.createdAt,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      premium: premium ?? this.premium,
      dailyMissionCompleted:
          dailyMissionCompleted ?? this.dailyMissionCompleted,
      streaks: streaks ?? this.streaks,
      mood: mood ?? this.mood,
      buddyId: buddyId ?? this.buddyId,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      timezone: timezone ?? this.timezone,
      onboarding: onboarding ?? this.onboarding,
      settings: settings ?? this.settings,
    );
  }
}

class OnboardingData {
  final String goal;
  final String? customGoal;
  final String mood;
  final String mode;
  final String socialComfort;
  final String talkFrequency;

  const OnboardingData({
    required this.goal,
    this.customGoal,
    required this.mood,
    required this.mode,
    required this.socialComfort,
    required this.talkFrequency,
  });

  factory OnboardingData.fromMap(Map<String, dynamic> data) {
    return OnboardingData(
      goal: data['goal'] ?? '',
      customGoal: data['customGoal'],
      mood: data['mood'] ?? '',
      mode: data['mode'] ?? '',
      socialComfort: data['socialComfort'] ?? '',
      talkFrequency: data['talkFrequency'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'goal': goal,
      'customGoal': customGoal,
      'mood': mood,
      'mode': mode,
      'socialComfort': socialComfort,
      'talkFrequency': talkFrequency,
    };
  }

  OnboardingData copyWith({
    String? goal,
    String? customGoal,
    String? mood,
    String? mode,
    String? socialComfort,
    String? talkFrequency,
  }) {
    return OnboardingData(
      goal: goal ?? this.goal,
      customGoal: customGoal ?? this.customGoal,
      mood: mood ?? this.mood,
      mode: mode ?? this.mode,
      socialComfort: socialComfort ?? this.socialComfort,
      talkFrequency: talkFrequency ?? this.talkFrequency,
    );
  }
}

class UserSettings {
  // Preferences
  final bool darkModeEnabled;
  final bool soundEnabled;
  final String language;

  // Notifications
  final bool pushNotificationsEnabled;
  final String moodCheckInFrequency;
  final bool missionRemindersEnabled;
  final bool buddyMessagesEnabled;

  // Privacy & Security
  final bool dataCollectionEnabled;
  final bool analyticsEnabled;

  // Account
  final DateTime? lastDataExport;
  final DateTime? lastPasswordChange;

  const UserSettings({
    this.darkModeEnabled = false,
    this.soundEnabled = true,
    this.language = 'English',
    this.pushNotificationsEnabled = true,
    this.moodCheckInFrequency = 'Every 3 days',
    this.missionRemindersEnabled = true,
    this.buddyMessagesEnabled = true,
    this.dataCollectionEnabled = true,
    this.analyticsEnabled = true,
    this.lastDataExport,
    this.lastPasswordChange,
  });

  factory UserSettings.fromMap(Map<String, dynamic> data) {
    return UserSettings(
      darkModeEnabled: data['darkModeEnabled'] ?? false,
      soundEnabled: data['soundEnabled'] ?? true,
      language: data['language'] ?? 'English',
      pushNotificationsEnabled: data['pushNotificationsEnabled'] ?? true,
      moodCheckInFrequency: data['moodCheckInFrequency'] ?? 'Every 3 days',
      missionRemindersEnabled: data['missionRemindersEnabled'] ?? true,
      buddyMessagesEnabled: data['buddyMessagesEnabled'] ?? true,
      dataCollectionEnabled: data['dataCollectionEnabled'] ?? true,
      analyticsEnabled: data['analyticsEnabled'] ?? true,
      lastDataExport: data['lastDataExport'] != null
          ? (data['lastDataExport'] as Timestamp).toDate()
          : null,
      lastPasswordChange: data['lastPasswordChange'] != null
          ? (data['lastPasswordChange'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'darkModeEnabled': darkModeEnabled,
      'soundEnabled': soundEnabled,
      'language': language,
      'pushNotificationsEnabled': pushNotificationsEnabled,
      'moodCheckInFrequency': moodCheckInFrequency,
      'missionRemindersEnabled': missionRemindersEnabled,
      'buddyMessagesEnabled': buddyMessagesEnabled,
      'dataCollectionEnabled': dataCollectionEnabled,
      'analyticsEnabled': analyticsEnabled,
      'lastDataExport': lastDataExport != null
          ? Timestamp.fromDate(lastDataExport!)
          : null,
      'lastPasswordChange': lastPasswordChange != null
          ? Timestamp.fromDate(lastPasswordChange!)
          : null,
    };
  }

  UserSettings copyWith({
    bool? darkModeEnabled,
    bool? soundEnabled,
    String? language,
    bool? pushNotificationsEnabled,
    String? moodCheckInFrequency,
    bool? missionRemindersEnabled,
    bool? buddyMessagesEnabled,
    bool? dataCollectionEnabled,
    bool? analyticsEnabled,
    DateTime? lastDataExport,
    DateTime? lastPasswordChange,
  }) {
    return UserSettings(
      darkModeEnabled: darkModeEnabled ?? this.darkModeEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      language: language ?? this.language,
      pushNotificationsEnabled:
          pushNotificationsEnabled ?? this.pushNotificationsEnabled,
      moodCheckInFrequency: moodCheckInFrequency ?? this.moodCheckInFrequency,
      missionRemindersEnabled:
          missionRemindersEnabled ?? this.missionRemindersEnabled,
      buddyMessagesEnabled: buddyMessagesEnabled ?? this.buddyMessagesEnabled,
      dataCollectionEnabled:
          dataCollectionEnabled ?? this.dataCollectionEnabled,
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
      lastDataExport: lastDataExport ?? this.lastDataExport,
      lastPasswordChange: lastPasswordChange ?? this.lastPasswordChange,
    );
  }
}
