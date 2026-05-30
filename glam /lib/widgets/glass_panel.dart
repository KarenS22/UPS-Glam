import 'package:flutter/material.dart';

class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Border? border;
  final Color? backgroundColor;
  final double? width;
  final double? height;
  final List<BoxShadow>? boxShadow;
  final bool enableBlur;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 16,
    this.border,
    this.backgroundColor,
    this.width,
    this.height,
    this.boxShadow,
    this.enableBlur = false, // Disabled for flat design
  });

  @override
  Widget build(BuildContext context) {
    // Force solid flat blue #14396A and white border for a beautiful flat dual-tone design
    final panelBorder = border ?? Border.all(color: Colors.white, width: 1.5);

    final panelBgColor =
        backgroundColor ?? const Color(0xFF14396A);

    return Container(
      width: width,
      height: height,
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: panelBgColor,
        border: panelBorder,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: child,
    );
  }
}
