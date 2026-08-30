import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../providers/session_providers.dart';

/// Account management, separate from the primary bottom-nav destinations
/// (Dashboard/Jobs/Applications/Job Coach/Profile) — per the decision to
/// keep "core product" and "account" navigation from mixing (see
/// docs/ARCHITECTURE.md → "Decision: navigation drawer"). Doesn't repeat
/// Profile — that already has its own bottom-nav tab, so listing it here
/// too would just be the same destination reachable two confusing ways.
/// Saved lives here rather than as a bottom-nav tab: six tabs overflowed
/// the floating nav bar on real device widths, and Saved was the one
/// asked to move.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final profile = ref.watch(currentProfileProvider).valueOrNull;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  profile?.displayName.isNotEmpty == true ? profile!.displayName : (profile?.email ?? ''),
                  style: text.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.bookmark_border_rounded),
              title: const Text('Saved'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/saved');
              },
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Resume'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/resume');
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/settings');
              },
            ),
            ListTile(
              leading: const Icon(Icons.workspace_premium_outlined),
              title: const Text('Subscription'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/subscription');
              },
            ),
            const Spacer(),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Sign out'),
              onTap: () {
                Navigator.of(context).pop();
                ref.read(authControllerProvider.notifier).signOut();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
