import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/app_shell.dart';

/// Admin: manage user accounts and see office workload.
class UsersOfficesScreen extends StatelessWidget {
  const UsersOfficesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Users & Offices',
      activeLabel: 'Users & Offices',
      child: DefaultTabController(
        length: 2,
        child: Column(children: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.navy,
              unselectedLabelColor: AppColors.muted,
              indicatorColor: AppColors.gold,
              tabs: [Tab(text: 'Users'), Tab(text: 'Offices')],
            ),
          ),
          Expanded(child: TabBarView(children: [_UsersTab(), _OfficesTab()])),
        ]),
      ),
    );
  }
}

class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> with AutomaticKeepAliveClientMixin {
  final _search = TextEditingController();
  List<UserRecord>? _users;
  String? _error;
  UserRole? _role;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = context.read<ApiService>();
    setState(() => _error = null);
    try {
      final r = await api.adminUsers();
      if (mounted) setState(() => _users = r);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to load users.');
    }
  }

  Future<void> _toggle(UserRecord u, bool active) async {
    final api = context.read<ApiService>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await api.setUserActive(u.id, active);
      messenger.showSnackBar(SnackBar(content: Text('${u.name} ${active ? 'activated' : 'deactivated'}.')));
      _load();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final me = context.watch<AuthProvider>().user;
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!),
          TextButton(onPressed: _load, child: const Text('Try again')),
        ]),
      );
    }
    final all = _users;
    if (all == null) return const Center(child: CircularProgressIndicator());

    final q = _search.text.trim().toLowerCase();
    final list = all
        .where((u) =>
            (_role == null || u.role == _role) &&
            (q.isEmpty || u.name.toLowerCase().contains(q) || u.email.toLowerCase().contains(q)))
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Search name or email',
            prefixIcon: Icon(Icons.search_rounded, size: 20),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          ChoiceChip(label: const Text('All'), selected: _role == null, onSelected: (_) => setState(() => _role = null)),
          for (final r in UserRole.values)
            ChoiceChip(
              label: Text(r.label),
              selected: _role == r,
              onSelected: (_) => setState(() => _role = _role == r ? null : r),
            ),
        ]),
        const SizedBox(height: 14),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('No users match.', style: TextStyle(color: AppColors.muted))),
          ),
        for (final u in list)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(children: [
              CircleAvatar(
                backgroundColor: u.active ? AppColors.navy : AppColors.muted,
                child: Text(AppUser(id: u.id, name: u.name, email: u.email, role: u.role).initials,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(u.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(u.email, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                  const SizedBox(height: 4),
                  Text(
                    u.role == UserRole.staff && u.officeId != null
                        ? '${u.role.label} · ${officeById(u.officeId!).shortName}'
                        : u.role.label,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.navy),
                  ),
                ]),
              ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Switch(
                  value: u.active,
                  onChanged: u.email == me?.email ? null : (v) => _toggle(u, v),
                ),
                Text(u.active ? 'Active' : 'Disabled', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              ]),
            ]),
          ),
      ],
    );
  }
}

class _OfficesTab extends StatefulWidget {
  const _OfficesTab();

  @override
  State<_OfficesTab> createState() => _OfficesTabState();
}

class _OfficesTabState extends State<_OfficesTab> with AutomaticKeepAliveClientMixin {
  List<OfficeSummary>? _items;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<ApiService>();
    setState(() => _error = null);
    try {
      final r = await api.adminOffices();
      if (mounted) setState(() => _items = r);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to load offices.');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!),
          TextButton(onPressed: _load, child: const Text('Try again')),
        ]),
      );
    }
    final items = _items;
    if (items == null) return const Center(child: CircularProgressIndicator());

    Widget stat(String label, int v, Color c) => Expanded(
          child: Column(children: [
            Text('$v', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c)),
            Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
          ]),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        for (final o in items)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(o.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 12),
              Row(children: [
                stat('Staff accounts', o.staffCount, AppColors.navy),
                stat('Open complaints', o.openCount, const Color(0xFFEF9F1A)),
                stat('All complaints', o.totalCount, AppColors.forest),
              ]),
            ]),
          ),
      ],
    );
  }
}
