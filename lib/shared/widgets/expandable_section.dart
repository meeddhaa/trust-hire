import 'package:flutter/material.dart';
import '../../core/theme/app_motion.dart';

/// The gap breakdown "expands/interacts rather than just being static
/// text underneath" (per the brief) — an accordion, not a modal, so it
/// stays in the flow of the page. A small custom widget instead of
/// [ExpansionTile] so the header/chevron match "Editorial Trust" exactly
/// rather than Material's default expansion-tile chrome.
class ExpandableSection extends StatefulWidget {
  const ExpandableSection({
    super.key,
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
  });

  final String title;
  final Widget child;
  final bool initiallyExpanded;

  @override
  State<ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<ExpandableSection> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(child: Text(widget.title, style: text.titleMedium)),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: AppMotion.fast,
                  curve: AppMotion.settle,
                  child: const Icon(Icons.keyboard_arrow_down_rounded),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: AppMotion.standard,
          curve: AppMotion.settle,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Padding(padding: const EdgeInsets.only(top: 4, bottom: 8), child: widget.child)
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
