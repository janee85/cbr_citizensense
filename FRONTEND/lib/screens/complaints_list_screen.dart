import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/chips.dart';

/// Complaint Tracking (citizen), Assigned Complaints (staff), Complaints (admin).
class ComplaintsListScreen extends StatefulWidget {
  const ComplaintsListScreen({super.key, this.initialQuery = ''});
  final String initialQuery;

  @override
  State<ComplaintsListScreen> createState() => _ComplaintsListScreenState();
}

class _ComplaintsListScreenState extends State<ComplaintsListScreen> {
  static const _pageSize = 10;
  final _search = TextEditingController();
  late final UserRole _role;
  List<Complaint>? _all;
  String? _error;
  bool _loading = true;
  ComplaintStatus? _status;
  Priority? _priority;
  late bool _byPriority;
  int _shown = _pageSize;
  int _filterVersion = 0;

  @override
  void initState() {
    super.initState();
    _role = context.read<AuthProvider>().user?.role ?? UserRole.citizen;
    _byPriority = _role == UserRole.staff; // staff see urgent complaints first
    _search.text = widget.initialQuery;
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = context.read<ApiService>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await api.listComplaints(_role);
      if (!mounted) return;
      setState(() {
        _all = r;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load complaints. Please try again.';
        _loading = false;
      });
    }
  }

  List<Complaint> get _filtered {
    final q = _search.text.trim().toLowerCase();
    final list = (_all ?? const <Complaint>[]).where((c) {
      if (_status != null && c.status != _status) return false;
      if (_priority != null && c.priority != _priority) return false;
      if (q.isEmpty) return true;
      return c.title.toLowerCase().contains(q) ||
          categoryById(c.categoryId).name.toLowerCase().contains(q) ||
          c.citizenName.toLowerCase().contains(q) ||
          '#${c.id}'.contains(q);
    }).toList();
    list.sort((a, b) {
      if (_byPriority) {
        final p = b.priority.index.compareTo(a.priority.index);
        if (p != 0) return p;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  bool get _hasFilters => _status != null || _priority != null || _search.text.trim().isNotEmpty;

  void _clear() => setState(() {
        _status = null;
        _priority = null;
        _search.clear();
        _shown = _pageSize;
        _filterVersion++;
      });

  @override
  Widget build(BuildContext context) {
    final label = _role.listLabel;
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.muted),
          const SizedBox(height: 10),
          Text(_error!),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _load,
            child: const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Try again')),
          ),
        ]),
      );
    } else {
      final items = _filtered;
      final visible = items.take(_shown).toList();
      body = ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          _controls(items.length),
          const SizedBox(height: 14),
          if (items.isEmpty) _empty() else ...[
            for (final c in visible) _ComplaintTile(c: c, showCitizen: _role != UserRole.citizen),
            if (items.length > visible.length)
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _shown += _pageSize),
                  child: Text('Show more (${items.length - visible.length} left)'),
                ),
              ),
          ],
        ],
      );
    }
    return AppShell(title: label, activeLabel: label, child: body);
  }

  Widget _controls(int count) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() => _shown = _pageSize),
            decoration: const InputDecoration(
              hintText: 'Search by title, category, or #id',
              prefixIcon: Icon(Icons.search_rounded, size: 20),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
      ]),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        ChoiceChip(
          label: const Text('All'),
          selected: _status == null,
          onSelected: (_) => setState(() {
            _status = null;
            _shown = _pageSize;
          }),
        ),
        for (final s in ComplaintStatus.values)
          ChoiceChip(
            label: Text(s.label),
            selected: _status == s,
            onSelected: (_) => setState(() {
              _status = _status == s ? null : s;
              _shown = _pageSize;
            }),
          ),
      ]),
      const SizedBox(height: 12),
      Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(
          width: 190,
          child: DropdownButtonFormField<Priority?>(
            key: ValueKey('prio-$_filterVersion'),
            initialValue: _priority,
            isDense: true,
            decoration: const InputDecoration(labelText: 'Priority', isDense: true),
            items: [
              const DropdownMenuItem<Priority?>(value: null, child: Text('All priorities')),
              for (final p in Priority.values) DropdownMenuItem<Priority?>(value: p, child: Text(p.label)),
            ],
            onChanged: (v) => setState(() {
              _priority = v;
              _shown = _pageSize;
            }),
          ),
        ),
        SizedBox(
          width: 190,
          child: DropdownButtonFormField<bool>(
            initialValue: _byPriority,
            isDense: true,
            decoration: const InputDecoration(labelText: 'Sort by', isDense: true),
            items: const [
              DropdownMenuItem(value: false, child: Text('Newest first')),
              DropdownMenuItem(value: true, child: Text('Highest priority')),
            ],
            onChanged: (v) => setState(() => _byPriority = v ?? false),
          ),
        ),
        Text('$count complaint${count == 1 ? '' : 's'}', style: const TextStyle(color: AppColors.muted)),
        if (_hasFilters) TextButton(onPressed: _clear, child: const Text('Clear filters')),
      ]),
    ]);
  }

  Widget _empty() {
    final filtered = _hasFilters;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Center(
        child: Column(children: [
          const Icon(Icons.inbox_outlined, size: 40, color: AppColors.muted),
          const SizedBox(height: 10),
          Text(filtered ? 'No complaints match these filters.' : 'No complaints yet.',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          if (filtered)
            TextButton(onPressed: _clear, child: const Text('Clear filters'))
          else if (_role == UserRole.citizen)
            TextButton(onPressed: () => context.go('/submit-complaint'), child: const Text('Submit a complaint'))
          else
            const Text('New complaints routed here will appear in this list.',
                style: TextStyle(color: AppColors.muted)),
        ]),
      ),
    );
  }
}

class _ComplaintTile extends StatelessWidget {
  const _ComplaintTile({required this.c, required this.showCitizen});
  final Complaint c;
  final bool showCitizen;

  @override
  Widget build(BuildContext context) {
    final meta = [
      '#${c.id}',
      categoryById(c.categoryId).name,
      if (showCitizen && c.citizenName.isNotEmpty) c.citizenName,
      officeById(c.officeId).shortName,
      fmtDate(c.createdAt),
    ].join('  ·  ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.go('/complaints/${c.id}'),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(
                  width: 6,
                  decoration: BoxDecoration(
                    color: c.priority.color,
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(meta, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 6, children: [PriorityChip(c.priority), StatusChip(c.status)]),
                    ]),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
