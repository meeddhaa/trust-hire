import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/failure.dart';
import '../../../core/providers/session_providers.dart';
import '../../../core/theme/risk_colors.dart';
import '../../../data/models/resume.dart';
import '../../../data/resume_templates.dart';
import '../../../shared/widgets/expandable_section.dart';
import '../providers/resume_providers.dart';

/// "My Resumes" — multiple named versions (e.g. "AI/LLM Resume", "General
/// Resume"), exactly one active at a time (see `Resume`'s doc comment for
/// what "active" means), plus a written template for anyone who doesn't
/// have one yet. Each stored as a base64 field on its own subcollection
/// doc, not a separate file store — see "Decision: resume storage, twice
/// reconsidered" in docs/ARCHITECTURE.md (both Firebase Storage and
/// Cloudflare R2 need a billing card on file, even at $0 actual cost,
/// which wasn't available).
class ResumeScreen extends ConsumerWidget {
  const ResumeScreen({super.key});

  /// Firestore caps a whole document at 1MiB, and base64 inflates raw
  /// bytes by ~4/3 — 700KB raw leaves comfortable headroom (≈933KB
  /// encoded) for the rest of the profile doc's fields.
  static const _maxResumeBytes = 700 * 1024;

  Future<void> _pickAndAdd(BuildContext context, WidgetRef ref, {required int existingCount}) async {
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

    if (!context.mounted) return;
    final defaultName = existingCount == 0 ? 'My Resume' : 'Resume ${existingCount + 1}';
    final name = await _promptForName(context, title: 'Name this resume', initialValue: defaultName);
    if (name == null || !context.mounted) return;

    final addedSkills = await ref.read(resumeControllerProvider.notifier).addResume(name: name, bytes: file.bytes!);
    if (!context.mounted || addedSkills.isEmpty) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            addedSkills.length == 1
                ? '"$name" added and active — added "${addedSkills.first}" to your skills.'
                : '"$name" added and active — added ${addedSkills.length} skills: ${addedSkills.join(', ')}.',
          ),
        ),
      );
  }

  Future<void> _setActive(BuildContext context, WidgetRef ref, Resume resume) async {
    final addedSkills = await ref.read(resumeControllerProvider.notifier).setActiveResume(resume.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            addedSkills.isEmpty
                ? '"${resume.name}" is now active.'
                : '"${resume.name}" is now active — added ${addedSkills.length} skill${addedSkills.length == 1 ? '' : 's'}.',
          ),
        ),
      );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, Resume resume) async {
    final name = await _promptForName(context, title: 'Rename resume', initialValue: resume.name);
    if (name == null || name == resume.name) return;
    await ref.read(resumeControllerProvider.notifier).renameResume(resume.id, name);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Resume resume) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this resume?'),
        content: Text('"${resume.name}" will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(resumeControllerProvider.notifier).deleteResume(resume.id, wasActive: resume.isActive);
  }

  Future<void> _syncSkills(BuildContext context, WidgetRef ref) async {
    final addedSkills = await ref.read(resumeControllerProvider.notifier).syncSkills();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            addedSkills.isEmpty
                ? 'Your profile is already up to date with this resume.'
                : addedSkills.length == 1
                    ? 'Synced — added "${addedSkills.first}" to your skills.'
                    : 'Synced — added ${addedSkills.length} skills: ${addedSkills.join(', ')}.',
          ),
        ),
      );
  }

  static Future<String?> _promptForName(BuildContext context, {required String title, required String initialValue}) {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. "AI/LLM Resume"'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final value = controller.text.trim();
              Navigator.pop(dialogContext, value.isEmpty ? initialValue : value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final resumesAsync = ref.watch(resumesStreamProvider);
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

    // One-time backfill: a resume uploaded before "My Resumes" existed
    // lives only in `profile.resumeBase64` — see `ResumeController.
    // migrateLegacyResume`'s doc comment for why this check (rather than
    // e.g. a server-side migration script) is the right place for it.
    ref.listen(resumesStreamProvider, (previous, next) {
      final resumes = next.valueOrNull;
      final legacyBase64 = ref.read(currentProfileProvider).valueOrNull?.resumeBase64;
      if (resumes != null && resumes.isEmpty && legacyBase64 != null) {
        ref.read(resumeControllerProvider.notifier).migrateLegacyResume(legacyBase64);
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
            'actual experience, not just what you typed in. Keep a few named versions and '
            'switch which one is active for a given search.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 20),
          Text('My Resumes', style: text.titleMedium),
          const SizedBox(height: 10),
          resumesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text(error.toString(), style: text.bodyMedium),
            data: (resumes) {
              if (resumes.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No resumes yet — add one below.',
                      style: text.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (final resume in resumes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ResumeRow(
                        resume: resume,
                        busy: isBusy,
                        onSetActive: () => _setActive(context, ref, resume),
                        onRename: () => _rename(context, ref, resume),
                        onDelete: () => _delete(context, ref, resume),
                        onSyncAgain: () => _syncSkills(context, ref),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: isBusy
                ? null
                : () => _pickAndAdd(context, ref, existingCount: resumesAsync.valueOrNull?.length ?? 0),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add resume (PDF)'),
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

class _ResumeRow extends StatelessWidget {
  const _ResumeRow({
    required this.resume,
    required this.busy,
    required this.onSetActive,
    required this.onRename,
    required this.onDelete,
    required this.onSyncAgain,
  });

  final Resume resume;
  final bool busy;
  final VoidCallback onSetActive;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onSyncAgain;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final risk = Theme.of(context).extension<RiskColors>()!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  resume.isActive ? Icons.description : Icons.description_outlined,
                  color: resume.isActive ? scheme.primary : null,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(resume.name, style: text.titleSmall)),
                PopupMenuButton<String>(
                  enabled: !busy,
                  onSelected: (value) {
                    switch (value) {
                      case 'rename':
                        onRename();
                      case 'delete':
                        onDelete();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(value: 'delete', child: Text('Remove')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (resume.isActive)
              Row(
                children: [
                  Icon(Icons.check_circle, size: 15, color: risk.verifiedLeaning),
                  const SizedBox(width: 6),
                  Text('Active — synced to profile', style: text.labelMedium?.copyWith(color: risk.verifiedLeaning)),
                  const Spacer(),
                  if (busy)
                    const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    TextButton.icon(
                      onPressed: onSyncAgain,
                      icon: const Icon(Icons.sync, size: 16),
                      label: const Text('Sync again'),
                    ),
                ],
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: busy ? null : onSetActive,
                  child: const Text('Set as active'),
                ),
              ),
          ],
        ),
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
