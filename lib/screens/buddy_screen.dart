import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/buddy_request_model.dart';
import '../models/ai_chat_model.dart';

import '../utils/buddy_service.dart';
import '../utils/user_service.dart';
import '../utils/chat_service.dart';
import '../utils/ai_chat_service.dart';
import '../utils/ai_router.dart';
import '../widgets/profile_picture.dart';
import 'dart:async'; // Added for Timer

class BuddyScreen extends StatefulWidget {
  const BuddyScreen({super.key});

  @override
  State<BuddyScreen> createState() => _BuddyScreenState();
}

class _BuddyScreenState extends State<BuddyScreen> {
  final UserService _userService = UserService();
  final BuddyService _buddyService = BuddyService();
  final ChatService _chatService = ChatService();
  final AIChatService _aiChatService = AIChatService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _addBuddySearchController =
      TextEditingController();
  final TextEditingController _aiMessageController = TextEditingController();

  List<UserModel> _searchResults = [];
  List<UserModel> _searchCache = [];
  List<BuddyRequestModel> _buddyRequests = [];
  UserModel? _currentUser;
  UserModel? _buddy;
  bool _isLoading = false;
  bool _isSearching = false;
  bool _isAISending = false;
  Timer? _searchDebounceTimer;
  Set<String> _pendingRequests = {}; // Track pending requests
  int _currentTabIndex = 0; // 0 for buddy, 1 for AI chat

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadBuddyRequests();
    _loadPendingRequests();
    _warmSearchCache();

    // Check if we should start with AI chat tab
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args['initialTab'] == 1) {
        setState(() {
          _currentTabIndex = 1;
        });
      }
    });
  }

  Future<void> _warmSearchCache() async {
    // Preload first 200 users alphabetically for instant filter UX
    final cached = await _userService.getUsersAlphabetical(limit: 200);
    setState(() {
      _searchCache = cached;
    });
  }

  Future<void> _loadCurrentUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final user = await _userService.getUser(currentUser.uid);
      setState(() {
        _currentUser = user;
      });

      if (user?.buddyId != null) {
        _loadBuddy(user!.buddyId!);
      }
    }
  }

  Future<void> _loadPendingRequests() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        final sentRequests = await _buddyService
            .getSentRequests(currentUser.uid)
            .first;
        final pendingUserIds = sentRequests
            .where((request) => request.status == BuddyRequestStatus.pending)
            .map((request) => request.toUserId)
            .toSet();

        setState(() {
          _pendingRequests = pendingUserIds;
        });
      } catch (e) {
        print('Error loading pending requests: $e');
      }
    }
  }

  Future<void> _loadBuddy(String buddyId) async {
    try {
      final buddy = await _userService.getUser(buddyId);
      setState(() {
        _buddy = buddy;
      });
    } catch (e) {
      print('Error loading buddy: $e');
    }
  }

  void _loadBuddyRequests() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Simple buddy loading without complex syncing
    // The buddy relationship will be handled directly through buddy requests

    // Listen to pending requests (incoming)
    _buddyService.getPendingRequests(currentUser.uid).listen((requests) {
      setState(() {
        _buddyRequests = requests;
      });
    });
  }

  void _onSearchChanged() {
    if (_searchController.text.length >= 3) {
      _searchUsers();
    } else {
      setState(() {
        _searchResults = [];
      });
    }
  }

  void _showAddBuddyDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAddBuddySheet(),
    );
  }

  void _showFaithModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildFaithModal(),
    );
  }

  void _showVibeCastModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildVibeCastModal(),
    );
  }

  void _selectVibeRecipients(String vibeType, String vibeTitle, String emoji) {
    Navigator.pop(context); // Close the vibe selection modal
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _buildRecipientSelectionModal(vibeType, vibeTitle, emoji),
    );
  }

  void _showIceBreakModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildIceBreakModal(),
    );
  }

  Widget _buildAddBuddySheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        final theme = Theme.of(context);
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
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
                  color: theme.colorScheme.onSurface.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      'Add Buddy',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.headlineSmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Search bar for new buddies
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.inputDecorationTheme.fillColor,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: TextField(
                    controller: _addBuddySearchController,
                    onChanged: (value) {
                      // Cancel previous timer
                      _searchDebounceTimer?.cancel();

                      if (value.length >= 2) {
                        // Debounce the search to avoid too many requests
                        _searchDebounceTimer = Timer(
                          const Duration(milliseconds: 60),
                          () {
                            // Instant local filter if we have cache
                            if (_searchCache.isNotEmpty) {
                              final q = value.toLowerCase();
                              final local = _searchCache
                                  .where((u) => u.username.contains(q))
                                  .take(15)
                                  .toList();
                              setState(() {
                                _searchResults = local;
                                _isSearching =
                                    local.isEmpty; // keep spinner if none
                              });
                            }
                            _searchUsersForAdd(value);
                          },
                        );
                      } else {
                        setState(() {
                          _searchResults = [];
                          _isSearching = false;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Search by username...',
                      prefixIcon: Icon(
                        Icons.search,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Content
              Expanded(
                child: _isSearching
                    ? const Center(child: CircularProgressIndicator())
                    : _searchResults.isNotEmpty
                    ? _buildSearchResultsForAdd()
                    : _buildRecommendations(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchResultsForAdd() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        final theme = Theme.of(context);
        final isPending = _pendingRequests.contains(user.uid);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: theme.cardColor,
          child: ListTile(
            leading: ProfilePicture(
              user: user,
              size: 40,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
              textColor: theme.colorScheme.primary,
            ),
            title: Text(
              user.username,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Level ${user.level} • ${user.premium ? 'Premium' : 'Free'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                if (isPending)
                  Text(
                    'Request sent',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.secondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
            trailing: ElevatedButton(
              onPressed: _isLoading ? null : () => _sendBuddyRequest(user.uid),
              style: ElevatedButton.styleFrom(
                backgroundColor: isPending
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                isPending ? 'Pending' : 'Add',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecommendations() {
    final theme = Theme.of(context);
    final hasSearchQuery = _addBuddySearchController.text.isNotEmpty;
    final searchLength = _addBuddySearchController.text.length;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        Text(
          hasSearchQuery ? 'No users found' : 'Find Buddies',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: theme.textTheme.titleLarge?.color,
          ),
        ),
        const SizedBox(height: 16),
        // Placeholder for recommendations
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                hasSearchQuery ? Icons.search_off : Icons.people,
                size: 48,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              const SizedBox(height: 12),
              Text(
                hasSearchQuery
                    ? searchLength < 2
                          ? 'Type at least 2 characters to search'
                          : 'No users match your search'
                    : 'Search for users by username',
                style: TextStyle(
                  fontSize: 16,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hasSearchQuery
                    ? searchLength < 2
                          ? 'Start typing to find buddies'
                          : 'Try searching with a different username'
                    : 'Enter a username to find and add buddies',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
              if (!hasSearchQuery) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tip: Search by exact username for best results',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _searchUsersForAdd(String query) async {
    if (query.length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    // Optimistic: clear old results immediately and show spinner
    setState(() {
      _isSearching = true;
      _searchResults = [];
    });

    try {
      final results = await _userService.getUserByUsername(query);
      final currentUser = FirebaseAuth.instance.currentUser;

      // Simple filter: exclude current user and users who already have buddies
      final filteredResults = results.where((user) {
        return user.uid != currentUser?.uid && user.buddyId == null;
      }).toList();

      if (!mounted) return;

      // If nothing found yet but query is long, keep spinner briefly
      if (filteredResults.isEmpty && query.length >= 3) {
        setState(() {
          _isSearching = true;
        });
      } else {
        setState(() {
          _searchResults = filteredResults;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching users: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Widget _buildRecipientSelectionModal(
    String vibeType,
    String vibeTitle,
    String emoji,
  ) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        final theme = Theme.of(context);
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
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
                  color: theme.colorScheme.onSurface.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Header with vibe info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Center(
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vibeTitle,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: theme.textTheme.titleLarge?.color,
                            ),
                          ),
                          Text(
                            'Select who to send your vibe to',
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
              ),
              const SizedBox(height: 20),

              // Recipients list
              Expanded(
                child: StreamBuilder<UserModel?>(
                  stream: _userService.streamUser(
                    FirebaseAuth.instance.currentUser!.uid,
                  ),
                  builder: (context, userSnapshot) {
                    if (userSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final user = userSnapshot.data;
                    if (user == null || user.buddyId == null) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_add,
                              size: 64,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No buddies to cast to',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.titleLarge?.color,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add a buddy first to cast your vibe!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return FutureBuilder<UserModel?>(
                      future: _userService.getUser(user.buddyId!),
                      builder: (context, buddySnapshot) {
                        if (buddySnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final buddy = buddySnapshot.data;
                        if (buddy == null) {
                          return const Center(child: Text('Buddy not found'));
                        }

                        return ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          children: [
                            Card(
                              color: theme.cardColor,
                              child: ListTile(
                                leading: ProfilePicture(
                                  user: buddy,
                                  size: 40,
                                  backgroundColor: theme.colorScheme.primary
                                      .withOpacity(0.1),
                                  textColor: theme.colorScheme.primary,
                                ),
                                title: Text(
                                  buddy.username,
                                  style: theme.textTheme.titleMedium,
                                ),
                                subtitle: Text(
                                  'Level ${buddy.level}',
                                  style: theme.textTheme.bodySmall,
                                ),
                                trailing: ElevatedButton(
                                  onPressed: () => _sendVibeCastToRecipient(
                                    vibeType,
                                    buddy.uid,
                                    buddy.email,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor:
                                        theme.colorScheme.onPrimary,
                                  ),
                                  child: const Text('Send'),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIceBreakModal() {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        final theme = Theme.of(context);
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
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
                  color: theme.colorScheme.onSurface.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      '🧊 Break the Ice',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.headlineSmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Ice breaker options
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildIceBreakOption(
                      'AI Generated',
                      '🤖',
                      'Get a personalized ice breaker based on your buddy\'s interests',
                      'ai',
                    ),
                    _buildIceBreakOption(
                      'Random Fun',
                      '🎲',
                      'Get a random fun question to spark conversation',
                      'random',
                    ),
                    _buildIceBreakOption(
                      'Deep & Meaningful',
                      '💭',
                      'Ask something that will lead to deeper conversation',
                      'deep',
                    ),
                    _buildIceBreakOption(
                      'Creative & Artsy',
                      '🎨',
                      'Explore creativity and artistic interests',
                      'creative',
                    ),
                    _buildIceBreakOption(
                      'Adventure & Travel',
                      '✈️',
                      'Talk about adventures, travel, and experiences',
                      'adventure',
                    ),
                    _buildIceBreakOption(
                      'Goals & Dreams',
                      '⭐',
                      'Discuss aspirations, goals, and future plans',
                      'goals',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIceBreakOption(
    String title,
    String emoji,
    String description,
    String type,
  ) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: theme.cardColor,
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 24)),
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.textTheme.titleMedium?.color,
          ),
        ),
        subtitle: Text(
          description,
          style: TextStyle(color: theme.textTheme.bodyMedium?.color),
        ),
        trailing: ElevatedButton(
          onPressed: () => _generateIceBreaker(type),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: const Text('Generate'),
        ),
      ),
    );
  }

  Widget _buildFaithModal() {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        final theme = Theme.of(context);
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
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
                  color: theme.colorScheme.onSurface.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      'Send Faith',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.headlineSmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Faith types
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildFaithOption(
                      'Daily Faith',
                      '🌅',
                      'Send your daily faith to keep the streak alive!',
                      1,
                    ),
                    _buildFaithOption(
                      'Encouragement Faith',
                      '💪',
                      'Boost your buddy\'s confidence!',
                      2,
                    ),
                    _buildFaithOption(
                      'Gratitude Faith',
                      '🙏',
                      'Express your gratitude and appreciation!',
                      3,
                    ),
                    _buildFaithOption(
                      'Motivation Faith',
                      '🚀',
                      'Inspire your buddy to reach their goals!',
                      4,
                    ),
                    _buildFaithOption(
                      'Support Faith',
                      '🤝',
                      'Show your unwavering support!',
                      5,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFaithOption(
    String title,
    String emoji,
    String description,
    int faithType,
  ) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: theme.cardColor,
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 24)),
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.textTheme.titleMedium?.color,
          ),
        ),
        subtitle: Text(
          description,
          style: TextStyle(color: theme.textTheme.bodyMedium?.color),
        ),
        trailing: ElevatedButton(
          onPressed: () => _sendFaithToBuddy(faithType),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: const Text('Send'),
        ),
      ),
    );
  }

  Widget _buildVibeCastModal() {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        final theme = Theme.of(context);
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
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
                  color: theme.colorScheme.onSurface.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      'Cast Your Vibe',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.headlineSmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildVibeOption(
                      'Happy',
                      '😊',
                      'Share your joy and happiness!',
                      'happy',
                    ),
                    _buildVibeOption(
                      'Motivated',
                      '💪',
                      'Show your determination and drive!',
                      'motivated',
                    ),
                    _buildVibeOption(
                      'Relaxed',
                      '😌',
                      'Express your calm and peaceful state!',
                      'relaxed',
                    ),
                    _buildVibeOption(
                      'Excited',
                      '🎉',
                      'Share your excitement and enthusiasm!',
                      'excited',
                    ),
                    _buildVibeOption(
                      'Focused',
                      '🎯',
                      'Show your concentration and focus!',
                      'focused',
                    ),
                    _buildVibeOption(
                      'Grateful',
                      '🙏',
                      'Express your gratitude and appreciation!',
                      'grateful',
                    ),
                    _buildVibeOption(
                      'Creative',
                      '🎨',
                      'Share your creative energy!',
                      'creative',
                    ),
                    _buildVibeOption(
                      'Adventurous',
                      '🏔️',
                      'Show your adventurous spirit!',
                      'adventurous',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVibeOption(
    String title,
    String emoji,
    String description,
    String vibeType,
  ) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: theme.cardColor,
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 24)),
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.textTheme.titleMedium?.color,
          ),
        ),
        subtitle: Text(
          description,
          style: TextStyle(color: theme.textTheme.bodyMedium?.color),
        ),
        trailing: ElevatedButton(
          onPressed: () => _selectVibeRecipients(vibeType, title, emoji),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: const Text('Cast'),
        ),
      ),
    );
  }

  Future<void> _searchUsers() async {
    if (_searchController.text.isEmpty) return;

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await _userService.getUserByEmail(_searchController.text);
      final currentUser = FirebaseAuth.instance.currentUser;

      // Filter out current user and users who already have buddies
      final filteredResults = results
          .where((user) => user.uid != currentUser?.uid && user.buddyId == null)
          .toList();

      setState(() {
        _searchResults = filteredResults;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Search error: $e')));
    }
  }

  Future<void> _sendBuddyRequest(String toUserId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Immediately reflect pending state in UI and collapse keyboard
    FocusScope.of(context).unfocus();
    setState(() {
      _pendingRequests.add(toUserId);
    });

    try {
      await _buddyService.sendBuddyRequest(currentUser.uid, toUserId);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Buddy request sent!')));
    } catch (e) {
      setState(() {
        _pendingRequests.remove(toUserId); // Remove from pending if failed
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send request: $e')));
    }
  }

  Future<void> _acceptBuddyRequest(BuddyRequestModel request) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      await _buddyService.acceptBuddyRequest(request.requestId);

      // Remove from UI after success
      if (!mounted) return;
      setState(() {
        _buddyRequests.removeWhere((r) => r.requestId == request.requestId);
      });

      // Show success message with option to start chatting
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Buddy request accepted! 🎉 You can now chat!'),
          action: SnackBarAction(
            label: 'Chat Now',
            onPressed: () {
              // Navigate to chat with the new buddy
              Navigator.pushNamed(
                context,
                '/chat',
                arguments: {'buddyId': request.fromUserId},
              );
            },
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      // If it fails, add the request back to the UI
      if (mounted) {
        setState(() {
          _buddyRequests.add(request);
        });
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to accept request: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _declineBuddyRequest(BuddyRequestModel request) async {
    setState(() {
      _isLoading = true;
      // Immediately remove the request from the UI
      _buddyRequests.removeWhere((r) => r.requestId == request.requestId);
    });

    try {
      await _buddyService.declineBuddyRequest(request.requestId);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Buddy request declined')));
    } catch (e) {
      // If it fails, add the request back to the UI
      setState(() {
        _buddyRequests.add(request);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to decline request: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _generateIcebreakers() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _userService.getUser(currentUser.uid);
      if (user?.buddyId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You need a buddy first!')),
        );
        return;
      }

      await _chatService.generateIcebreakers(user!.buddyId!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ice breakers generated! 🧊')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate ice breakers: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _generateIceBreaker(String type) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _userService.getUser(currentUser.uid);
      if (user?.buddyId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You need a buddy first!')),
        );
        return;
      }

      final buddy = await _userService.getUser(user!.buddyId!);
      if (buddy == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Buddy not found!')));
        return;
      }

      String iceBreakerQuestion = '';

      if (type == 'ai') {
        // Generate AI-powered personalized ice breaker
        iceBreakerQuestion = await _generateAIIceBreaker(buddy);
      } else {
        // Generate category-based ice breaker
        iceBreakerQuestion = _generateCategoryIceBreaker(type);
      }

      // Show the ice breaker with reroll option
      _showIceBreakerResult(iceBreakerQuestion, type, buddy);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate ice breaker: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String> _generateAIIceBreaker(UserModel buddy) async {
    // Create a personalized prompt based on buddy's level and interests
    final prompt =
        '''
Generate a fun, engaging ice breaker question for a conversation with someone who is at level ${buddy.level}.
The question should be:
- Personalized and thoughtful
- Easy to answer but interesting
- Something that could lead to deeper conversation
- Appropriate for their experience level

Make it feel natural and conversational, not like a formal interview question.
Return only the question without any quotation marks or extra formatting.
''';

    try {
      // Use AI router to generate the question
      final response = await AiRouter.generate(
        task: AiTaskType.feedbackCoach,
        prompt: prompt,
      );

      // Clean up the response by removing any quotes
      final cleanedResponse = response
          ?.replaceAll('"', '')
          .replaceAll("'", '')
          .trim();

      return cleanedResponse ?? _getFallbackIceBreaker();
    } catch (e) {
      return _getFallbackIceBreaker();
    }
  }

  String _generateCategoryIceBreaker(String type) {
    final iceBreakers = {
      'random': [
        "What's the most interesting thing that happened to you today?",
        "If you could have any superpower, what would it be and why?",
        "What's your favorite way to spend a weekend?",
        "What's the best piece of advice you've ever received?",
        "If you could travel anywhere in the world, where would you go?",
        "What's something you're looking forward to this week?",
        "What's your favorite book or movie and why?",
        "What's a skill you'd love to learn?",
        "What's your favorite season and why?",
        "What's something that always makes you smile?",
      ],
      'deep': [
        "What's a challenge you've overcome that made you stronger?",
        "What's something you believe that most people disagree with?",
        "What's a lesson you learned the hard way?",
        "What's something you're passionate about that others might not understand?",
        "What's a dream you have that you haven't told many people about?",
        "What's something you're grateful for today?",
        "What's a quality you admire in others?",
        "What's something you're working on improving about yourself?",
        "What's a moment that changed your perspective on life?",
        "What's something you're curious about lately?",
      ],
      'creative': [
        "If you could create any piece of art, what would it be?",
        "What's the most creative thing you've ever done?",
        "If you could learn any artistic skill instantly, what would you choose?",
        "What's a creative project you've always wanted to start?",
        "What's your favorite form of creative expression?",
        "If you could collaborate with any artist, who would it be?",
        "What's something beautiful you've noticed recently?",
        "What's a creative solution you came up with for a problem?",
        "If you could design anything, what would it be?",
        "What's a creative hobby you'd love to try?",
      ],
      'adventure': [
        "What's the most adventurous thing you've ever done?",
        "If you could go on any adventure tomorrow, what would it be?",
        "What's a place you've always wanted to explore?",
        "What's the most exciting trip you've ever taken?",
        "If you could travel back in time, what era would you visit?",
        "What's an adventure you'd love to have with a friend?",
        "What's the most beautiful place you've ever seen?",
        "If you could live anywhere in the world, where would you choose?",
        "What's an outdoor activity you'd love to try?",
        "What's a travel destination that's on your bucket list?",
      ],
      'goals': [
        "What's a goal you're working towards right now?",
        "What's something you want to achieve this year?",
        "What's a dream you have for your future?",
        "What's a skill you're trying to develop?",
        "What's something you want to improve about yourself?",
        "What's a goal you've achieved that you're proud of?",
        "What's something you want to learn more about?",
        "What's a challenge you want to overcome?",
        "What's a habit you're trying to build?",
        "What's something you want to accomplish in the next 5 years?",
      ],
    };

    final questions = iceBreakers[type] ?? iceBreakers['random']!;
    questions.shuffle();
    return questions.first;
  }

  String _getFallbackIceBreaker() {
    return "What's the most interesting thing that happened to you today?";
  }

  void _showIceBreakerResult(String question, String type, UserModel buddy) {
    Navigator.pop(context); // Close the ice breaker selection modal
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        title: Row(
          children: [
            Text('🧊 Ice Breaker', style: theme.textTheme.titleLarge),
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close, color: theme.iconTheme.color),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'For ${buddy.username}:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                ),
              ),
              child: Text(
                question,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => _rerollIceBreaker(type, buddy),
            child: Text(
              '🔄 Reroll',
              style: TextStyle(color: theme.colorScheme.primary),
            ),
          ),
          ElevatedButton(
            onPressed: () => _sendIceBreaker(question, buddy),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            child: const Text('Send to Buddy'),
          ),
        ],
      ),
    );
  }

  Future<void> _rerollIceBreaker(String type, UserModel buddy) async {
    Navigator.pop(context); // Close the current dialog

    String newQuestion = '';
    if (type == 'ai') {
      newQuestion = await _generateAIIceBreaker(buddy);
    } else {
      newQuestion = _generateCategoryIceBreaker(type);
    }

    _showIceBreakerResult(newQuestion, type, buddy);
  }

  Future<void> _sendIceBreaker(String question, UserModel buddy) async {
    Navigator.pop(context); // Close the dialog

    setState(() {
      _isLoading = true;
    });

    try {
      // Get chat ID and send the ice breaker as a message
      final chatId = _chatService.getChatId(
        FirebaseAuth.instance.currentUser!.uid,
        buddy.uid,
      );

      await _chatService.sendMessage(
        chatId: chatId,
        message: question,
        buddyId: buddy.uid,
        buddyName: buddy.username,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ice breaker sent to ${buddy.username}! 🧊')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send ice breaker: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendFaith() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _userService.getUser(currentUser.uid);
      if (user?.buddyId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You need a buddy first!')),
        );
        return;
      }

      final buddy = await _userService.getUser(user!.buddyId!);
      if (buddy == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Buddy not found!')));
        return;
      }

      final success = await _chatService.sendFaith(
        currentUser.uid,
        buddy.uid,
        'You\'re doing amazing! Keep pushing forward! ✨',
      );

      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Faith sent! ✨')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Daily faith limit reached (3/3). Upgrade to premium for unlimited faith! 💎',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send faith: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendVibeCast() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _userService.getUser(currentUser.uid);
      if (user?.buddyId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You need a buddy first!')),
        );
        return;
      }

      await _chatService.sendVibeCast(
        currentUser.uid,
        'Motivated',
        '💪',
        'Ready to tackle today\'s challenges!',
      );

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vibe cast sent! 🌟')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send vibe cast: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendFaithToBuddy(int faithType) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _userService.getUser(currentUser.uid);
      if (user?.buddyId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You need a buddy first!')),
        );
        return;
      }

      final faithMessages = {
        1: '🌅 Daily Faith: Keeping our streak alive!',
        2: '💪 Encouragement Faith: You\'ve got this!',
        3: '🙏 Gratitude Faith: Thankful for you!',
        4: '🚀 Motivation Faith: Reach for the stars!',
        5: '🤝 Support Faith: I\'m here for you!',
      };

      final message = faithMessages[faithType] ?? 'Faith sent! ✨';

      final success = await _chatService.sendFaith(
        currentUser.uid,
        user!.buddyId!,
        message,
      );
      if (success) {
        Navigator.pop(context); // Close the modal
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Faith sent! $message')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Daily faith limit reached (3/3). Upgrade to premium for unlimited faith! 💎',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send faith: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendVibeCastToBuddy(String vibeType) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _userService.getUser(currentUser.uid);
      if (user?.buddyId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You need a buddy first!')),
        );
        return;
      }

      final vibeMessages = {
        'happy': '😊 Happy: Spreading joy and positivity!',
        'motivated': '💪 Motivated: Ready to conquer the day!',
        'relaxed': '😌 Relaxed: Finding peace in the moment!',
        'excited': '🎉 Excited: Can\'t wait to see what\'s next!',
        'focused': '🎯 Focused: Locked in and determined!',
        'grateful': '🙏 Grateful: Appreciating all the blessings!',
        'creative': '🎨 Creative: Ideas flowing freely!',
        'adventurous': '🏔️ Adventurous: Ready for new challenges!',
      };

      final message = vibeMessages[vibeType] ?? 'Vibe cast sent! 🌟';

      await _chatService.sendVibeCast(
        currentUser.uid,
        vibeType,
        vibeMessages[vibeType]?.split(' ')[0] ?? '🌟',
        message,
      );

      Navigator.pop(context); // Close the modal
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Vibe cast sent! $message')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send vibe cast: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendVibeCastToRecipient(
    String vibeType,
    String recipientId,
    String recipientEmail,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final vibeMessages = {
        'happy': '😊 Happy: Spreading joy and positivity!',
        'motivated': '💪 Motivated: Ready to conquer the day!',
        'relaxed': '😌 Relaxed: Finding peace in the moment!',
        'excited': '🎉 Excited: Can\'t wait to see what\'s next!',
        'focused': '🎯 Focused: Locked in and determined!',
        'grateful': '🙏 Grateful: Appreciating all the blessings!',
        'creative': '🎨 Creative: Ideas flowing freely!',
        'adventurous': '🏔️ Adventurous: Ready for new challenges!',
      };

      final message = vibeMessages[vibeType] ?? 'Vibe cast sent! 🌟';

      await _chatService.sendVibeCast(
        currentUser.uid,
        vibeType,
        vibeMessages[vibeType]?.split(' ')[0] ?? '🌟',
        message,
      );

      // Send a chat message to the specific recipient
      final chatId = _chatService.getChatId(currentUser.uid, recipientId);
      final recipient = await _userService.getUser(recipientId);
      final recipientName = recipient?.username ?? 'Your buddy';

      await _chatService.sendMessage(
        chatId: chatId,
        message: message,
        buddyId: recipientId,
        buddyName: recipientName,
      );

      Navigator.pop(context); // Close the recipient selection modal
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vibe cast sent to $recipientEmail! $message')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send vibe cast: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Please log in')));
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
        ),
        margin: const EdgeInsets.all(16),
        child: SafeArea(
          child: Column(
            children: [
              // Header with tabs
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Main header
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            Icons.arrow_back,
                            color: theme.iconTheme.color,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Chat',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/settings'),
                          icon: Icon(
                            Icons.settings,
                            color: theme.iconTheme.color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Tab bar
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _currentTabIndex = 0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: _currentTabIndex == 0
                                      ? theme.colorScheme.primary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.people,
                                      color: _currentTabIndex == 0
                                          ? theme.colorScheme.onPrimary
                                          : theme.colorScheme.onSurface,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Buddy',
                                      style: TextStyle(
                                        color: _currentTabIndex == 0
                                            ? theme.colorScheme.onPrimary
                                            : theme.colorScheme.onSurface,
                                        fontWeight: _currentTabIndex == 0
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _currentTabIndex = 1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: _currentTabIndex == 1
                                      ? theme.colorScheme.primary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.smart_toy,
                                      color: _currentTabIndex == 1
                                          ? theme.colorScheme.onPrimary
                                          : theme.colorScheme.onSurface,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'AI Chat',
                                      style: TextStyle(
                                        color: _currentTabIndex == 1
                                            ? theme.colorScheme.onPrimary
                                            : theme.colorScheme.onSurface,
                                        fontWeight: _currentTabIndex == 1
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ],
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

              // Content area
              Expanded(
                child: _currentTabIndex == 0
                    ? _buildBuddyContent()
                    : _buildAIChatInterface(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _currentTabIndex == 0
          ? FloatingActionButton(
              onPressed: () => _showAddBuddyDialog(context),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              child: const Icon(Icons.person_add),
            )
          : null,
      bottomNavigationBar: _buildBottomNavigationBar(context, 2),
    );
  }

  Widget _buildBuddyContent() {
    final theme = Theme.of(context);
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Container(); // Return empty container if no user
    }
    return Column(
      children: [
        // Buddy Request Notifications
        if (_buddyRequests.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20.0),
            padding: const EdgeInsets.all(16.0),
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
                    Icon(Icons.person_add, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Buddy Request${_buddyRequests.length > 1 ? 's' : ''}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._buddyRequests.map((request) => _buildRequestCard(request)),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: TextField(
            controller: _searchController,
            style: TextStyle(color: theme.textTheme.bodyLarge?.color),
            decoration: InputDecoration(
              hintText: 'Search by username...',
              hintStyle: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
              ),
              prefixIcon: Icon(
                Icons.search,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              filled: true,
              fillColor: theme.cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide(
                  color: theme.colorScheme.onSurface.withOpacity(0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide(
                  color: theme.colorScheme.onSurface.withOpacity(0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 15,
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Action Buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'Send Faith',
                  Icons.favorite,
                  () => _showFaithModal(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'Break Ice',
                  Icons.ac_unit,
                  () => _showIceBreakModal(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'Vibe Cast',
                  Icons.emoji_emotions,
                  () => _showVibeCastModal(context),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Search Results or Buddy Info
        Expanded(
          child: _searchResults.isNotEmpty
              ? _buildSearchResults()
              : _buildBuddyInfo(currentUser.uid),
        ),
      ],
    );
  }

  Widget _buildBuddiesList(String currentUserId) {
    return StreamBuilder<UserModel?>(
      stream: _userService.streamUser(currentUserId),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final user = userSnapshot.data;
        if (user == null) {
          return const Center(child: Text('User not found'));
        }

        if (user.buddyId == null) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_add, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No buddy found',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Tap the + button to add a buddy!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return FutureBuilder<UserModel?>(
          future: _userService.getUser(user.buddyId!),
          builder: (context, buddySnapshot) {
            if (buddySnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final buddy = buddySnapshot.data;
            if (buddy == null) {
              return const Center(child: Text('Buddy not found'));
            }

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                Card(
                  child: ListTile(
                    leading: ProfilePicture(
                      user: buddy,
                      size: 40,
                      backgroundColor: Colors.deepPurple.shade100,
                      textColor: Colors.deepPurple,
                    ),
                    title: Text(buddy.username),
                    subtitle: Text('Level ${buddy.level}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: _isLoading ? null : () => _sendFaith(),
                          icon: const Icon(Icons.favorite, color: Colors.red),
                          tooltip: 'Send Faith',
                        ),
                        IconButton(
                          onPressed: _isLoading
                              ? null
                              : () => _generateIcebreakers(),
                          icon: const Icon(Icons.ac_unit, color: Colors.blue),
                          tooltip: 'Break Ice',
                        ),
                        IconButton(
                          onPressed: _isLoading ? null : () => _sendVibeCast(),
                          icon: const Icon(
                            Icons.emoji_emotions,
                            color: Colors.orange,
                          ),
                          tooltip: 'Vibe Cast',
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/chat',
                        arguments: {
                          'buddyId': buddy.uid,
                          'buddyEmail':
                              buddy.email, // Keep for backward compatibility
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        final theme = Theme.of(context);
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: theme.cardColor,
          child: ListTile(
            leading: ProfilePicture(
              user: user,
              size: 40,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
              textColor: theme.colorScheme.primary,
            ),
            title: Text(user.username, style: theme.textTheme.titleMedium),
            subtitle: Text(
              'Level ${user.level}',
              style: theme.textTheme.bodySmall,
            ),
            trailing: ElevatedButton(
              onPressed: _pendingRequests.contains(user.uid)
                  ? null
                  : () => _sendBuddyRequest(user.uid),
              style: ElevatedButton.styleFrom(
                backgroundColor: _pendingRequests.contains(user.uid)
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              child: Text(
                _pendingRequests.contains(user.uid) ? 'Pending' : 'Add Buddy',
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBuddyInfo(String currentUserId) {
    return StreamBuilder<UserModel?>(
      stream: _userService.streamUser(currentUserId),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final user = userSnapshot.data;
        if (user == null) {
          return const Center(child: Text('User not found'));
        }

        if (user.buddyId == null) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_add, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No buddy found',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Search for a buddy by username to get started!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return FutureBuilder<UserModel?>(
          future: _userService.getUser(user.buddyId!),
          builder: (context, buddySnapshot) {
            if (buddySnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final buddy = buddySnapshot.data;
            if (buddy == null) {
              return const Center(child: Text('Buddy not found'));
            }

            final theme = Theme.of(context);
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Buddy Header (similar to AI chat header)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        ProfilePicture(
                          user: buddy,
                          size: 50,
                          backgroundColor: theme.colorScheme.primary
                              .withOpacity(0.1),
                          textColor: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                buddy.username,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: theme.textTheme.titleLarge?.color,
                                ),
                              ),
                              Text(
                                'Level ${buddy.level} • Your Buddy',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: theme.textTheme.bodySmall?.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF667eea),
                                const Color(0xFF764ba2),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: IconButton(
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                '/chat',
                                arguments: {'buddyId': buddy.uid},
                              );
                            },
                            icon: const Icon(Icons.chat, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRequestCard(BuddyRequestModel request) {
    return FutureBuilder<UserModel?>(
      future: _userService.getUser(request.fromUserId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(
            child: ListTile(
              leading: CircularProgressIndicator(),
              title: Text('Loading...'),
            ),
          );
        }

        final user = snapshot.data!;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: ProfilePicture(
              user: user,
              size: 40,
              backgroundColor: Colors.deepPurple.shade100,
              textColor: Colors.deepPurple,
            ),
            title: Text(user.username),
            subtitle: Text('Level ${user.level}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: _isLoading
                      ? null
                      : () => _acceptBuddyRequest(request),
                  icon: const Icon(Icons.check, color: Colors.green),
                  tooltip: 'Accept',
                ),
                IconButton(
                  onPressed: _isLoading
                      ? null
                      : () => _declineBuddyRequest(request),
                  icon: const Icon(Icons.close, color: Colors.red),
                  tooltip: 'Decline',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    final theme = Theme.of(context);
    return ElevatedButton(
      onPressed: _isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
        foregroundColor: theme.colorScheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

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
            if (ModalRoute.of(context)?.settings.name != '/missions') {
              Navigator.pushNamed(context, '/missions');
            }
            break;
          case 2:
            // Already on buddy
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
              fontSize: 12,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withOpacity(0.5),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIChatInterface() {
    final theme = Theme.of(context);
    return Column(
      children: [
        // AI Chat Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: Image.asset(
                    'assets/images/octopus.png',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Camarra AI',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.titleLarge?.color,
                      ),
                    ),
                    Text(
                      'Your AI companion',
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
        ),

        // AI Chat Messages
        Expanded(
          child: StreamBuilder<List<AIChatModel>>(
            stream: _aiChatService.streamAIChat(
              FirebaseAuth.instance.currentUser?.uid ?? '',
            ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading chat: ${snapshot.error}',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final messages = snapshot.data!;

              if (messages.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/octopus.png',
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Start a conversation with Camarra AI',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.titleMedium?.color,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Share your thoughts, feelings, or ask for guidance',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final isUser = message.sender == 'user';

                  return _buildAIMessageBubble(message, isUser);
                },
              );
            },
          ),
        ),

        // AI Chat Input
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: TextField(
                    controller: _aiMessageController,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      border: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF667eea), const Color(0xFF764ba2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: IconButton(
                  onPressed: _isAISending ? null : _sendAIMessage,
                  icon: _isAISending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAIMessageBubble(AIChatModel message, bool isUser) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/images/octopus.png',
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomLeft: isUser
                      ? const Radius.circular(20)
                      : const Radius.circular(4),
                  bottomRight: isUser
                      ? const Radius.circular(4)
                      : const Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withOpacity(0.1),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.message,
                style: TextStyle(
                  color: isUser
                      ? theme.colorScheme.onPrimary
                      : theme.textTheme.bodyMedium?.color,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 16),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _sendAIMessage() async {
    final message = _aiMessageController.text.trim();
    if (message.isEmpty || _isAISending) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() {
      _isAISending = true;
    });

    try {
      // Add user message to chat
      await _aiChatService.addUserMessage(currentUser.uid, message);

      // Clear input
      _aiMessageController.clear();

      // Send to AI and get response
      await _aiChatService.sendMessageToAI(currentUser.uid, message);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error sending message: $e')));
    } finally {
      setState(() {
        _isAISending = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _addBuddySearchController.dispose();
    _searchDebounceTimer?.cancel();
    super.dispose();
  }
}
