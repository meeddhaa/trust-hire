import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/failure.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/session_providers.dart';
import '../../../core/providers/theme_mode_provider.dart';
import '../providers/account_providers.dart';

/// "How the app behaves for you" — appearance, account. Resume and
/// Subscription used to have quick-link cards here too; both are now
/// their own drawer destinations instead (see `app_drawer.dart`), so
/// they're not duplicated in this list.
///
/// Profile visibility (Public/Private) was built (`profile_visibility_provider.dart`)
/// but is deliberately not surfaced here: no employer-facing view of any
/// profile exists yet, so a toggle with nothing to enforce read as the
/// app announcing an unfinished half of itself. Re-add to this screen
/// once there's an actual audience for a profile to be visible to.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _editName(BuildContext context, WidgetRef ref, String currentName) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final controller = TextEditingController(text: currentName == 'there' ? '' : currentName);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. Naafisa Medha'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final trimmed = controller.text.trim();
              if (trimmed.isEmpty) return;
              Navigator.pop(dialogContext, trimmed);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || !context.mounted) return;
    try {
      await ref.read(profileRepositoryProvider).setDisplayName(uid, name);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e is Failure ? e.message : '$e')));
    }
  }

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
    final accountState = ref.watch(accountControllerProvider);
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final currentName = profile?.friendlyUsername ?? 'there';

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

          Text('Account', style: text.titleMedium),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Name'),
            subtitle: Text(currentName),
            trailing: const Icon(Icons.edit_outlined, size: 18),
            onTap: () => _editName(context, ref, currentName),
          ),
          const SizedBox(height: 12),
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
