import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'app_drawer.dart';

/// The primary product surface: Jobs / Applications / Saved / Job Coach /
/// Profile as bottom-nav tabs, each keeping its own navigation stack (so
/// pushing a listing detail from Jobs doesn't disturb the other tabs) via
/// go_router's `StatefulShellRoute.indexedStack`. The account drawer
/// (Resume/Settings/Subscription/Sign out) lives one level up from all of
/// them — see `app_drawer.dart`'s doc comment for why that split exists.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    NavigationDestination(icon: Icon(Icons.work_outline_rounded), label: 'Jobs'),
    NavigationDestination(icon: Icon(Icons.assignment_outlined), label: 'Applications'),
    NavigationDestination(icon: Icon(Icons.bookmark_border_rounded), label: 'Saved'),
    NavigationDestination(icon: Icon(Icons.school_outlined), label: 'Job Coach'),
    NavigationDestination(icon: Icon(Icons.person_outline_rounded), label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          // Tapping the already-selected tab pops it back to its root,
          // same as most apps' bottom-nav behavior, instead of doing
          // nothing.
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: _destinations,
      ),
    );
  }
}

/// Reachable from any bottom-nav tab's `AppBar` — `Scaffold.of(context)`
/// called with the *branch screen's own* build context (not a context
/// from inside that screen's nested Scaffold) resolves to this shell's
/// Scaffold, since the branch's own Scaffold is a descendant being built
/// by that same call, not yet an ancestor of `context`.
IconButton buildDrawerButton(BuildContext context) {
  return IconButton(
    icon: const Icon(Icons.menu_rounded),
    tooltip: 'Menu',
    onPressed: () => Scaffold.of(context).openDrawer(),
  );
}
