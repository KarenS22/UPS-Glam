import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../widgets/telemetry_overlay.dart';
import '../widgets/glass_panel.dart';
import 'user_profile_screen.dart';

class FeedScreen extends StatefulWidget {
  final String token;
  final User currentUser;

  const FeedScreen({super.key, required this.token, required this.currentUser});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<FeedItem> _feedItems = [];
  bool _loading = true;
  String _error = '';

  // Track expanded comments by publication ID: { pubId: commentsList }
  final Map<int, List<CommentItem>> _commentsMap = {};
  // Track which page we are on for each publication's comments
  final Map<int, int> _commentsPageMap = {};
  // Track if there are more comments to load for each publication
  final Map<int, bool> _hasMoreCommentsMap = {};
  // Track if we are currently loading more comments for each publication
  final Map<int, bool> _loadingMoreMap = {};
  // Track which publication has comments drawer open
  int? _activeCommentsPubId;
  final TextEditingController _commentController = TextEditingController();

  // Track expanded metrics by publication ID: { pubId: metricsObject }
  final Map<int, GpuMetrics> _metricsMap = {};
  // Track which publication has metrics drawer open
  int? _activeMetricsPubId;

  // Track which publications are currently showing the original image instead of the filtered one
  final Set<int> _showOriginalPubIds = {};

  @override
  void initState() {
    super.initState();
    _fetchFeed();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _fetchFeed() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final items = await ApiService.fetchFeed(widget.token);
      setState(() {
        _feedItems = items;
      });
    } catch (err) {
      setState(() {
        _error =
            'Error al recuperar publicaciones: Asegúrate de que el backend reactivo esté activo.';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _navigateToProfile(User target) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(
          targetUser: target,
          currentUser: widget.currentUser,
          token: widget.token,
        ),
      ),
    ).then((_) {
      // Reload feed upon returning to catch any profile information changes (username, avatar, etc.)
      _fetchFeed();
    });
  }

  // Liking handler with optimistic UI updates
  Future<void> _handleLikeToggle(FeedItem item) async {
    final int pubId = item.publication.id;
    final bool previousLiked = item.isLikedByMe;
    final int previousCount = item.likesCount;

    // 1. Optimistic Update
    setState(() {
      item.isLikedByMe = !previousLiked;
      item.likesCount = previousLiked ? previousCount - 1 : previousCount + 1;
      if (!previousLiked) {
        item.animateHeart = true; // triggers pop effect
      }
    });

    // Reset heart animation after brief delay
    if (!previousLiked) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          setState(() {
            item.animateHeart = false;
          });
        }
      });
    }

    try {
      // 2. Network Request
      await ApiService.toggleLike(widget.token, pubId, !previousLiked);
    } catch (err) {
      // 3. Revert on Error
      setState(() {
        item.isLikedByMe = previousLiked;
        item.likesCount = previousCount;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo procesar la reacción: ${err.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // Comments drawer toggle
  Future<void> _handleToggleComments(int pubId) async {
    if (_activeCommentsPubId == pubId) {
      setState(() {
        _activeCommentsPubId = null;
      });
      return;
    }

    setState(() {
      _activeCommentsPubId = pubId;
      _commentController.clear();
    });

    // Fetch comments if not loaded yet
    if (!_commentsMap.containsKey(pubId)) {
      _fetchComments(pubId);
    }
  }

  Future<void> _fetchComments(int pubId, {bool isLoadMore = false}) async {
    if (isLoadMore && (_loadingMoreMap[pubId] == true)) return;

    try {
      if (isLoadMore) {
        setState(() => _loadingMoreMap[pubId] = true);
      }

      final int page = isLoadMore ? (_commentsPageMap[pubId] ?? 0) + 1 : 0;
      const int size = 8;
      
      final comments = await ApiService.fetchComments(widget.token, pubId, page: page, size: size);
      
      setState(() {
        if (isLoadMore) {
          _commentsMap[pubId] = [...(_commentsMap[pubId] ?? []), ...comments];
          _commentsPageMap[pubId] = page;
          _loadingMoreMap[pubId] = false;
        } else {
          _commentsMap[pubId] = comments;
          _commentsPageMap[pubId] = 0;
        }
        // If we got fewer comments than requested, there are likely no more
        _hasMoreCommentsMap[pubId] = comments.length == size;
      });
    } catch (err) {
      if (isLoadMore) {
        setState(() => _loadingMoreMap[pubId] = false);
      } else {
        setState(() {
          _commentsMap[pubId] = [];
          _hasMoreCommentsMap[pubId] = false;
        });
      }
    }
  }

  Future<void> _fetchMoreComments(int pubId) async {
    await _fetchComments(pubId, isLoadMore: true);
  }

  Future<void> _handleAddComment(int pubId) async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    try {
      setState(() {
        _commentController.clear();
      });

      await ApiService.addComment(widget.token, pubId, text);

      // Reload comments (will fetch the latest descending page)
      await _fetchComments(pubId);

      // Force feed update to keep count in sync
      setState(() {
        final itemIdx = _feedItems.indexWhere((x) => x.publication.id == pubId);
        if (itemIdx != -1) {
          _feedItems[itemIdx].commentsCount++;
        }
      });
    } catch (err) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al comentar: ${err.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // GPU Metrics overlay dialog
  Future<void> _handleToggleMetrics(int pubId, String? processedUrl, String filterApplied) async {
    if (processedUrl == null) return;

    GpuMetrics? metrics = _metricsMap[pubId];

    // Fetch metrics if not loaded
    if (metrics == null) {
      try {
        metrics = await ApiService.fetchMetricsByUrl(
          widget.token,
          processedUrl,
        );
        setState(() {
          _metricsMap[pubId] = metrics!;
        });
      } catch (err) {
        // Safe UI Fallback simulated metrics (Respecting the publication's isGpu flag)
        metrics = GpuMetrics(
          imageSize: '1024x768',
          blockDim: '16x16',
          gridDim: '64x48',
          totalThreads: 786432,
          executionTimeMs: 1.254,
          memoryUsedBytes: 1572864,
          isGpu: _feedItems.firstWhere((x) => x.publication.id == pubId).publication.isGpu,
          createdAt: DateTime.now().toIso8601String(),
        );
        setState(() {
          _metricsMap[pubId] = metrics!;
        });
      }
    }

    if (mounted) {
      _showTelemetryDialog(metrics, filterApplied);
    }
  }

  void _showTelemetryDialog(GpuMetrics metrics, String filterApplied) {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Stack(
            alignment: Alignment.center,
            children: [
              TelemetryOverlay(
                metrics: metrics,
                filterId: filterApplied,
                isCompact: false,
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String isoString) {
    if (isoString.isEmpty) return '';
    try {
      final date = DateTime.parse(isoString).toLocal();
      final months = [
        'ene',
        'feb',
        'mar',
        'abr',
        'may',
        'jun',
        'jul',
        'ago',
        'sep',
        'oct',
        'nov',
        'dic',
      ];

      final day = date.day;
      final month = months[date.month - 1];
      final year = date.year;
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');

      return '$day de $month, $year a las $hour:$minute';
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Header
          // Padding(
          //   padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          //   child: Row(
          //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
          //     children: [
          //       const Text(
          //         'Muro de Inspiración',
          //         style: TextStyle(
          //           fontSize: 20,
          //           fontWeight: FontWeight.w800,
          //           color: Color(0xFF14396A),
          //         ),
          //       ),
          //       TextButton(
          //         onPressed: _fetchFeed,
          //         child: const Text(
          //           'Recargar Feed',
          //           style: TextStyle(
          //             color: Color(0xFF14396A),
          //             fontWeight: FontWeight.bold,
          //             fontSize: 13,
          //             decoration: TextDecoration.underline,
          //             decorationColor: Color(0xFF14396A),
          //           ),
          //         ),
          //       ),
          //     ],
          //   ),
          // ),

          // Error message
          if (_error.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.05),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error,
                  style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Loading or Empty states
          Expanded(
            child: _loading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF14396A),
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Preparando tu feed...',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            color: Color(0xFF14396A),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                : _feedItems.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: GlassPanel(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.image_search,
                              size: 48,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No hay publicaciones aún',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '¡Sé el primero en crear un nuevo estilo y compartirlo!',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchFeed,
                    color: const Color(0xFF14396A),
                    backgroundColor: Colors.white,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      itemCount: _feedItems.length,
                      itemBuilder: (context, idx) {
                        final item = _feedItems[idx];
                        return _buildFeedCard(item);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // Main Card Widget
  Widget _buildFeedCard(FeedItem item) {
    final pub = item.publication;
    final creator = item.creator;

    final double screenWidth = MediaQuery.of(context).size.width;
    final int deviceCacheWidth =
        (screenWidth * MediaQuery.of(context).devicePixelRatio).toInt().clamp(
          300,
          1080,
        );

    // Check if filter is applied
    final bool isFiltered = pub.processedImageUrl != null && pub.processedImageUrl!.isNotEmpty;

    final int commentsCount = item.commentsCount;

    return Container(
      margin: const EdgeInsets.only(bottom: 24.0),
      decoration: BoxDecoration(
        color: const Color(0xFF14396A), // Flat solid blue background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white, // Solid white border
          width: isFiltered ? 2.5 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header: Avatar, Username, Date, Telemetry Button
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _navigateToProfile(creator),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                          color: const Color(0xFF14396A),
                        ),
                        child: ClipOval(
                          child:
                              creator.avatarUrl != null &&
                                  creator.avatarUrl!.isNotEmpty
                              ? Image.network(
                                  ApiService.getOptimizedImageUrl(
                                    creator.avatarUrl!,
                                  ),
                                  fit: BoxFit.cover,
                                  cacheWidth: 100,
                                  errorBuilder: (context, _, __) => Center(
                                    child: Text(
                                      creator.username.isNotEmpty
                                          ? creator.username[0].toUpperCase()
                                          : 'U',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    creator.username.isNotEmpty
                                        ? creator.username[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Username & Time
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '@${creator.username}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 10,
                                  color: Colors.grey[500],
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _formatDate(pub.createdAt),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                ),

                // Interactive GPU/CPU Badge (Toggles Telemetry)
                if (isFiltered)
                  InkWell(
                    onTap: () =>
                        _handleToggleMetrics(pub.id, pub.processedImageUrl, pub.filterApplied ?? 'none'),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 160),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white, // Solid flat white background
                        border: Border.all(color: Colors.white, width: 1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.tune,
                            size: 11,
                            color: Color(0xFF14396A), // Contrast flat blue
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${pub.isGpu ? 'GPU' : 'CPU'}: ${pub.filterApplied!.toUpperCase()}', // Uses the new isGpu flag directly
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF14396A), // Contrast flat blue
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 2. Card Content Image (Filtered by default, tap to view original, complete contain fit)
          Container(
            height: 400,
            width: double.infinity,
            color: const Color(0xFF14396A), // Solid flat blue background
            child: isFiltered
                ? GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_showOriginalPubIds.contains(pub.id)) {
                          _showOriginalPubIds.remove(pub.id);
                        } else {
                          _showOriginalPubIds.add(pub.id);
                        }
                      });
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.network(
                          ApiService.getOptimizedImageUrl(
                            _showOriginalPubIds.contains(pub.id)
                                ? pub.imageUrl
                                : pub.processedImageUrl!,
                          ),
                          width: double.infinity,
                          height: 400,
                          fit: BoxFit
                              .contain, // Show complete image inside container
                          cacheWidth: deviceCacheWidth,
                          errorBuilder: (context, err, stack) => const SizedBox(
                            height: 200,
                            child: Center(
                              child: Icon(
                                Icons.broken_image,
                                color: Colors.white60,
                                size: 40,
                              ),
                            ),
                          ),
                        ),
                        // Premium flat dual-tone view badge
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF14396A),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _showOriginalPubIds.contains(pub.id)
                                      ? Icons.image
                                      : Icons.auto_awesome,
                                  size: 12,
                                  color: const Color(0xFF14396A),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _showOriginalPubIds.contains(pub.id)
                                      ? 'ORIGINAL'
                                      : 'FILTRO',
                                  style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF14396A),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Image.network(
                    ApiService.getOptimizedImageUrl(pub.imageUrl),
                    width: double.infinity,
                    height: 400,
                    fit: BoxFit.contain, // Show complete image inside container
                    cacheWidth: deviceCacheWidth,
                    errorBuilder: (context, err, stack) => const SizedBox(
                      height: 200,
                      child: Center(
                        child: Icon(
                          Icons.broken_image,
                          color: Colors.white60,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
          ),


          // 4. Action Row (Likes, Comments Toggle)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              children: [
                // Heart Like Button
                InkWell(
                  onTap: () => _handleLikeToggle(item),
                  child: Row(
                    children: [
                      AnimatedScale(
                        scale: item.animateHeart ? 1.4 : 1.0,
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOutBack,
                        child: Icon(
                          item.isLikedByMe
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: item.isLikedByMe
                              ? Colors.white
                              : Colors.white60,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${item.likesCount}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: item.isLikedByMe
                              ? Colors.white
                              : Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),

                // Comment Button
                InkWell(
                  onTap: () => _handleToggleComments(pub.id),
                  child: Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        color: _activeCommentsPubId == pub.id
                            ? Colors.white
                            : Colors.white60,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$commentsCount',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _activeCommentsPubId == pub.id
                              ? Colors.white
                              : Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 5. Caption Row
          if (pub.caption != null && pub.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 13, height: 1.4),
                  children: [
                    TextSpan(
                      text: '@${creator.username} ',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    TextSpan(
                      text: pub.caption,
                      style: TextStyle(color: Colors.grey[300]),
                    ),
                  ],
                ),
              ),
            ),

          // 6. Comments drawer
          if (_activeCommentsPubId == pub.id) _buildCommentsDrawer(pub.id),
        ],
      ),
    );
  }

  // Comments drawer UI builder
  Widget _buildCommentsDrawer(int pubId) {
    final comments = _commentsMap[pubId];

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.01),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.04)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Comentarios (${_feedItems.firstWhere((x) => x.publication.id == pubId).commentsCount})',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[400],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Comments List
          if (comments == null)
            const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else if (comments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'No hay comentarios aún. ¡Escribe el primero!',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.white60,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: NotificationListener<ScrollNotification>(
                onNotification: (scrollInfo) {
                  if (scrollInfo.metrics.pixels >= 
                          scrollInfo.metrics.maxScrollExtent - 50 &&
                      _hasMoreCommentsMap[pubId] == true &&
                      _loadingMoreMap[pubId] != true) {
                    _fetchMoreComments(pubId);
                  }
                  return false;
                },
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  itemCount: comments.length + (_loadingMoreMap[pubId] == true ? 1 : 0),
                  itemBuilder: (context, idx) {
                    if (idx == comments.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Center(
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                            ),
                          ),
                        ),
                      );
                    }
                    
                    final dto = comments[idx];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 12.5),
                              children: [
                                TextSpan(
                                  text: '@${dto.user.username} ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () => _navigateToProfile(dto.user),
                                ),
                                TextSpan(
                                  text: dto.comment.content,
                                  style: TextStyle(color: Colors.grey[300]),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDate(dto.comment.createdAt),
                            style: TextStyle(
                              fontSize: 9.5,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

          const SizedBox(height: 8),

          // Comment Box Input Form
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _commentController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Escribe un comentario...',
                      hintStyle: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12.5,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF14396A),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Colors.white,
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Colors.white,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Colors.white,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _handleAddComment(pubId),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 18),
                onPressed: () => _handleAddComment(pubId),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
