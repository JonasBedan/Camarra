import 'package:flutter/material.dart';

import '../models/chat_message_model.dart';
import '../models/user_model.dart';
import '../utils/chat_service.dart';
import '../utils/user_service.dart';
import '../widgets/profile_picture.dart';

class ChatScreen extends StatefulWidget {
  final String? buddyId;
  final String? buddyEmail;

  const ChatScreen({super.key, this.buddyId, this.buddyEmail});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final UserService _userService = UserService();
  UserModel? _currentUser;
  UserModel? _buddyUser;
  List<IcebreakerModel> _icebreakers = [];
  VibeCastModel? _currentUserVibe;
  VibeCastModel? _buddyUserVibe;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadIcebreakers();
    _loadVibeCasts();
  }

  Future<void> _loadUserData() async {
    final currentUser = _userService.getCurrentUser();
    if (currentUser != null) {
      _currentUser = await _userService.getUser(currentUser.uid);

      if (widget.buddyId != null) {
        _buddyUser = await _userService.getUser(widget.buddyId!);
        // Ensure chat room exists to prevent permission errors
        await _ensureChatRoomExists();
      } else if (widget.buddyEmail != null) {
        final users = await _userService.getUserByEmail(widget.buddyEmail!);
        if (users.isNotEmpty) {
          _buddyUser = users.first;
          // Ensure chat room exists to prevent permission errors
          await _ensureChatRoomExists();
        }
      }

      setState(() {});
    }
  }

  Future<void> _ensureChatRoomExists() async {
    if (_currentUser != null && _buddyUser != null) {
      try {
        // Create chat room if it doesn't exist
        await _chatService.ensureChatRoomExists(
          _currentUser!.uid,
          _buddyUser!.uid,
        );
      } catch (e) {
        print('Error ensuring chat room exists: $e');
        // Don't show error to user, just log it
      }
    }
  }

  Future<void> _loadIcebreakers() async {
    if (_currentUser?.buddyId != null) {
      _chatService.streamIcebreakers(_currentUser!.buddyId!).listen((
        icebreakers,
      ) {
        setState(() {
          _icebreakers = icebreakers;
        });
      });
    }
  }

  Future<void> _loadVibeCasts() async {
    if (_currentUser != null && _buddyUser != null) {
      // Stream current user's vibe cast
      _chatService.streamLatestVibeCast(_currentUser!.uid).listen((vibe) {
        setState(() {
          _currentUserVibe = vibe;
        });
      });

      // Stream buddy's vibe cast
      _chatService.streamLatestVibeCast(_buddyUser!.uid).listen((vibe) {
        setState(() {
          _buddyUserVibe = vibe;
        });
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty ||
        _currentUser == null ||
        _buddyUser == null) {
      return;
    }

    final message = _messageController.text.trim();
    _messageController.clear();

    try {
      final chatId = _chatService.getChatId(_currentUser!.uid, _buddyUser!.uid);
      await _chatService.sendMessage(
        chatId: chatId,
        message: message,
        buddyId: _buddyUser!.uid,
        buddyName: _buddyUser!.username,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
    }
  }

  Future<void> _useIcebreaker(IcebreakerModel icebreaker) async {
    if (_currentUser == null || _buddyUser == null) return;

    try {
      setState(() => _isLoading = true);

      await _chatService.useIcebreaker(
        _currentUser!.uid,
        _buddyUser!.uid,
        icebreaker.id,
      );

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ice breaker sent! 🧊')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send ice breaker: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_currentUser == null || _buddyUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Column(
        children: [
          // Header to match AI chat screen (consistent corner radius)
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.transparent,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 8),
                _buildAvatarWithMood(_buddyUser!.username, false, radius: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _buddyUser!.username,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.titleLarge?.color,
                        ),
                      ),
                      Text(
                        'Level ${_buddyUser!.level} • Your Buddy',
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
          // Ice breakers section
          if (_icebreakers.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.05),
                border: Border(bottom: BorderSide(color: theme.dividerColor)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🧊 Ice Breakers',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _icebreakers.length,
                      itemBuilder: (context, index) {
                        final icebreaker = _icebreakers[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : () => _useIcebreaker(icebreaker),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.cardColor,
                              foregroundColor: theme.colorScheme.primary,
                              elevation: 2,
                            ),
                            child: Text(
                              icebreaker.question.length > 30
                                  ? '${icebreaker.question.substring(0, 30)}...'
                                  : icebreaker.question,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Chat messages
          Expanded(
            child: StreamBuilder<List<ChatMessageModel>>(
              stream: _chatService.streamChatMessages(
                _currentUser!.uid,
                _buddyUser!.uid,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!;

                if (messages.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Start a conversation!',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Use ice breakers or send a message',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
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
                    final isMe = message.senderId == _currentUser!.uid;

                    return _buildMessageBubble(message, isMe);
                  },
                );
              },
            ),
          ),

          // Message input (match AI chat)
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
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Type your message...',
                        border: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: IconButton(
                    onPressed: _isLoading ? null : _sendMessage,
                    icon: const Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel message, bool isMe) {
    final theme = Theme.of(context);
    Color bubbleColor = theme.colorScheme.surface;
    Color textColor = theme.textTheme.bodyMedium?.color ?? Colors.black;
    IconData? icon;
    String? label;

    switch (message.type) {
      case 'text':
        bubbleColor = isMe
            ? theme.colorScheme.primary
            : theme.colorScheme.surface;
        textColor = isMe
            ? theme.colorScheme.onPrimary
            : (theme.textTheme.bodyMedium?.color ?? Colors.black);
        break;
      case 'icebreak':
        bubbleColor = Colors.blue.shade100;
        textColor = Colors.blue.shade900;
        icon = Icons.ac_unit;
        label = 'Ice Breaker';
        break;
      case 'faith':
        bubbleColor = Colors.pink.shade100;
        textColor = Colors.pink.shade900;
        icon = Icons.favorite;
        label = 'Faith';
        break;
      case 'vibeCast':
        bubbleColor = Colors.orange.shade100;
        textColor = Colors.orange.shade900;
        icon = Icons.emoji_emotions;
        label = 'Vibe Cast';
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            _buildAvatarWithMood(_buddyUser!.username, false),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomLeft: isMe
                      ? const Radius.circular(20)
                      : const Radius.circular(4),
                  bottomRight: isMe
                      ? const Radius.circular(4)
                      : const Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (label != null) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(message.text, style: TextStyle(color: textColor)),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: textColor.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            _buildAvatarWithMood(_currentUser!.username, true),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildAvatarWithMood(
    String username,
    bool isCurrentUser, {
    double radius = 16,
  }) {
    final vibe = isCurrentUser ? _currentUserVibe : _buddyUserVibe;
    final user = isCurrentUser ? _currentUser : _buddyUser;

    return Stack(
      children: [
        ProfilePicture(
          user: user,
          size: radius * 2,
          backgroundColor: isCurrentUser
              ? Colors.deepPurple
              : Colors.deepPurple.shade100,
          textColor: isCurrentUser ? Colors.white : Colors.deepPurple,
        ),
        if (vibe != null)
          Positioned(
            bottom: -2,
            left: -2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300, width: 1),
              ),
              child: Text(vibe.emoji, style: TextStyle(fontSize: radius * 0.4)),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
