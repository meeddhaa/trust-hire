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
    (Icons.work_outline_rounded, Icons.work_rounded, 'Jobs'),
    (Icons.assignment_outlined, Icons.assignment_rounded, 'Applications'),
    (Icons.bookmark_border_rounded, Icons.bookmark_rounded, 'Saved'),
    (Icons.school_outlined, Icons.school_rounded, 'Job Coach'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      body: navigationShell,
      // Not extendBody: true — the nav bar is visually "floating" (margin,
      // rounded stadium) but still reserves its own layout height, so a
      // long list's last item scrolls to rest above it rather than
      // needing every branch screen to hand-tune bottom padding to avoid
      // being obscured underneath.
      bottomNavigationBar: _FloatingNavBar(
        currentIndex: navigationShell.currentIndex,
        destinations: _destinations,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          // Tapping the already-selected tab pops it back to its root,
          // same as most apps' bottom-nav behavior, instead of doing
          // nothing.
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}

/// A floating rounded-stadium bar with circular per-icon active states —
/// not the stock Material [NavigationBar] — per the user-supplied
/// reference's bottom nav: individual circular icon buttons, the active
/// one filled solid in the accent color, rather than one shared indicator
/// pill sliding under a row of icon+label pairs.
class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.currentIndex,
    required this.destinations,
    required this.onDestinationSelected,
  });

  final int currentIndex;
  final List<(IconData, IconData, String)> destinations;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: scheme.outline),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 0; i < destinations.length; i++)
              _NavIcon(
                outlineIcon: destinations[i].$1,
                filledIcon: destinations[i].$2,
                label: destinations[i].$3,
                selected: i == currentIndex,
                onTap: () => onDestinationSelected(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.outlineIcon,
    required this.filledIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData outlineIcon;
  final IconData filledIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? scheme.primary : Colors.transparent,
          ),
          child: Icon(
            selected ? filledIcon : outlineIcon,
            color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
            size: 22,
          ),
        ),
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
