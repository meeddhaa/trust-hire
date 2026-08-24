import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_motion.dart';

/// Shared empty/error-state layout — icon, title, message, optional
/// retry action — so the feed's "no listings", a load failure, and any
/// future empty list all get the same considered treatment instead of a
/// bare "No data" text, per the brief's call-out that empty/loading states
/// are usually where template apps show their seams.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: muted),
            const SizedBox(height: 16),
            Text(title, style: text.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(message, style: text.bodyMedium, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ).animate().fadeIn(duration: AppMotion.standard).slideY(begin: 0.05, end: 0, curve: AppMotion.settle),
      ),
    );
  }
}
