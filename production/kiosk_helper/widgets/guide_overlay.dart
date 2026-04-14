import 'package:flutter/material.dart';
import '../models/scan_result.dart';

/// 카메라 프리뷰 위에 가이드 오버레이를 그리는 위젯
///
/// - 매칭된 텍스트 위치에 빨간 박스 + 테두리
/// - "여기를 누르세요" 라벨
/// - 펄스 애니메이션으로 시선 유도
/// - 여러 매칭 결과를 번호와 함께 표시
class GuideOverlay extends StatefulWidget {
  final List<ScanResult> scanResults; // 여러 키워드 결과
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
    return AnimatedBuilder(
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
    );
  }
}

class _GuidePainter extends CustomPainter {
  final List<ScanResult> scanResults;
  final Size previewSize;
  final double pulseScale;

  // 결과별 색상
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
        _drawLabel(canvas, rect, result.userQuery, color, colorIndex + 1);
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

    // 화살표
    final arrowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final arrowTip = Offset(center.dx, rect.top - 10);
    final path = Path()
      ..moveTo(arrowTip.dx, arrowTip.dy)
      ..lineTo(arrowTip.dx - 12, arrowTip.dy - 24)
      ..lineTo(arrowTip.dx + 12, arrowTip.dy - 24)
      ..close();
    canvas.drawPath(path, arrowPaint);
  }

  void _drawLabel(Canvas canvas, Rect rect, String query, Color color, int number) {
    final labelText = '❶②③④⑤'.length > number
        ? '👆 $number. $query'
        : '👆 $query';

    final textSpan = TextSpan(
      text: labelText,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
        shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final labelRect = Rect.fromLTWH(
      rect.center.dx - textPainter.width / 2 - 12,
      rect.top - 65,
      textPainter.width + 24,
      textPainter.height + 12,
    );

    final bgPaint = Paint()
      ..color = color.withOpacity(0.85)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(8)),
      bgPaint,
    );

    textPainter.paint(
      canvas,
      Offset(labelRect.left + 12, labelRect.top + 6),
    );
  }

  @override
  bool shouldRepaint(covariant _GuidePainter oldDelegate) {
    return oldDelegate.pulseScale != pulseScale ||
        oldDelegate.scanResults != scanResults;
  }
}
