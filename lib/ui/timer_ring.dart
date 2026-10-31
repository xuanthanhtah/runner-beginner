import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Circular countdown ring that depletes as the interval elapses.
class TimerRing extends StatelessWidget {
  const TimerRing({
    super.key,
    required this.progress,
    required this.color,
    required this.child,
    this.strokeWidth = 16,
  });

  /// Elapsed fraction of the interval, 0.0 → 1.0.
  final double progress;
  final Color color;
  final double strokeWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RingPainter(
        remaining: (1 - progress).clamp(0.0, 1.0),
        color: color,
        strokeWidth: strokeWidth,
      ),
      child: Center(child: child),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.remaining,
    required this.color,
    required this.strokeWidth,
  });

  final double remaining;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect =
        Offset(strokeWidth / 2, strokeWidth / 2) &
        Size(size.width - strokeWidth, size.height - strokeWidth);

    final track = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * remaining, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.remaining != remaining ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}
