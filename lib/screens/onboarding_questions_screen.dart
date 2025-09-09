import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../utils/user_service.dart';
import '../utils/mission_service.dart';
import '../utils/mood_scheduler_service.dart';

class OnboardingQuestionsScreen extends StatefulWidget {
  const OnboardingQuestionsScreen({super.key});

  @override
  State<OnboardingQuestionsScreen> createState() =>
      _OnboardingQuestionsScreenState();
}

class _OnboardingQuestionsScreenState extends State<OnboardingQuestionsScreen> {
  final PageController _pageController = PageController();
  final UserService _userService = UserService();
  final MissionService _missionService = MissionService();
  final MoodSchedulerService _moodSchedulerService = MoodSchedulerService();

  int _currentPage = 0;
  String _selectedMood = '';
  String _selectedGoal = '';
  String _selectedMode = '';
  String _selectedSocialComfort = '';
  String _selectedTalkFrequency = '';
  String _customGoal = '';
  bool _isLoading = false;
  bool _showCustomGoalField = false;

  // Safe goal suggestions for anxiety treatment
  final List<String> _safeGoalSuggestions = [
    'Reduce social anxiety in public places',
    'Build confidence in group conversations',
    'Overcome fear of public speaking',
    'Improve communication with family',
    'Learn to handle social rejection better',
    'Develop better listening skills',
    'Practice self-compassion in social situations',
    'Build meaningful friendships',
    'Overcome phone call anxiety',
    'Improve body language and eye contact',
  ];

  final List<Map<String, dynamic>> _questions = [
    {
      'question': 'How are you feeling today?',
      'options': ['Happy', 'Calm', 'Anxious', 'Excited', 'Tired'],
      'field': 'mood',
    },
    {
      'question': 'What is your main goal?',
      'options': [
        'Make new friends',
        'Improve social skills',
        'Overcome anxiety',
        'Build confidence',
        'Other',
      ],
      'field': 'goal',
    },
    {
      'question': 'What mode do you prefer?',
      'options': ['Intense', 'Light', 'Mixed'],
      'field': 'mode',
    },
    {
      'question': 'How comfortable are you in social situations?',
      'options': [
        'Very comfortable',
        'Somewhat comfortable',
        'Neutral',
        'Somewhat uncomfortable',
        'Very uncomfortable',
      ],
      'field': 'socialComfort',
    },
    {
      'question': 'How often do you want to talk?',
      'options': ['Daily', 'Every few days', 'Weekly', 'When needed'],
      'field': 'talkFrequency',
    },
  ];

  void _selectOption(String option, String field) {
    setState(() {
      switch (field) {
        case 'mood':
          _selectedMood = option;
          break;
        case 'goal':
          _selectedGoal = option;
          _showCustomGoalField = option == 'Other';
          if (option != 'Other') {
            _customGoal = ''; // Clear custom goal if not "Other"
          }
          break;
        case 'mode':
          _selectedMode = option;
          break;
        case 'socialComfort':
          _selectedSocialComfort = option;
          break;
        case 'talkFrequency':
          _selectedTalkFrequency = option;
          break;
      }
    });
  }

  void _nextPage() {
    // Check if current question is answered
    if (!_isCurrentQuestionAnswered()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an answer before continuing'),
        ),
      );
      return;
    }

    if (_currentPage < _questions.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  bool _isCurrentQuestionAnswered() {
    final currentQuestion = _questions[_currentPage];
    final field = currentQuestion['field'];

    switch (field) {
      case 'mood':
        return _selectedMood.isNotEmpty;
      case 'goal':
        if (_selectedGoal.isEmpty) return false;
        if (_selectedGoal == 'Other') {
          return _customGoal.trim().isNotEmpty &&
              _isValidCustomGoal(_customGoal);
        }
        return true;
      case 'mode':
        return _selectedMode.isNotEmpty;
      case 'socialComfort':
        return _selectedSocialComfort.isNotEmpty;
      case 'talkFrequency':
        return _selectedTalkFrequency.isNotEmpty;
      default:
        return false;
    }
  }

  bool _canProceed() {
    if (_selectedMood.isEmpty ||
        _selectedGoal.isEmpty ||
        _selectedMode.isEmpty ||
        _selectedSocialComfort.isEmpty ||
        _selectedTalkFrequency.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please answer all questions')),
      );
      return false;
    }

    // Validate custom goal if "Other" is selected
    if (_selectedGoal == 'Other' && _customGoal.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please specify your custom goal')),
      );
      return false;
    }

    // Validate custom goal content for safety
    if (_selectedGoal == 'Other' && !_isValidCustomGoal(_customGoal)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a goal related to social anxiety or personal growth',
          ),
        ),
      );
      return false;
    }
    return true;
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _isValidCustomGoal(String goal) {
    final lowerGoal = goal.toLowerCase();

    // Check for inappropriate words
    final inappropriateWords = [
      'kill',
      'hurt',
      'harm',
      'violence',
      'abuse',
      'drugs',
      'illegal',
      'criminal',
      'hate',
      'attack',
      'fight',
      'war',
    ];

    for (final word in inappropriateWords) {
      if (lowerGoal.contains(word)) return false;
    }

    // Simple check for anxiety-related or personal growth keywords
    final positiveKeywords = [
      'anxiety',
      'social',
      'confidence',
      'communication',
      'friendship',
      'family',
      'speaking',
      'listening',
      'growth',
      'improve',
      'overcome',
      'build',
      'develop',
      'learn',
      'connect',
      'relationship',
      'comfort',
      'calm',
      'peace',
      'happiness',
      'success',
      'achieve',
      'goal',
      'better',
      'stronger',
      'braver',
      'courage',
      'strength',
      'support',
      'help',
      'heal',
      'recover',
      'progress',
      'face',
      'deal',
      'manage',
      'handle',
      'cope',
      'adapt',
      'change',
      'transform',
      'enhance',
      'boost',
      'increase',
      'raise',
      'elevate',
      'uplift',
      'inspire',
      'motivate',
      'encourage',
      'empower',
    ];

    bool hasPositiveKeyword = false;
    for (final keyword in positiveKeywords) {
      if (lowerGoal.contains(keyword)) {
        hasPositiveKeyword = true;
        break;
      }
    }

    // Also accept goals that are clearly about personal improvement
    if (!hasPositiveKeyword) {
      final improvementWords = [
        'want',
        'need',
        'hope',
        'wish',
        'desire',
        'aspire',
      ];
      for (final word in improvementWords) {
        if (lowerGoal.contains(word)) {
          hasPositiveKeyword = true;
          break;
        }
      }
    }

    return hasPositiveKeyword;
  }

  Future<void> _completeOnboarding() async {
    if (!_canProceed()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user found');
      }

      print('Creating onboarding data...');
      final onboardingData = OnboardingData(
        mood: _selectedMood,
        goal: _selectedGoal,
        mode: _selectedMode,
        socialComfort: _selectedSocialComfort,
        talkFrequency: _selectedTalkFrequency,
        customGoal: _selectedGoal == 'Other' ? _customGoal : null,
      );

      print('Updating onboarding data...');
      await _userService.updateOnboarding(user.uid, onboardingData);
      print('Onboarding data updated successfully');

      // Show loading screen for chapter generation
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/chapter-generation-loading',
          arguments: {'userId': user.uid, 'onboardingData': onboardingData},
        );
      }
    } catch (e) {
      print('Error in onboarding completion: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
            // Progress bar
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Setup Progress',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${_currentPage + 1}/${_questions.length}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_currentPage + 1) / _questions.length,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                        minHeight: 8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Question content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _questions.length,
                itemBuilder: (context, index) {
                  return _buildQuestionPage(_questions[index]);
                },
              ),
            ),
            // Navigation buttons
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.onSurface,
                          side: BorderSide(
                            color: theme.colorScheme.outline.withOpacity(0.3),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          backgroundColor: theme.cardColor,
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                  if (_currentPage > 0) const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_isLoading || !_isCurrentQuestionAnswered())
                          ? null
                          : _nextPage,
                      style: theme.elevatedButtonTheme.style?.copyWith(
                        backgroundColor: MaterialStateProperty.all(
                          (_isLoading || !_isCurrentQuestionAnswered())
                              ? theme.colorScheme.primary.withOpacity(0.5)
                              : theme.colorScheme.primary,
                        ),
                        foregroundColor: MaterialStateProperty.all(
                          theme.colorScheme.onPrimary,
                        ),
                        shape: MaterialStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        padding: MaterialStateProperty.all(
                          const EdgeInsets.symmetric(vertical: 18),
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.onPrimary,
                              ),
                            )
                          : Text(
                              _currentPage == _questions.length - 1
                                  ? 'Complete Setup'
                                  : 'Continue',
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
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

  Widget _buildQuestionPage(Map<String, dynamic> question) {
    final theme = Theme.of(context);

    String selectedValue = '';
    switch (question['field']) {
      case 'mood':
        selectedValue = _selectedMood;
        break;
      case 'goal':
        selectedValue = _selectedGoal;
        break;
      case 'mode':
        selectedValue = _selectedMode;
        break;
      case 'socialComfort':
        selectedValue = _selectedSocialComfort;
        break;
      case 'talkFrequency':
        selectedValue = _selectedTalkFrequency;
        break;
    }

    return Container(
      margin: const EdgeInsets.all(20.0),
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Step ${_currentPage + 1}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            question['question'],
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 40),
          if (question['field'] == 'goal' && _showCustomGoalField) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Suggested goals for social anxiety',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _safeGoalSuggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = _safeGoalSuggestions[index];
                        final isSelected = _customGoal == suggestion;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _customGoal = suggestion;
                            });
                          },
                          child: Container(
                            width: 200,
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.primary.withOpacity(0.1)
                                  : theme.cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outline.withOpacity(
                                        0.3,
                                      ),
                              ),
                            ),
                            child: Text(
                              suggestion,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.textTheme.bodyMedium?.color,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              onChanged: (value) {
                setState(() {
                  _customGoal = value;
                });
              },
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: 'Or write your own goal...',
                hintStyle: theme.inputDecorationTheme.hintStyle,
                helperText:
                    _customGoal.isNotEmpty && !_isValidCustomGoal(_customGoal)
                    ? 'Please write a goal related to social anxiety, confidence, or personal growth'
                    : null,
                helperStyle: TextStyle(color: theme.colorScheme.error),
                filled: true,
                fillColor: theme.inputDecorationTheme.fillColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              maxLines: 3,
            ),
          ] else ...[
            ...question['options'].map<Widget>((option) {
              final isSelected = selectedValue == option;
              return GestureDetector(
                onTap: () => _selectOption(option, question['field']),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary.withOpacity(0.1)
                        : theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline.withOpacity(0.3),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.shadowColor.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          option,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.textTheme.bodyLarge?.color,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
