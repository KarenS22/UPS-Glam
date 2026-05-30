import 'package:flutter/material.dart';

class SliderCompare extends StatefulWidget {
  final String original;
  final String filtered;
  final double aspectRatio;
  final int? cacheWidth;

  const SliderCompare({
    super.key,
    required this.original,
    required this.filtered,
    this.aspectRatio = 1.0,
    this.cacheWidth,
  });

  @override
  State<SliderCompare> createState() => _SliderCompareState();
}

class _SliderCompareState extends State<SliderCompare> {
  double _sliderPos = 0.5; // ranges from 0.0 to 1.0
  double? _resolvedAspectRatio;
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;

  @override
  void initState() {
    super.initState();
    _resolveAspectRatio();
  }

  @override
  void didUpdateWidget(covariant SliderCompare oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.original != widget.original) {
      _resolveAspectRatio();
    }
  }

  @override
  void dispose() {
    _cleanupListener();
    super.dispose();
  }

  void _cleanupListener() {
    if (_imageStream != null && _imageListener != null) {
      _imageStream!.removeListener(_imageListener!);
    }
  }

  void _resolveAspectRatio() {
    _cleanupListener();
    if (widget.original.isEmpty) return;

    try {
      final ImageProvider provider = Image.network(widget.original).image;
      _imageStream = provider.resolve(ImageConfiguration.empty);
      _imageListener = ImageStreamListener(
        (ImageInfo info, bool synchronousCall) {
          if (mounted) {
            setState(() {
              _resolvedAspectRatio = info.image.width / info.image.height;
            });
          }
        },
        onError: (exception, stackTrace) {
          // Fallback gracefully on error
        },
      );
      _imageStream!.addListener(_imageListener!);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // Clamp the aspect ratio between 0.8 (portrait) and 1.8 (landscape) to maintain a gorgeous feed layout.
    final double rawAspectRatio = _resolvedAspectRatio ?? widget.aspectRatio;
    final double finalAspectRatio = rawAspectRatio.clamp(0.8, 1.8);

    return AspectRatio(
      aspectRatio: finalAspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double width = constraints.maxWidth;
            final double height = constraints.maxHeight;

            return GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _sliderPos = (details.localPosition.dx / width).clamp(0.0, 1.0);
                });
              },
              child: Stack(
                children: [
                  // 1. Background Image: Original Image (takes full size)
                  Positioned.fill(
                    child: _buildImage(widget.original),
                  ),

                  // 2. Foreground Image: Processed Filtered Image (clipped horizontally)
                  // Align widthFactor clips the Align widget, but keep the inner image the full width.
                  // This keeps the image stationary while scrubbing.
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      widthFactor: _sliderPos,
                      child: SizedBox(
                        width: width,
                        height: height,
                        child: _buildImage(widget.filtered),
                      ),
                    ),
                  ),

                  // 3. Slider Divider Line
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: (_sliderPos * width) - 1.5,
                    child: Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 4. Glowing Handle Button (in the center of the divider)
                  Positioned(
                    top: (height / 2) - 18,
                    left: (_sliderPos * width) - 18,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                          BoxShadow(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.swap_horiz,
                          color: Color(0xFF8B5CF6), // --accent-violet
                          size: 20,
                        ),
                      ),
                    ),
                  ),

                  // 5. "ORIGINAL" Helper Badge
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: const Text(
                        'ORIGINAL',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),

                  // 6. "FILTRADA" Helper Badge
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: const Text(
                        'FILTRADA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // Network Image builder with loading and error states
  Widget _buildImage(String url) {
    if (url.isEmpty) {
      return Container(
        color: const Color(0xFF040407),
        child: const Center(
          child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
        ),
      );
    }
    
    return Image.network(
      url,
      fit: BoxFit.contain,
      cacheWidth: widget.cacheWidth,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: const Color(0xFF040407),
          child: Center(
            child: SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: const Color(0xFF040407),
          child: const Center(
            child: Icon(Icons.broken_image, color: Colors.grey, size: 30),
          ),
        );
      },
    );
  }
}
