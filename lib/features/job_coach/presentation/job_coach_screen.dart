import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/failure.dart';
import '../../../core/router/main_shell.dart';
import '../providers/job_coach_providers.dart';

/// Single entry point for all Gemini-powered career help — presented as
/// "Job Coach," never as "Gemini" or a generic chat (see
/// docs/ARCHITECTURE.md → "Decision: Job Coach"). One underlying system:
/// tapping an intent card or typing a question both call the same
/// Worker endpoint, just with a different `intent`/`question` — no
/// separate assistant per feature.
///
/// [listingId] is set when opened contextually (e.g. from a listing's
/// "Get Job Coach advice" button) so intents like "analyze this job" have
/// something to analyze; `null` for the standalone Job Coach tab.
class JobCoachScreen extends ConsumerStatefulWidget {
  const JobCoachScreen({super.key, this.listingId});

  final String? listingId;

  @override
  ConsumerState<JobCoachScreen> createState() => _JobCoachScreenState();
}

class _JobCoachScreenState extends ConsumerState<JobCoachScreen> {
  final _questionController = TextEditingController();

  static const _intents = [
    ('improve_resume', 'Improve my resume', Icons.description_outlined),
    ('analyze_job', 'Analyze this job', Icons.fact_check_outlined),
    ('interview_prep', 'Prepare for an interview', Icons.forum_outlined),
    ('skill_gaps', 'Identify my skill gaps', Icons.trending_up_rounded),
    ('career_guidance', 'Career direction', Icons.explore_outlined),
  ];

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  void _ask({required String intent, String? question}) {
    ref.read(jobCoachControllerProvider.notifier).ask(
          intent: intent,
          listingId: widget.listingId,
          question: question,
        );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final state = ref.watch(jobCoachControllerProvider);

    ref.listen(jobCoachControllerProvider, (previous, next) {
      final error = next.error;
      if (error == null) return;
      final message = error is Failure ? error.message : 'Something went wrong — please try again.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    });

    return Scaffold(
      appBar: AppBar(
        // Drawer icon on the standalone tab; default back-button behavior
        // when pushed with listing context from elsewhere.
        leading: widget.listingId == null ? buildDrawerButton(context) : null,
        title: const Text('Job Coach'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text('What do you need help with?', style: text.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    widget.listingId != null
                        ? "I'll use this listing's details in my answer."
                        : 'Career-focused help only — resumes, job fit, interviews, skills, and strategy.',
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (intent, label, icon) in _intents)
                        ActionChip(
                          avatar: Icon(icon, size: 16),
                          label: Text(label),
                          onPressed: state.isLoading ? null : () => _ask(intent: intent),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  state.when(
                    data: (result) {
                      if (result == null) return const SizedBox.shrink();
                      return _JobCoachAnswer(
                        answer: result.answer,
                        followUps: result.followUpSuggestions,
                        onFollowUp: (question) => _ask(intent: 'custom', question: question),
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _questionController,
                        decoration: const InputDecoration(hintText: 'Ask your Job Coach…'),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (value) {
                          if (value.trim().isEmpty) return;
                          _ask(intent: 'custom', question: value.trim());
                          _questionController.clear();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      icon: const Icon(Icons.send_rounded),
                      onPressed: state.isLoading
                          ? null
                          : () {
                              final value = _questionController.text.trim();
                              if (value.isEmpty) return;
                              _ask(intent: 'custom', question: value);
                              _questionController.clear();
                            },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JobCoachAnswer extends StatelessWidget {
  const _JobCoachAnswer({required this.answer, required this.followUps, required this.onFollowUp});

  final String answer;
  final List<String> followUps;
  final ValueChanged<String> onFollowUp;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(answer, style: text.bodyLarge),
            if (followUps.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Ask next', style: text.labelMedium),
              const SizedBox(height: 8),
              // A vertical list of full-width rows, not a Wrap of Chips —
              // Chip is built for short tags, and clips its label at its
              // own shape boundary with no wrap/ellipsis once the text is
              // long. Follow-up suggestions are full questions, so they
              // need a widget that actually wraps multi-line text (caught
              // live: the reference's real follow-ups clipped mid-word
              // with a Wrap of ActionChips).
              for (final followUp in followUps)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _FollowUpRow(question: followUp, onTap: () => onFollowUp(followUp)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FollowUpRow extends StatelessWidget {
  const _FollowUpRow({required this.question, required this.onTap});

  final String question;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(question, style: text.bodyMedium)),
              const SizedBox(width: 8),
              Icon(Icons.arrow_outward_rounded, size: 16, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
