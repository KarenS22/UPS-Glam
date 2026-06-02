class User {
  final String id;
  final String username;
  final String email;
  final String fullName;
  final String? avatarUrl;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    this.avatarUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? json['full_name'] ?? '',
      avatarUrl: json['avatarUrl'] ?? json['avatar_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'fullName': fullName,
      'avatarUrl': avatarUrl,
    };
  }
}

class Publication {
  final int id;
  final String? caption;
  final String imageUrl;
  final String? processedImageUrl;
  final String? filterApplied;
  final bool isGpu;
  final String createdAt;

  Publication({
    required this.id,
    this.caption,
    required this.imageUrl,
    this.processedImageUrl,
    this.filterApplied,
    required this.isGpu,
    required this.createdAt,
  });

  factory Publication.fromJson(Map<String, dynamic> json) {
    return Publication(
      id: json['id'] ?? 0,
      caption: json['caption'],
      imageUrl: json['imageUrl'] ?? json['image_url'] ?? '',
      processedImageUrl: json['processedImageUrl'] ?? json['processed_image_url'],
      filterApplied: json['filterApplied'] ?? json['filter_applied'],
      isGpu: json['isGpu'] ?? json['is_gpu'] ?? true,
      createdAt: json['createdAt'] ?? json['created_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'caption': caption,
      'imageUrl': imageUrl,
      'processedImageUrl': processedImageUrl,
      'filterApplied': filterApplied,
      'isGpu': isGpu,
      'createdAt': createdAt,
    };
  }
}

class GpuMetrics {
  final String imageSize;
  final String blockDim;
  final String gridDim;
  final int totalThreads;
  final double executionTimeMs;
  final int memoryUsedBytes;
  final bool isGpu;
  final String? createdAt;

  GpuMetrics({
    required this.imageSize,
    required this.blockDim,
    required this.gridDim,
    required this.totalThreads,
    required this.executionTimeMs,
    required this.memoryUsedBytes,
    required this.isGpu,
    this.createdAt,
  });

  factory GpuMetrics.fromJson(Map<String, dynamic> json) {
    return GpuMetrics(
      imageSize: json['imageSize'] ?? json['image_size'] ?? '1024x768',
      blockDim: json['blockDim'] ?? json['block_dim'] ?? '16x16',
      gridDim: json['gridDim'] ?? json['grid_dim'] ?? '64x48',
      totalThreads: json['totalThreads'] ?? json['total_threads'] ?? 786432,
      executionTimeMs: (json['executionTimeMs'] ?? json['execution_time_ms'] ?? json['totalGpuTimeMs'] ?? json['total_gpu_time_ms'] ?? 0.0).toDouble(),
      memoryUsedBytes: (json['memoryUsedBytes'] ?? json['memory_used_bytes'] ?? 0),
      isGpu: json['isGpu'] ?? json['is_gpu'] ?? true,
      createdAt: json['created_at'] ?? json['createdAt'],
    );
  }
}

class Comment {
  final int id;
  final String content;
  final String createdAt;

  Comment({
    required this.id,
    required this.content,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] ?? 0,
      content: json['content'] ?? '',
      createdAt: json['createdAt'] ?? json['created_at'] ?? '',
    );
  }
}

class CommentItem {
  final Comment comment;
  final User user;

  CommentItem({
    required this.comment,
    required this.user,
  });

  factory CommentItem.fromJson(Map<String, dynamic> json) {
    return CommentItem(
      comment: Comment.fromJson(json['comment'] ?? {}),
      user: User.fromJson(json['user'] ?? {}),
    );
  }
}

class FeedItem {
  final Publication publication;
  final User creator;
  int likesCount;
  int commentsCount;
  bool isLikedByMe;
  bool animateHeart; // Local UI state

  FeedItem({
    required this.publication,
    required this.creator,
    required this.likesCount,
    required this.commentsCount,
    required this.isLikedByMe,
    this.animateHeart = false,
  });

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    return FeedItem(
      publication: Publication.fromJson(json['publication'] ?? {}),
      creator: User.fromJson(json['creator'] ?? {}),
      likesCount: json['likesCount'] ?? json['likes_count'] ?? 0,
      commentsCount: json['commentsCount'] ?? json['comments_count'] ?? 0,
      isLikedByMe: json['isLikedByMe'] ?? json['is_liked_by_me'] ?? false,
    );
  }
}

class FilterInfo {
  final String id;
  final String name;
  final String description;

  FilterInfo({
    required this.id,
    required this.name,
    required this.description,
  });

  factory FilterInfo.fromJson(Map<String, dynamic> json) {
    return FilterInfo(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
    );
  }
}
