import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/failure.dart';
import '../../../core/providers/session_providers.dart';
import '../../../data/resume_templates.dart';
import '../../../shared/widgets/expandable_section.dart';
import '../providers/resume_providers.dart';

/// Upload/replace/remove a resume PDF, plus a written template for anyone
/// who doesn't have one yet. Stored as a base64 field directly on the
/// profile doc, not a separate file store — see "Decision: resume
/// storage, twice reconsidered" in docs/ARCHITECTURE.md (both Firebase
/// Storage and Cloudflare R2 need a billing card on file, even at $0
/// actual cost, which wasn't available).
class ResumeScreen extends ConsumerWidget {
  const ResumeScreen({super.key});

  /// Firestore caps a whole document at 1MiB, and base64 inflates raw
  /// bytes by ~4/3 — 700KB raw leaves comfortable headroom (≈933KB
  /// encoded) for the rest of the profile doc's fields.
  static const _maxResumeBytes = 700 * 1024;

  Future<void> _pickAndUpload(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    final file = result?.files.singleOrNull;
    if (file == null || file.bytes == null) return;

    if (file.size > _maxResumeBytes) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('That file is over the 700KB limit — try a text-based PDF export.')));
      }
      return;
    }

    final addedSkills = await ref.read(resumeControllerProvider.notifier).uploadResume(file.bytes!);
    if (!context.mounted || addedSkills.isEmpty) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            addedSkills.length == 1
                ? 'Resume uploaded — added "${addedSkills.first}" to your skills.'
                : 'Resume uploaded — added ${addedSkills.length} skills: ${addedSkills.join(', ')}.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final profileAsync = ref.watch(currentProfileProvider);
    final controllerState = ref.watch(resumeControllerProvider);
    final isBusy = controllerState.isLoading;

    ref.listen(resumeControllerProvider, (previous, next) {
      final error = next.error;
      if (error != null) {
        final message = error is Failure ? error.message : 'Something went wrong — please try again.';
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Resume')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Uploading a resume automatically pulls skills from it into your profile, '
            'and lets match scoring and tailoring suggestions on a listing draw on your '
            'actual experience, not just what you typed in.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 20),
          profileAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text(error.toString(), style: text.bodyMedium),
            data: (profile) {
              final hasResume = profile?.resumeBase64 != null;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        hasResume ? Icons.description : Icons.description_outlined,
                        color: hasResume ? Theme.of(context).colorScheme.primary : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          hasResume ? 'Resume on file' : 'No resume uploaded yet',
                          style: text.titleSmall,
                        ),
                      ),
                      if (isBusy)
                        const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      else if (hasResume)
                        TextButton(
                          onPressed: () => ref.read(resumeControllerProvider.notifier).deleteResume(),
                          child: const Text('Remove'),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: isBusy ? null : () => _pickAndUpload(context, ref),
            icon: const Icon(Icons.upload_file_outlined),
            label: Text(
              profileAsync.value?.resumeBase64 != null ? 'Replace resume (PDF)' : 'Upload resume (PDF)',
            ),
          ),
          const SizedBox(height: 32),

          Text("Don't have a resume yet?", style: text.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Five ATS-friendly structures to write your own from — not live editing, '
            'just a section-by-section guide for each.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 12),
          for (final template in resumeTemplates)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ResumeTemplateCard(template: template),
            ),
        ],
      ),
    );
  }
}

class _ResumeTemplateCard extends StatelessWidget {
  const _ResumeTemplateCard({required this.template});

  final ResumeTemplate template;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ExpandableSection(
          title: template.name,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(template.description, style: text.bodyMedium),
              const SizedBox(height: 4),
              Text('Best for: ${template.bestFor}', style: text.bodySmall?.copyWith(color: muted)),
              const SizedBox(height: 14),
              for (final (title, guidance) in template.sections)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: text.labelLarge),
                      const SizedBox(height: 3),
                      Text(guidance, style: text.bodyMedium),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
