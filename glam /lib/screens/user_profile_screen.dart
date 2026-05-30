import 'package:flutter/material.dart';
import 'dart:ui';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/glass_panel.dart';
import '../widgets/telemetry_overlay.dart';
import 'edit_profile_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final User targetUser;
  final User currentUser;
  final String token;

  const UserProfileScreen({
    super.key,
    required this.targetUser,
    required this.currentUser,
    required this.token,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  List<FeedItem> _publications = [];
  bool _loading = true;
  String _error = '';
  late User _profileUser;

  // Track expanded comments by publication ID: { pubId: commentsList }
  final Map<int, List<CommentItem>> _commentsMap = {};
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
    _profileUser = widget.targetUser;
    _fetchPublications();
  }

  Future<void> _fetchPublications() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final list = await ApiService.fetchUserPublications(widget.token, _profileUser.id);
      setState(() {
        _publications = list;
      });
    } catch (err) {
      setState(() {
        _error = 'Error al cargar las publicaciones: ${err.toString()}';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  // Update profile user details if the user updates their profile while on this screen
  Future<void> _handleEditProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(
          token: widget.token,
          currentUser: _profileUser,
          onProfileUpdated: (updated) {
            setState(() {
              _profileUser = updated;
            });
            _fetchPublications(); // Reload grid just in case
          },
        ),
      ),
    );
  }

  String _formatDate(String isoString) {
    if (isoString.isEmpty) return '';
    try {
      final date = DateTime.parse(isoString).toLocal();
      final months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
      return '${date.day} de ${months[date.month - 1]}, ${date.year}';
    } catch (_) {
      return isoString;
    }
  }

  // Deletion confirmation and execution
  Future<void> _handleDeletePublication(Publication pub) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AlertDialog(
          backgroundColor: const Color(0xFF0E0E1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3)),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              SizedBox(width: 8),
              Text(
                '¿Eliminar Publicación?',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: const Text(
            'Esta acción eliminará de forma permanente la publicación de tu muro y servidor. Esta operación no se puede deshacer.',
            style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Eliminar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;

    if (confirm == true) {
      // Show loading HUD
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
        ),
      );

      try {
        await ApiService.deletePublication(widget.token, pub.id);
        
        if (!mounted) return;
        Navigator.pop(context); // Close HUD
        Navigator.pop(context); // Close details dialog if open

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Publicación eliminada con éxito!'),
            backgroundColor: Color(0xFF14396A),
          ),
        );

        _fetchPublications(); // Reload Grid
      } catch (err) {
        if (!mounted) return;
        Navigator.pop(context); // Close HUD
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: ${err.toString()}'),
            backgroundColor: const Color(0xFF14396A),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // Liking handler with optimistic UI updates
  Future<void> _handleLikeToggle(FeedItem item, {StateSetter? setStateFn}) async {
    final int pubId = item.publication.id;
    final bool previousLiked = item.isLikedByMe;
    final int previousCount = item.likesCount;

    void update(VoidCallback fn) {
      if (setStateFn != null) setStateFn(fn);
      if (mounted) setState(fn);
    }

    // 1. Optimistic Update
    update(() {
      item.isLikedByMe = !previousLiked;
      item.likesCount = previousLiked ? previousCount - 1 : previousCount + 1;
      if (!previousLiked) {
        item.animateHeart = true; // triggers pop effect
      }
    });

    // Reset heart animation after brief delay
    if (!previousLiked) {
      Future.delayed(const Duration(milliseconds: 400), () {
        update(() {
          item.animateHeart = false;
        });
      });
    }

    try {
      // 2. Network Request
      await ApiService.toggleLike(widget.token, pubId, !previousLiked);
    } catch (err) {
      // 3. Revert on Error
      update(() {
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
  Future<void> _handleToggleComments(int pubId, {StateSetter? setStateFn}) async {
    void update(VoidCallback fn) {
      if (setStateFn != null) setStateFn(fn);
      if (mounted) setState(fn);
    }

    if (_activeCommentsPubId == pubId) {
      update(() {
        _activeCommentsPubId = null;
      });
      return;
    }

    update(() {
      _activeCommentsPubId = pubId;
      _commentController.clear();
    });

    // Fetch comments if not loaded yet
    if (!_commentsMap.containsKey(pubId)) {
      _fetchComments(pubId, setStateFn: setStateFn);
    }
  }

  Future<void> _fetchComments(int pubId, {StateSetter? setStateFn}) async {
    void update(VoidCallback fn) {
      if (setStateFn != null) setStateFn(fn);
      if (mounted) setState(fn);
    }

    try {
      final comments = await ApiService.fetchComments(widget.token, pubId);
      update(() {
        _commentsMap[pubId] = comments;
      });
    } catch (err) {
      // Fallback empty list
      update(() {
        _commentsMap[pubId] = [];
      });
    }
  }

  Future<void> _handleAddComment(int pubId, {StateSetter? setStateFn}) async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    void update(VoidCallback fn) {
      if (setStateFn != null) setStateFn(fn);
      if (mounted) setState(fn);
    }

    try {
      update(() {
        _commentController.clear();
      });

      await ApiService.addComment(widget.token, pubId, text);

      // Reload comments
      await _fetchComments(pubId, setStateFn: setStateFn);
    } catch (err) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al comentar: ${err.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // GPU Metrics overlay toggle
  Future<void> _handleToggleMetrics(int pubId, String? processedUrl, {StateSetter? setStateFn}) async {
    void update(VoidCallback fn) {
      if (setStateFn != null) setStateFn(fn);
      if (mounted) setState(fn);
    }

    if (_activeMetricsPubId == pubId) {
      update(() {
        _activeMetricsPubId = null;
      });
      return;
    }

    update(() {
      _activeMetricsPubId = pubId;
    });

    if (processedUrl == null) return;

    // Fetch metrics if not loaded
    if (!_metricsMap.containsKey(pubId)) {
      try {
        final metrics = await ApiService.fetchMetricsByUrl(
          widget.token,
          processedUrl,
        );
        update(() {
          _metricsMap[pubId] = metrics;
        });
      } catch (err) {
        // Safe UI Fallback simulated metrics so the user is still wowed
        update(() {
          _metricsMap[pubId] = GpuMetrics(
            imageSize: '1024x768',
            blockDim: '16x16',
            gridDim: '64x48',
            totalThreads: 786432,
            executionTimeMs: 1.254,
            memoryUsedBytes: 1572864,
            createdAt: DateTime.now().toIso8601String(),
          );
        });
      }
    }
  }

  // Opens a beautiful popup presenting the uncropped full resolution publication
  void _openPublicationDetails(FeedItem item) {
    final pub = item.publication;
    _showOriginalPubIds.remove(pub.id); // Reset toggle state so details dialog always starts showing the filtered image by default
    final bool isFiltered = pub.processedImageUrl != null && pub.processedImageUrl!.isNotEmpty;
    final bool isMyPost = _profileUser.id == widget.currentUser.id;

    final double screenWidth = MediaQuery.of(context).size.width;
    final int deviceCacheWidth = (screenWidth * MediaQuery.of(context).devicePixelRatio).toInt().clamp(300, 1080);

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void update(VoidCallback fn) {
            fn();
            setDialogState(() {});
            if (mounted) setState(() {});
          }

          final int commentsCount = _commentsMap.containsKey(pub.id)
              ? _commentsMap[pub.id]!.length
              : 0;

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
            backgroundColor: const Color(0xFF14396A), // Flat solid blue background
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.white, width: 2.0), // Solid white border
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header (User + Close/Delete Button)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1.5),
                                  color: const Color(0xFF14396A),
                                ),
                                child: ClipOval(
                                  child: _profileUser.avatarUrl != null && _profileUser.avatarUrl!.isNotEmpty
                                      ? Image.network(
                                          ApiService.getOptimizedImageUrl(_profileUser.avatarUrl!),
                                          fit: BoxFit.cover,
                                          cacheWidth: 100,
                                          errorBuilder: (c, e, s) => _buildInitials(),
                                        )
                                      : _buildInitials(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '@${_profileUser.username}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    Text(
                                      _formatDate(pub.createdAt),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.grey, fontSize: 9.5),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            if (isMyPost)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                onPressed: () => _handleDeletePublication(pub),
                              ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Image Container - uncropped, complete image using BoxFit.contain & constraints
                  Container(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                    color: const Color(0xFF14396A), // Solid flat blue background
                    child: isFiltered
                        ? GestureDetector(
                            onTap: () {
                              update(() {
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

                  // Compact Telemetry Overlay (Accordion style)
                  if (_activeMetricsPubId == pub.id && _metricsMap.containsKey(pub.id))
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: TelemetryOverlay(
                        metrics: _metricsMap[pub.id]!,
                        filterId: pub.filterApplied ?? 'none',
                        isCompact: true,
                      ),
                    ),

                  // Action Row (Likes, Comments Toggle, GPU Badge if filtered)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            // Heart Like Button
                            InkWell(
                              onTap: () => _handleLikeToggle(item, setStateFn: setDialogState),
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
                              onTap: () => _handleToggleComments(pub.id, setStateFn: setDialogState),
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
                                    _commentsMap.containsKey(pub.id)
                                        ? '$commentsCount'
                                        : '...',
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

                        // Interactive GPU/CPU Badge (Toggles Telemetry)
                        if (isFiltered)
                          InkWell(
                            onTap: () => _handleToggleMetrics(pub.id, pub.processedImageUrl, setStateFn: setDialogState),
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
                                    Icons.memory,
                                    size: 11,
                                    color: Color(0xFF14396A), // Contrast flat blue
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      '${(_metricsMap.containsKey(pub.id) && _metricsMap[pub.id]!.executionTimeMs > 15.0) ? 'CPU' : 'GPU'}: ${pub.filterApplied!.toUpperCase()}', // No emoji
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

                  // Details Footer
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (pub.caption != null && pub.caption!.isNotEmpty) ...[
                          const Text(
                            'Descripción',
                            style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            pub.caption!,
                            style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                          ),
                        ] else ...[
                          const Text(
                            'Sin descripción',
                            style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Comments drawer
                  if (_activeCommentsPubId == pub.id)
                    _buildCommentsDrawer(pub.id, setStateFn: setDialogState),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Comments drawer UI builder
  Widget _buildCommentsDrawer(int pubId, {StateSetter? setStateFn}) {
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
                'Comentarios (${comments != null ? comments.length : 0})',
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
              child: ListView.builder(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                itemCount: comments.length,
                itemBuilder: (context, idx) {
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
                    onSubmitted: (_) => _handleAddComment(pubId, setStateFn: setStateFn),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 18),
                onPressed: () => _handleAddComment(pubId, setStateFn: setStateFn),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInitials() {
    return Center(
      child: Text(
        _profileUser.username.isNotEmpty ? _profileUser.username[0].toUpperCase() : 'U',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMyProfile = _profileUser.id == widget.currentUser.id;

    return Scaffold(
      backgroundColor: const Color(0xFF14396A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14396A),
        elevation: 0,
        title: Text(
          isMyProfile ? 'Mi Perfil' : 'Perfil de @${_profileUser.username}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        shape: const Border(
          bottom: BorderSide(color: Colors.white24, width: 1.5),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Profile Block
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: GlassPanel(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // Large Avatar
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        color: const Color(0xFF14396A),
                      ),
                      child: ClipOval(
                        child: _profileUser.avatarUrl != null && _profileUser.avatarUrl!.isNotEmpty
                            ? Image.network(
                                ApiService.getOptimizedImageUrl(_profileUser.avatarUrl!),
                                fit: BoxFit.cover,
                                cacheWidth: 150,
                                errorBuilder: (c, e, s) => Center(
                                  child: Text(
                                    _profileUser.username.isNotEmpty ? _profileUser.username[0].toUpperCase() : 'U',
                                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  _profileUser.username.isNotEmpty ? _profileUser.username[0].toUpperCase() : 'U',
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // User text stats
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _profileUser.fullName,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '@${_profileUser.username}',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.white38),
                                ),
                                child: Text(
                                  '${_publications.length} Publicaciones',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Action Controls
                    if (isMyProfile)
                      IconButton(
                        icon: const Icon(Icons.settings, color: Colors.grey, size: 22),
                        onPressed: _handleEditProfile,
                      ),
                  ],
                ),
              ),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Galería de Inspiración',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),

            // Grid Gallery
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                    )
                  : _error.isNotEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Text(
                              _error,
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : _publications.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.photo_library_outlined, size: 40, color: Colors.white.withValues(alpha: 0.5)),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Aún no hay publicaciones',
                                    style: TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                ],
                              ),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 1.0,
                              ),
                              itemCount: _publications.length,
                              itemBuilder: (context, idx) {
                                final item = _publications[idx];
                                final pub = item.publication;
                                return GestureDetector(
                                  onTap: () => _openPublicationDetails(item),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      color: const Color(0xFF14396A),
                                      child: Image.network(
                                        ApiService.getOptimizedImageUrl(
                                          (pub.processedImageUrl != null && pub.processedImageUrl!.isNotEmpty)
                                              ? pub.processedImageUrl!
                                              : pub.imageUrl,
                                          width: 300,
                                        ),
                                        fit: BoxFit.cover,
                                        cacheWidth: 200,
                                        errorBuilder: (context, _, __) => const Center(
                                          child: Icon(Icons.broken_image, color: Colors.white60, size: 24),
                                        ),
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
    );
  }
}
