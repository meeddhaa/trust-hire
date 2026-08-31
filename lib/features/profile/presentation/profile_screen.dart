import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/session_providers.dart';
import '../../../core/router/main_shell.dart';
import '../../../data/models/subscription.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/models/work_experience_entry.dart';
import '../providers/profile_photo_provider.dart';

/// View profile after onboarding — bio, skills, experience. Account-level
/// actions (sign-out, subscription, appearance, resume) live in the
/// account drawer instead (see `app_drawer.dart`) — kept separate so this
/// screen stays "who you are" and the drawer stays "manage my account."
///
/// Layout follows a centered-identity-card pattern (avatar + name centered
/// up top, a rounded "at a glance" info card below, then content
/// sections) rather than the earlier left-aligned list — set by explicit
/// design reference, not just a preference call.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final profileAsync = ref.watch(currentProfileProvider);
    final subscriptionAsync = ref.watch(currentSubscriptionProvider);

    return Scaffold(
      appBar: AppBar(leading: buildDrawerButton(context), title: const Text('Profile')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (profile) {
          if (profile == null) return const SizedBox.shrink();
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: Column(
              children: [
                _AvatarEditor(profile: profile),
                const SizedBox(height: 16),
                Text(
                  profile.friendlyUsername,
                  style: text.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                if (profile.headline != null) ...[
                  const SizedBox(height: 4),
                  Text(profile.headline!, style: text.bodyLarge, textAlign: TextAlign.center),
                ],
                const SizedBox(height: 12),
                subscriptionAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (subscription) => _TierBadge(subscription: subscription),
                ),
                const SizedBox(height: 24),

                _InfoCard(profile: profile),
                const SizedBox(height: 24),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Work experience', style: text.titleMedium),
                ),
                const SizedBox(height: 10),
                _WorkExperienceSection(profile: profile),
                const SizedBox(height: 24),

                if (profile.skills.isNotEmpty) ...[
                  Align(alignment: Alignment.centerLeft, child: Text('Skills', style: text.titleMedium)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [for (final skill in profile.skills) Chip(label: Text(skill))],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The "at a glance" rounded card — icon-in-circle rows for experience,
/// education, and email, echoing the reference's Phone/Email/Address
/// pattern. Headline already renders above the avatar as a subtitle, so
/// it isn't repeated here.
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = <_InfoRowData>[
      if (profile.yearsOfExperience != null)
        _InfoRowData(Icons.schedule_outlined, 'Experience', '${profile.yearsOfExperience} years'),
      if (profile.educationLevel != null)
        _InfoRowData(Icons.school_outlined, 'Education', profile.educationLevel!),
      _InfoRowData(Icons.mail_outline, 'Email', profile.email),
    ];

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _InfoRow(data: rows[i]),
            if (i != rows.length - 1) Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
          ],
        ],
      ),
    );
  }
}

class _InfoRowData {
  const _InfoRowData(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.data});

  final _InfoRowData data;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: scheme.primary.withValues(alpha: 0.12),
            child: Icon(data.icon, size: 17, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.label.toUpperCase(),
                  style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 0.4),
                ),
                const SizedBox(height: 2),
                Text(data.value, style: text.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Work history pulled from the resume upload (see `ResumeController`,
/// which asks Gemini to extract it alongside skills). Empty states are
/// deliberately different depending on *why* it's empty — no resume at
/// all vs. a resume with no parseable work-history section — so the user
/// isn't left guessing which is true.
class _WorkExperienceSection extends StatelessWidget {
  const _WorkExperienceSection({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    if (profile.workExperience.isEmpty) {
      final message = profile.resumeBase64 == null
          ? 'Upload a resume in Settings → Resume to pull your work history in automatically.'
          : "Your resume didn't have a work-history section we could read — nothing to show yet.";
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(message, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
      );
    }

    return Column(
      children: [
        for (final entry in profile.workExperience)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _WorkExperienceCard(entry: entry),
          ),
      ],
    );
  }
}

class _WorkExperienceCard extends StatelessWidget {
  const _WorkExperienceCard({required this.entry});

  final WorkExperienceEntry entry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: scheme.primary.withValues(alpha: 0.12),
            child: Icon(Icons.work_outline, size: 18, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title, style: text.titleSmall),
                const SizedBox(height: 2),
                Text(entry.company, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                if (entry.duration.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    entry.duration,
                    style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarEditor extends ConsumerWidget {
  const _AvatarEditor({required this.profile});

  final UserProfile profile;

  Future<void> _showOptions(BuildContext context, WidgetRef ref) async {
    final hasPhoto = profile.photoBase64 != null;
    final action = await showModalBottomSheet<_AvatarAction>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: Text(hasPhoto ? 'Replace photo' : 'Upload photo'),
              onTap: () => Navigator.pop(sheetContext, _AvatarAction.upload),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove photo'),
                onTap: () => Navigator.pop(sheetContext, _AvatarAction.remove),
              ),
          ],
        ),
      ),
    );

    final controller = ref.read(profilePhotoControllerProvider.notifier);
    switch (action) {
      case _AvatarAction.upload:
        await controller.pickAndUpload();
      case _AvatarAction.remove:
        await controller.removePhoto();
      case null:
        break;
    }

    final error = ref.read(profilePhotoControllerProvider).error;
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error is FormatException ? error.message : 'Couldn\'t update your photo — try again.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final photoState = ref.watch(profilePhotoControllerProvider);
    final isBusy = photoState.isLoading;
    final photoBase64 = profile.photoBase64;

    return Stack(
      children: [
        CircleAvatar(
          radius: 44,
          backgroundColor: scheme.surfaceContainerHighest,
          backgroundImage: photoBase64 != null ? MemoryImage(base64Decode(photoBase64)) : null,
          child: isBusy
              ? const CircularProgressIndicator(strokeWidth: 2)
              : photoBase64 == null
                  ? Icon(Icons.person_outline, size: 40, color: scheme.onSurfaceVariant)
                  : null,
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Material(
            color: scheme.primary,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: isBusy ? null : () => _showOptions(context, ref),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.camera_alt_outlined, size: 16, color: scheme.onPrimary),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _AvatarAction { upload, remove }

class _TierBadge extends StatelessWidget {
  const _TierBadge({required this.subscription});

  final Subscription subscription;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPaid = subscription.isPaid;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isPaid ? scheme.primary.withValues(alpha: 0.12) : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isPaid ? scheme.primary : scheme.outline),
      ),
      child: Text(
        isPaid ? 'TrustHire Plus' : 'Free plan',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: isPaid ? scheme.primary : scheme.onSurfaceVariant,
            ),
      ),
    );
  }
}
