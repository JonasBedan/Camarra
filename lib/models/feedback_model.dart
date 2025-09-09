class FeedbackModel {
  final String id;
  final String userId;
  final String userDisplayName;
  final String userProfilePicture;
  final String title;
  final String description;
  final String category;
  final DateTime createdAt;
  final int upvotes;
  final int downvotes;
  final List<String> upvotedBy;
  final List<String> downvotedBy;
  final String status; // 'pending', 'in_progress', 'completed', 'declined'
  final String? adminResponse;
  final DateTime? adminResponseDate;

  FeedbackModel({
    required this.id,
    required this.userId,
    required this.userDisplayName,
    required this.userProfilePicture,
    required this.title,
    required this.description,
    required this.category,
    required this.createdAt,
    required this.upvotes,
    required this.downvotes,
    required this.upvotedBy,
    required this.downvotedBy,
    required this.status,
    this.adminResponse,
    this.adminResponseDate,
  });

  int get score => upvotes - downvotes;

  bool hasUserVoted(String userId) {
    return upvotedBy.contains(userId) || downvotedBy.contains(userId);
  }

  String getUserVote(String userId) {
    if (upvotedBy.contains(userId)) return 'upvote';
    if (downvotedBy.contains(userId)) return 'downvote';
    return 'none';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userDisplayName': userDisplayName,
      'userProfilePicture': userProfilePicture,
      'title': title,
      'description': description,
      'category': category,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'upvotes': upvotes,
      'downvotes': downvotes,
      'upvotedBy': upvotedBy,
      'downvotedBy': downvotedBy,
      'status': status,
      'adminResponse': adminResponse,
      'adminResponseDate': adminResponseDate?.millisecondsSinceEpoch,
    };
  }

  factory FeedbackModel.fromMap(Map<String, dynamic> map) {
    return FeedbackModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      userDisplayName: map['userDisplayName'] ?? '',
      userProfilePicture: map['userProfilePicture'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      upvotes: map['upvotes'] ?? 0,
      downvotes: map['downvotes'] ?? 0,
      upvotedBy: List<String>.from(map['upvotedBy'] ?? []),
      downvotedBy: List<String>.from(map['downvotedBy'] ?? []),
      status: map['status'] ?? 'pending',
      adminResponse: map['adminResponse'],
      adminResponseDate: map['adminResponseDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['adminResponseDate'])
          : null,
    );
  }

  FeedbackModel copyWith({
    String? id,
    String? userId,
    String? userDisplayName,
    String? userProfilePicture,
    String? title,
    String? description,
    String? category,
    DateTime? createdAt,
    int? upvotes,
    int? downvotes,
    List<String>? upvotedBy,
    List<String>? downvotedBy,
    String? status,
    String? adminResponse,
    DateTime? adminResponseDate,
  }) {
    return FeedbackModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      userProfilePicture: userProfilePicture ?? this.userProfilePicture,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
      upvotedBy: upvotedBy ?? this.upvotedBy,
      downvotedBy: downvotedBy ?? this.downvotedBy,
      status: status ?? this.status,
      adminResponse: adminResponse ?? this.adminResponse,
      adminResponseDate: adminResponseDate ?? this.adminResponseDate,
    );
  }
}
