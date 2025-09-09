import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/theme_provider.dart';
import '../utils/mood_service.dart';
import '../models/mood_model.dart';
import '../utils/premium_features_impl.dart';
import '../utils/premium_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MoodCheckPopup extends StatefulWidget {
  final VoidCallback? onComplete;
  final VoidCallback? onDismiss;

  const MoodCheckPopup({super.key, this.onComplete, this.onDismiss});

  @override
  State<MoodCheckPopup> createState() => _MoodCheckPopupState();
}

class _MoodCheckPopupState extends State<MoodCheckPopup>
    with TickerProviderStateMixin {
  final MoodService _moodService = MoodService();
  final PremiumFeaturesImpl _premiumFeatures = PremiumFeaturesImpl();

  int _selectedMood = 5;
  String _selectedMoodDescription = 'Neutral';
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = false;
  MoodEntry? _todayMood;

  // Voice journaling state
  bool _isRecording = false;
  String? _sessionId;
  bool _isVoiceLoading = false;
  bool _hasPremiumAccess = false;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  final Map<int, String> _moodDescriptions = {
    1: 'Terrible',
    2: 'Very Bad',
    3: 'Bad',
    4: 'Poor',
    5: 'Neutral',
    6: 'Okay',
    7: 'Good',
    8: 'Great',
    9: 'Excellent',
    10: 'Amazing',
  };

  final Map<int, Color> _moodColors = {
    1: Colors.red,
    2: Colors.redAccent,
    3: Colors.orange,
    4: Colors.orangeAccent,
    5: Colors.yellow,
    6: Colors.lightGreen,
    7: Colors.green,
    8: Colors.greenAccent,
    9: Colors.lightBlue,
    10: Colors.blue,
  };

  final Map<int, String> _moodEmojis = {
    1: '😢',
    2: '😢',
    3: '😕',
    4: '😕',
    5: '😐',
    6: '🙂',
    7: '😊',
    8: '😄',
    9: '😃',
    10: '😁',
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
    _loadTodayMood();
    _checkPremiumAccess();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadTodayMood() async {
    try {
      final todayMood = await _moodService.getTodayMoodEntry();
      if (mounted) {
        setState(() {
          _todayMood = todayMood;
          if (todayMood != null) {
            _selectedMood = todayMood.moodLevel;
            _selectedMoodDescription = todayMood.moodDescription;
            _notesController.text = todayMood.notes ?? '';
          } else {
            // Clear the notes controller when there's no existing mood entry
            _selectedMood = 5;
            _selectedMoodDescription = 'Neutral';
            _notesController.clear();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading today\'s mood: $e')),
        );
      }
    }
  }

  void _resetMood() {
    setState(() {
      _selectedMood = 5;
      _selectedMoodDescription = 'Neutral';
      _notesController.clear();
      _todayMood = null; // Treat as new entry
    });
  }

  Future<void> _saveMood() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (_todayMood != null) {
        // Update existing entry
        await _moodService.updateMoodEntry(
          entryId: _todayMood!.id,
          moodLevel: _selectedMood,
          moodDescription: _selectedMoodDescription,
          notes: _notesController.text.isNotEmpty
              ? _notesController.text
              : null,
        );
      } else {
        // Create new entry
        await _moodService.addMoodEntry(
          moodLevel: _selectedMood,
          moodDescription: _selectedMoodDescription,
          notes: _notesController.text.isNotEmpty
              ? _notesController.text
              : null,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mood saved successfully! 😊'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onComplete?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving mood: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _dismiss() {
    _animationController.reverse().then((_) {
      widget.onDismiss?.call();
      Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Material(
              color: Colors.transparent,
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.all(32),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(
                                  0.1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.psychology,
                                color: theme.colorScheme.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'How are you feeling?',
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Take a moment to check in with yourself',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.textTheme.bodySmall?.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _dismiss,
                              icon: Icon(
                                Icons.close,
                                color: theme.iconTheme.color,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Mood Slider
                        Text(
                          'Rate your mood (1-10)',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Mood Level Display
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _moodColors[_selectedMood]?.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  _moodColors[_selectedMood]?.withOpacity(
                                    0.3,
                                  ) ??
                                  Colors.grey,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _moodEmojis[_selectedMood] ?? '😊',
                                style: const TextStyle(fontSize: 24),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_selectedMood}',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: _moodColors[_selectedMood],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _selectedMoodDescription,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: _moodColors[_selectedMood],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Mood Slider
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: _moodColors[_selectedMood],
                            inactiveTrackColor: _moodColors[_selectedMood]
                                ?.withOpacity(0.3),
                            thumbColor: _moodColors[_selectedMood],
                            overlayColor: _moodColors[_selectedMood]
                                ?.withOpacity(0.2),
                            trackHeight: 6,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 12,
                            ),
                          ),
                          child: Slider(
                            value: _selectedMood.toDouble(),
                            min: 1,
                            max: 10,
                            divisions: 9,
                            onChanged: (value) {
                              setState(() {
                                _selectedMood = value.round();
                                _selectedMoodDescription =
                                    _moodDescriptions[_selectedMood] ??
                                    'Neutral';
                              });
                            },
                          ),
                        ),

                        // Mood Scale Labels
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Terrible',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'Amazing',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.blue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Notes Field
                        TextField(
                          controller: _notesController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Any notes? (optional)',
                            hintText: 'What\'s on your mind today?',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: theme.colorScheme.primary,
                                width: 2,
                              ),
                            ),
                          ),
                        ),

                        // Voice Journaling Button (Premium only)
                        if (_hasPremiumAccess) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: theme.colorScheme.primary.withOpacity(
                                  0.3,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: _isRecording
                                          ? [Colors.red, Colors.red.shade700]
                                          : [
                                              theme.colorScheme.primary,
                                              theme.colorScheme.secondary,
                                            ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _isVoiceLoading
                                          ? null
                                          : (_isRecording
                                                ? _stopVoiceRecording
                                                : _startVoiceRecording),
                                      borderRadius: BorderRadius.circular(20),
                                      child: Center(
                                        child: _isVoiceLoading
                                            ? const SizedBox(
                                                height: 16,
                                                width: 16,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(Colors.white),
                                                ),
                                              )
                                            : Icon(
                                                _isRecording
                                                    ? Icons.stop
                                                    : Icons.mic,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Voice Journal',
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      Text(
                                        _isRecording
                                            ? 'Recording... Tap to stop'
                                            : 'Tap to record your thoughts',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme
                                                  .textTheme
                                                  .bodySmall
                                                  ?.color
                                                  ?.withOpacity(0.7),
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),

                        // Reset Button (only show if there's an existing entry)
                        if (_todayMood != null) ...[
                          Center(
                            child: TextButton(
                              onPressed: _resetMood,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                              child: Text(
                                'Start Fresh',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: _dismiss,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Skip for now',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: theme.textTheme.bodySmall?.color,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _saveMood,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: theme.colorScheme.onPrimary,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : Text(
                                        _todayMood != null
                                            ? 'Update Mood'
                                            : 'Save Mood',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _checkPremiumAccess() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // Simple direct check using premium service
      final premiumService = PremiumService();
      final hasAccess = await premiumService.hasPremiumAccess(userId);

      if (mounted) {
        setState(() {
          _hasPremiumAccess = hasAccess;
        });
      }
    } catch (e) {
      print('Premium access check failed: $e');
      // Premium access check failed, keep as false
    }
  }

  Future<void> _startVoiceRecording() async {
    setState(() {
      _isVoiceLoading = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to use voice journaling'),
          ),
        );
        return;
      }

      final result = await _premiumFeatures.startVoiceJournaling(userId);

      if (result.containsKey('error')) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result['error'])));
        return;
      }

      setState(() {
        _isRecording = true;
        _sessionId = result['session_id'];
        _isVoiceLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recording started! Speak your thoughts...'),
        ),
      );
    } catch (e) {
      setState(() {
        _isVoiceLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error starting recording: $e')));
    }
  }

  Future<void> _stopVoiceRecording() async {
    setState(() {
      _isVoiceLoading = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null || _sessionId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: No active session')),
        );
        return;
      }

      final result = await _premiumFeatures.stopVoiceJournaling(
        userId,
        _sessionId!,
      );

      if (result.containsKey('error')) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result['error'])));
        return;
      }

      setState(() {
        _isRecording = false;
        _sessionId = null;
        _isVoiceLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Voice journal processed!')));
    } catch (e) {
      setState(() {
        _isVoiceLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing voice journal: $e')),
      );
    }
  }
}
