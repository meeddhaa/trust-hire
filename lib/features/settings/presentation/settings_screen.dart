import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/theme_mode_provider.dart';
import '../../auth/providers/auth_providers.dart';

/// Account-level settings — separate from Profile (which shows bio/skills)
/// per the decision to split them: appearance, subscription, sign-out,
/// and resume management all live here.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Appearance', style: text.titleMedium),
          const SizedBox(height: 10),
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

          Text('Resume', style: text.titleMedium),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Upload resume'),
              subtitle: const Text('Used to sharpen match scoring and tailor suggestions'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/resume'),
            ),
          ),
          const SizedBox(height: 28),

          Text('Subscription', style: text.titleMedium),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.workspace_premium_outlined),
              title: const Text('Manage subscription'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/subscription'),
            ),
          ),
          const SizedBox(height: 28),

          OutlinedButton(
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
