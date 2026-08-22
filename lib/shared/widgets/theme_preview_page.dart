import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/risk_colors.dart';

/// TEMPORARY dev-only screen — not one of TrustHire's product screens.
///
/// Exists purely so the confirmed "Editorial Trust" palette, type scale,
/// and motion language (score-arc reveal, badge stamp reveal) can be run
/// and eyeballed on a device before any real screens are built (build-order
/// step 4). Delete this file and swap the router's `/` route for the real
/// listings feed once onboarding/feed screens land.
class ThemePreviewPage extends StatelessWidget {
  const ThemePreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final risk = Theme.of(context).extension<RiskColors>()!;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('TrustHire — theme preview')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Editorial Trust', style: text.headlineLarge),
          const SizedBox(height: 4),
          Text(
            'Design-system preview — palette, type, motion.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 28),

          Text('Match score reveal', style: text.titleMedium),
          const SizedBox(height: 12),
          const Center(child: _MatchScoreDial(score: 0.78)),
          const SizedBox(height: 28),

          Text('Trust badge reveal', style: text.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _TrustBadgePreview(
                label: 'Verified-leaning',
                fg: risk.verifiedLeaning,
                bg: risk.verifiedLeaningBg,
                delay: Duration.zero,
              ),
              _TrustBadgePreview(
                label: 'Caution',
                fg: risk.caution,
                bg: risk.cautionBg,
                delay: const Duration(milliseconds: 120),
              ),
              _TrustBadgePreview(
                label: 'High Risk',
                fg: risk.highRisk,
                bg: risk.highRiskBg,
                delay: const Duration(milliseconds: 240),
              ),
            ],
          ),
          const SizedBox(height: 28),

          Text('Palette', style: text.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _Swatch('Paper bg', AppColors.paperBg),
              _Swatch('Paper ink', AppColors.paperInk),
              _Swatch('Accent', AppColors.accent),
              _Swatch('Verified', AppColors.verifiedLeaning),
              _Swatch('Caution', AppColors.caution),
              _Swatch('High risk', AppColors.highRisk),
            ],
          ),
          const SizedBox(height: 28),

          Text('Type scale', style: text.titleMedium),
          const SizedBox(height: 12),
          Text('72% match', style: text.displayMedium),
          Text('Strong match on core skills', style: text.headlineSmall),
          Text('Card title / list item', style: text.titleLarge),
          Text(
            'Body copy — reasoning strings, gap breakdowns, and listing '
            'descriptions all read in Manrope for legibility at small sizes.',
            style: text.bodyMedium,
          ),
          Text('LABEL / TAG TEXT', style: text.labelMedium),
        ],
      ),
    );
  }
}

/// Radial arc draw + digit count-up, per the confirmed motion language.
class _MatchScoreDial extends StatelessWidget {
  const _MatchScoreDial({required this.score});

  final double score; // 0..1

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final track = Theme.of(context).colorScheme.outline;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: score),
      duration: AppMotion.scoreReveal,
      curve: AppMotion.arc,
      builder: (context, value, _) {
        return SizedBox(
          width: 160,
          height: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size.square(160),
                painter: _ArcPainter(progress: value, color: accent, track: track),
              ),
              Text(
                '${(value * 100).round()}%',
                style: Theme.of(context).textTheme.displaySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({required this.progress, required this.color, required this.track});

  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final strokeWidth = 10.0;
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
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweep,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

/// Hold-then-stamp reveal for a trust badge.
class _TrustBadgePreview extends StatelessWidget {
  const _TrustBadgePreview({
    required this.label,
    required this.fg,
    required this.bg,
    required this.delay,
  });

  final String label;
  final Color fg;
  final Color bg;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: fg),
      ),
    )
        .animate(delay: AppMotion.badgeHold + delay)
        .scaleXY(
          begin: 0.7,
          end: 1.0,
          duration: AppMotion.badgeReveal,
          curve: AppMotion.stamp,
        )
        .fadeIn(duration: AppMotion.fast);
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
