import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/theme_provider.dart';
import '../utils/mood_service.dart';
import '../models/mood_model.dart';
import '../utils/notification_service.dart';
import '../utils/premium_features_impl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MoodCheckScreen extends StatefulWidget {
  const MoodCheckScreen({super.key});

  @override
  State<MoodCheckScreen> createState() => _MoodCheckScreenState();
}

class _MoodCheckScreenState extends State<MoodCheckScreen> {
  final MoodService _moodService = MoodService();
  final NotificationService _notificationService = NotificationService();
  final PremiumFeaturesImpl _premiumFeatures = PremiumFeaturesImpl();

  int _selectedMood = 5;
  String _selectedMoodDescription = 'Neutral';
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = false;
  MoodEntry? _todayMood;

  // Voice journaling state
  bool _isRecording = false;
  String? _sessionId;
  Map<String, dynamic>? _lastJournal;
  bool _isVoiceLoading = false;

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
    _loadTodayMood();
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
          const SnackBar(content: Text('Mood saved successfully!')),
        );
        _loadTodayMood(); // Reload to get the updated entry
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving mood: $e')));
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
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final theme = themeProvider.currentTheme;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: theme.appBarTheme.backgroundColor,
            foregroundColor: theme.appBarTheme.foregroundColor,
            title: const Text('Mood Check'),
            elevation: 0,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'How are you feeling today?',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Take a moment to check in with yourself',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 32),

                // Mood Scale
                _buildMoodScale(theme),
                const SizedBox(height: 32),

                // Selected Mood Display
                _buildSelectedMoodDisplay(theme),
                const SizedBox(height: 24),

                // Notes Section
                _buildNotesSection(theme),
                const SizedBox(height: 32),

                // Voice Journaling Section (Premium)
                _buildVoiceJournalingSection(theme),
                const SizedBox(height: 32),

                // Save Button
                _buildSaveButton(theme),
                const SizedBox(height: 24),

                // Mood History
                _buildMoodHistory(theme),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMoodScale(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rate your mood (1-10)',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(10, (index) {
                  final moodLevel = index + 1;
                  final isSelected = moodLevel == _selectedMood;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedMood = moodLevel;
                        _selectedMoodDescription =
                            _moodDescriptions[moodLevel]!;
                      });
                    },
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _moodColors[moodLevel]
                            : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: isSelected
                              ? _moodColors[moodLevel]!
                              : theme.colorScheme.outline.withOpacity(0.3),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          moodLevel.toString(),
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : theme.colorScheme.onSurface,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Terrible',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  Text(
                    'Amazing',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedMoodDisplay(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _moodColors[_selectedMood]!.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _moodColors[_selectedMood]!.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: _moodColors[_selectedMood],
              borderRadius: BorderRadius.circular(30),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _moodEmojis[_selectedMood] ?? '😊',
                    style: const TextStyle(fontSize: 20),
                  ),
                  Text(
                    _selectedMood.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedMoodDescription,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'You selected a mood level of $_selectedMood',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Additional Notes (Optional)',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'How are you feeling? What\'s on your mind?',
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: theme.cardColor,
          ),
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
      ],
    );
  }

  Widget _buildSaveButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveMood,
        style: ElevatedButton.styleFrom(
          backgroundColor: _moodColors[_selectedMood],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
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
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                _todayMood != null ? 'Update Mood' : 'Save Mood',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildMoodHistory(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Mood History',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<MoodEntry>>(
          stream: _moodService.getMoodEntries(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Text(
                'Error loading mood history: ${snapshot.error}',
                style: TextStyle(color: theme.colorScheme.error),
              );
            }

            final entries = snapshot.data ?? [];
            if (entries.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: Center(
                  child: Text(
                    'No mood entries yet. Start tracking your mood!',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: entries.take(5).length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _moodColors[entry.moodLevel],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            entry.moodLevel.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.moodDescription,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (entry.notes != null && entry.notes!.isNotEmpty)
                              Text(
                                entry.notes!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.7),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      Text(
                        _formatDate(entry.timestamp),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final entryDate = DateTime(date.year, date.month, date.day);

    if (entryDate == today) {
      return 'Today';
    } else if (entryDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Widget _buildVoiceJournalingSection(ThemeData theme) {
    return FutureBuilder<bool>(
      future: _checkPremiumAccess(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final hasPremiumAccess = snapshot.data ?? false;
        if (!hasPremiumAccess) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withOpacity(0.1),
                theme.colorScheme.secondary.withOpacity(0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.mic, color: theme.colorScheme.primary, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Voice Journal',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Record your thoughts about today\'s mood',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 16),

              // Recording Button
              Center(
                child: Container(
                  width: 80,
                  height: 80,
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
                    boxShadow: [
                      BoxShadow(
                        color:
                            (_isRecording
                                    ? Colors.red
                                    : theme.colorScheme.primary)
                                .withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isVoiceLoading
                          ? null
                          : (_isRecording
                                ? _stopVoiceRecording
                                : _startVoiceRecording),
                      borderRadius: BorderRadius.circular(40),
                      child: Center(
                        child: _isVoiceLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Icon(
                                _isRecording ? Icons.stop : Icons.mic,
                                color: Colors.white,
                                size: 32,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Status Text
              Center(
                child: Text(
                  _isRecording ? 'Recording...' : 'Tap to record',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ),

              // Last Journal Entry
              if (_lastJournal != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Last Recording:',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _lastJournal!['transcription'] ?? '',
                        style: theme.textTheme.bodySmall,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<bool> _checkPremiumAccess() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return false;

      return await _premiumFeatures
          .getPremiumThemes(userId)
          .then((themes) => themes.isNotEmpty);
    } catch (e) {
      return false;
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
        _lastJournal = result;
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
