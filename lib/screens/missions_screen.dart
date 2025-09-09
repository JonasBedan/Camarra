import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;
import 'dart:ui';
import '../utils/user_service.dart';
import '../utils/mission_service.dart';
import '../models/user_model.dart';
import '../models/mission_model.dart';

class MissionsScreen extends StatefulWidget {
  const MissionsScreen({super.key});

  @override
  State<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends State<MissionsScreen> {
  final MissionService _missionService = MissionService();
  final UserService _userService = UserService();

  Future<void> _createTestMissions() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() {
      // Show loading state
    });

    try {
      print('Starting AI book generation for user: ${currentUser.uid}');
      await _missionService.initializeUserLearningJourney(currentUser.uid);
      print('AI book generation completed successfully');

      // Check if widget is still mounted before showing snackbar
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('AI books created! 📚')));
      }
    } catch (e) {
      print('Error creating AI books: $e');
      // Check if widget is still mounted before showing snackbar
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to create books: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back, color: theme.iconTheme.color),
                  ),
                  Expanded(
                    child: Text(
                      'Learning Journey',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Development button to create test books
                  IconButton(
                    onPressed: _createTestMissions,
                    icon: const Icon(Icons.add),
                    tooltip: 'Create Test Books',
                  ),
                ],
              ),
            ),

            // Books Path
            Expanded(
              child: StreamBuilder<UserModel?>(
                stream: _userService.streamUser(currentUser?.uid ?? ''),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final user = userSnapshot.data;
                  if (user == null) {
                    return const Center(child: Text('User not found'));
                  }

                  return StreamBuilder<List<BookModel>>(
                    stream: _missionService.streamUserBooks(
                      currentUser?.uid ?? '',
                    ),
                    builder: (context, booksSnapshot) {
                      if (booksSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final books = booksSnapshot.data ?? [];

                      if (books.isEmpty) {
                        return _buildEmptyState();
                      }

                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Stack(
                          children: [
                            // Single continuous background path
                            Positioned.fill(
                              child: CustomPaint(
                                painter: ContinuousPathPainter(
                                  missionCount: books.length,
                                  color: const Color(0xFF6B46C1),
                                ),
                                child: Container(),
                              ),
                            ),
                            // Foreground book cards
                            Column(
                              children: [
                                ...books.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final book = entry.value;
                                  final isCompleted = book.isCompleted;
                                  final isNextAvailable = book.isUnlocked;

                                  return _buildBookIsland(
                                    book,
                                    isCompleted,
                                    isNextAvailable,
                                    index,
                                    () => _showBookDetails(book),
                                  );
                                }),
                                // Add bottom padding to prevent overflow
                                const SizedBox(height: 100),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context, 1),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.book,
            size: 64,
            color: theme.colorScheme.onSurface.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No books available yet',
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start your learning journey!',
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _createTestMissions,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Create First Book'),
          ),
        ],
      ),
    );
  }

  Widget _buildBookIsland(
    BookModel book,
    bool isCompleted,
    bool isNextAvailable,
    int index,
    VoidCallback onTap,
  ) {
    final isLeft = index % 2 == 0;

    return GestureDetector(
      onTap: isNextAvailable ? onTap : null,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            if (isLeft) ...[
              // Left side - Book Island
              Expanded(
                flex: 3,
                child: _buildBookCard(book, isCompleted, isNextAvailable),
              ),
              const SizedBox(width: 20),
              // Right side - Illustration
              Expanded(flex: 2, child: _buildBookIllustration(book, index)),
            ] else ...[
              // Right side - Illustration
              Expanded(flex: 2, child: _buildBookIllustration(book, index)),
              const SizedBox(width: 20),
              // Right side - Book Island
              Expanded(
                flex: 3,
                child: _buildBookCard(book, isCompleted, isNextAvailable),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBookCard(
    BookModel book,
    bool isCompleted,
    bool isNextAvailable,
  ) {
    final theme = Theme.of(context);
    // For locked books, show a blurred rectangle with lock
    if (!isNextAvailable && !isCompleted) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(0.8),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Blurred content background
            Container(
              width: double.infinity,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    color: theme.colorScheme.surface.withOpacity(0.95),
                    child: Center(
                      child: Text(
                        'Book ${book.bookNumber}',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Lock icon overlay
            Positioned.fill(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: theme.shadowColor.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.lock,
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Original card for available and completed books
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCompleted
            ? theme.colorScheme.primary
            : isNextAvailable
            ? theme.cardColor
            : theme.colorScheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? Colors.white.withOpacity(0.2)
                      : const Color(0xFF6B46C1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getBookIcon(book.theme),
                  color: isCompleted
                      ? Colors.white
                      : isNextAvailable
                      ? const Color(0xFF6B46C1)
                      : Colors.grey[500],
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isCompleted
                            ? Colors.white
                            : isNextAvailable
                            ? theme.textTheme.titleMedium?.color
                            : theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Book ${book.bookNumber} • ${book.completedChapters}/5 Chapters',
                      style: TextStyle(
                        fontSize: 12,
                        color: isCompleted
                            ? Colors.white.withOpacity(0.8)
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (isCompleted)
                const Icon(Icons.check_circle, color: Colors.white, size: 20)
              else if (!isNextAvailable)
                Icon(Icons.lock, color: Colors.grey[500], size: 20),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: isCompleted
                  ? Colors.white.withOpacity(0.3)
                  : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: book.progress,
              child: Container(
                decoration: BoxDecoration(
                  color: isCompleted ? Colors.white : const Color(0xFF6B46C1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getDifficultyColor(book.difficultyLevel).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              book.difficultyLevel.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                color: _getDifficultyColor(book.difficultyLevel),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookIllustration(BookModel book, int index) {
    // For locked books, show the illustration but with reduced opacity
    if (book.status == BookStatus.locked) {
      return Container(
        height: 80,
        child: Opacity(opacity: 0.7, child: _getBookIllustration(book, index)),
      );
    }

    // For available and completed books, show normal illustration
    return Container(height: 80, child: _getBookIllustration(book, index));
  }

  Widget _getBookIllustration(BookModel book, int index) {
    switch (book.theme.toLowerCase()) {
      case 'courage':
        return _buildCourageIllustration();
      case 'light':
        return _buildLightIllustration();
      case 'voice':
        return _buildVoiceIllustration();
      case 'foundation':
        return _buildFoundationIllustration();
      case 'reflection':
        return _buildReflectionIllustration();
      case 'transformation':
        return _buildTransformationIllustration();
      case 'connection':
        return _buildConnectionIllustration();
      case 'freedom':
        return _buildFreedomIllustration();
      case 'wisdom':
        return _buildWisdomIllustration();
      case 'completion':
        return _buildCompletionIllustration();
      default:
        return _buildDefaultIllustration();
    }
  }

  IconData _getBookIcon(String theme) {
    switch (theme.toLowerCase()) {
      case 'courage':
        return Icons.psychology;
      case 'light':
        return Icons.lightbulb;
      case 'voice':
        return Icons.record_voice_over;
      case 'foundation':
        return Icons.fitness_center;
      case 'reflection':
        return Icons.face;
      case 'transformation':
        return Icons.transform;
      case 'connection':
        return Icons.visibility;
      case 'freedom':
        return Icons.flight_takeoff;
      case 'wisdom':
        return Icons.school;
      case 'completion':
        return Icons.flag;
      default:
        return Icons.book;
    }
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

  void _showBookDetails(BookModel book) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // Book Header
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6B46C1),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(
                            _getBookIcon(book.theme),
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                book.title,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: theme.textTheme.titleLarge?.color,
                                ),
                                softWrap: true,
                                overflow: TextOverflow.visible,
                              ),
                              Text(
                                'Book ${book.bookNumber} • ${book.theme}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: theme.textTheme.bodySmall?.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Progress Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Progress',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: theme.textTheme.titleMedium?.color,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: book.progress,
                                  backgroundColor: theme.colorScheme.onSurface
                                      .withOpacity(0.2),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${(book.progress * 100).toInt()}%',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${book.completedChapters} of 5 chapters completed',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Book Description
                    Text(
                      'About This Book',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.titleMedium?.color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      book.description,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                      softWrap: true,
                      overflow: TextOverflow.visible,
                    ),

                    const SizedBox(height: 20),

                    // Chapters List
                    Text(
                      'Chapters',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.titleMedium?.color,
                      ),
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<List<ChapterModel>>(
                      stream: _missionService.streamBookChapters(
                        FirebaseAuth.instance.currentUser?.uid ?? '',
                        book.id,
                      ),
                      builder: (context, chaptersSnapshot) {
                        if (chaptersSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final chapters = chaptersSnapshot.data ?? [];

                        return Column(
                          children: chapters.map((chapter) {
                            return _buildChapterTile(chapter, book);
                          }).toList(),
                        );
                      },
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterTile(ChapterModel chapter, BookModel book) {
    final theme = Theme.of(context);
    final isCompleted = chapter.completed;
    final isNextAvailable =
        chapter.chapterNumber == 1 ||
        (chapter.chapterNumber > 1 &&
            _isPreviousChapterCompleted(chapter.chapterNumber - 1, book.id));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCompleted
            ? theme.colorScheme.primary.withOpacity(0.1)
            : theme.colorScheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface.withOpacity(0.3),
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isCompleted
                ? theme.colorScheme.primary
                : isNextAvailable
                ? theme.colorScheme.primary.withOpacity(0.1)
                : theme.colorScheme.onSurface.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isCompleted
                ? Icons.check
                : isNextAvailable
                ? Icons.play_arrow
                : Icons.lock,
            color: isCompleted
                ? Colors.white
                : isNextAvailable
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withOpacity(0.5),
            size: 20,
          ),
        ),
        title: Text(
          'Chapter ${chapter.chapterNumber}: ${chapter.title}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isCompleted
                ? theme.colorScheme.primary
                : isNextAvailable
                ? theme.textTheme.titleMedium?.color
                : theme.colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
        subtitle: Text(
          chapter.missionObjective,
          style: TextStyle(
            fontSize: 12,
            color: theme.textTheme.bodySmall?.color,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${chapter.xpReward} XP',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isCompleted
                    ? theme.colorScheme.primary
                    : theme.textTheme.bodySmall?.color,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getDifficultyColor(chapter.difficulty).withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                chapter.difficulty.toUpperCase(),
                style: TextStyle(
                  fontSize: 8,
                  color: _getDifficultyColor(chapter.difficulty),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        onTap: isNextAvailable
            ? () => _showChapterDetails(chapter, book.id)
            : null,
      ),
    );
  }

  bool _isPreviousChapterCompleted(int chapterNumber, String bookId) {
    // This would need to be implemented with actual data
    // For now, return true to allow progression
    return true;
  }

  void _showChapterDetails(ChapterModel chapter, String bookId) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // Chapter Header
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6B46C1),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                chapter.title,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                softWrap: true,
                                overflow: TextOverflow.visible,
                              ),
                              Text(
                                'Chapter ${chapter.chapterNumber}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Mission Objective
                    Text(
                      'Mission Objective',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      chapter.missionObjective,
                      style: const TextStyle(fontSize: 16, height: 1.5),
                      softWrap: true,
                      overflow: TextOverflow.visible,
                    ),

                    const SizedBox(height: 20),

                    // Mission Tasks
                    Text(
                      'Tasks to Complete',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const SizedBox(height: 8),
                    ...chapter.missionTasks
                        .map(
                          (task) => Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(
                                    top: 6,
                                    right: 12,
                                  ),
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6B46C1),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    task,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                    softWrap: true,
                                    overflow: TextOverflow.visible,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),

                    const SizedBox(height: 20),

                    // Mission Instructions
                    Text(
                      'Instructions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      chapter.missionInstructions,
                      style: const TextStyle(fontSize: 14, height: 1.5),
                      softWrap: true,
                      overflow: TextOverflow.visible,
                    ),

                    const SizedBox(height: 20),

                    // Completion Criteria
                    Text(
                      'Completion Criteria',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1ECFB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF6B46C1).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        chapter.completionCriteria,
                        style: const TextStyle(fontSize: 14, height: 1.4),
                        softWrap: true,
                        overflow: TextOverflow.visible,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Chapter Stats
                    Row(
                      children: [
                        _buildStatChip(
                          'Difficulty',
                          chapter.difficulty.toUpperCase(),
                        ),
                        const SizedBox(width: 12),
                        _buildStatChip('XP Reward', '${chapter.xpReward} XP'),
                      ],
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Action Button (Fixed at bottom)
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  if (!chapter.completed)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _completeChapter(chapter, bookId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6B46C1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Complete Chapter',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  else if (chapter.chapterNumber == 5)
                    // Special congratulations message for completing the final chapter
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B46C1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF6B46C1)),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.celebration,
                            color: Color(0xFF6B46C1),
                            size: 32,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '🎉 Congratulations! 🎉',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6B46C1),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'You\'ve completed this book!',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF6B46C1),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6B46C1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Generating your next adventure...',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: const Center(
                        child: Text(
                          'Chapter Completed! 🎉',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _completeChapter(ChapterModel chapter, String bookId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await _missionService.completeChapter(
        chapter.id,
        currentUser.uid,
        bookId,
        completionTime: 1.0, // Default completion time
      );

      Navigator.pop(context); // Close the modal

      // Show different messages based on whether it's the final chapter
      if (chapter.chapterNumber == 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '🎉 Book completed! Generating your next adventure...',
            ),
            backgroundColor: Color(0xFF6B46C1),
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chapter "${chapter.title}" completed! 🎉')),
        );
      }
    } catch (e) {
      String errorMessage = 'Failed to complete chapter';

      // Provide more specific error messages
      if (e.toString().contains('already completed')) {
        errorMessage = 'This chapter is already completed';
      } else if (e.toString().contains('Book is already completed')) {
        errorMessage = 'This book is already completed';
      } else if (e.toString().contains('already being generated')) {
        errorMessage =
            'Your next book is already being generated. Please wait...';
      } else if (e.toString().contains(
        'Non-premium users can only complete one chapter per day',
      )) {
        errorMessage =
            'You\'ve completed your chapter for today! Upgrade to Premium for unlimited chapters.';

        // Show a more prominent message with upgrade option
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Chapter Limit Reached'),
              content: const Text(
                'You\'ve completed your chapter for today. Upgrade to Premium for unlimited chapters and more features!',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Maybe Later'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.pushNamed(context, '/premium');
                  },
                  child: const Text('Upgrade to Premium'),
                ),
              ],
            );
          },
        );
        return; // Don't show the snackbar for this case
      } else {
        errorMessage = 'Failed to complete chapter: $e';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildStatChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1ECFB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6B46C1),
            ),
          ),
        ],
      ),
    );
  }

  // Illustration methods (same as before)
  Widget _buildCourageIllustration() {
    return CustomPaint(painter: CouragePainter(), size: const Size(80, 80));
  }

  Widget _buildLightIllustration() {
    return CustomPaint(painter: LightPainter(), size: const Size(80, 80));
  }

  Widget _buildVoiceIllustration() {
    return CustomPaint(painter: VoicePainter(), size: const Size(80, 80));
  }

  Widget _buildFoundationIllustration() {
    return CustomPaint(painter: FoundationPainter(), size: const Size(80, 80));
  }

  Widget _buildReflectionIllustration() {
    return CustomPaint(painter: ReflectionPainter(), size: const Size(80, 80));
  }

  Widget _buildTransformationIllustration() {
    return CustomPaint(
      painter: TransformationPainter(),
      size: const Size(80, 80),
    );
  }

  Widget _buildConnectionIllustration() {
    return CustomPaint(painter: ConnectionPainter(), size: const Size(80, 80));
  }

  Widget _buildFreedomIllustration() {
    return CustomPaint(painter: FreedomPainter(), size: const Size(80, 80));
  }

  Widget _buildWisdomIllustration() {
    return CustomPaint(painter: WisdomPainter(), size: const Size(80, 80));
  }

  Widget _buildCompletionIllustration() {
    return CustomPaint(painter: CompletionPainter(), size: const Size(80, 80));
  }

  Widget _buildDefaultIllustration() {
    return CustomPaint(painter: DefaultPainter(), size: const Size(80, 80));
  }

  // Bottom navigation bar
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
            // Already on missions
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

// Custom painters for illustrations
class ContinuousPathPainter extends CustomPainter {
  final int missionCount;
  final Color color;

  ContinuousPathPainter({required this.missionCount, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final double cardHeight = size.height / (missionCount + 1);

    // Start from top center
    path.moveTo(size.width * 0.5, 0);

    // Create a winding path through all mission positions
    for (int i = 0; i < missionCount; i++) {
      final double y = cardHeight * (i + 1);
      final bool isLeft = i % 2 == 0;
      final double x = isLeft ? size.width * 0.2 : size.width * 0.8;

      // Create a more dramatic curve to the next position
      if (isLeft) {
        // Curve to left position - more dramatic curve
        path.quadraticBezierTo(
          size.width * 0.1, // Control point further left for more curve
          y - cardHeight * 0.4,
          x,
          y,
        );
      } else {
        // Curve to right position - more dramatic curve
        path.quadraticBezierTo(
          size.width * 0.9, // Control point further right for more curve
          y - cardHeight * 0.4,
          x,
          y,
        );
      }
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = 8.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is ContinuousPathPainter &&
        oldDelegate.missionCount != missionCount;
  }
}

// Add the new custom painters for the book themes
class FoundationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF6B46C1)
      ..style = PaintingStyle.fill;

    // Draw a strong foundation/base
    final basePath = Path();
    basePath.addRect(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.8),
        width: size.width * 0.8,
        height: size.height * 0.2,
      ),
    );
    canvas.drawPath(basePath, paint);

    // Draw a pillar
    final pillarPaint = Paint()
      ..color = const Color(0xFF6B46C1)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.5),
        width: size.width * 0.2,
        height: size.height * 0.6,
      ),
      pillarPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ReflectionPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF6B46C1)
      ..style = PaintingStyle.fill;

    // Draw mirror frame
    final framePath = Path();
    framePath.addRect(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.5),
        width: size.width * 0.6,
        height: size.height * 0.6,
      ),
    );
    canvas.drawPath(framePath, paint);

    // Draw mirror surface
    final mirrorPaint = Paint()
      ..color = Colors.grey[300]!
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.5),
        width: size.width * 0.5,
        height: size.height * 0.5,
      ),
      mirrorPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TransformationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF6B46C1)
      ..style = PaintingStyle.fill;

    // Draw a butterfly-like transformation
    final leftWing = Path();
    leftWing.moveTo(size.width * 0.5, size.height * 0.5);
    leftWing.quadraticBezierTo(
      size.width * 0.2,
      size.height * 0.3,
      size.width * 0.1,
      size.height * 0.5,
    );
    leftWing.quadraticBezierTo(
      size.width * 0.2,
      size.height * 0.7,
      size.width * 0.5,
      size.height * 0.5,
    );
    canvas.drawPath(leftWing, paint);

    final rightWing = Path();
    rightWing.moveTo(size.width * 0.5, size.height * 0.5);
    rightWing.quadraticBezierTo(
      size.width * 0.8,
      size.height * 0.3,
      size.width * 0.9,
      size.height * 0.5,
    );
    rightWing.quadraticBezierTo(
      size.width * 0.8,
      size.height * 0.7,
      size.width * 0.5,
      size.height * 0.5,
    );
    canvas.drawPath(rightWing, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class FreedomPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF6B46C1)
      ..style = PaintingStyle.fill;

    // Draw a bird in flight
    final birdPath = Path();
    birdPath.moveTo(size.width * 0.3, size.height * 0.6);
    birdPath.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.4,
      size.width * 0.7,
      size.height * 0.6,
    );
    birdPath.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.8,
      size.width * 0.3,
      size.height * 0.6,
    );
    canvas.drawPath(birdPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WisdomPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF6B46C1)
      ..style = PaintingStyle.fill;

    // Draw a tree of wisdom
    final trunkPath = Path();
    trunkPath.addRect(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.7),
        width: size.width * 0.15,
        height: size.height * 0.4,
      ),
    );
    canvas.drawPath(trunkPath, paint);

    // Draw leaves
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.4),
      size.width * 0.25,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CompletionPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF6B46C1)
      ..style = PaintingStyle.fill;

    // Draw a trophy
    final trophyPath = Path();
    trophyPath.moveTo(size.width * 0.4, size.height * 0.8);
    trophyPath.lineTo(size.width * 0.4, size.height * 0.4);
    trophyPath.quadraticBezierTo(
      size.width * 0.4,
      size.height * 0.2,
      size.width * 0.6,
      size.height * 0.2,
    );
    trophyPath.quadraticBezierTo(
      size.width * 0.6,
      size.height * 0.4,
      size.width * 0.6,
      size.height * 0.8,
    );
    trophyPath.close();
    canvas.drawPath(trophyPath, paint);

    // Draw handles
    canvas.drawCircle(
      Offset(size.width * 0.35, size.height * 0.5),
      size.width * 0.05,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.65, size.height * 0.5),
      size.width * 0.05,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Keep the existing custom painters
class CouragePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF6B46C1)
      ..style = PaintingStyle.fill;

    // Draw a shield-like shape
    final path = Path();
    path.moveTo(size.width * 0.5, size.height * 0.2);
    path.lineTo(size.width * 0.8, size.height * 0.4);
    path.lineTo(size.width * 0.8, size.height * 0.7);
    path.lineTo(size.width * 0.5, size.height * 0.9);
    path.lineTo(size.width * 0.2, size.height * 0.7);
    path.lineTo(size.width * 0.2, size.height * 0.4);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LightPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.fill;

    // Draw a lightbulb
    final bulbPath = Path();
    bulbPath.addOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.4),
        width: size.width * 0.6,
        height: size.height * 0.6,
      ),
    );
    canvas.drawPath(bulbPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class VoicePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF6B46C1)
      ..style = PaintingStyle.fill;

    // Draw sound waves
    for (int i = 0; i < 3; i++) {
      final wavePath = Path();
      final centerX = size.width * 0.5;
      final centerY = size.height * 0.5;
      final radius = (i + 1) * size.width * 0.15;

      wavePath.addOval(
        Rect.fromCenter(
          center: Offset(centerX, centerY),
          width: radius * 2,
          height: radius * 2,
        ),
      );

      final wavePaint = Paint()
        ..color = const Color(0xFF6B46C1).withOpacity(0.3)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      canvas.drawPath(wavePath, wavePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ConnectionPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF6B46C1)
      ..style = PaintingStyle.fill;

    // Draw two connected circles
    canvas.drawCircle(
      Offset(size.width * 0.3, size.height * 0.5),
      size.width * 0.15,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.7, size.height * 0.5),
      size.width * 0.15,
      paint,
    );

    // Draw connection line
    final linePaint = Paint()
      ..color = const Color(0xFF6B46C1)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(size.width * 0.45, size.height * 0.5),
      Offset(size.width * 0.55, size.height * 0.5),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DefaultPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF6B46C1)
      ..style = PaintingStyle.fill;

    // Draw a simple circle
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.5),
      size.width * 0.3,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
