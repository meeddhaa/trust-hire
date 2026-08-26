import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/failure.dart';
import '../../../core/providers/theme_mode_provider.dart';
import '../providers/account_providers.dart';
import '../providers/profile_visibility_provider.dart';

/// "How the app behaves for you" — appearance, account, privacy. Resume
/// and Subscription used to have quick-link cards here too; both are now
/// their own drawer destinations instead (see `app_drawer.dart`), so
/// they're not duplicated in this list.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This permanently deletes your profile, resume, saved jobs, and application '
          'tracking. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(accountControllerProvider.notifier).deleteAccount();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final themeMode = ref.watch(themeModeProvider);
    final visibility = ref.watch(profileVisibilityProvider);
    final accountState = ref.watch(accountControllerProvider);

    ref.listen(accountControllerProvider, (previous, next) {
      final error = next.error;
      if (error == null) return;
      final message = error is Failure ? error.message : 'Something went wrong — please try again.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('App settings', style: text.titleMedium),
          const SizedBox(height: 10),
          Text('Appearance', style: text.labelMedium),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined)),
              ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto_outlined)),
            ],
            selected: {themeMode},
            onSelectionChanged: (selection) {
              ref.read(themeModeProvider.notifier).setThemeMode(selection.first);
            },
          ),
          const SizedBox(height: 28),

          Text('Privacy & visibility', style: text.titleMedium),
          const SizedBox(height: 4),
          Text(
            // Honest about what this actually does today — see
            // profile_visibility_provider.dart's doc comment.
            'Nothing currently shows your profile to anyone else (no employer accounts '
            'exist yet), so this has nothing to enforce yet — it just saves your '
            'preference for when that exists.',
            style: text.bodySmall,
          ),
          const SizedBox(height: 10),
          Card(
            child: RadioGroup<ProfileVisibility>(
              groupValue: visibility,
              onChanged: (value) => ref.read(profileVisibilityProvider.notifier).setVisibility(value!),
              child: const Column(
                children: [
                  RadioListTile<ProfileVisibility>(
                    title: Text('Public'),
                    subtitle: Text('Your profile can be discovered by employers/recruiters.'),
                    value: ProfileVisibility.public,
                  ),
                  RadioListTile<ProfileVisibility>(
                    title: Text('Private'),
                    subtitle: Text('Your profile is visible only to you.'),
                    value: ProfileVisibility.private,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          Text('Account', style: text.titleMedium),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: accountState.isLoading ? null : () => _confirmDelete(context, ref),
            icon: accountState.isLoading
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
            label: Text(
              'Delete account',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            style: OutlinedButton.styleFrom(side: BorderSide(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }
}
