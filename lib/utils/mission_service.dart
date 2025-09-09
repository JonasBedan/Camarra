import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/mission_model.dart';
import 'ai_router.dart';
import 'user_service.dart';
import 'sound_service.dart';
import 'premium_service.dart';
import 'premium_features_impl.dart';
import 'ai_chat_service.dart';

class MissionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();
  final SoundService _soundService = SoundService();
  final PremiumService _premiumService = PremiumService();
  final PremiumFeaturesImpl _premiumFeatures = PremiumFeaturesImpl();
  final AIChatService _aiChatService = AIChatService();

  // Book-based system methods
  Stream<List<BookModel>> streamUserBooks(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('books')
        .orderBy('bookNumber')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => BookModel.fromFirestore(doc)).toList(),
        );
  }

  Stream<List<ChapterModel>> streamBookChapters(String userId, String bookId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('books')
        .doc(bookId)
        .collection('chapters')
        .orderBy('chapterNumber')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChapterModel.fromFirestore(doc))
              .toList(),
        );
  }

  Stream<UserLearningAnalytics?> streamUserAnalytics(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('learningAnalytics')
        .doc('main')
        .snapshots()
        .map(
          (doc) => doc.exists ? UserLearningAnalytics.fromFirestore(doc) : null,
        );
  }

  // Get user learning analytics (Future version)
  Future<UserLearningAnalytics?> getUserLearningAnalytics(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('learningAnalytics')
          .doc('main')
          .get();

      return doc.exists ? UserLearningAnalytics.fromFirestore(doc) : null;
    } catch (e) {
      print('Error getting user learning analytics: $e');
      return null;
    }
  }

  // Initialize user's learning journey
  Future<void> initializeUserLearningJourney(String userId) async {
    try {
      // Create user analytics document
      final analytics = UserLearningAnalytics(
        userId: userId,
        totalBooksCompleted: 0,
        totalChaptersCompleted: 0,
        averageChapterCompletionTime: 0.0,
        preferredDifficulty: 'medium',
        favoriteThemes: [],
        themeCompletionCount: {},
        lastActiveDate: DateTime.now(),
        currentStreak: 0,
        longestStreak: 0,
        learningPreferences: {
          'learningStyle': 'balanced',
          'preferredTimeOfDay': 'morning',
          'motivationLevel': 'high',
        },
        completedMissionsHistory: [],
        missionTypeCompletionCount: {},
        difficultyProgression: {},
        generatedContentHistory: [],
        skillLevelByTheme: {},
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('learningAnalytics')
          .doc('main')
          .set(analytics.toFirestore());

      // Generate first book
      await _generateFirstBook(userId);
    } catch (e) {
      print('Error initializing user learning journey: $e');
      rethrow;
    }
  }

  // Initialize user's learning journey with onboarding data
  Future<void> initializeUserLearningJourneyWithOnboarding(
    String userId,
    OnboardingData onboardingData,
  ) async {
    try {
      // Create user analytics document with onboarding insights
      final analytics = UserLearningAnalytics(
        userId: userId,
        totalBooksCompleted: 0,
        totalChaptersCompleted: 0,
        averageChapterCompletionTime: 0.0,
        preferredDifficulty: _determineDifficultyFromOnboarding(onboardingData),
        favoriteThemes: _determineThemesFromOnboarding(onboardingData),
        themeCompletionCount: {},
        lastActiveDate: DateTime.now(),
        currentStreak: 0,
        longestStreak: 0,
        learningPreferences: {
          'learningStyle': onboardingData.mode.toLowerCase(),
          'preferredTimeOfDay': _determineTimePreference(
            onboardingData.talkFrequency,
          ),
          'motivationLevel': _determineMotivationLevel(onboardingData.mood),
          'socialComfortLevel': onboardingData.socialComfort,
          'primaryGoal': onboardingData.goal,
          'customGoal': onboardingData.customGoal,
        },
        completedMissionsHistory: [],
        missionTypeCompletionCount: {},
        difficultyProgression: {},
        generatedContentHistory: [],
        skillLevelByTheme: {},
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('learningAnalytics')
          .doc('main')
          .set(analytics.toFirestore());

      // Generate first personalized book based on onboarding
      await _generatePersonalizedFirstBook(userId, onboardingData);
    } catch (e) {
      print('Error initializing user learning journey with onboarding: $e');
      rethrow;
    }
  }

  // Generate the first book for a new user
  Future<void> _generateFirstBook(String userId) async {
    try {
      // Create 10 locked books upfront with placeholder content
      for (int bookNumber = 1; bookNumber <= 10; bookNumber++) {
        String bookTitle;
        String bookDescription;
        String bookTheme;

        if (bookNumber == 1) {
          // Generate real content for the first book
          bookTitle = await _generateBookTitle(userId, bookNumber);
          bookDescription = await _generateBookDescription(
            bookTitle,
            bookNumber,
          );
          bookTheme = await _generateBookTheme(bookNumber);
        } else {
          // Use generic placeholders for locked books
          bookTitle = 'Book $bookNumber';
          bookDescription =
              'This book will be unlocked as you progress through your learning journey.';
          bookTheme = _getDefaultThemeForBook(bookNumber);
        }

        final book = BookModel(
          id: '', // Will be set by Firestore
          title: bookTitle,
          description: bookDescription,
          theme: bookTheme,
          bookNumber: bookNumber,
          createdAt: DateTime.now(),
          userId: userId,
          status: bookNumber == 1 ? BookStatus.available : BookStatus.locked,
          completedChapters: 0,
          averageCompletionTime: 0.0,
          difficultyLevel: 'medium',
          aiMetadata: {
            'generatedAt': DateTime.now().toIso8601String(),
            'version': '1.0',
            'isPlaceholder':
                bookNumber > 1, // Mark as placeholder for locked books
          },
        );

        final bookDoc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('books')
            .add(book.toFirestore());
        final bookId = bookDoc.id;

        // Only generate chapters for the first book (available)
        if (bookNumber == 1) {
          await _generateBookChapters(bookId, userId, bookTitle, bookTheme, 1);
        }
      }
    } catch (e) {
      print('Error generating first book: $e');
      rethrow;
    }
  }

  // Get default theme for locked books
  String _getDefaultThemeForBook(int bookNumber) {
    final themes = [
      'courage',
      'light',
      'voice',
      'foundation',
      'reflection',
      'transformation',
      'connection',
      'freedom',
      'wisdom',
      'completion',
    ];

    return themes[bookNumber - 1] ?? 'courage';
  }

  // Generate book title using AI
  Future<String> _generateBookTitle(String userId, int bookNumber) async {
    try {
      final prompt =
          '''
Generate a unique and inspiring book title for book number $bookNumber in a personal development series.

Requirements:
- Must be completely different from these existing titles: "The Courage Within", "Light Your Path", "Voice of Strength", "Unshaken Foundation", "Mirror of Growth", "Storm of Change", "Connection Deep", "Fear to Freedom", "Wisdom Rising", "Journey Complete"
- 2-5 words maximum
- Should reflect a specific aspect of personal growth
- Be memorable and impactful
- Avoid generic terms like "journey", "path", "strength" unless used in a unique way

Book $bookNumber themes to consider:
- Book 1: Courage, bravery, facing fears
- Book 2: Clarity, enlightenment, finding direction  
- Book 3: Communication, self-expression, finding voice
- Book 4: Stability, building foundations, core values
- Book 5: Self-reflection, introspection, understanding
- Book 6: Transformation, change, evolution
- Book 7: Relationships, connections, social skills
- Book 8: Liberation, breaking free, independence
- Book 9: Knowledge, insight, understanding
- Book 10: Achievement, completion, mastery

Generate only the title, nothing else.
''';

      final response = await AiRouter.generate(
        task: AiTaskType.feedbackCoach,
        prompt: prompt,
      );

      return response.trim().replaceAll('"', '').replaceAll("'", '');
    } catch (e) {
      // More diverse fallback titles
      final fallbackTitles = [
        'Brave Heart Rising',
        'Clarity in Chaos',
        'Express Your Truth',
        'Solid Ground',
        'Inner Compass',
        'Metamorphosis',
        'Bridge Builder',
        'Breaking Chains',
        'Insight Engine',
        'Peak Performance',
      ];

      return fallbackTitles[bookNumber - 1];
    }
  }

  // Generate book description using AI
  Future<String> _generateBookDescription(
    String bookTitle,
    int bookNumber,
  ) async {
    try {
      final prompt =
          '''
Write a compelling 2-3 sentence description for a personal development book titled "$bookTitle".
This is book number $bookNumber in a series of 10 books about personal growth and self-improvement.

The description should:
- Be inspiring and motivational
- Explain what the reader will learn
- Be 2-3 sentences maximum
- Match the tone and theme of the title

Write only the description, nothing else.
''';

      final response = await AiRouter.generate(
        task: AiTaskType.feedbackCoach,
        prompt: prompt,
      );

      return response.trim();
    } catch (e) {
      return 'Embark on a transformative journey of self-discovery and personal growth. This book will guide you through essential life lessons and help you unlock your full potential.';
    }
  }

  // Generate book theme
  Future<String> _generateBookTheme(int bookNumber) async {
    final themes = [
      'courage',
      'light',
      'voice',
      'foundation',
      'reflection',
      'transformation',
      'connection',
      'freedom',
      'wisdom',
      'completion',
    ];

    return themes[bookNumber - 1];
  }

  // Generate chapters for a book
  Future<void> _generateBookChapters(
    String bookId,
    String userId,
    String bookTitle,
    String bookTheme,
    int bookNumber,
  ) async {
    try {
      for (int chapterNum = 1; chapterNum <= 5; chapterNum++) {
        final chapterTitle = await _generateChapterTitle(
          bookTitle,
          chapterNum,
          bookTheme,
        );

        // Generate mission content instead of description
        final missionContent = await _generateChapterMission(
          bookTitle,
          chapterTitle,
          chapterNum,
          bookTheme,
          bookNumber,
          userId,
        );

        final difficulty = _determineChapterDifficulty(chapterNum, bookNumber);

        final chapter = ChapterModel(
          id: '', // Will be set by Firestore
          title: chapterTitle,
          missionObjective: missionContent['objective'],
          missionTasks: missionContent['tasks'],
          missionInstructions: missionContent['instructions'],
          completionCriteria: missionContent['criteria'],
          chapterNumber: chapterNum,
          bookId: bookId,
          userId: userId,
          completed: false,
          createdAt: DateTime.now(),
          xpReward: _calculateXpReward(chapterNum, bookNumber),
          difficulty: difficulty,
          aiMetadata: {
            'generatedAt': DateTime.now().toIso8601String(),
            'bookNumber': bookNumber,
            'bookTheme': bookTheme,
          },
        );

        await _firestore
            .collection('users')
            .doc(userId)
            .collection('books')
            .doc(bookId)
            .collection('chapters')
            .add(chapter.toFirestore());
      }
    } catch (e) {
      print('Error generating book chapters: $e');
      rethrow;
    }
  }

  // Generate chapter title using AI
  Future<String> _generateChapterTitle(
    String bookTitle,
    int chapterNum,
    String bookTheme,
  ) async {
    try {
      // Create unique prompts for each chapter to ensure diversity
      final chapterPrompts = [
        // Chapter 1 - Focus on discovery and beginnings
        '''
Generate a unique chapter title for chapter 1 of "$bookTitle" (theme: $bookTheme).

Requirements:
- Must be completely different from these existing titles: "Understanding Your Fears", "Building Inner Strength", "Taking the First Step", "Embracing Change", "Celebrating Growth", "The Beginning", "Building Foundations", "Growing Stronger", "Facing Challenges", "Achieving Success", "Awakening Your Potential", "Expanding Your Horizons", "Mastering the Craft", "Applying Your Knowledge", "Integrating Everything"
- 3-6 words maximum
- Focus on discovery, awakening, or first encounters
- Use words like: discover, awaken, explore, reveal, uncover, begin, start, initiate
- Be inspiring and clear
- Avoid generic terms unless used in a unique way

Generate only the title, nothing else.
''',
        // Chapter 2 - Focus on growth and development
        '''
Generate a unique chapter title for chapter 2 of "$bookTitle" (theme: $bookTheme).

Requirements:
- Must be completely different from these existing titles: "Understanding Your Fears", "Building Inner Strength", "Taking the First Step", "Embracing Change", "Celebrating Growth", "The Beginning", "Building Foundations", "Growing Stronger", "Facing Challenges", "Achieving Success", "Awakening Your Potential", "Expanding Your Horizons", "Mastering the Craft", "Applying Your Knowledge", "Integrating Everything"
- 3-6 words maximum
- Focus on growth, development, or building skills
- Use words like: develop, grow, build, strengthen, enhance, cultivate, nurture, evolve
- Be inspiring and clear
- Avoid generic terms unless used in a unique way

Generate only the title, nothing else.
''',
        // Chapter 3 - Focus on mastery and depth
        '''
Generate a unique chapter title for chapter 3 of "$bookTitle" (theme: $bookTheme).

Requirements:
- Must be completely different from these existing titles: "Understanding Your Fears", "Building Inner Strength", "Taking the First Step", "Embracing Change", "Celebrating Growth", "The Beginning", "Building Foundations", "Growing Stronger", "Facing Challenges", "Achieving Success", "Awakening Your Potential", "Expanding Your Horizons", "Mastering the Craft", "Applying Your Knowledge", "Integrating Everything"
- 3-6 words maximum
- Focus on mastery, depth, or advanced concepts
- Use words like: master, deepen, refine, perfect, excel, advance, elevate, transcend
- Be inspiring and clear
- Avoid generic terms unless used in a unique way

Generate only the title, nothing else.
''',
        // Chapter 4 - Focus on application and practice
        '''
Generate a unique chapter title for chapter 4 of "$bookTitle" (theme: $bookTheme).

Requirements:
- Must be completely different from these existing titles: "Understanding Your Fears", "Building Inner Strength", "Taking the First Step", "Embracing Change", "Celebrating Growth", "The Beginning", "Building Foundations", "Growing Stronger", "Facing Challenges", "Achieving Success", "Awakening Your Potential", "Expanding Your Horizons", "Mastering the Craft", "Applying Your Knowledge", "Integrating Everything"
- 3-6 words maximum
- Focus on application, practice, or real-world use
- Use words like: apply, practice, implement, execute, perform, demonstrate, showcase, utilize
- Be inspiring and clear
- Avoid generic terms unless used in a unique way

Generate only the title, nothing else.
''',
        // Chapter 5 - Focus on integration and completion
        '''
Generate a unique chapter title for chapter 5 of "$bookTitle" (theme: $bookTheme).

Requirements:
- Must be completely different from these existing titles: "Understanding Your Fears", "Building Inner Strength", "Taking the First Step", "Embracing Change", "Celebrating Growth", "The Beginning", "Building Foundations", "Growing Stronger", "Facing Challenges", "Achieving Success", "Awakening Your Potential", "Expanding Your Horizons", "Mastering the Craft", "Applying Your Knowledge", "Integrating Everything"
- 3-6 words maximum
- Focus on integration, completion, or celebration
- Use words like: integrate, complete, celebrate, culminate, unite, harmonize, synthesize, finalize
- Be inspiring and clear
- Avoid generic terms unless used in a unique way

Generate only the title, nothing else.
''',
      ];

      final prompt = chapterPrompts[chapterNum - 1];

      final response = await AiRouter.generate(
        task: AiTaskType.feedbackCoach,
        prompt: prompt,
      );

      return response.trim().replaceAll('"', '').replaceAll("'", '');
    } catch (e) {
      // Diverse fallback titles based on chapter number with different themes
      final fallbackTitles = [
        'Discovering New Possibilities',
        'Cultivating Your Strengths',
        'Perfecting Your Approach',
        'Putting Theory Into Practice',
        'Uniting All Your Skills',
      ];

      return fallbackTitles[chapterNum - 1];
    }
  }

  // Generate chapter mission
  Future<Map<String, dynamic>> _generateChapterMission(
    String bookTitle,
    String chapterTitle,
    int chapterNum,
    String bookTheme,
    int bookNumber,
    String userId,
  ) async {
    try {
      // Determine mission type based on book number and chapter
      final missionType = _getMissionTypeForChapter(bookNumber, chapterNum);
      final missionFocus = _getMissionFocusForChapter(chapterNum);

      // Get user analytics for progressive difficulty and AI context
      UserLearningAnalytics? analytics;
      try {
        final analyticsDoc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('learningAnalytics')
            .doc('main')
            .get();

        if (analyticsDoc.exists) {
          analytics = UserLearningAnalytics.fromFirestore(analyticsDoc);
        }
      } catch (e) {
        print('Could not fetch user analytics: $e');
      }

      // Determine difficulty level based on user progress
      final difficulty = analytics != null
          ? _determineDifficultyLevel(
              bookNumber,
              chapterNum,
              analytics,
              missionType,
              bookTheme,
            )
          : 'medium';

      // Generate AI context prompt
      final aiContext = analytics != null
          ? _generateAIContextPrompt(
              analytics,
              bookNumber,
              chapterNum,
              missionType,
              bookTheme,
            )
          : '';

      final prompt =
          '''

You're designing a unique real-world mission for the Camarra app.
This mission is inspired by Chapter $chapterNum: "$chapterTitle" from the book "$bookTitle" (Book $bookNumber, Theme: $bookTheme).

MISSION TYPE: $missionType
CHAPTER FOCUS: $missionFocus
DIFFICULTY LEVEL: $difficulty

$aiContext

Your goal is to generate a meaningful one-day challenge that promotes personal growth and development. The mission should feel fresh, practical, and emotionally relevant to the user – avoid repetition and clichés.

Generate a mission that includes:

    OBJECTIVE: A personal challenge the user can complete in 15–60 minutes.

    TASKS: 2–4 concrete micro-actions that guide the user toward achieving the objective.

    INSTRUCTIONS: Friendly, encouraging steps that help the user carry out the mission, including emotional tips, mindset shifts, or examples.

    CRITERIA: Specific signs or outcomes that tell the user the mission is complete.

Your mission must be:

    Realistic but a little outside the comfort zone

    Thematically linked to the chapter's message and focus

    Adaptable to different user personalities (introvert/extrovert, etc.)

    Positive, doable, and creative

    Varied in approach (not always social interaction)

    PROGRESSIVELY CHALLENGING based on the user's skill level

Format strictly as follows:

OBJECTIVE: [write a personalized goal]
TASKS: [task 1] | [task 2] | [task 3]
INSTRUCTIONS: [step-by-step but relaxed and motivational guidance]
CRITERIA: [how the user knows they are done]

MISSION VARIETY GUIDELINES:
- Book 1: Focus on foundational social skills and self-awareness
- Book 2+: Introduce more creative, reflective, and skill-building missions
- Chapter 1: Discovery and first steps
- Chapter 2: Growth and development  
- Chapter 3: Mastery and depth
- Chapter 4: Application and practice
- Chapter 5: Integration and celebration

MISSION TYPE EXAMPLES(prefer the ones that are more social interaction and less self-reflection, but still use both. use a 3:2 ratio):
- Social Interaction: Conversations, asking questions, giving compliments
- Self-Reflection: Journaling, meditation, self-assessment
- Creative Expression: Writing, drawing, creating something meaningful
- Skill Building: Learning something new, practicing a technique
- Community Engagement: Helping others, volunteering, supporting friends
- Personal Challenge: Stepping outside comfort zone in various ways
- Communication: Different forms of expression and connection
- Mindfulness: Being present, observing, appreciating

DIFFICULTY GUIDELINES:
- Easy: Simple, low-pressure activities, mostly familiar territory
- Medium: Moderate challenge, some new elements, balanced risk/reward
- Hard: Complex challenges, significant comfort zone expansion, advanced skills

Avoid repetitive "walk up to stranger" missions. Be creative and varied!
''';

      final response = await AiRouter.generate(
        task: AiTaskType.feedbackCoach,
        prompt: prompt,
      );

      // Parse the response with improved logic
      final lines = response.trim().split('\n');
      String objective = '';
      List<String> tasks = [];
      String instructions = '';
      String criteria = '';

      print('DEBUG: Raw AI response: $response');
      print('DEBUG: Parsing lines: ${lines.length}');

      for (String line in lines) {
        final trimmedLine = line.trim();
        print('DEBUG: Processing line: "$trimmedLine"');

        if (trimmedLine.startsWith('OBJECTIVE:')) {
          objective = trimmedLine.substring(10).trim();
          print('DEBUG: Found objective: "$objective"');
        } else if (trimmedLine.startsWith('TASKS:')) {
          final tasksStr = trimmedLine.substring(6).trim();
          print('DEBUG: Found tasks string: "$tasksStr"');
          // Try pipe separator first, then comma
          if (tasksStr.contains('|')) {
            tasks = tasksStr
                .split('|')
                .map((t) => t.trim())
                .where((t) => t.isNotEmpty)
                .toList();
            print('DEBUG: Parsed tasks with pipe: $tasks');
          } else {
            tasks = tasksStr
                .split(',')
                .map((t) => t.trim())
                .where((t) => t.isNotEmpty)
                .toList();
            print('DEBUG: Parsed tasks with comma: $tasks');
          }
        } else if (trimmedLine.startsWith('INSTRUCTIONS:')) {
          instructions = trimmedLine.substring(13).trim();
          print('DEBUG: Found instructions: "$instructions"');
        } else if (trimmedLine.startsWith('CRITERIA:')) {
          criteria = trimmedLine.substring(9).trim();
          print('DEBUG: Found criteria: "$criteria"');
        }
      }

      // Ensure we have valid tasks
      if (tasks.isEmpty || tasks.length < 2) {
        print('DEBUG: Tasks empty or insufficient, using fallback tasks');
        tasks = [
          'Find a stranger in a public place',
          'Approach them politely and ask your question',
          'Thank them for their response',
        ];
      }

      return {
        'objective': objective.isNotEmpty
            ? objective
            : 'Complete a simple social interaction to build confidence and communication skills.',
        'tasks': tasks,
        'instructions': instructions.isNotEmpty
            ? instructions
            : 'Follow the specific tasks outlined above. Take your time and approach this challenge with confidence. Remember that every step forward is progress.',
        'criteria': criteria.isNotEmpty
            ? criteria
            : 'You have successfully completed the social interaction and received a response from the person.',
      };
    } catch (e) {
      // Fallback content with practical tasks
      return {
        'objective':
            'Complete a simple social interaction to build confidence and communication skills.',
        'tasks': [
          'Find a stranger in a public place',
          'Approach them politely and ask your question',
          'Thank them for their response',
        ],
        'instructions':
            'Follow the specific tasks outlined above. Take your time and approach this challenge with confidence. Remember that every step forward is progress.',
        'criteria':
            'You have successfully completed the social interaction and received a response from the person.',
      };
    }
  }

  // Helper functions for mission generation
  String _getMissionTypeForChapter(int bookNumber, int chapterNum) {
    // Book 1 focuses on foundational social skills
    if (bookNumber == 1) {
      final types = [
        'Social Interaction',
        'Self-Reflection',
        'Social Interaction',
        'Skill Building',
        'Integration',
      ];
      return types[chapterNum - 1];
    }

    // Books 2+ introduce more variety
    final missionTypes = [
      'Social Interaction',
      'Self-Reflection',
      'Creative Expression',
      'Skill Building',
      'Community Engagement',
      'Personal Challenge',
      'Communication',
      'Mindfulness',
      'Leadership',
      'Empathy Building',
    ];

    // Use chapter number and book number to create variety
    final index =
        ((chapterNum - 1) + (bookNumber - 2) * 3) % missionTypes.length;
    return missionTypes[index];
  }

  String _getMissionFocusForChapter(int chapterNum) {
    final focuses = [
      'Discovery and first steps',
      'Growth and development',
      'Mastery and depth',
      'Application and practice',
      'Integration and celebration',
    ];
    return focuses[chapterNum - 1];
  }

  // New helper functions for progressive difficulty and AI context
  String _determineDifficultyLevel(
    int bookNumber,
    int chapterNum,
    UserLearningAnalytics analytics,
    String missionType,
    String bookTheme,
  ) {
    // Base difficulty increases with book and chapter number
    double baseDifficulty = (bookNumber - 1) * 0.3 + (chapterNum - 1) * 0.1;

    // Adjust based on user's skill level in this theme/type
    final themeSkillLevel = analytics.skillLevelByTheme[bookTheme] ?? 0;
    final typeSkillLevel = analytics.skillLevelByTheme[missionType] ?? 0;
    final averageSkillLevel = (themeSkillLevel + typeSkillLevel) / 2;

    // Adjust difficulty based on skill level (higher skill = higher difficulty)
    double skillAdjustment = averageSkillLevel * 0.2;

    // Consider completion rate for this mission type
    final typeCompletions =
        analytics.missionTypeCompletionCount[missionType] ?? 0;
    double completionAdjustment =
        (typeCompletions / 10.0).clamp(0.0, 1.0) * 0.3;

    // Calculate final difficulty
    double finalDifficulty =
        (baseDifficulty + skillAdjustment + completionAdjustment).clamp(
          0.0,
          1.0,
        );

    // Convert to difficulty string
    if (finalDifficulty < 0.3) return 'easy';
    if (finalDifficulty < 0.7) return 'medium';
    return 'hard';
  }

  String _generateAIContextPrompt(
    UserLearningAnalytics analytics,
    int bookNumber,
    int chapterNum,
    String missionType,
    String bookTheme,
  ) {
    final recentMissions = analytics.completedMissionsHistory
        .take(10) // Last 10 missions
        .where((mission) => mission.missionType == missionType)
        .toList();

    final recentThemes = analytics.completedMissionsHistory
        .take(15) // Last 15 missions
        .where((mission) => mission.bookTheme == bookTheme)
        .toList();

    final generatedContent = analytics.generatedContentHistory
        .take(20)
        .toList();

    String contextPrompt =
        '''
PREVIOUS CONTEXT - Avoid repeating these patterns:

Recent $missionType missions completed:
''';

    for (final mission in recentMissions.take(3)) {
      contextPrompt +=
          '''
- "${mission.objective}" (Book ${mission.bookNumber}, Chapter ${mission.chapterNumber})
''';
    }

    contextPrompt +=
        '''
Recent $bookTheme themed content:
''';

    for (final mission in recentThemes.take(3)) {
      contextPrompt +=
          '''
- "${mission.objective}" (${mission.missionType})
''';
    }

    contextPrompt += '''
Recently generated content to avoid:
''';

    for (final content in generatedContent.take(5)) {
      contextPrompt += '- $content\n';
    }

    contextPrompt +=
        '''
USER PROGRESS:
- Total books completed: ${analytics.totalBooksCompleted}
- Total chapters completed: ${analytics.totalChaptersCompleted}
- Skill level in $bookTheme: ${analytics.skillLevelByTheme[bookTheme] ?? 0}
- Skill level in $missionType: ${analytics.skillLevelByTheme[missionType] ?? 0}
- Current book: $bookNumber, Chapter: $chapterNum

IMPORTANT: Create something NEW and PROGRESSIVELY CHALLENGING based on this context.
''';

    return contextPrompt;
  }

  Future<void> _updateUserProgress(
    String userId,
    String missionType,
    String bookTheme,
    String difficulty,
    String objective,
    List<String> tasks,
    String bookTitle,
    String chapterTitle,
    int bookNumber,
    int chapterNum,
  ) async {
    try {
      final analyticsDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('learningAnalytics')
          .doc('main')
          .get();

      if (!analyticsDoc.exists) return;

      final analytics = UserLearningAnalytics.fromFirestore(analyticsDoc);

      // Update completed missions history
      final newMission = CompletedMission(
        bookTitle: bookTitle,
        chapterTitle: chapterTitle,
        missionType: missionType,
        bookTheme: bookTheme,
        bookNumber: bookNumber,
        chapterNumber: chapterNum,
        completedAt: DateTime.now(),
        difficulty: difficulty,
        objective: objective,
        tasks: tasks,
      );

      final updatedHistory = [
        newMission,
        ...analytics.completedMissionsHistory,
      ];
      if (updatedHistory.length > 50) {
        updatedHistory.removeRange(50, updatedHistory.length);
      }

      // Update mission type completion count
      final updatedTypeCount = Map<String, int>.from(
        analytics.missionTypeCompletionCount,
      );
      updatedTypeCount[missionType] = (updatedTypeCount[missionType] ?? 0) + 1;

      // Update skill levels based on completion
      final updatedSkillLevels = Map<String, int>.from(
        analytics.skillLevelByTheme,
      );
      final currentThemeLevel = updatedSkillLevels[bookTheme] ?? 0;
      final currentTypeLevel = updatedSkillLevels[missionType] ?? 0;

      // Increase skill level based on difficulty
      int skillIncrease = 1;
      if (difficulty == 'hard') skillIncrease = 2;
      if (difficulty == 'easy') skillIncrease = 0;

      updatedSkillLevels[bookTheme] = currentThemeLevel + skillIncrease;
      updatedSkillLevels[missionType] = currentTypeLevel + skillIncrease;

      // Update generated content history
      final updatedContentHistory = [
        objective,
        ...analytics.generatedContentHistory,
      ];
      if (updatedContentHistory.length > 100) {
        updatedContentHistory.removeRange(100, updatedContentHistory.length);
      }

      // Update analytics
      final updatedAnalytics = analytics.copyWith(
        completedMissionsHistory: updatedHistory,
        missionTypeCompletionCount: updatedTypeCount,
        skillLevelByTheme: updatedSkillLevels,
        generatedContentHistory: updatedContentHistory,
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('learningAnalytics')
          .doc('main')
          .set(updatedAnalytics.toFirestore());
    } catch (e) {
      print('Error updating user progress: $e');
    }
  }

  // Fallback methods for mission generation
  String _getFallbackObjective(int chapterNum, String bookTheme) {
    final objectives = [
      'Reflect on your current understanding of $bookTheme and identify areas for growth',
      'Practice applying $bookTheme concepts in a real-world situation',
      'Challenge yourself to step outside your comfort zone related to $bookTheme',
      'Create a plan to integrate $bookTheme principles into your daily life',
      'Celebrate your progress and set new goals for continued growth in $bookTheme',
    ];
    return objectives[chapterNum - 1];
  }

  List<String> _getFallbackTasks(
    int chapterNum,
    String bookTheme,
    int bookNumber,
  ) {
    final missionType = _getMissionTypeForChapter(bookNumber, chapterNum);

    // Create diverse fallback tasks based on mission type
    final taskSets = {
      'Social Interaction': [
        'Find a safe, comfortable environment to practice social skills',
        'Start with a simple greeting or compliment',
        'Gradually build up to more meaningful conversations',
      ],
      'Self-Reflection': [
        'Find a quiet space for 10 minutes of reflection',
        'Write down your thoughts and feelings about $bookTheme',
        'Identify one insight or area for growth',
      ],
      'Creative Expression': [
        'Choose a creative medium that feels comfortable to you',
        'Express your thoughts about $bookTheme through your chosen medium',
        'Reflect on what you created and what it reveals',
      ],
      'Skill Building': [
        'Identify a specific skill related to $bookTheme you want to develop',
        'Practice this skill in a low-pressure environment',
        'Note your progress and areas for improvement',
      ],
      'Community Engagement': [
        'Look for opportunities to help or support others',
        'Engage in a small act of kindness or service',
        'Reflect on how this connects to $bookTheme',
      ],
      'Personal Challenge': [
        'Identify one aspect of $bookTheme that challenges you',
        'Take a small step outside your comfort zone',
        'Acknowledge your courage and progress',
      ],
      'Communication': [
        'Practice expressing your thoughts about $bookTheme',
        'Find a trusted person to share your ideas with',
        'Listen actively to their perspective',
      ],
      'Mindfulness': [
        'Take 5 minutes to be fully present with $bookTheme',
        'Observe your thoughts and feelings without judgment',
        'Notice what insights emerge from this practice',
      ],
      'Leadership': [
        'Identify a situation where you can take initiative',
        'Practice leading by example in a small way',
        'Reflect on your leadership style and impact',
      ],
      'Empathy Building': [
        'Practice seeing situations from different perspectives',
        'Connect with someone who has a different viewpoint',
        'Reflect on how this expands your understanding of $bookTheme',
      ],
    };

    return taskSets[missionType] ??
        [
          'Take 5 minutes to reflect on your current relationship with $bookTheme',
          'Write down 3 areas where you want to improve',
          'Identify one small action you can take today',
        ];
  }

  String _getFallbackInstructions(int chapterNum, String bookTheme) {
    final instructions = [
      'Find a quiet space where you can reflect without interruption. Take deep breaths and focus on your thoughts about $bookTheme.',
      'Choose a specific situation today where you can apply $bookTheme principles. Be intentional and observe the results.',
      'Identify something that makes you uncomfortable related to $bookTheme. Take a small, manageable step to face this challenge.',
      'Design a simple daily practice that aligns with $bookTheme. Start small and build consistency over time.',
      'Look back at your progress with $bookTheme. Celebrate your growth and plan your next steps forward.',
    ];
    return instructions[chapterNum - 1];
  }

  String _getFallbackCriteria(int chapterNum, String bookTheme) {
    final criteria = [
      'You have completed all reflection tasks and documented your insights about $bookTheme.',
      'You have successfully applied $bookTheme principles in a real situation and documented the experience.',
      'You have identified and taken action on a challenge related to $bookTheme, regardless of the outcome.',
      'You have created and started implementing a daily practice related to $bookTheme.',
      'You have reviewed your progress, celebrated achievements, and set new goals for continued growth in $bookTheme.',
    ];
    return criteria[chapterNum - 1];
  }

  // Determine chapter difficulty based on position and book number
  String _determineChapterDifficulty(int chapterNum, int bookNumber) {
    if (bookNumber <= 3) {
      return 'easy';
    } else if (bookNumber <= 7) {
      return chapterNum <= 3 ? 'easy' : 'medium';
    } else {
      return chapterNum <= 2 ? 'medium' : 'hard';
    }
  }

  // Calculate XP reward based on chapter and book number
  int _calculateXpReward(int chapterNum, int bookNumber) {
    final baseReward = 25;
    final bookMultiplier = (bookNumber - 1) * 5;
    final chapterMultiplier = (chapterNum - 1) * 3;

    return baseReward + bookMultiplier + chapterMultiplier;
  }

  // Complete a chapter and update analytics
  Future<void> completeChapter(
    String chapterId,
    String userId,
    String bookId, {
    double? completionTime,
    String? userFeedback,
    int? userRating,
  }) async {
    try {
      // Check if user is premium
      final user = await _userService.getUser(userId);
      if (user == null) {
        throw Exception('User not found');
      }

      // For non-premium users, check if they've already completed a chapter today
      if (!user.premium) {
        final hasCompletedChapterToday = await _hasCompletedChapterToday(
          userId,
        );
        if (hasCompletedChapterToday) {
          throw Exception(
            'Non-premium users can only complete one chapter per day. Upgrade to Premium for unlimited chapters!',
          );
        }
      }

      // First, check if the chapter is already completed
      final chapterRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('books')
          .doc(bookId)
          .collection('chapters')
          .doc(chapterId);

      final chapterDoc = await chapterRef.get();
      if (!chapterDoc.exists) {
        throw Exception('Chapter not found');
      }

      final chapter = ChapterModel.fromFirestore(chapterDoc);
      if (chapter.completed) {
        throw Exception('Chapter is already completed');
      }

      // Check if book is already being generated
      final bookRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('books')
          .doc(bookId);
      final bookDoc = await bookRef.get();
      final book = BookModel.fromFirestore(bookDoc);

      // If this is the final chapter (chapter 5) and book is already completed, prevent completion
      if (chapter.chapterNumber == 5 && book.isCompleted) {
        throw Exception('Book is already completed');
      }

      final batch = _firestore.batch();

      // Update chapter in nested structure
      batch.update(chapterRef, {
        'completed': true,
        'completedAt': Timestamp.now(),
        'completionTime': completionTime,
        'userFeedback': userFeedback,
        'userRating': userRating,
      });

      final newCompletedChapters = book.completedChapters + 1;
      final isBookCompleted = newCompletedChapters >= 5;

      // If this is the final chapter, mark book as completed and set a flag to prevent multiple generations
      if (isBookCompleted) {
        // Check if we're already generating the next book
        if (book.aiMetadata?['isGeneratingNextBook'] == true) {
          throw Exception('Next book is already being generated');
        }

        batch.update(bookRef, {
          'completedChapters': newCompletedChapters,
          'status': 'completed',
          'completedAt': Timestamp.now(),
          'aiMetadata': {
            ...book.aiMetadata ?? {},
            'isGeneratingNextBook':
                true, // Flag to prevent multiple generations
          },
        });
      } else {
        batch.update(bookRef, {
          'completedChapters': newCompletedChapters,
          'status': 'inProgress',
        });
      }

      // Update user analytics
      final analyticsRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('learningAnalytics')
          .doc('main');
      final analyticsDoc = await analyticsRef.get();

      if (analyticsDoc.exists) {
        final analytics = UserLearningAnalytics.fromFirestore(analyticsDoc);

        // Calculate new average completion time
        final totalTime =
            analytics.averageChapterCompletionTime *
            analytics.totalChaptersCompleted;
        final newTotalTime = totalTime + (completionTime ?? 0.0);
        final newAverageTime = (analytics.totalChaptersCompleted + 1) > 0
            ? newTotalTime / (analytics.totalChaptersCompleted + 1)
            : 0.0;

        // Update theme completion count
        final newThemeCount = Map<String, int>.from(
          analytics.themeCompletionCount,
        );
        newThemeCount[book.theme] = (newThemeCount[book.theme] ?? 0) + 1;

        batch.update(analyticsRef, {
          'totalChaptersCompleted': analytics.totalChaptersCompleted + 1,
          'totalBooksCompleted':
              analytics.totalBooksCompleted + (isBookCompleted ? 1 : 0),
          'averageChapterCompletionTime': newAverageTime,
          'themeCompletionCount': newThemeCount,
          'lastActiveDate': Timestamp.now(),
        });
      }

      await batch.commit();

      // Award XP to the user for completing the chapter
      await _userService.addXP(
        userId,
        chapter.xpReward,
        'Completed chapter: ${chapter.title} from ${book.title}',
      );

      // Update mission streak
      await _userService.updateMissionStreak(userId);

      // Generate AI feedback for mission completion
      await _generateMissionCompletionFeedback(userId, chapter, book);

      // Play chapter completion sound
      await _soundService.playChapterComplete();

      // Award bonus XP for completing the book
      if (isBookCompleted) {
        final bookCompletionBonus = 100; // Bonus XP for completing a book
        await _userService.addXP(
          userId,
          bookCompletionBonus,
          'Completed book: ${book.title}',
        );

        // Play book completion sound
        await _soundService.playMissionComplete();
      }

      // Update user progress tracking for progressive difficulty
      await _updateUserProgress(
        userId,
        _getMissionTypeForChapter(book.bookNumber, chapter.chapterNumber),
        book.theme,
        chapter.difficulty,
        chapter.missionObjective,
        chapter.missionTasks,
        book.title,
        chapter.title,
        book.bookNumber,
        chapter.chapterNumber,
      );

      // Check if we need to generate the next book
      if (isBookCompleted && book.bookNumber < 10) {
        await _generateNextBook(userId, book.bookNumber + 1);

        // Remove the generation flag after successful generation
        await bookRef.update({
          'aiMetadata': {
            ...book.aiMetadata ?? {},
            'isGeneratingNextBook': false,
          },
        });
      }
    } catch (e) {
      print('Error completing chapter: $e');
      rethrow;
    }
  }

  // Generate the next book based on user analytics
  Future<void> _generateNextBook(String userId, int bookNumber) async {
    try {
      // Get user analytics to personalize the book
      final analyticsDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('learningAnalytics')
          .doc('main')
          .get();

      UserLearningAnalytics? analytics;
      if (analyticsDoc.exists) {
        analytics = UserLearningAnalytics.fromFirestore(analyticsDoc);
      }

      // Find the existing locked book for this book number
      final booksQuery = await _firestore
          .collection('users')
          .doc(userId)
          .collection('books')
          .where('bookNumber', isEqualTo: bookNumber)
          .get();

      if (booksQuery.docs.isEmpty) {
        throw Exception('Book number $bookNumber not found');
      }

      final bookDoc = booksQuery.docs.first;
      final existingBook = BookModel.fromFirestore(bookDoc);

      // Generate personalized content for the existing book
      final bookTitle = await _generatePersonalizedBookTitle(
        userId,
        bookNumber,
        analytics,
      );

      final bookDescription = await _generatePersonalizedBookDescription(
        bookTitle,
        bookNumber,
        analytics,
      );

      final bookTheme = await _generatePersonalizedBookTheme(
        bookNumber,
        analytics,
      );

      // Update the existing book with personalized content
      final updatedBook = existingBook.copyWith(
        title: bookTitle,
        description: bookDescription,
        theme: bookTheme,
        status: BookStatus.available,
        averageCompletionTime: analytics?.averageChapterCompletionTime ?? 0.0,
        difficultyLevel: _determineBookDifficulty(analytics),
        aiMetadata: {
          'generatedAt': DateTime.now().toIso8601String(),
          'version': '1.0',
          'personalized': true,
          'userAnalytics': analytics?.toFirestore(),
          'isPlaceholder': false, // No longer a placeholder
        },
      );

      // Update the book document
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('books')
          .doc(bookDoc.id)
          .update(updatedBook.toFirestore());

      // Generate personalized chapters for this book
      await _generatePersonalizedBookChapters(
        bookDoc.id,
        userId,
        bookTitle,
        bookTheme,
        bookNumber,
        analytics,
      );
    } catch (e) {
      print('Error generating next book: $e');
      rethrow;
    }
  }

  // Generate personalized book title based on user analytics
  Future<String> _generatePersonalizedBookTitle(
    String userId,
    int bookNumber,
    UserLearningAnalytics? analytics,
  ) async {
    try {
      String personalizationContext = '';
      String onboardingContext = '';

      if (analytics != null) {
        personalizationContext =
            '''
User Learning Profile:
- Completed ${analytics.totalChaptersCompleted} chapters
- Average completion time: ${analytics.averageChapterCompletionTime.toStringAsFixed(1)} hours
- Preferred difficulty: ${analytics.preferredDifficulty}
- Favorite themes: ${analytics.favoriteThemes.join(', ')}
- Current streak: ${analytics.currentStreak} days
''';

        // Include onboarding preferences for better personalization
        if (analytics.learningPreferences != null) {
          final prefs = analytics.learningPreferences!;
          onboardingContext =
              '''
Onboarding Preferences:
- Primary Goal: ${prefs['primaryGoal'] ?? 'Not specified'}
- Custom Goal: ${prefs['customGoal'] ?? 'Not specified'}
- Learning Style: ${prefs['learningStyle'] ?? 'balanced'}
- Social Comfort Level: ${prefs['socialComfortLevel'] ?? 'Not specified'}
- Preferred Time: ${prefs['preferredTimeOfDay'] ?? 'morning'}
- Motivation Level: ${prefs['motivationLevel'] ?? 'medium'}
''';
        }
      }

      final prompt =
          '''
Generate a personalized book title for book number $bookNumber based on this user's learning profile:

$personalizationContext
$onboardingContext

The title should:
- Build upon their previous learning journey
- Address their preferred themes and difficulty level
- Be specifically tailored to their primary goal: ${analytics?.learningPreferences?['primaryGoal'] ?? 'general improvement'}
- Be motivating and relevant to their progress
- Be 2-5 words maximum

Generate only the title, nothing else.
''';

      final response = await AiRouter.generate(
        task: AiTaskType.feedbackCoach,
        prompt: prompt,
      );

      return response.trim().replaceAll('"', '').replaceAll("'", '');
    } catch (e) {
      return _generateBookTitle(userId, bookNumber);
    }
  }

  // Generate personalized book description
  Future<String> _generatePersonalizedBookDescription(
    String bookTitle,
    int bookNumber,
    UserLearningAnalytics? analytics,
  ) async {
    try {
      String personalizationContext = '';
      String onboardingContext = '';

      if (analytics != null) {
        personalizationContext =
            '''
Based on your learning journey:
- You've completed ${analytics.totalChaptersCompleted} chapters
- Your average completion time is ${analytics.averageChapterCompletionTime.toStringAsFixed(1)} hours
- You prefer ${analytics.preferredDifficulty} difficulty
- Your favorite themes are: ${analytics.favoriteThemes.join(', ')}
''';

        // Include onboarding preferences for better personalization
        if (analytics.learningPreferences != null) {
          final prefs = analytics.learningPreferences!;
          onboardingContext =
              '''
Your specific goals and preferences:
- Your main goal: ${prefs['primaryGoal'] ?? 'general improvement'}
- Your custom goal: ${prefs['customGoal'] ?? 'Not specified'}
- Your learning style: ${prefs['learningStyle'] ?? 'balanced'}
- Your social comfort level: ${prefs['socialComfortLevel'] ?? 'Not specified'}
- Your motivation level: ${prefs['motivationLevel'] ?? 'medium'}
''';
        }
      }

      final prompt =
          '''
Write a personalized description for "$bookTitle" (book $bookNumber):

$personalizationContext
$onboardingContext

The description should:
- Acknowledge their progress and learning style
- Be specifically tailored to their primary goal: ${analytics?.learningPreferences?['primaryGoal'] ?? 'general improvement'}
- Address their social comfort level and learning preferences
- Be 2-3 sentences maximum
- Be encouraging and motivating

Write only the description, nothing else.
''';

      final response = await AiRouter.generate(
        task: AiTaskType.feedbackCoach,
        prompt: prompt,
      );

      return response.trim();
    } catch (e) {
      return _generateBookDescription(bookTitle, bookNumber);
    }
  }

  // Generate personalized book theme
  Future<String> _generatePersonalizedBookTheme(
    int bookNumber,
    UserLearningAnalytics? analytics,
  ) async {
    if (analytics != null && analytics.favoriteThemes.isNotEmpty) {
      // Use one of their favorite themes if available
      return analytics.favoriteThemes.first;
    }

    return _generateBookTheme(bookNumber);
  }

  // Determine book difficulty based on user analytics
  String _determineBookDifficulty(UserLearningAnalytics? analytics) {
    if (analytics == null) return 'medium';

    if (analytics.averageChapterCompletionTime < 0.5) {
      return 'hard';
    } else if (analytics.averageChapterCompletionTime > 2.0) {
      return 'easy';
    } else {
      return analytics.preferredDifficulty;
    }
  }

  // Generate personalized chapters
  Future<void> _generatePersonalizedBookChapters(
    String bookId,
    String userId,
    String bookTitle,
    String bookTheme,
    int bookNumber,
    UserLearningAnalytics? analytics,
  ) async {
    try {
      for (int chapterNum = 1; chapterNum <= 5; chapterNum++) {
        final chapterTitle = await _generatePersonalizedChapterTitle(
          bookTitle,
          chapterNum,
          bookTheme,
          analytics,
        );

        final missionContent = await _generatePersonalizedChapterMission(
          bookTitle,
          chapterTitle,
          chapterNum,
          bookTheme,
          bookNumber,
          analytics,
          userId,
        );

        final difficulty = _determinePersonalizedChapterDifficulty(
          chapterNum,
          bookNumber,
          analytics,
        );

        final chapter = ChapterModel(
          id: '',
          title: chapterTitle,
          missionObjective: missionContent['objective'],
          missionTasks: missionContent['tasks'],
          missionInstructions: missionContent['instructions'],
          completionCriteria: missionContent['criteria'],
          chapterNumber: chapterNum,
          bookId: bookId,
          userId: userId,
          completed: false,
          createdAt: DateTime.now(),
          xpReward: _calculatePersonalizedXpReward(
            chapterNum,
            bookNumber,
            analytics,
          ),
          difficulty: difficulty,
          aiMetadata: {
            'generatedAt': DateTime.now().toIso8601String(),
            'bookNumber': bookNumber,
            'bookTheme': bookTheme,
            'personalized': true,
            'userAnalytics': analytics?.toFirestore(),
          },
        );

        await _firestore
            .collection('users')
            .doc(userId)
            .collection('books')
            .doc(bookId)
            .collection('chapters')
            .add(chapter.toFirestore());
      }
    } catch (e) {
      print('Error generating personalized book chapters: $e');
      rethrow;
    }
  }

  // Generate personalized chapter title
  Future<String> _generatePersonalizedChapterTitle(
    String bookTitle,
    int chapterNum,
    String bookTheme,
    UserLearningAnalytics? analytics,
  ) async {
    try {
      String personalizationContext = '';
      String onboardingContext = '';

      if (analytics != null) {
        personalizationContext =
            '''
Based on your learning profile:
- You prefer ${analytics.preferredDifficulty} difficulty
- Your favorite themes: ${analytics.favoriteThemes.join(', ')}
- You complete chapters in ${analytics.averageChapterCompletionTime.toStringAsFixed(1)} hours on average
''';

        // Include onboarding preferences for better personalization
        if (analytics.learningPreferences != null) {
          final prefs = analytics.learningPreferences!;
          onboardingContext =
              '''
Your specific goals and preferences:
- Your main goal: ${prefs['primaryGoal'] ?? 'general improvement'}
- Your custom goal: ${prefs['customGoal'] ?? 'Not specified'}
- Your social comfort level: ${prefs['socialComfortLevel'] ?? 'Not specified'}
- Your motivation level: ${prefs['motivationLevel'] ?? 'medium'}
''';
        }
      }

      // Create unique prompts for each chapter with personalization
      final chapterPrompts = [
        // Chapter 1 - Focus on discovery and beginnings
        '''
Generate a personalized chapter title for chapter 1 of "$bookTitle" (theme: $bookTheme).

$personalizationContext
$onboardingContext

Requirements:
- Must be completely different from these existing titles: "Understanding Your Fears", "Building Inner Strength", "Taking the First Step", "Embracing Change", "Celebrating Growth", "The Beginning", "Building Foundations", "Growing Stronger", "Facing Challenges", "Achieving Success", "Awakening Your Potential", "Expanding Your Horizons", "Mastering the Craft", "Applying Your Knowledge", "Integrating Everything", "Discovering New Possibilities", "Cultivating Your Strengths", "Perfecting Your Approach", "Putting Theory Into Practice", "Uniting All Your Skills"
- 3-6 words maximum
- Focus on discovery, awakening, or first encounters
- Use words like: discover, awaken, explore, reveal, uncover, begin, start, initiate
- Be specifically tailored to their primary goal: ${analytics?.learningPreferences?['primaryGoal'] ?? 'general improvement'}
- Match your preferred difficulty and themes
- Be inspiring and relevant to your learning journey
- Avoid generic terms unless used in a unique way

Generate only the title, nothing else.
''',
        // Chapter 2 - Focus on growth and development
        '''
Generate a personalized chapter title for chapter 2 of "$bookTitle" (theme: $bookTheme).

$personalizationContext
$onboardingContext

Requirements:
- Must be completely different from these existing titles: "Understanding Your Fears", "Building Inner Strength", "Taking the First Step", "Embracing Change", "Celebrating Growth", "The Beginning", "Building Foundations", "Growing Stronger", "Facing Challenges", "Achieving Success", "Awakening Your Potential", "Expanding Your Horizons", "Mastering the Craft", "Applying Your Knowledge", "Integrating Everything", "Discovering New Possibilities", "Cultivating Your Strengths", "Perfecting Your Approach", "Putting Theory Into Practice", "Uniting All Your Skills"
- 3-6 words maximum
- Focus on growth, development, or building skills
- Use words like: develop, grow, build, strengthen, enhance, cultivate, nurture, evolve
- Be specifically tailored to their primary goal: ${analytics?.learningPreferences?['primaryGoal'] ?? 'general improvement'}
- Match your preferred difficulty and themes
- Be inspiring and relevant to your learning journey
- Avoid generic terms unless used in a unique way

Generate only the title, nothing else.
''',
        // Chapter 3 - Focus on mastery and depth
        '''
Generate a personalized chapter title for chapter 3 of "$bookTitle" (theme: $bookTheme).

$personalizationContext
$onboardingContext

Requirements:
- Must be completely different from these existing titles: "Understanding Your Fears", "Building Inner Strength", "Taking the First Step", "Embracing Change", "Celebrating Growth", "The Beginning", "Building Foundations", "Growing Stronger", "Facing Challenges", "Achieving Success", "Awakening Your Potential", "Expanding Your Horizons", "Mastering the Craft", "Applying Your Knowledge", "Integrating Everything", "Discovering New Possibilities", "Cultivating Your Strengths", "Perfecting Your Approach", "Putting Theory Into Practice", "Uniting All Your Skills"
- 3-6 words maximum
- Focus on mastery, depth, or advanced concepts
- Use words like: master, deepen, refine, perfect, excel, advance, elevate, transcend
- Be specifically tailored to their primary goal: ${analytics?.learningPreferences?['primaryGoal'] ?? 'general improvement'}
- Match your preferred difficulty and themes
- Be inspiring and relevant to your learning journey
- Avoid generic terms unless used in a unique way

Generate only the title, nothing else.
''',
        // Chapter 4 - Focus on application and practice
        '''
Generate a personalized chapter title for chapter 4 of "$bookTitle" (theme: $bookTheme).

$personalizationContext
$onboardingContext

Requirements:
- Must be completely different from these existing titles: "Understanding Your Fears", "Building Inner Strength", "Taking the First Step", "Embracing Change", "Celebrating Growth", "The Beginning", "Building Foundations", "Growing Stronger", "Facing Challenges", "Achieving Success", "Awakening Your Potential", "Expanding Your Horizons", "Mastering the Craft", "Applying Your Knowledge", "Integrating Everything", "Discovering New Possibilities", "Cultivating Your Strengths", "Perfecting Your Approach", "Putting Theory Into Practice", "Uniting All Your Skills"
- 3-6 words maximum
- Focus on application, practice, or real-world use
- Use words like: apply, practice, implement, execute, perform, demonstrate, showcase, utilize
- Be specifically tailored to their primary goal: ${analytics?.learningPreferences?['primaryGoal'] ?? 'general improvement'}
- Match your preferred difficulty and themes
- Be inspiring and relevant to your learning journey
- Avoid generic terms unless used in a unique way

Generate only the title, nothing else.
''',
        // Chapter 5 - Focus on integration and completion
        '''
Generate a personalized chapter title for chapter 5 of "$bookTitle" (theme: $bookTheme).

$personalizationContext
$onboardingContext

Requirements:
- Must be completely different from these existing titles: "Understanding Your Fears", "Building Inner Strength", "Taking the First Step", "Embracing Change", "Celebrating Growth", "The Beginning", "Building Foundations", "Growing Stronger", "Facing Challenges", "Achieving Success", "Awakening Your Potential", "Expanding Your Horizons", "Mastering the Craft", "Applying Your Knowledge", "Integrating Everything", "Discovering New Possibilities", "Cultivating Your Strengths", "Perfecting Your Approach", "Putting Theory Into Practice", "Uniting All Your Skills"
- 3-6 words maximum
- Focus on integration, completion, or celebration
- Use words like: integrate, complete, celebrate, culminate, unite, harmonize, synthesize, finalize
- Be specifically tailored to their primary goal: ${analytics?.learningPreferences?['primaryGoal'] ?? 'general improvement'}
- Match your preferred difficulty and themes
- Be inspiring and relevant to your learning journey
- Avoid generic terms unless used in a unique way

Generate only the title, nothing else.
''',
      ];

      final prompt = chapterPrompts[chapterNum - 1];

      final response = await AiRouter.generate(
        task: AiTaskType.feedbackCoach,
        prompt: prompt,
      );

      return response.trim().replaceAll('"', '').replaceAll("'", '');
    } catch (e) {
      return _generateChapterTitle(bookTitle, chapterNum, bookTheme);
    }
  }

  // Generate personalized chapter mission
  Future<Map<String, dynamic>> _generatePersonalizedChapterMission(
    String bookTitle,
    String chapterTitle,
    int chapterNum,
    String bookTheme,
    int bookNumber,
    UserLearningAnalytics? analytics,
    String userId,
  ) async {
    try {
      String personalizationContext = '';
      String onboardingContext = '';

      if (analytics != null) {
        personalizationContext =
            '''
Based on your learning journey:
- You've completed ${analytics.totalChaptersCompleted} chapters
- You prefer ${analytics.preferredDifficulty} difficulty
- Your average completion time: ${analytics.averageChapterCompletionTime.toStringAsFixed(1)} hours
- Your favorite themes: ${analytics.favoriteThemes.join(', ')}
''';

        // Include onboarding preferences for better personalization
        if (analytics.learningPreferences != null) {
          final prefs = analytics.learningPreferences!;
          onboardingContext =
              '''
Your specific goals and preferences:
- Your main goal: ${prefs['primaryGoal'] ?? 'general improvement'}
- Your custom goal: ${prefs['customGoal'] ?? 'Not specified'}
- Your learning style: ${prefs['learningStyle'] ?? 'balanced'}
- Your social comfort level: ${prefs['socialComfortLevel'] ?? 'Not specified'}
- Your motivation level: ${prefs['motivationLevel'] ?? 'medium'}
''';
        }
      }

      // Determine mission type based on book number and chapter
      final missionType = _getMissionTypeForChapter(bookNumber, chapterNum);
      final missionFocus = _getMissionFocusForChapter(chapterNum);

      // Determine difficulty level based on user progress
      final difficulty = analytics != null
          ? _determineDifficultyLevel(
              bookNumber,
              chapterNum,
              analytics,
              missionType,
              bookTheme,
            )
          : 'medium';

      // Generate AI context prompt
      final aiContext = analytics != null
          ? _generateAIContextPrompt(
              analytics,
              bookNumber,
              chapterNum,
              missionType,
              bookTheme,
            )
          : '';

      final prompt =
          '''
Create a practical, real-world mission for chapter $chapterNum: "$chapterTitle" 
from "$bookTitle" (book $bookNumber, theme: $bookTheme).

MISSION TYPE: $missionType
CHAPTER FOCUS: $missionFocus
DIFFICULTY LEVEL: $difficulty

$personalizationContext
$onboardingContext

$aiContext

Generate a mission that includes:
1. Mission Objective: A clear, specific goal that can be completed in one day
2. Mission Tasks: 3-4 simple, actionable tasks that are easy to understand and complete
3. Mission Instructions: Step-by-step guidance on how to complete the mission
4. Completion Criteria: Clear criteria for when the mission is considered complete

The mission should be:
- Practical and real-world focused
- Something that can be completed in 15-60 minutes
- Easy to understand and execute
- Related to personal growth and development
- Specific and actionable (not abstract concepts)
- Tailored to your learning pace and preferences
- DIRECTLY related to the chapter theme: $bookTheme
- SPECIFICALLY tailored to their primary goal: ${analytics?.learningPreferences?['primaryGoal'] ?? 'general improvement'}
- Varied in approach (not always social interaction)
- PROGRESSIVELY CHALLENGING based on the user's skill level

MISSION VARIETY GUIDELINES:
- Book 1: Focus on foundational social skills and self-awareness
- Book 2+: Introduce more creative, reflective, and skill-building missions
- Chapter 1: Discovery and first steps
- Chapter 2: Growth and development  
- Chapter 3: Mastery and depth
- Chapter 4: Application and practice
- Chapter 5: Integration and celebration

MISSION TYPE EXAMPLES:
- Social Interaction: Conversations, asking questions, giving compliments
- Self-Reflection: Journaling, meditation, self-assessment
- Creative Expression: Writing, drawing, creating something meaningful
- Skill Building: Learning something new, practicing a technique
- Community Engagement: Helping others, volunteering, supporting friends
- Personal Challenge: Stepping outside comfort zone in various ways
- Communication: Different forms of expression and connection
- Mindfulness: Being present, observing, appreciating

IMPORTANT: Format your response EXACTLY as follows:
OBJECTIVE: [specific, actionable goal related to $bookTheme]
TASKS: [task 1] | [task 2] | [task 3]
INSTRUCTIONS: [step-by-step guidance specifically for completing the objective and tasks above]
CRITERIA: [clear completion criteria for the specific mission]

Use | (pipe) to separate tasks, not commas.

CRITICAL: The INSTRUCTIONS must be specifically about how to complete the OBJECTIVE and TASKS you just defined. Do not provide generic advice - give specific steps for this particular mission.

Avoid repetitive "walk up to stranger" missions. Be creative and varied!
''';

      final response = await AiRouter.generate(
        task: AiTaskType.feedbackCoach,
        prompt: prompt,
      );

      // Parse the response with improved logic
      final lines = response.trim().split('\n');
      String objective = '';
      List<String> tasks = [];
      String instructions = '';
      String criteria = '';

      print('DEBUG: Raw AI response: $response');
      print('DEBUG: Parsing lines: ${lines.length}');

      for (String line in lines) {
        final trimmedLine = line.trim();
        print('DEBUG: Processing line: "$trimmedLine"');

        if (trimmedLine.startsWith('OBJECTIVE:')) {
          objective = trimmedLine.substring(10).trim();
          print('DEBUG: Found objective: "$objective"');
        } else if (trimmedLine.startsWith('TASKS:')) {
          final tasksStr = trimmedLine.substring(6).trim();
          print('DEBUG: Found tasks string: "$tasksStr"');
          // Try pipe separator first, then comma
          if (tasksStr.contains('|')) {
            tasks = tasksStr
                .split('|')
                .map((t) => t.trim())
                .where((t) => t.isNotEmpty)
                .toList();
            print('DEBUG: Parsed tasks with pipe: $tasks');
          } else {
            tasks = tasksStr
                .split(',')
                .map((t) => t.trim())
                .where((t) => t.isNotEmpty)
                .toList();
            print('DEBUG: Parsed tasks with comma: $tasks');
          }
        } else if (trimmedLine.startsWith('INSTRUCTIONS:')) {
          instructions = trimmedLine.substring(13).trim();
          print('DEBUG: Found instructions: "$instructions"');
        } else if (trimmedLine.startsWith('CRITERIA:')) {
          criteria = trimmedLine.substring(9).trim();
          print('DEBUG: Found criteria: "$criteria"');
        }
      }

      // Ensure we have valid tasks
      if (tasks.isEmpty || tasks.length < 2) {
        print('DEBUG: Tasks empty or insufficient, using fallback tasks');
        tasks = [
          'Find a stranger in a public place',
          'Approach them politely and ask your question',
          'Thank them for their response',
        ];
      }

      return {
        'objective': objective.isNotEmpty
            ? objective
            : 'Complete a simple social interaction to build confidence and communication skills.',
        'tasks': tasks,
        'instructions': instructions.isNotEmpty
            ? instructions
            : 'Follow the specific tasks outlined above. Take your time and approach this challenge with confidence. Remember that every step forward is progress.',
        'criteria': criteria.isNotEmpty
            ? criteria
            : 'You have successfully completed the social interaction and received a response from the person.',
      };
    } catch (e) {
      // Fallback content with practical tasks
      return {
        'objective':
            'Complete a simple social interaction to build confidence and communication skills.',
        'tasks': [
          'Find a stranger in a public place',
          'Approach them politely and ask your question',
          'Thank them for their response',
        ],
        'instructions':
            'Follow the specific tasks outlined above. Take your time and approach this challenge with confidence. Remember that every step forward is progress.',
        'criteria':
            'You have successfully completed the social interaction and received a response from the person.',
      };
    }
  }

  // Determine personalized chapter difficulty
  String _determinePersonalizedChapterDifficulty(
    int chapterNum,
    int bookNumber,
    UserLearningAnalytics? analytics,
  ) {
    if (analytics == null) {
      return _determineChapterDifficulty(chapterNum, bookNumber);
    }

    // Adjust difficulty based on user's completion time
    if (analytics.averageChapterCompletionTime < 0.5) {
      // Fast learner - increase difficulty
      return chapterNum <= 2 ? 'medium' : 'hard';
    } else if (analytics.averageChapterCompletionTime > 2.0) {
      // Slower learner - decrease difficulty
      return chapterNum <= 4 ? 'easy' : 'medium';
    } else {
      // Balanced learner - use preferred difficulty
      return analytics.preferredDifficulty;
    }
  }

  // Calculate personalized XP reward
  int _calculatePersonalizedXpReward(
    int chapterNum,
    int bookNumber,
    UserLearningAnalytics? analytics,
  ) {
    final baseReward = _calculateXpReward(chapterNum, bookNumber);

    if (analytics == null) return baseReward;

    // Adjust based on user's streak and engagement
    double multiplier = 1.0;

    if (analytics.currentStreak >= 7) {
      multiplier += 0.2; // Bonus for consistent engagement
    }

    if (analytics.averageChapterCompletionTime < 1.0) {
      multiplier += 0.1; // Bonus for quick learners
    }

    return (baseReward * multiplier).round();
  }

  // Generate personalized first book based on onboarding
  Future<void> _generatePersonalizedFirstBook(
    String userId,
    OnboardingData onboardingData,
  ) async {
    try {
      // Create 10 books upfront with the first one being available and the rest locked
      for (int bookNumber = 1; bookNumber <= 10; bookNumber++) {
        String bookTitle;
        String bookDescription;
        String bookTheme;

        if (bookNumber == 1) {
          // Generate real content for the first book
          bookTitle = await _generatePersonalizedBookTitleWithOnboarding(
            userId,
            bookNumber,
            onboardingData,
          );
          bookDescription =
              await _generatePersonalizedBookDescriptionWithOnboarding(
                bookTitle,
                bookNumber,
                onboardingData,
              );
          bookTheme = _selectBestThemeForFirstBook(onboardingData);
        } else {
          // Use generic placeholders for locked books
          bookTitle = 'Book $bookNumber';
          bookDescription =
              'This book will be unlocked as you progress through your learning journey.';
          bookTheme = _getDefaultThemeForBook(bookNumber);
        }

        final book = BookModel(
          id: '', // Will be set by Firestore
          title: bookTitle,
          description: bookDescription,
          theme: bookTheme,
          bookNumber: bookNumber,
          createdAt: DateTime.now(),
          userId: userId,
          status: bookNumber == 1 ? BookStatus.available : BookStatus.locked,
          completedChapters: 0,
          averageCompletionTime: 0.0,
          difficultyLevel: _determineDifficultyFromOnboarding(onboardingData),
          aiMetadata: {
            'generatedAt': DateTime.now().toIso8601String(),
            'version': '1.0',
            'personalized': true,
            'isPlaceholder':
                bookNumber > 1, // Mark as placeholder for locked books
            'onboardingData': {
              'mood': onboardingData.mood,
              'goal': onboardingData.goal,
              'mode': onboardingData.mode,
              'socialComfort': onboardingData.socialComfort,
              'talkFrequency': onboardingData.talkFrequency,
              'customGoal': onboardingData.customGoal,
            },
          },
        );

        final bookDoc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('books')
            .add(book.toFirestore());
        final bookId = bookDoc.id;

        // Only generate chapters for the first book (available)
        if (bookNumber == 1) {
          await _generatePersonalizedBookChaptersWithOnboarding(
            bookId,
            userId,
            bookTitle,
            bookTheme,
            1,
            onboardingData,
          );
        }
      }
    } catch (e) {
      print('Error generating personalized first book: $e');
      rethrow;
    }
  }

  // Select the best theme for the first book based on onboarding
  String _selectBestThemeForFirstBook(OnboardingData onboardingData) {
    final themes = _determineThemesFromOnboarding(onboardingData);

    // Prioritize themes based on user's primary goal
    if (onboardingData.goal.toLowerCase() == 'overcome anxiety') {
      return themes.contains('courage') ? 'courage' : 'light';
    } else if (onboardingData.goal.toLowerCase() == 'build confidence') {
      return themes.contains('courage') ? 'courage' : 'foundation';
    } else if (onboardingData.goal.toLowerCase() == 'improve social skills') {
      return themes.contains('voice') ? 'voice' : 'connection';
    } else if (onboardingData.goal.toLowerCase() == 'make new friends') {
      return themes.contains('connection') ? 'connection' : 'voice';
    }

    // Default to first available theme or courage
    return themes.isNotEmpty ? themes.first : 'courage';
  }

  // Generate personalized book title using onboarding data
  Future<String> _generatePersonalizedBookTitleWithOnboarding(
    String userId,
    int bookNumber,
    OnboardingData onboardingData,
  ) async {
    try {
      final prompt =
          '''
Generate a unique and personalized book title for book number $bookNumber based on this user's specific profile:

User Profile:
- Current mood: ${onboardingData.mood}
- Main goal: ${onboardingData.goal}${onboardingData.customGoal != null ? ' (${onboardingData.customGoal})' : ''}
- Preferred mode: ${onboardingData.mode}
- Social comfort level: ${onboardingData.socialComfort}
- Talk frequency: ${onboardingData.talkFrequency}

Requirements:
- Must be completely different from these existing titles: "The Courage Within", "Light Your Path", "Voice of Strength", "Unshaken Foundation", "Mirror of Growth", "Storm of Change", "Connection Deep", "Fear to Freedom", "Wisdom Rising", "Journey Complete", "Brave Heart Rising", "Clarity in Chaos", "Express Your Truth", "Solid Ground", "Inner Compass", "Metamorphosis", "Bridge Builder", "Breaking Chains", "Insight Engine", "Peak Performance"
- 2-5 words maximum
- Should directly address their specific goal and challenges
- Be motivating and relevant to their current situation
- Feel personal and tailored to their needs
- Avoid generic terms unless used in a unique way

Book $bookNumber themes to consider:
- Book 1: Courage, bravery, facing fears
- Book 2: Clarity, enlightenment, finding direction  
- Book 3: Communication, self-expression, finding voice
- Book 4: Stability, building foundations, core values
- Book 5: Self-reflection, introspection, understanding
- Book 6: Transformation, change, evolution
- Book 7: Relationships, connections, social skills
- Book 8: Liberation, breaking free, independence
- Book 9: Knowledge, insight, understanding
- Book 10: Achievement, completion, mastery

Generate only the title, nothing else.
''';

      final response = await AiRouter.generate(
        task: AiTaskType.feedbackCoach,
        prompt: prompt,
      );

      return response.trim().replaceAll('"', '').replaceAll("'", '');
    } catch (e) {
      // More diverse fallback titles based on onboarding data
      final fallbackTitles = [
        'Brave Heart Rising',
        'Clarity in Chaos',
        'Express Your Truth',
        'Solid Ground',
        'Inner Compass',
        'Metamorphosis',
        'Bridge Builder',
        'Breaking Chains',
        'Insight Engine',
        'Peak Performance',
      ];

      return fallbackTitles[bookNumber - 1];
    }
  }

  // Generate personalized book description using onboarding data
  Future<String> _generatePersonalizedBookDescriptionWithOnboarding(
    String bookTitle,
    int bookNumber,
    OnboardingData onboardingData,
  ) async {
    try {
      final prompt =
          '''
Write a personalized description for "$bookTitle" (book $bookNumber) based on this user's profile:

User Profile:
- Current mood: ${onboardingData.mood}
- Main goal: ${onboardingData.goal}${onboardingData.customGoal != null ? ' (${onboardingData.customGoal})' : ''}
- Preferred mode: ${onboardingData.mode}
- Social comfort level: ${onboardingData.socialComfort}
- Talk frequency: ${onboardingData.talkFrequency}

The description should:
- Acknowledge their specific challenges and goals
- Be tailored to their comfort level and preferred pace
- Be encouraging and relevant to their situation
- Be 2-3 sentences maximum
- Feel like it was written specifically for them

Write only the description, nothing else.
''';

      final response = await AiRouter.generate(
        task: AiTaskType.feedbackCoach,
        prompt: prompt,
      );

      return response.trim();
    } catch (e) {
      return 'Embark on a transformative journey tailored to your specific needs and goals. This book will guide you through personalized challenges and help you achieve your unique objectives.';
    }
  }

  // Generate personalized chapters with onboarding data
  Future<void> _generatePersonalizedBookChaptersWithOnboarding(
    String bookId,
    String userId,
    String bookTitle,
    String bookTheme,
    int bookNumber,
    OnboardingData onboardingData,
  ) async {
    try {
      for (int chapterNum = 1; chapterNum <= 5; chapterNum++) {
        final chapterTitle =
            await _generatePersonalizedChapterTitleWithOnboarding(
              bookTitle,
              chapterNum,
              bookTheme,
              onboardingData,
            );

        final missionContent =
            await _generatePersonalizedChapterMissionWithOnboarding(
              bookTitle,
              chapterTitle,
              chapterNum,
              bookTheme,
              bookNumber,
              onboardingData,
              userId,
            );

        final difficulty =
            _determinePersonalizedChapterDifficultyWithOnboarding(
              chapterNum,
              bookNumber,
              onboardingData,
            );

        final chapter = ChapterModel(
          id: '',
          title: chapterTitle,
          missionObjective: missionContent['objective'],
          missionTasks: missionContent['tasks'],
          missionInstructions: missionContent['instructions'],
          completionCriteria: missionContent['criteria'],
          chapterNumber: chapterNum,
          bookId: bookId,
          userId: userId,
          completed: false,
          createdAt: DateTime.now(),
          xpReward: _calculatePersonalizedXpRewardWithOnboarding(
            chapterNum,
            bookNumber,
            onboardingData,
          ),
          difficulty: difficulty,
          aiMetadata: {
            'generatedAt': DateTime.now().toIso8601String(),
            'bookNumber': bookNumber,
            'bookTheme': bookTheme,
            'personalized': true,
            'onboardingData': {
              'mood': onboardingData.mood,
              'goal': onboardingData.goal,
              'mode': onboardingData.mode,
              'socialComfort': onboardingData.socialComfort,
              'talkFrequency': onboardingData.talkFrequency,
              'customGoal': onboardingData.customGoal,
            },
          },
        );

        await _firestore
            .collection('users')
            .doc(userId)
            .collection('books')
            .doc(bookId)
            .collection('chapters')
            .add(chapter.toFirestore());
      }
    } catch (e) {
      print('Error generating personalized book chapters with onboarding: $e');
      rethrow;
    }
  }

  // Generate personalized chapter title with onboarding data
  Future<String> _generatePersonalizedChapterTitleWithOnboarding(
    String bookTitle,
    int chapterNum,
    String bookTheme,
    OnboardingData onboardingData,
  ) async {
    try {
      final userProfile =
          '''
User Profile:
- Current mood: ${onboardingData.mood}
- Main goal: ${onboardingData.goal}${onboardingData.customGoal != null ? ' (${onboardingData.customGoal})' : ''}
- Preferred mode: ${onboardingData.mode}
- Social comfort level: ${onboardingData.socialComfort}
- Talk frequency: ${onboardingData.talkFrequency}
''';

      // Create unique prompts for each chapter with onboarding personalization
      final chapterPrompts = [
        // Chapter 1 - Focus on discovery and beginnings
        '''
Generate a unique and personalized chapter title for chapter 1 of "$bookTitle" (theme: $bookTheme) based on this user's specific profile:

$userProfile

Requirements:
- Must be completely different from these existing titles: "Understanding Your Fears", "Building Inner Strength", "Taking the First Step", "Embracing Change", "Celebrating Growth", "The Beginning", "Building Foundations", "Growing Stronger", "Facing Challenges", "Achieving Success", "Awakening Your Potential", "Expanding Your Horizons", "Mastering the Craft", "Applying Your Knowledge", "Integrating Everything", "Discovering New Possibilities", "Cultivating Your Strengths", "Perfecting Your Approach", "Putting Theory Into Practice", "Uniting All Your Skills"
- 3-6 words maximum
- Focus on discovery, awakening, or first encounters
- Use words like: discover, awaken, explore, reveal, uncover, begin, start, initiate
- Should address their specific challenges and goals
- Match their comfort level and preferred pace
- Be inspiring and relevant to their journey
- Avoid generic terms unless used in a unique way

Generate only the title, nothing else.
''',
        // Chapter 2 - Focus on growth and development
        '''
Generate a unique and personalized chapter title for chapter 2 of "$bookTitle" (theme: $bookTheme) based on this user's specific profile:

$userProfile

Requirements:
- Must be completely different from these existing titles: "Understanding Your Fears", "Building Inner Strength", "Taking the First Step", "Embracing Change", "Celebrating Growth", "The Beginning", "Building Foundations", "Growing Stronger", "Facing Challenges", "Achieving Success", "Awakening Your Potential", "Expanding Your Horizons", "Mastering the Craft", "Applying Your Knowledge", "Integrating Everything", "Discovering New Possibilities", "Cultivating Your Strengths", "Perfecting Your Approach", "Putting Theory Into Practice", "Uniting All Your Skills"
- 3-6 words maximum
- Focus on growth, development, or building skills
- Use words like: develop, grow, build, strengthen, enhance, cultivate, nurture, evolve
- Should address their specific challenges and goals
- Match their comfort level and preferred pace
- Be inspiring and relevant to their journey
- Avoid generic terms unless used in a unique way

Generate only the title, nothing else.
''',
        // Chapter 3 - Focus on mastery and depth
        '''
Generate a unique and personalized chapter title for chapter 3 of "$bookTitle" (theme: $bookTheme) based on this user's specific profile:

$userProfile

Requirements:
- Must be completely different from these existing titles: "Understanding Your Fears", "Building Inner Strength", "Taking the First Step", "Embracing Change", "Celebrating Growth", "The Beginning", "Building Foundations", "Growing Stronger", "Facing Challenges", "Achieving Success", "Awakening Your Potential", "Expanding Your Horizons", "Mastering the Craft", "Applying Your Knowledge", "Integrating Everything", "Discovering New Possibilities", "Cultivating Your Strengths", "Perfecting Your Approach", "Putting Theory Into Practice", "Uniting All Your Skills"
- 3-6 words maximum
- Focus on mastery, depth, or advanced concepts
- Use words like: master, deepen, refine, perfect, excel, advance, elevate, transcend
- Should address their specific challenges and goals
- Match their comfort level and preferred pace
- Be inspiring and relevant to their journey
- Avoid generic terms unless used in a unique way

Generate only the title, nothing else.
''',
        // Chapter 4 - Focus on application and practice
        '''
Generate a unique and personalized chapter title for chapter 4 of "$bookTitle" (theme: $bookTheme) based on this user's specific profile:

$userProfile

Requirements:
- Must be completely different from these existing titles: "Understanding Your Fears", "Building Inner Strength", "Taking the First Step", "Embracing Change", "Celebrating Growth", "The Beginning", "Building Foundations", "Growing Stronger", "Facing Challenges", "Achieving Success", "Awakening Your Potential", "Expanding Your Horizons", "Mastering the Craft", "Applying Your Knowledge", "Integrating Everything", "Discovering New Possibilities", "Cultivating Your Strengths", "Perfecting Your Approach", "Putting Theory Into Practice", "Uniting All Your Skills"
- 3-6 words maximum
- Focus on application, practice, or real-world use
- Use words like: apply, practice, implement, execute, perform, demonstrate, showcase, utilize
- Should address their specific challenges and goals
- Match their comfort level and preferred pace
- Be inspiring and relevant to their journey
- Avoid generic terms unless used in a unique way

Generate only the title, nothing else.
''',
        // Chapter 5 - Focus on integration and completion
        '''
Generate a unique and personalized chapter title for chapter 5 of "$bookTitle" (theme: $bookTheme) based on this user's specific profile:

$userProfile

Requirements:
- Must be completely different from these existing titles: "Understanding Your Fears", "Building Inner Strength", "Taking the First Step", "Embracing Change", "Celebrating Growth", "The Beginning", "Building Foundations", "Growing Stronger", "Facing Challenges", "Achieving Success", "Awakening Your Potential", "Expanding Your Horizons", "Mastering the Craft", "Applying Your Knowledge", "Integrating Everything", "Discovering New Possibilities", "Cultivating Your Strengths", "Perfecting Your Approach", "Putting Theory Into Practice", "Uniting All Your Skills"
- 3-6 words maximum
- Focus on integration, completion, or celebration
- Use words like: integrate, complete, celebrate, culminate, unite, harmonize, synthesize, finalize
- Should address their specific challenges and goals
- Match their comfort level and preferred pace
- Be inspiring and relevant to their journey
- Avoid generic terms unless used in a unique way

Generate only the title, nothing else.
''',
      ];

      final prompt = chapterPrompts[chapterNum - 1];

      final response = await AiRouter.generate(
        task: AiTaskType.feedbackCoach,
        prompt: prompt,
      );

      return response.trim().replaceAll('"', '').replaceAll("'", '');
    } catch (e) {
      // Diverse fallback titles based on chapter number with different themes
      final fallbackTitles = [
        'Discovering New Possibilities',
        'Cultivating Your Strengths',
        'Perfecting Your Approach',
        'Putting Theory Into Practice',
        'Uniting All Your Skills',
      ];

      return fallbackTitles[chapterNum - 1];
    }
  }

  // Generate personalized chapter mission with onboarding data
  Future<Map<String, dynamic>>
  _generatePersonalizedChapterMissionWithOnboarding(
    String bookTitle,
    String chapterTitle,
    int chapterNum,
    String bookTheme,
    int bookNumber,
    OnboardingData onboardingData,
    String userId,
  ) async {
    try {
      final personalizationContext =
          '''
Based on your profile:
- Current mood: ${onboardingData.mood}
- Main goal: ${onboardingData.goal}${onboardingData.customGoal != null ? ' (${onboardingData.customGoal})' : ''}
- Preferred mode: ${onboardingData.mode}
- Social comfort level: ${onboardingData.socialComfort}
- Talk frequency: ${onboardingData.talkFrequency}
''';

      // Determine mission type based on book number and chapter
      final missionType = _getMissionTypeForChapter(bookNumber, chapterNum);
      final missionFocus = _getMissionFocusForChapter(chapterNum);

      // Determine difficulty level (start with medium for first book)
      final difficulty = bookNumber == 1 ? 'medium' : 'medium';

      // Generate AI context prompt for first book
      final aiContext = '';

      final prompt =
          '''
Create a practical, real-world mission for chapter $chapterNum: "$chapterTitle" 
from "$bookTitle" (book $bookNumber, theme: $bookTheme).

MISSION TYPE: $missionType
CHAPTER FOCUS: $missionFocus
DIFFICULTY LEVEL: $difficulty

$personalizationContext

$aiContext

Generate a mission that includes:
1. Mission Objective: A clear, specific goal that can be completed in one day
2. Mission Tasks: 3-4 simple, actionable tasks that are easy to understand and complete
3. Mission Instructions: Step-by-step guidance on how to complete the mission
4. Completion Criteria: Clear criteria for when the mission is considered complete

The mission should be:
- Practical and real-world focused
- Something that can be completed in 15-60 minutes
- Easy to understand and execute
- Related to personal growth and development
- Specific and actionable (not abstract concepts)
- Tailored to your specific challenges and goals
- SPECIFICALLY tailored to your primary goal: ${onboardingData.goal}
- Match your comfort level and preferred pace
- DIRECTLY related to the chapter theme: $bookTheme
- Varied in approach (not always social interaction)
- PROGRESSIVELY CHALLENGING based on the user's skill level

MISSION VARIETY GUIDELINES:
- Book 1: Focus on foundational social skills and self-awareness
- Book 2+: Introduce more creative, reflective, and skill-building missions
- Chapter 1: Discovery and first steps
- Chapter 2: Growth and development  
- Chapter 3: Mastery and depth
- Chapter 4: Application and practice
- Chapter 5: Integration and celebration

MISSION TYPE EXAMPLES:
- Social Interaction: Conversations, asking questions, giving compliments
- Self-Reflection: Journaling, meditation, self-assessment
- Creative Expression: Writing, drawing, creating something meaningful
- Skill Building: Learning something new, practicing a technique
- Community Engagement: Helping others, volunteering, supporting friends
- Personal Challenge: Stepping outside comfort zone in various ways
- Communication: Different forms of expression and connection
- Mindfulness: Being present, observing, appreciating

IMPORTANT: Format your response EXACTLY as follows:
OBJECTIVE: [specific, actionable goal related to $bookTheme]
TASKS: [task 1] | [task 2] | [task 3]
INSTRUCTIONS: [step-by-step guidance specifically for completing the objective and tasks above]
CRITERIA: [clear completion criteria for the specific mission]

Use | (pipe) to separate tasks, not commas.

CRITICAL: The INSTRUCTIONS must be specifically about how to complete the OBJECTIVE and TASKS you just defined. Do not provide generic advice - give specific steps for this particular mission.

Avoid repetitive "walk up to stranger" missions. Be creative and varied!
''';

      final response = await AiRouter.generate(
        task: AiTaskType.feedbackCoach,
        prompt: prompt,
      );

      // Parse the response with improved logic
      final lines = response.trim().split('\n');
      String objective = '';
      List<String> tasks = [];
      String instructions = '';
      String criteria = '';

      print('DEBUG: Raw AI response: $response');
      print('DEBUG: Parsing lines: ${lines.length}');

      for (String line in lines) {
        final trimmedLine = line.trim();
        print('DEBUG: Processing line: "$trimmedLine"');

        if (trimmedLine.startsWith('OBJECTIVE:')) {
          objective = trimmedLine.substring(10).trim();
          print('DEBUG: Found objective: "$objective"');
        } else if (trimmedLine.startsWith('TASKS:')) {
          final tasksStr = trimmedLine.substring(6).trim();
          print('DEBUG: Found tasks string: "$tasksStr"');
          // Try pipe separator first, then comma
          if (tasksStr.contains('|')) {
            tasks = tasksStr
                .split('|')
                .map((t) => t.trim())
                .where((t) => t.isNotEmpty)
                .toList();
            print('DEBUG: Parsed tasks with pipe: $tasks');
          } else {
            tasks = tasksStr
                .split(',')
                .map((t) => t.trim())
                .where((t) => t.isNotEmpty)
                .toList();
            print('DEBUG: Parsed tasks with comma: $tasks');
          }
        } else if (trimmedLine.startsWith('INSTRUCTIONS:')) {
          instructions = trimmedLine.substring(13).trim();
          print('DEBUG: Found instructions: "$instructions"');
        } else if (trimmedLine.startsWith('CRITERIA:')) {
          criteria = trimmedLine.substring(9).trim();
          print('DEBUG: Found criteria: "$criteria"');
        }
      }

      // Ensure we have valid tasks
      if (tasks.isEmpty || tasks.length < 2) {
        print('DEBUG: Tasks empty or insufficient, using fallback tasks');
        tasks = [
          'Find a stranger in a public place',
          'Approach them politely and ask your question',
          'Thank them for their response',
        ];
      }

      return {
        'objective': objective.isNotEmpty
            ? objective
            : 'Complete a simple social interaction to build confidence and communication skills.',
        'tasks': tasks,
        'instructions': instructions.isNotEmpty
            ? instructions
            : 'Follow the specific tasks outlined above. Take your time and approach this challenge with confidence. Remember that every step forward is progress.',
        'criteria': criteria.isNotEmpty
            ? criteria
            : 'You have successfully completed the social interaction and received a response from the person.',
      };
    } catch (e) {
      // Fallback content with practical tasks
      return {
        'objective':
            'Complete a simple social interaction to build confidence and communication skills.',
        'tasks': [
          'Find a stranger in a public place',
          'Approach them politely and ask your question',
          'Thank them for their response',
        ],
        'instructions':
            'Follow the specific tasks outlined above. Take your time and approach this challenge with confidence. Remember that every step forward is progress.',
        'criteria':
            'You have successfully completed the social interaction and received a response from the person.',
      };
    }
  }

  // Determine personalized chapter difficulty with onboarding data
  String _determinePersonalizedChapterDifficultyWithOnboarding(
    int chapterNum,
    int bookNumber,
    OnboardingData onboardingData,
  ) {
    // Adjust based on user's mode preference
    if (onboardingData.mode.toLowerCase() == 'intense') {
      return chapterNum <= 3 ? 'medium' : 'hard';
    } else if (onboardingData.mode.toLowerCase() == 'light') {
      return chapterNum <= 4 ? 'easy' : 'medium';
    } else {
      // Mixed mode - progressive difficulty
      return chapterNum <= 2
          ? 'easy'
          : chapterNum <= 4
          ? 'medium'
          : 'hard';
    }
  }

  // Calculate personalized XP reward with onboarding data
  int _calculatePersonalizedXpRewardWithOnboarding(
    int chapterNum,
    int bookNumber,
    OnboardingData onboardingData,
  ) {
    final baseReward = _calculateXpReward(chapterNum, bookNumber);

    // Adjust based on user's talk frequency (engagement level)
    double multiplier = 1.0;

    switch (onboardingData.talkFrequency.toLowerCase()) {
      case 'daily':
        multiplier += 0.3; // High engagement bonus
        break;
      case 'every few days':
        multiplier += 0.2; // Medium engagement bonus
        break;
      case 'weekly':
        multiplier += 0.1; // Low engagement bonus
        break;
      case 'when needed':
        multiplier += 0.0; // No bonus
        break;
    }

    // Adjust based on social comfort level
    if (onboardingData.socialComfort.toLowerCase().contains('uncomfortable')) {
      multiplier += 0.2; // Bonus for facing challenges
    }

    return (baseReward * multiplier).round();
  }

  // Legacy methods for backward compatibility
  Stream<List<MainMissionModel>> streamUserMainMissions(String userId) {
    return _firestore
        .collection('missions')
        .where('userId', isEqualTo: userId)
        .orderBy('order')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MainMissionModel.fromFirestore(doc))
              .toList(),
        );
  }

  Future<void> createTestMainMissions(String userId) async {
    // Legacy method - now redirects to new system
    await initializeUserLearningJourney(userId);
  }

  Future<void> completeMainMission(String userId, String missionId) async {
    // Legacy method - now redirects to new system
    // For legacy missions, we'll need to find the bookId or handle differently
    // For now, we'll skip this as it's legacy functionality
    print('Legacy completeMainMission called - not supported in new system');
  }

  // Daily missions (unchanged)
  Stream<List<DailyMissionModel>> streamDailyMissions() {
    return _firestore
        .collection('daily_missions')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DailyMissionModel.fromFirestore(doc))
              .toList(),
        );
  }

  // Legacy method for backward compatibility
  Stream<DailyMissionModel?> streamDailyMission(String userId) {
    // Ensure a daily mission exists when the stream starts
    _ensureDailyMissionExists(userId);

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('daily_missions')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.isNotEmpty
              ? DailyMissionModel.fromFirestore(snapshot.docs.first)
              : null,
        );
  }

  // Get a specific daily mission
  Future<DailyMissionModel?> getDailyMission(String userId) async {
    try {
      // Ensure a daily mission exists before trying to get it
      await _ensureDailyMissionExists(userId);

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_missions')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return DailyMissionModel.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      print('Error getting daily mission: $e');
      return null;
    }
  }

  // Complete a daily mission
  Future<void> completeDailyMission(String userId) async {
    try {
      final mission = await getDailyMission(userId);
      if (mission != null) {
        print('Debug: Completing daily mission: ${mission.content}');
        print('Debug: Mission was completed: ${mission.isCompleted}');

        // Mark the mission as completed for this user
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('daily_missions')
            .doc(mission.id)
            .update({'isCompleted': true, 'completedAt': DateTime.now()});

        // Award XP to the user for completing the daily mission
        await _userService.addXP(
          userId,
          mission.xpReward,
          'Completed daily mission: ${mission.content}',
        );

        // Update mission streak
        await _userService.updateMissionStreak(userId);

        // Generate AI feedback for daily mission completion
        await _generateDailyMissionCompletionFeedback(userId, mission);

        // Play daily mission completion sound
        await _soundService.playMissionComplete();

        // Mark daily mission as completed in user profile
        await _userService.markDailyMissionCompleted(userId);

        print('Debug: Daily mission completed successfully');
      } else {
        print('Debug: No daily mission found to complete');
      }
    } catch (e) {
      print('Error completing daily mission: $e');
      rethrow;
    }
  }

  // Create a test daily mission (now uses AI generation)
  Future<void> createTestDailyMission(String userId) async {
    try {
      final aiMission = await _generatePersonalizedAIDailyMission(userId);

      // Override the ID to indicate it's a test mission
      final testMission = aiMission.copyWith(
        id: 'test_mission_${DateTime.now().millisecondsSinceEpoch}',
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_missions')
          .doc(testMission.id)
          .set(testMission.toFirestore());

      print('Created AI-generated test mission: ${testMission.content}');
    } catch (e) {
      print('Error creating test daily mission: $e');
      rethrow;
    }
  }

  // Force generate a new daily mission (for testing or manual refresh)
  Future<void> forceGenerateNewDailyMission() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        final newMission = await _generatePersonalizedAIDailyMission(
          currentUser.uid,
        );
        await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('daily_missions')
            .doc(newMission.id)
            .set(newMission.toFirestore());

        print(
          'Force generated new personalized AI daily mission: ${newMission.content}',
        );
      } else {
        print('No user logged in, cannot generate personalized mission');
      }
    } catch (e) {
      print('Error force generating daily mission: $e');
      rethrow;
    }
  }

  // Generate AI feedback for mission completion
  Future<void> _generateMissionCompletionFeedback(
    String userId,
    ChapterModel chapter,
    BookModel book,
  ) async {
    try {
      // Get user for context
      final user = await _userService.getUser(userId);
      if (user == null) return;

      // Create a simple MainMissionModel from the chapter for AI feedback
      final mission = MainMissionModel(
        id: chapter.id,
        title: chapter.title,
        description: chapter.missionObjective,
        completed: true,
        createdAt: chapter.createdAt,
        order: chapter.chapterNumber,
        difficulty: chapter.difficulty,
        xpReward: chapter.xpReward,
        book: book.title,
        chapter: 'Chapter ${chapter.chapterNumber}',
      );

      // Generate AI feedback
      await _aiChatService.generateMissionCompletionFeedback(
        userId,
        mission,
        user,
      );

      print('AI feedback generated for mission completion: ${chapter.title}');
    } catch (e) {
      print('Error generating AI feedback: $e');
      // Don't throw - this is optional feedback
    }
  }

  // Generate AI feedback for daily mission completion
  Future<void> _generateDailyMissionCompletionFeedback(
    String userId,
    DailyMissionModel mission,
  ) async {
    try {
      // Get user for context
      final user = await _userService.getUser(userId);
      if (user == null) return;

      // Create a simple MainMissionModel from the daily mission for AI feedback
      final mainMission = MainMissionModel(
        id: mission.id,
        title: 'Daily Mission',
        description: mission.content,
        completed: true,
        createdAt: mission.createdAt,
        order: 1,
        difficulty: mission.difficulty,
        xpReward: mission.xpReward,
        book: 'Daily Challenge',
        chapter: 'Today\'s Mission',
      );

      // Generate AI feedback
      await _aiChatService.generateMissionCompletionFeedback(
        userId,
        mainMission,
        user,
      );

      print(
        'AI feedback generated for daily mission completion: ${mission.content}',
      );
    } catch (e) {
      print('Error generating AI feedback for daily mission: $e');
      // Don't throw - this is optional feedback
    }
  }

  // Test method to create all 10 books for demonstration
  Future<void> createTestBooks(String userId) async {
    try {
      print('Creating 10 test books for user: $userId');

      // Create 10 books upfront with placeholder content
      for (int bookNumber = 1; bookNumber <= 10; bookNumber++) {
        String bookTitle;
        String bookDescription;
        String bookTheme;

        if (bookNumber == 1) {
          // Generate real content for the first book
          bookTitle = await _generateBookTitle(userId, bookNumber);
          bookDescription = await _generateBookDescription(
            bookTitle,
            bookNumber,
          );
          bookTheme = await _generateBookTheme(bookNumber);
        } else {
          // Use generic placeholders for locked books
          bookTitle = 'Book $bookNumber';
          bookDescription =
              'This book will be unlocked as you progress through your learning journey.';
          bookTheme = _getDefaultThemeForBook(bookNumber);
        }

        final book = BookModel(
          id: '', // Will be set by Firestore
          title: bookTitle,
          description: bookDescription,
          theme: bookTheme,
          bookNumber: bookNumber,
          createdAt: DateTime.now(),
          userId: userId,
          status: bookNumber == 1 ? BookStatus.available : BookStatus.locked,
          completedChapters: 0,
          averageCompletionTime: 0.0,
          difficultyLevel: 'medium',
          aiMetadata: {
            'generatedAt': DateTime.now().toIso8601String(),
            'version': '1.0',
            'isPlaceholder':
                bookNumber > 1, // Mark as placeholder for locked books
            'testBook': true,
          },
        );

        final bookDoc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('books')
            .add(book.toFirestore());
        final bookId = bookDoc.id;

        // Only generate chapters for the first book (available)
        if (bookNumber == 1) {
          await _generateBookChapters(bookId, userId, bookTitle, bookTheme, 1);
        }

        print('Created book $bookNumber: $bookTitle (Status: ${book.status})');
      }

      print('Successfully created 10 test books!');
    } catch (e) {
      print('Error creating test books: $e');
      rethrow;
    }
  }

  // Determine difficulty level from onboarding answers
  String _determineDifficultyFromOnboarding(OnboardingData onboardingData) {
    switch (onboardingData.socialComfort.toLowerCase()) {
      case 'very uncomfortable':
        return 'easy';
      case 'somewhat uncomfortable':
        return 'easy';
      case 'neutral':
        return 'medium';
      case 'somewhat comfortable':
        return 'medium';
      case 'very comfortable':
        return 'hard';
      default:
        return 'medium';
    }
  }

  // Determine themes from onboarding answers
  List<String> _determineThemesFromOnboarding(OnboardingData onboardingData) {
    final themes = <String>[];

    // Add themes based on primary goal
    switch (onboardingData.goal.toLowerCase()) {
      case 'make new friends':
        themes.addAll(['connection', 'courage', 'voice']);
        break;
      case 'improve social skills':
        themes.addAll(['voice', 'connection', 'foundation']);
        break;
      case 'overcome anxiety':
        themes.addAll(['courage', 'light', 'foundation']);
        break;
      case 'build confidence':
        themes.addAll(['courage', 'foundation', 'reflection']);
        break;
      case 'other':
        if (onboardingData.customGoal != null) {
          final customGoal = onboardingData.customGoal!.toLowerCase();
          if (customGoal.contains('anxiety') || customGoal.contains('fear')) {
            themes.addAll(['courage', 'light']);
          } else if (customGoal.contains('speaking') ||
              customGoal.contains('communication')) {
            themes.addAll(['voice', 'connection']);
          } else if (customGoal.contains('confidence') ||
              customGoal.contains('self-esteem')) {
            themes.addAll(['courage', 'reflection']);
          } else if (customGoal.contains('friends') ||
              customGoal.contains('social')) {
            themes.addAll(['connection', 'voice']);
          }
        }
        break;
    }

    // Add themes based on social comfort level
    switch (onboardingData.socialComfort.toLowerCase()) {
      case 'very uncomfortable':
      case 'somewhat uncomfortable':
        themes.addAll(['courage', 'foundation']);
        break;
      case 'neutral':
        themes.addAll(['light', 'reflection']);
        break;
      case 'somewhat comfortable':
      case 'very comfortable':
        themes.addAll(['transformation', 'wisdom']);
        break;
    }

    // Add themes based on mood
    switch (onboardingData.mood.toLowerCase()) {
      case 'anxious':
        themes.addAll(['light', 'courage']);
        break;
      case 'tired':
        themes.addAll(['foundation', 'reflection']);
        break;
      case 'excited':
        themes.addAll(['transformation', 'freedom']);
        break;
      case 'happy':
        themes.addAll(['connection', 'wisdom']);
        break;
      case 'calm':
        themes.addAll(['reflection', 'light']);
        break;
    }

    // Remove duplicates and return unique themes
    return themes.toSet().toList();
  }

  // Determine time preference from talk frequency
  String _determineTimePreference(String talkFrequency) {
    switch (talkFrequency.toLowerCase()) {
      case 'daily':
        return 'morning';
      case 'every few days':
        return 'afternoon';
      case 'weekly':
        return 'evening';
      case 'when needed':
        return 'flexible';
      default:
        return 'morning';
    }
  }

  // Determine motivation level from mood
  String _determineMotivationLevel(String mood) {
    switch (mood.toLowerCase()) {
      case 'excited':
        return 'high';
      case 'happy':
        return 'high';
      case 'calm':
        return 'medium';
      case 'tired':
        return 'low';
      case 'anxious':
        return 'medium';
      default:
        return 'medium';
    }
  }

  // Generate AI daily mission
  Future<DailyMissionModel> _generateAIDailyMission() async {
    try {
      final prompt = '''
Generate a short, creative daily mission for someone working on social anxiety and personal growth.

The mission should be:
- Brief and concise (max 2-3 sentences)
- Specific and actionable
- Encouraging and supportive
- Appropriate for someone with social anxiety
- Something that can be completed in one day
- Focused on small steps toward social confidence

Return only the mission content, no quotes, no additional text or formatting.
''';

      final response = await AiRouter.generate(
        task: AiTaskType.dailyMission,
        prompt: prompt,
      );

      // Clean the response - remove quotes and trim
      String cleanContent = response.trim();
      if (cleanContent.startsWith('"') && cleanContent.endsWith('"')) {
        cleanContent = cleanContent.substring(1, cleanContent.length - 1);
      }
      if (cleanContent.startsWith("'") && cleanContent.endsWith("'")) {
        cleanContent = cleanContent.substring(1, cleanContent.length - 1);
      }
      cleanContent = cleanContent.trim();

      // Determine difficulty and XP reward based on content
      final difficulty = _determineMissionDifficulty(cleanContent);
      final xpReward = _calculateMissionXPReward(difficulty);

      return DailyMissionModel(
        id: 'ai_mission_${DateTime.now().millisecondsSinceEpoch}',
        content: cleanContent,
        difficulty: difficulty,
        xpReward: xpReward,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      print('Error generating AI daily mission: $e');
      // Fallback mission
      return DailyMissionModel(
        id: 'fallback_mission_${DateTime.now().millisecondsSinceEpoch}',
        content:
            'Take a deep breath and smile at a stranger today. You\'ve got this!',
        difficulty: 'easy',
        xpReward: 10,
        createdAt: DateTime.now(),
      );
    }
  }

  // Generate personalized AI daily mission for a specific user
  Future<DailyMissionModel> _generatePersonalizedAIDailyMission(
    String userId,
  ) async {
    try {
      // Get user data for personalization
      final user = await _userService.getUser(userId);
      final analytics = await getUserLearningAnalytics(userId);

      // Check if user has premium access for enhanced AI
      final hasPremium = await _premiumService.hasPremiumAccess(userId);

      String missionText;

      if (hasPremium && user != null) {
        // Use enhanced AI for premium users
        final userContext = {
          'username': user.username,
          'currentLevel': user.level,
          'totalXP': user.xp,
          'currentMood': user.mood,
          'socialComfortLevel':
              analytics?.learningPreferences?['socialComfortLevel'] ?? 'medium',
          'primaryGoal':
              analytics?.learningPreferences?['primaryGoal'] ??
              'general confidence',
          'learningStyle':
              analytics?.learningPreferences?['learningStyle'] ?? 'balanced',
          'recentMissionTypes':
              analytics?.missionTypeCompletionCount.keys.take(3).join(', ') ??
              '',
          'completedMissions': analytics?.completedMissionsHistory.length ?? 0,
        };

        missionText = await _premiumFeatures.generateEnhancedMission(
          userId: userId,
          missionType: 'daily',
          userContext: userContext,
        );
      } else {
        // Use basic AI for regular users
        String personalizationContext = '';

        if (user != null && analytics != null) {
          // Build personalization context from user data
          final socialComfort =
              analytics.learningPreferences?['socialComfortLevel'] ?? 'medium';
          final primaryGoal =
              analytics.learningPreferences?['primaryGoal'] ??
              'general confidence';
          final learningStyle =
              analytics.learningPreferences?['learningStyle'] ?? 'balanced';

          personalizationContext =
              '''
User Context:
- Current Level: ${user.level}
- Total XP: ${user.xp}
- Social Comfort Level: $socialComfort
- Primary Goal: $primaryGoal
- Learning Style: $learningStyle
- Recent Mission Types: ${analytics.missionTypeCompletionCount.keys.take(3).join(', ')}
- Completed Missions: ${analytics.completedMissionsHistory.length}
''';
        }

        final prompt =
            '''
Generate a short, personalized daily mission for someone working on social anxiety and personal growth.

$personalizationContext

The mission should be:
- Brief and concise (max 2-3 sentences)
- Specific and actionable
- Encouraging and supportive
- Appropriate for the user's current level and comfort level
- Something that can be completed in one day
- Focused on small steps toward social confidence
- Personalized based on their goals and learning style
- Slightly challenging but not overwhelming

Consider the user's progress and create a mission that builds on their previous experiences.

Return only the mission content, no quotes, no additional text or formatting.
''';

        final response = await AiRouter.generate(
          task: AiTaskType.dailyMission,
          prompt: prompt,
        );

        missionText = response;
      }

      // Clean the response - remove quotes and trim
      String cleanContent = missionText.trim();
      if (cleanContent.startsWith('"') && cleanContent.endsWith('"')) {
        cleanContent = cleanContent.substring(1, cleanContent.length - 1);
      }
      if (cleanContent.startsWith("'") && cleanContent.endsWith("'")) {
        cleanContent = cleanContent.substring(1, cleanContent.length - 1);
      }
      cleanContent = cleanContent.trim();

      // Determine difficulty and XP reward based on content and user level
      final difficulty = _determinePersonalizedMissionDifficulty(
        cleanContent,
        user?.level ?? 1,
      );
      final xpReward = _calculatePersonalizedMissionXPReward(
        difficulty,
        user?.level ?? 1,
      );

      return DailyMissionModel(
        id: 'personalized_mission_${DateTime.now().millisecondsSinceEpoch}',
        content: cleanContent,
        difficulty: difficulty,
        xpReward: xpReward,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      print('Error generating personalized AI daily mission: $e');
      // Fallback mission
      return DailyMissionModel(
        id: 'fallback_mission_${DateTime.now().millisecondsSinceEpoch}',
        content:
            'Take a deep breath and smile at a stranger today. You\'ve got this!',
        difficulty: 'easy',
        xpReward: 10,
        createdAt: DateTime.now(),
      );
    }
  }

  // Determine personalized mission difficulty based on content and user level
  String _determinePersonalizedMissionDifficulty(
    String content,
    int userLevel,
  ) {
    final lowerContent = content.toLowerCase();

    // Adjust difficulty based on user level
    if (userLevel <= 3) {
      // Beginners get easier missions
      if (lowerContent.contains('smile') ||
          lowerContent.contains('breath') ||
          lowerContent.contains('observe') ||
          lowerContent.contains('reflect') ||
          lowerContent.contains('write') ||
          lowerContent.contains('think')) {
        return 'easy';
      }
      return 'medium';
    } else if (userLevel <= 7) {
      // Intermediate users get medium difficulty
      if (lowerContent.contains('ask') ||
          lowerContent.contains('greet') ||
          lowerContent.contains('compliment') ||
          lowerContent.contains('thank') ||
          lowerContent.contains('hold door') ||
          lowerContent.contains('small talk')) {
        return 'medium';
      }
      return 'hard';
    } else {
      // Advanced users get harder missions
      if (lowerContent.contains('introduce') ||
          lowerContent.contains('join') ||
          lowerContent.contains('present') ||
          lowerContent.contains('speak up') ||
          lowerContent.contains('initiate') ||
          lowerContent.contains('group')) {
        return 'hard';
      }
      return 'medium';
    }
  }

  // Calculate personalized XP reward based on difficulty and user level
  int _calculatePersonalizedMissionXPReward(String difficulty, int userLevel) {
    int baseReward;
    switch (difficulty) {
      case 'easy':
        baseReward = 10;
        break;
      case 'medium':
        baseReward = 15;
        break;
      case 'hard':
        baseReward = 25;
        break;
      default:
        baseReward = 15;
    }

    // Add level bonus (higher levels get more XP)
    final levelBonus = (userLevel - 1) * 2;
    return baseReward + levelBonus;
  }

  // Determine mission difficulty based on content
  String _determineMissionDifficulty(String content) {
    final lowerContent = content.toLowerCase();

    // Easy missions - simple, low-risk activities
    if (lowerContent.contains('smile') ||
        lowerContent.contains('breath') ||
        lowerContent.contains('observe') ||
        lowerContent.contains('reflect') ||
        lowerContent.contains('write') ||
        lowerContent.contains('think')) {
      return 'easy';
    }

    // Medium missions - some social interaction
    if (lowerContent.contains('ask') ||
        lowerContent.contains('greet') ||
        lowerContent.contains('compliment') ||
        lowerContent.contains('thank') ||
        lowerContent.contains('hold door') ||
        lowerContent.contains('small talk')) {
      return 'medium';
    }

    // Hard missions - more challenging social situations
    if (lowerContent.contains('introduce') ||
        lowerContent.contains('join') ||
        lowerContent.contains('present') ||
        lowerContent.contains('speak up') ||
        lowerContent.contains('initiate') ||
        lowerContent.contains('group')) {
      return 'hard';
    }

    return 'medium'; // Default
  }

  // Calculate XP reward based on difficulty
  int _calculateMissionXPReward(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return 10;
      case 'medium':
        return 15;
      case 'hard':
        return 25;
      default:
        return 15;
    }
  }

  // Check if we need to generate a new daily mission
  Future<bool> _shouldGenerateNewDailyMission(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_missions')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return true; // No missions exist, generate one
      }

      final lastMission = DailyMissionModel.fromFirestore(snapshot.docs.first);
      final now = DateTime.now();
      final missionDate = DateTime(
        lastMission.createdAt.year,
        lastMission.createdAt.month,
        lastMission.createdAt.day,
      );
      final today = DateTime(now.year, now.month, now.day);

      // Generate new mission if it's a new day
      return missionDate.isBefore(today);
    } catch (e) {
      print('Error checking if should generate new mission: $e');
      return true; // Generate on error to be safe
    }
  }

  // Generate new daily mission if needed
  Future<void> _ensureDailyMissionExists(String userId) async {
    try {
      print('Debug: Ensuring daily mission exists for user $userId');

      // Check if user is premium
      final user = await _userService.getUser(userId);
      if (user == null) {
        print('Debug: User not found');
        return;
      }

      // For non-premium users, check if they've already completed a daily mission today
      if (!user.premium) {
        final hasCompletedDailyMissionToday =
            await _hasCompletedDailyMissionToday(userId);
        if (hasCompletedDailyMissionToday) {
          print(
            'Non-premium user $userId has already completed a daily mission today',
          );
          return; // Don't generate new daily mission for non-premium users who already completed one
        }
      }

      // Check if there's an uncompleted mission for today
      final hasUncompletedMissionToday = await _hasUncompletedMissionToday(
        userId,
      );

      print(
        'Debug: Has uncompleted mission today: $hasUncompletedMissionToday',
      );

      if (!hasUncompletedMissionToday &&
          await _shouldGenerateNewDailyMission(userId)) {
        print('Debug: Generating new daily mission');
        // Generate personalized mission for the specific user
        final newMission = await _generatePersonalizedAIDailyMission(userId);
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('daily_missions')
            .doc(newMission.id)
            .set(newMission.toFirestore());

        print(
          'Generated new personalized AI daily mission for user $userId: ${newMission.content}',
        );
      } else {
        print(
          'Debug: No new mission needed - uncompleted exists or should not generate',
        );
      }
    } catch (e) {
      print('Error ensuring daily mission exists: $e');
    }
  }

  // Check if user has completed a daily mission today
  Future<bool> _hasCompletedDailyMissionToday(String userId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Check daily missions completed today
      final dailyMissionsQuery = await _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_missions')
          .where('isCompleted', isEqualTo: true)
          .where(
            'completedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where('completedAt', isLessThan: Timestamp.fromDate(endOfDay))
          .limit(1)
          .get();

      return dailyMissionsQuery.docs.isNotEmpty;
    } catch (e) {
      print('Error checking if user completed daily mission today: $e');
      return false;
    }
  }

  // Check if user has completed a chapter today
  Future<bool> _hasCompletedChapterToday(String userId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Check chapters completed today
      final chaptersQuery = await _firestore
          .collection('users')
          .doc(userId)
          .collection('books')
          .get();

      for (final bookDoc in chaptersQuery.docs) {
        final chaptersSnapshot = await bookDoc.reference
            .collection('chapters')
            .where('completed', isEqualTo: true)
            .where(
              'completedAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
            )
            .where('completedAt', isLessThan: Timestamp.fromDate(endOfDay))
            .limit(1)
            .get();

        if (chaptersSnapshot.docs.isNotEmpty) {
          return true;
        }
      }

      return false;
    } catch (e) {
      print('Error checking if user completed chapter today: $e');
      return false;
    }
  }

  // Check if user has an uncompleted mission for today
  Future<bool> _hasUncompletedMissionToday(String userId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Check for uncompleted missions created today
      final uncompletedMissionsQuery = await _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_missions')
          .where('isCompleted', isEqualTo: false)
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
          .limit(1)
          .get();

      return uncompletedMissionsQuery.docs.isNotEmpty;
    } catch (e) {
      print('Error checking if user has uncompleted mission today: $e');
      return false;
    }
  }

  // Check if user has completed any mission today (for backward compatibility)
  Future<bool> _hasCompletedMissionToday(String userId) async {
    final hasCompletedDailyMission = await _hasCompletedDailyMissionToday(
      userId,
    );
    final hasCompletedChapter = await _hasCompletedChapterToday(userId);
    return hasCompletedDailyMission || hasCompletedChapter;
  }

  // Reset daily missions at 1:00 AM local time
  Future<void> resetDailyMissionsAtMidnight(String userId) async {
    try {
      final now = DateTime.now();
      final user = await _userService.getUser(userId);
      if (user == null) return;

      // Get user's timezone (default to UTC if not set)
      final userTimezone = user.timezone ?? 'UTC';

      // Check if it's 1:00 AM in the user's timezone
      final userLocalTime = _getUserLocalTime(now, userTimezone);
      final isResetTime = userLocalTime.hour == 1 && userLocalTime.minute == 0;

      if (isResetTime) {
        print(
          'Attempting to reset daily missions for user $userId at ${userLocalTime.toString()}',
        );

        // Reset all completed daily missions for this user
        final completedMissionsQuery = await _firestore
            .collection('users')
            .doc(userId)
            .collection('daily_missions')
            .where('isCompleted', isEqualTo: true)
            .get();

        print(
          'Found ${completedMissionsQuery.docs.length} completed missions to reset',
        );

        if (completedMissionsQuery.docs.isNotEmpty) {
          final batch = _firestore.batch();

          for (final doc in completedMissionsQuery.docs) {
            batch.update(doc.reference, {
              'isCompleted': false,
              'completedAt': null,
            });
          }

          // Also reset the user's dailyMissionCompleted field
          batch.update(_firestore.collection('users').doc(userId), {
            'dailyMissionCompleted': false,
          });

          await batch.commit();
          print(
            'Successfully reset ${completedMissionsQuery.docs.length} daily missions and user completion status for user $userId',
          );

          // After resetting, ensure there's a new uncompleted mission available
          await _ensureDailyMissionExists(userId);
        } else {
          print('No completed missions found to reset for user $userId');
        }
      } else {
        print(
          'Not reset time for user $userId. Current local time: ${userLocalTime.hour}:${userLocalTime.minute}',
        );
      }
    } catch (e) {
      print('Error resetting daily missions: $e');
    }
  }

  // Get user's local time based on their timezone
  DateTime _getUserLocalTime(DateTime utcTime, String timezone) {
    try {
      // For now, we'll use a simple approach
      // In a production app, you'd use a proper timezone library like timezone
      final offset = _getTimezoneOffset(timezone);
      return utcTime.add(Duration(hours: offset));
    } catch (e) {
      // Fallback to UTC
      return utcTime;
    }
  }

  // Get timezone offset (simplified - in production use proper timezone library)
  int _getTimezoneOffset(String timezone) {
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

    return offsets[timezone.toUpperCase()] ?? 0;
  }

  // Public method to ensure daily mission exists
  Future<void> ensureDailyMissionExists(String userId) async {
    await _ensureDailyMissionExists(userId);
  }

  // Manual reset for testing - resets both mission documents and user completion status
  Future<void> manualResetDailyMissions(String userId) async {
    try {
      print('Manually resetting daily missions for user: $userId');

      // Reset all completed daily missions for this user
      final completedMissionsQuery = await _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_missions')
          .where('isCompleted', isEqualTo: true)
          .get();

      if (completedMissionsQuery.docs.isNotEmpty) {
        final batch = _firestore.batch();

        for (final doc in completedMissionsQuery.docs) {
          batch.update(doc.reference, {
            'isCompleted': false,
            'completedAt': null,
          });
        }

        // Also reset the user's dailyMissionCompleted field
        batch.update(_firestore.collection('users').doc(userId), {
          'dailyMissionCompleted': false,
        });

        await batch.commit();
        print(
          'Successfully manually reset ${completedMissionsQuery.docs.length} daily missions and user completion status for user $userId',
        );
      } else {
        print('No completed missions found to reset for user $userId');
      }

      // Ensure there's a new uncompleted mission available
      await _ensureDailyMissionExists(userId);
    } catch (e) {
      print('Error manually resetting daily missions: $e');
      rethrow;
    }
  }

  // Check if daily mission should be reset (called periodically)
  Future<void> checkAndResetDailyMissions(String userId) async {
    try {
      final now = DateTime.now();
      final user = await _userService.getUser(userId);
      if (user == null) {
        print('User not found for daily mission reset check: $userId');
        return;
      }

      final userTimezone = user.timezone ?? 'UTC';
      final userLocalTime = _getUserLocalTime(now, userTimezone);

      print('Checking daily mission reset for user $userId:');
      print('- UTC time: ${now.toString()}');
      print('- User timezone: $userTimezone');
      print('- User local time: ${userLocalTime.toString()}');
      print(
        '- Current hour: ${userLocalTime.hour}, minute: ${userLocalTime.minute}',
      );

      // Check if it's between 1:00 AM and 1:05 AM in user's timezone (5-minute window)
      final isResetWindow =
          userLocalTime.hour == 1 &&
          userLocalTime.minute >= 0 &&
          userLocalTime.minute <= 4;

      if (isResetWindow) {
        print(
          'Reset window detected for user $userId at ${userLocalTime.toString()}',
        );
        await resetDailyMissionsAtMidnight(userId);
      } else {
        print(
          'Not in reset window for user $userId. Current local time: ${userLocalTime.hour}:${userLocalTime.minute.toString().padLeft(2, '0')}',
        );

        // Check if we need to reset based on the last mission date
        await _checkAndResetBasedOnLastMissionDate(userId);
      }
    } catch (e) {
      print('Error checking daily mission reset: $e');
    }
  }

  // Check if we need to reset based on the last mission's creation date
  Future<void> _checkAndResetBasedOnLastMissionDate(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('daily_missions')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final lastMission = DailyMissionModel.fromFirestore(
          snapshot.docs.first,
        );
        final now = DateTime.now();
        final missionDate = DateTime(
          lastMission.createdAt.year,
          lastMission.createdAt.month,
          lastMission.createdAt.day,
        );
        final today = DateTime(now.year, now.month, now.day);

        print(
          'Debug: Last mission created on ${missionDate.toString()}, today is ${today.toString()}',
        );
        print('Debug: Mission is completed: ${lastMission.isCompleted}');

        // If the last mission was created on a different day, reset
        if (missionDate.isBefore(today)) {
          print(
            'Last mission was created on ${missionDate.toString()}, today is ${today.toString()}. Resetting daily missions.',
          );
          await manualResetDailyMissions(userId);
        } else {
          // Ensure there's an uncompleted mission available
          await _ensureDailyMissionExists(userId);
        }
      } else {
        // No missions exist, ensure one is created
        await _ensureDailyMissionExists(userId);
      }
    } catch (e) {
      print('Error checking and resetting based on last mission date: $e');
    }
  }
}
