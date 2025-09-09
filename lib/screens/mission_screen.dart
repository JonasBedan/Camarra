import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/mission_model.dart';
import '../models/user_model.dart';
import '../utils/mission_service.dart';
import '../utils/user_service.dart';

class MissionScreen extends StatefulWidget {
  const MissionScreen({super.key});

  @override
  State<MissionScreen> createState() => _MissionScreenState();
}

class _MissionScreenState extends State<MissionScreen> {
  final MissionService _missionService = MissionService();
  final UserService _userService = UserService();
  bool _isLoading = false;

  Future<void> _createTestMission() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _missionService.createTestDailyMission(
        FirebaseAuth.instance.currentUser?.uid ?? '',
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Test mission created! 🎯')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create test mission: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _generateNewMission() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _missionService.forceGenerateNewDailyMission();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New AI mission generated! 🚀')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate new mission: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Daily Mission', style: theme.textTheme.titleLarge),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: theme.iconTheme,
        actions: [
          // Development button to create test mission
          IconButton(
            onPressed: _createTestMission,
            icon: Icon(Icons.add, color: theme.iconTheme.color),
            tooltip: 'Create Test Mission',
          ),
          // Button to generate new AI mission
          IconButton(
            onPressed: _generateNewMission,
            icon: Icon(Icons.refresh, color: theme.iconTheme.color),
            tooltip: 'Generate New AI Mission',
          ),
        ],
      ),
      body: StreamBuilder<DailyMissionModel?>(
        stream: _missionService.streamDailyMission(
          FirebaseAuth.instance.currentUser?.uid ?? '',
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: theme.textTheme.bodyMedium,
              ),
            );
          }

          final mission = snapshot.data;
          if (mission == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.assignment_outlined,
                      size: 64,
                      color: theme.colorScheme.primary.withOpacity(0.6),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Mission Available',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Check back later for your daily mission, or try refreshing the page.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(
                          0.7,
                        ),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        // Force refresh the mission
                        setState(() {});
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('Refresh Mission'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              mission.isCompleted
                                  ? Icons.check_circle
                                  : Icons.assignment,
                              color: mission.isCompleted
                                  ? Colors.green
                                  : theme.colorScheme.primary,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              mission.isCompleted
                                  ? 'Mission Completed!'
                                  : 'Today\'s Mission',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: mission.isCompleted
                                    ? Colors.green
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Daily Mission',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          mission.content,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontSize: 16,
                            height: 1.5,
                            color: mission.isCompleted
                                ? theme.textTheme.bodyLarge?.color?.withOpacity(
                                    0.7,
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getDifficultyColor(mission.difficulty),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                mission.difficulty.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${mission.xpReward} XP',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Created: ${_formatDate(mission.createdAt)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                StreamBuilder(
                  stream: _userService.streamUser(
                    FirebaseAuth.instance.currentUser?.uid ?? '',
                  ),
                  builder: (context, userSnapshot) {
                    if (userSnapshot.hasData && userSnapshot.data != null) {
                      final user = userSnapshot.data!;
                      return Column(
                        children: [
                          if (!mission.isCompleted)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _completeMission,
                                style: theme.elevatedButtonTheme.style
                                    ?.copyWith(
                                      backgroundColor:
                                          MaterialStateProperty.all(
                                            theme.colorScheme.primary,
                                          ),
                                      foregroundColor:
                                          MaterialStateProperty.all(
                                            theme.colorScheme.onPrimary,
                                          ),
                                      padding: MaterialStateProperty.all(
                                        const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                      ),
                                      shape: MaterialStateProperty.all(
                                        RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                    ),
                                child: _isLoading
                                    ? CircularProgressIndicator(
                                        color: theme.colorScheme.onPrimary,
                                      )
                                    : Text(
                                        'Mark as Completed',
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(fontSize: 16),
                                      ),
                              ),
                            )
                          else
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.green),
                              ),
                              child: const Center(
                                child: Text(
                                  '✅ Mission Completed!',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _completeMission() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get the current mission
      final mission = await _missionService.getDailyMission(user.uid);
      if (mission == null) throw Exception('No mission available');

      // Complete the mission using the new service
      await _missionService.completeDailyMission(user.uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mission completed! +${mission.xpReward} XP'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
