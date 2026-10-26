import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../core/format.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'seal_logo.dart';

class NavItem {
  final String label;
  final IconData icon;
  final String route;
  const NavItem(this.label, this.icon, this.route);
}

List<NavItem> navFor(UserRole role) {
  switch (role) {
    case UserRole.citizen:
      return [
        NavItem('Dashboard', Icons.space_dashboard_outlined, role.home),
        const NavItem('Submit Complaint', Icons.edit_note_rounded, '/submit-complaint'),
        NavItem(role.listLabel, Icons.list_alt_rounded, role.listRoute),
        const NavItem('Settings', Icons.settings_outlined, '/settings'),
      ];
    case UserRole.staff:
      return [
        NavItem('Dashboard', Icons.space_dashboard_outlined, role.home),
        NavItem(role.listLabel, Icons.assignment_outlined, role.listRoute),
        const NavItem('Settings', Icons.settings_outlined, '/settings'),
      ];
    case UserRole.admin:
      return [
        NavItem('Dashboard', Icons.space_dashboard_outlined, role.home),
        NavItem(role.listLabel, Icons.list_alt_rounded, role.listRoute),
        const NavItem('Reports', Icons.bar_chart_rounded, '/reports-analytics'),
        const NavItem('Users & Offices', Icons.groups_2_outlined, '/admin/users'),
        const NavItem('Settings', Icons.settings_outlined, '/settings'),
      ];
  }
}

/// Blue sidebar + top bar, like the reference dashboard. Becomes a drawer on
/// narrow screens.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.title,
    required this.activeLabel,
    required this.child,
  });
  final String title;
  final String activeLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const SizedBox.shrink();

    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= 960;
      final content = Column(children: [
        _TopBar(title: title, user: user, showMenu: !wide),
        Expanded(child: child),
      ]);
      return Scaffold(
        drawer: wide
            ? null
            : Drawer(
                backgroundColor: AppColors.navy,
                child: _Sidebar(user: user, activeLabel: activeLabel, inDrawer: true),
              ),
        body: wide
            ? Row(children: [
                SizedBox(
                    width: 260,
                    child: _Sidebar(user: user, activeLabel: activeLabel, inDrawer: false)),
                Expanded(child: content),
              ])
            : SafeArea(child: content),
      );
    });
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.user, required this.activeLabel, required this.inDrawer});
  final AppUser user;
  final String activeLabel;
  final bool inDrawer;

  @override
  Widget build(BuildContext context) {
    final items = navFor(user.role);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.navy, AppColors.navyDark],
        ),
      ),
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Row(children: [
              const SealLogo(size: 52),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('CitizenSense',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                  Text('Cabadbaran City', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 20, bottom: 24),
            child: Container(width: 36, height: 3, color: AppColors.gold),
          ),
          Expanded(
            child: ListView(children: [
              for (final it in items)
                _NavTile(
                  icon: it.icon,
                  label: it.label,
                  active: it.label == activeLabel,
                  onTap: () {
                    if (inDrawer) Navigator.of(context).pop();
                    context.go(it.route);
                  },
                ),
            ]),
          ),
          _NavTile(
            icon: Icons.logout_rounded,
            label: 'Logout',
            active: false,
            onTap: () {
              if (inDrawer) Navigator.of(context).pop();
              context.read<AuthProvider>().logout();
            },
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.icon, required this.label, required this.active, required this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.horizontal(left: Radius.circular(28));
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 6),
      child: Material(
        color: active ? Colors.white : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(children: [
              Icon(icon, size: 22, color: active ? AppColors.navy : Colors.white70),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active ? AppColors.navy : Colors.white,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                    )),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.user, required this.showMenu});
  final String title;
  final AppUser user;
  final bool showMenu;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final showSearch = box.maxWidth >= 760;
      final showName = box.maxWidth >= 520;
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
        child: Row(children: [
          if (showMenu)
            Builder(
              builder: (ctx) => IconButton(
                tooltip: 'Open menu',
                icon: const Icon(Icons.menu_rounded),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          if (showSearch) ...[
            const SizedBox(width: 28),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: TextField(
                  textInputAction: TextInputAction.search,
                  onSubmitted: (q) => context.go(
                      '${user.role.listRoute}?q=${Uri.encodeQueryComponent(q.trim())}'),
                  decoration: const InputDecoration(
                    hintText: 'Search complaints',
                    isDense: true,
                    prefixIcon: Icon(Icons.search_rounded, size: 20),
                  ),
                ),
              ),
            ),
          ],
          const Spacer(),
          const _Bell(),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.navy,
            child: Text(user.initials,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
          ),
          if (showName) ...[
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(user.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              Text(user.role.label, style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
            ]),
          ],
        ]),
      );
    });
  }
}

class _Bell extends StatefulWidget {
  const _Bell();

  @override
  State<_Bell> createState() => _BellState();
}

class _BellState extends State<_Bell> {
  List<AppNotice> _items = const [];
  bool _seen = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<ApiService>();
    try {
      final r = await api.notifications();
      if (mounted) setState(() => _items = r);
    } catch (_) {}
  }

  void _open() {
    setState(() => _seen = true);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: 380,
          child: _items.isEmpty
              ? const Text('No new notifications.', style: TextStyle(color: AppColors.muted))
              : ListView(shrinkWrap: true, children: [
                  for (final n in _items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.notifications_active_outlined, color: AppColors.navy),
                      title: Text(n.text, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                      subtitle: Text(fmtDate(n.at), style: const TextStyle(fontSize: 12)),
                      onTap: n.complaintId == null
                          ? null
                          : () {
                              Navigator.of(ctx).pop();
                              context.go('/complaints/${n.complaintId}');
                            },
                    ),
                ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = _seen ? 0 : _items.length;
    return Stack(clipBehavior: Clip.none, children: [
      IconButton(
        tooltip: 'Notifications',
        icon: const Icon(Icons.notifications_none_rounded),
        onPressed: _open,
      ),
      if (count > 0)
        Positioned(
          right: 4,
          top: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(10)),
            child: Text(count > 9 ? '9+' : '$count',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.ink)),
          ),
        ),
    ]);
  }
}
