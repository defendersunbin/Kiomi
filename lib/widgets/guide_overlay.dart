import 'package:flutter/material.dart';
import '../models/scan_result.dart';

/// 카메라 프리뷰 위에 가이드 오버레이를 그리는 위젯
class GuideOverlay extends StatefulWidget {
  final List<ScanResult> scanResults;
  final Size previewSize;

  const GuideOverlay({
    super.key,
    required this.scanResults,
    required this.previewSize,
  });

  @override
  State<GuideOverlay> createState() => _GuideOverlayState();
}

class _GuideOverlayState extends State<GuideOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return CustomPaint(
            size: widget.previewSize,
            painter: _GuidePainter(
              scanResults: widget.scanResults,
              previewSize: widget.previewSize,
              pulseScale: _pulseAnimation.value,
            ),
          );
        },
      ),
    );
  }
}

class _GuidePainter extends CustomPainter {
  final List<ScanResult> scanResults;
  final Size previewSize;
  final double pulseScale;

  static const _colors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
  ];

  _GuidePainter({
    required this.scanResults,
    required this.previewSize,
    required this.pulseScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    int colorIndex = 0;

    for (final result in scanResults) {
      if (!result.hasMatch) continue;

      final color = _colors[colorIndex % _colors.length];
      final scaleX = previewSize.width / result.imageWidth;
      final scaleY = previewSize.height / result.imageHeight;

      for (final block in result.matchedBlocks) {
        final rect = Rect.fromLTRB(
          block.boundingBox.left * scaleX,
          block.boundingBox.top * scaleY,
          block.boundingBox.right * scaleX,
          block.boundingBox.bottom * scaleY,
        );

        _drawHighlight(canvas, rect, color);
      }
      colorIndex++;
    }
  }

  void _drawHighlight(Canvas canvas, Rect rect, Color color) {
    final center = rect.center;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = color.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    final scaledRect = Rect.fromCenter(
      center: center,
      width: rect.width + 24 * pulseScale,
      height: rect.height + 20 * pulseScale,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(scaledRect, const Radius.circular(12)),
      fillPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(scaledRect, const Radius.circular(12)),
      strokePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GuidePainter oldDelegate) {
    return oldDelegate.pulseScale != pulseScale ||
        oldDelegate.scanResults != scanResults;
  }
}
