import 'package:cloud_firestore/cloud_firestore.dart';

// Book Model - represents a learning book with 5 chapters
class BookModel {
  final String id;
  final String title;
  final String description;
  final String theme;
  final int bookNumber; // 1-10
  final DateTime createdAt;
  final DateTime? completedAt;
  final String userId;
  final Map<String, dynamic>? aiMetadata;
  final BookStatus status;
  final int completedChapters;
  final double averageCompletionTime; // in hours
  final String difficultyLevel; // based on user performance

  const BookModel({
    required this.id,
    required this.title,
    required this.description,
    required this.theme,
    required this.bookNumber,
    required this.createdAt,
    this.completedAt,
    required this.userId,
    this.aiMetadata,
    required this.status,
    required this.completedChapters,
    required this.averageCompletionTime,
    required this.difficultyLevel,
  });

  factory BookModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BookModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      theme: data['theme'] ?? '',
      bookNumber: data['bookNumber'] ?? 1,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
      userId: data['userId'] ?? '',
      aiMetadata: data['aiMetadata'],
      status: BookStatus.values.firstWhere(
        (e) => e.toString().split('.').last == data['status'],
        orElse: () => BookStatus.locked,
      ),
      completedChapters: data['completedChapters'] ?? 0,
      averageCompletionTime: (data['averageCompletionTime'] ?? 0.0).toDouble(),
      difficultyLevel: data['difficultyLevel'] ?? 'medium',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'theme': theme,
      'bookNumber': bookNumber,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
      'userId': userId,
      'aiMetadata': aiMetadata,
      'status': status.toString().split('.').last,
      'completedChapters': completedChapters,
      'averageCompletionTime': averageCompletionTime,
      'difficultyLevel': difficultyLevel,
    };
  }

  bool get isCompleted => completedChapters >= 5;
  double get progress => completedChapters / 5.0;
  bool get isUnlocked =>
      status == BookStatus.available || status == BookStatus.inProgress;

  BookModel copyWith({
    String? id,
    String? title,
    String? description,
    String? theme,
    int? bookNumber,
    DateTime? createdAt,
    DateTime? completedAt,
    String? userId,
    Map<String, dynamic>? aiMetadata,
    BookStatus? status,
    int? completedChapters,
    double? averageCompletionTime,
    String? difficultyLevel,
  }) {
    return BookModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      theme: theme ?? this.theme,
      bookNumber: bookNumber ?? this.bookNumber,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      userId: userId ?? this.userId,
      aiMetadata: aiMetadata ?? this.aiMetadata,
      status: status ?? this.status,
      completedChapters: completedChapters ?? this.completedChapters,
      averageCompletionTime:
          averageCompletionTime ?? this.averageCompletionTime,
      difficultyLevel: difficultyLevel ?? this.difficultyLevel,
    );
  }
}

enum BookStatus { locked, available, inProgress, completed }

// Chapter Model - represents a single chapter with missions within a book
class ChapterModel {
  final String id;
  final String title;
  final String missionObjective; // What the user needs to achieve
  final List<String> missionTasks; // Specific tasks to complete
  final String missionInstructions; // How to complete the mission
  final String completionCriteria; // What constitutes completion
  final int chapterNumber; // 1-5
  final String bookId;
  final String userId;
  final bool completed;
  final DateTime createdAt;
  final DateTime? completedAt;
  final int xpReward;
  final String difficulty;
  final Map<String, dynamic>? aiMetadata;
  final double? completionTime; // in hours
  final String? userFeedback; // user's reflection/feedback
  final int? userRating; // 1-5 stars
  final List<String>? completedTasks; // Track which tasks are done
  final String? userSubmission; // User's mission submission/response

  const ChapterModel({
    required this.id,
    required this.title,
    required this.missionObjective,
    required this.missionTasks,
    required this.missionInstructions,
    required this.completionCriteria,
    required this.chapterNumber,
    required this.bookId,
    required this.userId,
    required this.completed,
    required this.createdAt,
    this.completedAt,
    required this.xpReward,
    required this.difficulty,
    this.aiMetadata,
    this.completionTime,
    this.userFeedback,
    this.userRating,
    this.completedTasks,
    this.userSubmission,
  });

  factory ChapterModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChapterModel(
      id: doc.id,
      title: data['title'] ?? '',
      missionObjective: data['missionObjective'] ?? '',
      missionTasks: List<String>.from(data['missionTasks'] ?? []),
      missionInstructions: data['missionInstructions'] ?? '',
      completionCriteria: data['completionCriteria'] ?? '',
      chapterNumber: data['chapterNumber'] ?? 1,
      bookId: data['bookId'] ?? '',
      userId: data['userId'] ?? '',
      completed: data['completed'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
      xpReward: data['xpReward'] ?? 25,
      difficulty: data['difficulty'] ?? 'medium',
      aiMetadata: data['aiMetadata'],
      completionTime: data['completionTime']?.toDouble(),
      userFeedback: data['userFeedback'],
      userRating: data['userRating'],
      completedTasks: data['completedTasks'] != null
          ? List<String>.from(data['completedTasks'])
          : null,
      userSubmission: data['userSubmission'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'missionObjective': missionObjective,
      'missionTasks': missionTasks,
      'missionInstructions': missionInstructions,
      'completionCriteria': completionCriteria,
      'chapterNumber': chapterNumber,
      'bookId': bookId,
      'userId': userId,
      'completed': completed,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
      'xpReward': xpReward,
      'difficulty': difficulty,
      'aiMetadata': aiMetadata,
      'completionTime': completionTime,
      'userFeedback': userFeedback,
      'userRating': userRating,
      'completedTasks': completedTasks,
      'userSubmission': userSubmission,
    };
  }

  ChapterModel copyWith({
    String? id,
    String? title,
    String? missionObjective,
    List<String>? missionTasks,
    String? missionInstructions,
    String? completionCriteria,
    int? chapterNumber,
    String? bookId,
    String? userId,
    bool? completed,
    DateTime? createdAt,
    DateTime? completedAt,
    int? xpReward,
    String? difficulty,
    Map<String, dynamic>? aiMetadata,
    double? completionTime,
    String? userFeedback,
    int? userRating,
    List<String>? completedTasks,
    String? userSubmission,
  }) {
    return ChapterModel(
      id: id ?? this.id,
      title: title ?? this.title,
      missionObjective: missionObjective ?? this.missionObjective,
      missionTasks: missionTasks ?? this.missionTasks,
      missionInstructions: missionInstructions ?? this.missionInstructions,
      completionCriteria: completionCriteria ?? this.completionCriteria,
      chapterNumber: chapterNumber ?? this.chapterNumber,
      bookId: bookId ?? this.bookId,
      userId: userId ?? this.userId,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      xpReward: xpReward ?? this.xpReward,
      difficulty: difficulty ?? this.difficulty,
      aiMetadata: aiMetadata ?? this.aiMetadata,
      completionTime: completionTime ?? this.completionTime,
      userFeedback: userFeedback ?? this.userFeedback,
      userRating: userRating ?? this.userRating,
      completedTasks: completedTasks ?? this.completedTasks,
      userSubmission: userSubmission ?? this.userSubmission,
    );
  }
}

// User Learning Analytics - tracks user progress and preferences
class UserLearningAnalytics {
  final String userId;
  final int totalBooksCompleted;
  final int totalChaptersCompleted;
  final double averageChapterCompletionTime; // in hours
  final String preferredDifficulty;
  final List<String> favoriteThemes;
  final Map<String, int> themeCompletionCount;
  final DateTime lastActiveDate;
  final int currentStreak; // consecutive days
  final int longestStreak;
  final Map<String, dynamic>? learningPreferences;
  // New fields for progressive difficulty and AI context
  final List<CompletedMission> completedMissionsHistory;
  final Map<String, int> missionTypeCompletionCount;
  final Map<String, double>
  difficultyProgression; // tracks difficulty level per theme/type
  final List<String>
  generatedContentHistory; // tracks AI-generated content to avoid repetition
  final Map<String, int>
  skillLevelByTheme; // tracks user's skill level in different areas

  const UserLearningAnalytics({
    required this.userId,
    required this.totalBooksCompleted,
    required this.totalChaptersCompleted,
    required this.averageChapterCompletionTime,
    required this.preferredDifficulty,
    required this.favoriteThemes,
    required this.themeCompletionCount,
    required this.lastActiveDate,
    required this.currentStreak,
    required this.longestStreak,
    this.learningPreferences,
    this.completedMissionsHistory = const [],
    this.missionTypeCompletionCount = const {},
    this.difficultyProgression = const {},
    this.generatedContentHistory = const [],
    this.skillLevelByTheme = const {},
  });

  factory UserLearningAnalytics.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserLearningAnalytics(
      userId: doc.id,
      totalBooksCompleted: data['totalBooksCompleted'] ?? 0,
      totalChaptersCompleted: data['totalChaptersCompleted'] ?? 0,
      averageChapterCompletionTime:
          (data['averageChapterCompletionTime'] ?? 0.0).toDouble(),
      preferredDifficulty: data['preferredDifficulty'] ?? 'medium',
      favoriteThemes: List<String>.from(data['favoriteThemes'] ?? []),
      themeCompletionCount: Map<String, int>.from(
        data['themeCompletionCount'] ?? {},
      ),
      lastActiveDate: (data['lastActiveDate'] as Timestamp).toDate(),
      currentStreak: data['currentStreak'] ?? 0,
      longestStreak: data['longestStreak'] ?? 0,
      learningPreferences: data['learningPreferences'],
      completedMissionsHistory:
          (data['completedMissionsHistory'] as List<dynamic>?)
              ?.map((e) => CompletedMission.fromMap(e))
              .toList() ??
          [],
      missionTypeCompletionCount: Map<String, int>.from(
        data['missionTypeCompletionCount'] ?? {},
      ),
      difficultyProgression: Map<String, double>.from(
        data['difficultyProgression'] ?? {},
      ),
      generatedContentHistory: List<String>.from(
        data['generatedContentHistory'] ?? [],
      ),
      skillLevelByTheme: Map<String, int>.from(data['skillLevelByTheme'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'totalBooksCompleted': totalBooksCompleted,
      'totalChaptersCompleted': totalChaptersCompleted,
      'averageChapterCompletionTime': averageChapterCompletionTime,
      'preferredDifficulty': preferredDifficulty,
      'favoriteThemes': favoriteThemes,
      'themeCompletionCount': themeCompletionCount,
      'lastActiveDate': Timestamp.fromDate(lastActiveDate),
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'learningPreferences': learningPreferences,
      'completedMissionsHistory': completedMissionsHistory
          .map((mission) => mission.toMap())
          .toList(),
      'missionTypeCompletionCount': missionTypeCompletionCount,
      'difficultyProgression': difficultyProgression,
      'generatedContentHistory': generatedContentHistory,
      'skillLevelByTheme': skillLevelByTheme,
    };
  }

  UserLearningAnalytics copyWith({
    String? userId,
    int? totalBooksCompleted,
    int? totalChaptersCompleted,
    double? averageChapterCompletionTime,
    String? preferredDifficulty,
    List<String>? favoriteThemes,
    Map<String, int>? themeCompletionCount,
    DateTime? lastActiveDate,
    int? currentStreak,
    int? longestStreak,
    Map<String, dynamic>? learningPreferences,
    List<CompletedMission>? completedMissionsHistory,
    Map<String, int>? missionTypeCompletionCount,
    Map<String, double>? difficultyProgression,
    List<String>? generatedContentHistory,
    Map<String, int>? skillLevelByTheme,
  }) {
    return UserLearningAnalytics(
      userId: userId ?? this.userId,
      totalBooksCompleted: totalBooksCompleted ?? this.totalBooksCompleted,
      totalChaptersCompleted:
          totalChaptersCompleted ?? this.totalChaptersCompleted,
      averageChapterCompletionTime:
          averageChapterCompletionTime ?? this.averageChapterCompletionTime,
      preferredDifficulty: preferredDifficulty ?? this.preferredDifficulty,
      favoriteThemes: favoriteThemes ?? this.favoriteThemes,
      themeCompletionCount: themeCompletionCount ?? this.themeCompletionCount,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      learningPreferences: learningPreferences ?? this.learningPreferences,
      completedMissionsHistory:
          completedMissionsHistory ?? this.completedMissionsHistory,
      missionTypeCompletionCount:
          missionTypeCompletionCount ?? this.missionTypeCompletionCount,
      difficultyProgression:
          difficultyProgression ?? this.difficultyProgression,
      generatedContentHistory:
          generatedContentHistory ?? this.generatedContentHistory,
      skillLevelByTheme: skillLevelByTheme ?? this.skillLevelByTheme,
    );
  }
}

// New model to track completed missions for AI context
class CompletedMission {
  final String bookTitle;
  final String chapterTitle;
  final String missionType;
  final String bookTheme;
  final int bookNumber;
  final int chapterNumber;
  final DateTime completedAt;
  final String difficulty;
  final String objective;
  final List<String> tasks;

  const CompletedMission({
    required this.bookTitle,
    required this.chapterTitle,
    required this.missionType,
    required this.bookTheme,
    required this.bookNumber,
    required this.chapterNumber,
    required this.completedAt,
    required this.difficulty,
    required this.objective,
    required this.tasks,
  });

  factory CompletedMission.fromMap(Map<String, dynamic> map) {
    return CompletedMission(
      bookTitle: map['bookTitle'] ?? '',
      chapterTitle: map['chapterTitle'] ?? '',
      missionType: map['missionType'] ?? '',
      bookTheme: map['bookTheme'] ?? '',
      bookNumber: map['bookNumber'] ?? 0,
      chapterNumber: map['chapterNumber'] ?? 0,
      completedAt: (map['completedAt'] as Timestamp).toDate(),
      difficulty: map['difficulty'] ?? 'medium',
      objective: map['objective'] ?? '',
      tasks: List<String>.from(map['tasks'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bookTitle': bookTitle,
      'chapterTitle': chapterTitle,
      'missionType': missionType,
      'bookTheme': bookTheme,
      'bookNumber': bookNumber,
      'chapterNumber': chapterNumber,
      'completedAt': Timestamp.fromDate(completedAt),
      'difficulty': difficulty,
      'objective': objective,
      'tasks': tasks,
    };
  }
}

// Daily Mission (user-specific, personalized for each user)
class DailyMissionModel {
  final String id;
  final String content;
  final DateTime createdAt;
  final String difficulty;
  final int xpReward;
  final bool isCompleted;
  final DateTime? completedAt;

  const DailyMissionModel({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.difficulty,
    required this.xpReward,
    this.isCompleted = false,
    this.completedAt,
  });

  factory DailyMissionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DailyMissionModel(
      id: doc.id,
      content:
          data['text'] ?? '', // Your structure uses 'text' instead of 'content'
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      difficulty: data['difficulty'] ?? 'medium',
      xpReward: data['xpReward'] ?? 10,
      isCompleted: data['isCompleted'] ?? false,
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'text': content, // Your structure uses 'text' instead of 'content'
      'createdAt': Timestamp.fromDate(createdAt),
      'difficulty': difficulty,
      'xpReward': xpReward,
      'isCompleted': isCompleted,
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
    };
  }

  DailyMissionModel copyWith({
    String? id,
    String? content,
    DateTime? createdAt,
    String? difficulty,
    int? xpReward,
    bool? isCompleted,
    DateTime? completedAt,
  }) {
    return DailyMissionModel(
      id: id ?? this.id,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      difficulty: difficulty ?? this.difficulty,
      xpReward: xpReward ?? this.xpReward,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

// Main Mission (user-specific, part of a campaign) - Legacy for backward compatibility
class MainMissionModel {
  final String id;
  final String title;
  final String description;
  final bool completed;
  final DateTime createdAt;
  final int order;
  final String difficulty;
  final int xpReward;
  final String book;
  final String chapter;

  const MainMissionModel({
    required this.id,
    required this.title,
    required this.description,
    required this.completed,
    required this.createdAt,
    required this.order,
    required this.difficulty,
    required this.xpReward,
    required this.book,
    required this.chapter,
  });

  factory MainMissionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MainMissionModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      completed: data['completed'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      order: data['order'] ?? 0,
      difficulty: data['difficulty'] ?? 'medium',
      xpReward: data['xpReward'] ?? 25,
      book: data['book'] ?? '',
      chapter: data['chapter'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'completed': completed,
      'createdAt': Timestamp.fromDate(createdAt),
      'order': order,
      'difficulty': difficulty,
      'xpReward': xpReward,
      'book': book,
      'chapter': chapter,
    };
  }

  MainMissionModel copyWith({
    String? id,
    String? title,
    String? description,
    bool? completed,
    DateTime? createdAt,
    int? order,
    String? difficulty,
    int? xpReward,
    String? book,
    String? chapter,
  }) {
    return MainMissionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      order: order ?? this.order,
      difficulty: difficulty ?? this.difficulty,
      xpReward: xpReward ?? this.xpReward,
      book: book ?? this.book,
      chapter: chapter ?? this.chapter,
    );
  }
}

// Legacy models for backward compatibility
class MissionModel {
  final String id;
  final String title;
  final String description;
  final MissionType type;
  final MissionStatus status;
  final int xpReward;
  final String difficulty;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String userId;
  final String? campaignId;
  final int? campaignOrder;
  final Map<String, dynamic>? aiMetadata;

  const MissionModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.status,
    required this.xpReward,
    required this.difficulty,
    required this.createdAt,
    this.completedAt,
    required this.userId,
    this.campaignId,
    this.campaignOrder,
    this.aiMetadata,
  });

  factory MissionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MissionModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      type: MissionType.values.firstWhere(
        (e) => e.toString().split('.').last == data['type'],
        orElse: () => MissionType.daily,
      ),
      status: MissionStatus.values.firstWhere(
        (e) => e.toString().split('.').last == data['status'],
        orElse: () => MissionStatus.available,
      ),
      xpReward: data['xpReward'] ?? 10,
      difficulty: data['difficulty'] ?? 'medium',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
      userId: data['userId'] ?? '',
      campaignId: data['campaignId'],
      campaignOrder: data['campaignOrder'],
      aiMetadata: data['aiMetadata'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'xpReward': xpReward,
      'difficulty': difficulty,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
      'userId': userId,
      'campaignId': campaignId,
      'campaignOrder': campaignOrder,
      'aiMetadata': aiMetadata,
    };
  }

  MissionModel copyWith({
    String? id,
    String? title,
    String? description,
    MissionType? type,
    MissionStatus? status,
    int? xpReward,
    String? difficulty,
    DateTime? createdAt,
    DateTime? completedAt,
    String? userId,
    String? campaignId,
    int? campaignOrder,
    Map<String, dynamic>? aiMetadata,
  }) {
    return MissionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status,
      xpReward: xpReward ?? this.xpReward,
      difficulty: difficulty ?? this.difficulty,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      userId: userId ?? this.userId,
      campaignId: campaignId ?? this.campaignId,
      campaignOrder: campaignOrder ?? this.campaignOrder,
      aiMetadata: aiMetadata ?? this.aiMetadata,
    );
  }
}

enum MissionType { daily, main }

enum MissionStatus { available, inProgress, completed, locked }

// Legacy CampaignModel for backward compatibility
class CampaignModel {
  final String id;
  final String title;
  final String description;
  final String bookName;
  final int totalMissions;
  final int completedMissions;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String userId;
  final Map<String, dynamic>? aiMetadata;

  const CampaignModel({
    required this.id,
    required this.title,
    required this.description,
    required this.bookName,
    required this.totalMissions,
    required this.completedMissions,
    required this.createdAt,
    this.completedAt,
    required this.userId,
    this.aiMetadata,
  });

  factory CampaignModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CampaignModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      bookName: data['bookName'] ?? '',
      totalMissions: data['totalMissions'] ?? 0,
      completedMissions: data['completedMissions'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
      userId: data['userId'] ?? '',
      aiMetadata: data['aiMetadata'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'bookName': bookName,
      'totalMissions': totalMissions,
      'completedMissions': completedMissions,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
      'userId': userId,
      'aiMetadata': aiMetadata,
    };
  }

  double get progress =>
      totalMissions > 0 ? completedMissions / totalMissions : 0.0;
  bool get isCompleted => completedMissions >= totalMissions;

  CampaignModel copyWith({
    String? id,
    String? title,
    String? description,
    String? bookName,
    int? totalMissions,
    int? completedMissions,
    DateTime? createdAt,
    DateTime? completedAt,
    String? userId,
    Map<String, dynamic>? aiMetadata,
  }) {
    return CampaignModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      bookName: bookName ?? this.bookName,
      totalMissions: totalMissions ?? this.totalMissions,
      completedMissions: completedMissions ?? this.completedMissions,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      userId: userId ?? this.userId,
      aiMetadata: aiMetadata ?? this.aiMetadata,
    );
  }
}
