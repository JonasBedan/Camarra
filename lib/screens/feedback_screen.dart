import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/feedback_model.dart';
import '../utils/feedback_service.dart';
import '../widgets/profile_picture.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen>
    with TickerProviderStateMixin {
  final FeedbackService _feedbackService = FeedbackService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late TabController _tabController;
  String _selectedCategory = 'All';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF1A1A1A)
          : const Color(0xFFF1ECFB),
      appBar: AppBar(
        title: const Text('Feedback & Suggestions'),
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: isDark ? Colors.white : const Color(0xFF6B46C1),
          unselectedLabelColor: isDark ? Colors.white70 : Colors.grey,
          indicatorColor: isDark ? Colors.white : const Color(0xFF6B46C1),
          tabs: const [
            Tab(text: 'All Feedback'),
            Tab(text: 'My Feedback'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Category filter
          Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCategoryChip('All', isDark),
                  const SizedBox(width: 8),
                  ..._feedbackService.getFeedbackCategories().map(
                    (category) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildCategoryChip(category, isDark),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Feedback list
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFeedbackList(isDark, false),
                _buildFeedbackList(isDark, true),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateFeedbackDialog(context),
        backgroundColor: isDark ? Colors.white : const Color(0xFF6B46C1),
        foregroundColor: isDark ? Colors.black : Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCategoryChip(String category, bool isDark) {
    final isSelected = _selectedCategory == category;
    return FilterChip(
      label: Text(category),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedCategory = category;
        });
      },
      backgroundColor: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
      selectedColor: isDark
          ? Colors.white.withOpacity(0.2)
          : const Color(0xFF6B46C1).withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected
            ? (isDark ? Colors.white : const Color(0xFF6B46C1))
            : (isDark ? Colors.white70 : Colors.black87),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected
            ? (isDark ? Colors.white : const Color(0xFF6B46C1))
            : (isDark
                  ? Colors.white.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.3)),
      ),
    );
  }

  Widget _buildFeedbackList(bool isDark, bool isUserFeedback) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Center(child: Text('Please log in to view feedback'));
    }

    return StreamBuilder<List<FeedbackModel>>(
      stream: isUserFeedback
          ? _feedbackService.getUserFeedback(currentUser.uid)
          : _selectedCategory == 'All'
          ? _feedbackService.getFeedbackStream()
          : _feedbackService.getFeedbackByCategory(_selectedCategory),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final feedbackList = snapshot.data!;

        if (feedbackList.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.feedback_outlined,
                  size: 64,
                  color: isDark ? Colors.white70 : Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  isUserFeedback
                      ? 'No feedback yet'
                      : 'No feedback in this category',
                  style: TextStyle(
                    fontSize: 18,
                    color: isDark ? Colors.white70 : Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isUserFeedback
                      ? 'Share your ideas to help improve the app!'
                      : 'Be the first to share feedback in this category',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white54 : Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: feedbackList.length,
          itemBuilder: (context, index) {
            final feedback = feedbackList[index];
            return _buildFeedbackCard(feedback, isDark);
          },
        );
      },
    );
  }

  Widget _buildFeedbackCard(FeedbackModel feedback, bool isDark) {
    final currentUser = _auth.currentUser;
    final userVote = currentUser != null
        ? feedback.getUserVote(currentUser.uid)
        : 'none';
    final statusBadges = _feedbackService.getStatusBadges();
    final statusBadge = statusBadges[feedback.status];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with user info and status
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage: feedback.userProfilePicture.isNotEmpty
                      ? NetworkImage(feedback.userProfilePicture)
                      : null,
                  backgroundColor: isDark
                      ? Colors.white.withOpacity(0.2)
                      : Colors.grey.withOpacity(0.2),
                  child: feedback.userProfilePicture.isEmpty
                      ? Text(
                          feedback.userDisplayName.isNotEmpty
                              ? feedback.userDisplayName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feedback.userDisplayName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        _formatDate(feedback.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (statusBadge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusBadge['color'].withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: statusBadge['color'].withOpacity(0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          statusBadge['icon'],
                          size: 12,
                          color: statusBadge['color'],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          statusBadge['label'],
                          style: TextStyle(
                            fontSize: 10,
                            color: statusBadge['color'],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Category chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : const Color(0xFF6B46C1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                feedback.category,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : const Color(0xFF6B46C1),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              feedback.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),

            // Description
            Text(
              feedback.description,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            // Voting section
            Row(
              children: [
                // Upvote button
                GestureDetector(
                  onTap: () => _handleVote(feedback.id, 'upvote'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: userVote == 'upvote'
                          ? (isDark
                                ? Colors.white.withOpacity(0.2)
                                : const Color(0xFF6B46C1).withOpacity(0.2))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: userVote == 'upvote'
                            ? (isDark ? Colors.white : const Color(0xFF6B46C1))
                            : (isDark
                                  ? Colors.white.withOpacity(0.3)
                                  : Colors.grey.withOpacity(0.3)),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.keyboard_arrow_up,
                          size: 20,
                          color: userVote == 'upvote'
                              ? (isDark
                                    ? Colors.white
                                    : const Color(0xFF6B46C1))
                              : (isDark ? Colors.white70 : Colors.grey),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          feedback.upvotes.toString(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: userVote == 'upvote'
                                ? (isDark
                                      ? Colors.white
                                      : const Color(0xFF6B46C1))
                                : (isDark ? Colors.white70 : Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Downvote button
                GestureDetector(
                  onTap: () => _handleVote(feedback.id, 'downvote'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: userVote == 'downvote'
                          ? (isDark
                                ? Colors.white.withOpacity(0.2)
                                : const Color(0xFF6B46C1).withOpacity(0.2))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: userVote == 'downvote'
                            ? (isDark ? Colors.white : const Color(0xFF6B46C1))
                            : (isDark
                                  ? Colors.white.withOpacity(0.3)
                                  : Colors.grey.withOpacity(0.3)),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.keyboard_arrow_down,
                          size: 20,
                          color: userVote == 'downvote'
                              ? (isDark
                                    ? Colors.white
                                    : const Color(0xFF6B46C1))
                              : (isDark ? Colors.white70 : Colors.grey),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          feedback.downvotes.toString(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: userVote == 'downvote'
                                ? (isDark
                                      ? Colors.white
                                      : const Color(0xFF6B46C1))
                                : (isDark ? Colors.white70 : Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Score
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Score: ${feedback.score}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.grey,
                    ),
                  ),
                ),

                // Delete button (only for user's own feedback)
                if (currentUser != null && feedback.userId == currentUser.uid)
                  GestureDetector(
                    onTap: () => _showDeleteConfirmation(feedback.id),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: isDark
                            ? Colors.red.withOpacity(0.7)
                            : Colors.red,
                      ),
                    ),
                  ),
              ],
            ),

            // Admin response (if any)
            if (feedback.adminResponse != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.blue.withOpacity(0.1)
                      : Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? Colors.blue.withOpacity(0.3)
                        : Colors.blue.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.admin_panel_settings,
                          size: 16,
                          color: isDark ? Colors.blue : Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Admin Response',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.blue : Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      feedback.adminResponse!,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleVote(String feedbackId, String voteType) async {
    try {
      if (voteType == 'upvote') {
        await _feedbackService.upvoteFeedback(feedbackId);
      } else {
        await _feedbackService.downvoteFeedback(feedbackId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  Future<void> _showDeleteConfirmation(String feedbackId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Feedback'),
        content: const Text(
          'Are you sure you want to delete this feedback? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _feedbackService.deleteFeedback(feedbackId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Feedback deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
        }
      }
    }
  }

  void _showCreateFeedbackDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreateFeedbackSheet(),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

class CreateFeedbackSheet extends StatefulWidget {
  const CreateFeedbackSheet({super.key});

  @override
  State<CreateFeedbackSheet> createState() => _CreateFeedbackSheetState();
}

class _CreateFeedbackSheetState extends State<CreateFeedbackSheet> {
  final FeedbackService _feedbackService = FeedbackService();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedCategory = 'Feature Request';
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  'Share Your Feedback',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),

          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category selection
                  Text(
                    'Category',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: _feedbackService.getFeedbackCategories().map((
                      category,
                    ) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Text(
                    'Title',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: 'Brief title for your feedback',
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Description
                  Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Describe your feedback in detail...',
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Submit button
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitFeedback,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? Colors.white
                      : const Color(0xFF6B46C1),
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Submit Feedback',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitFeedback() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a title')));
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a description')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _feedbackService.createFeedback(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feedback submitted successfully!')),
        );
      }
    } catch (e) {
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
}
