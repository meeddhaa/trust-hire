import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_motion.dart';

/// The match-score visual centerpiece: a radial arc that draws in with a
/// digit count-up, per the confirmed "Editorial Trust" motion language —
/// not a static percentage number. Promoted from the design-direction
/// preview (`theme_preview_page.dart`) into a real, reusable widget once
/// screens started consuming it (listing card + listing detail).
class MatchScoreDial extends StatelessWidget {
  const MatchScoreDial({super.key, required this.matchPercent, this.size = 160, this.strokeWidth = 10});

  /// 0–100.
  final int matchPercent;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final track = Theme.of(context).colorScheme.outline;
    final textStyle = size >= 120
        ? Theme.of(context).textTheme.displaySmall
        : Theme.of(context).textTheme.headlineMedium;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: matchPercent / 100),
      duration: AppMotion.scoreReveal,
      curve: AppMotion.arc,
      builder: (context, value, _) {
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.square(size),
                painter: _ArcPainter(progress: value, color: accent, track: track, strokeWidth: strokeWidth),
              ),
              Text('${(value * 100).round()}%', style: textStyle),
            ],
          ),
        );
      },
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({required this.progress, required this.color, required this.track, required this.strokeWidth});

  final double progress;
  final Color color;
  final Color track;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final center = rect.center;
    final radius = (size.shortestSide - strokeWidth) / 2;
    canvas.drawCircle(center, radius, trackPaint);

    const startAngle = -math.pi / 2;
    final sweep = 2 * math.pi * progress;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweep, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
