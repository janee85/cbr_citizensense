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
import '../widgets/auth_layout.dart' show MessageBanner;
import '../widgets/chips.dart';
import '../widgets/classification_card.dart';

/// Complaint details + status timeline + staff responses.
/// Office staff of the assigned office also get the status-update form (EP-07).
class ComplaintDetailScreen extends StatefulWidget {
  const ComplaintDetailScreen({super.key, required this.id});
  final int id;

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  ComplaintDetail? _d;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool quiet = false}) async {
    final api = context.read<ApiService>();
    if (!quiet) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final d = await api.getComplaint(widget.id);
      if (!mounted) return;
      setState(() {
        _d = d;
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
        _error = 'Unable to load this complaint. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final role = user?.role ?? UserRole.citizen;

    Widget body;
    if (_loading && _d == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null && _d == null) {
      body = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.search_off_rounded, size: 40, color: AppColors.muted),
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => context.go(role.listRoute),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('Back to ${role.listLabel}'),
            ),
          ),
        ]),
      );
    } else {
      final d = _d!;
      final canUpdate =
          role == UserRole.staff && user?.officeId == d.complaint.officeId;
      body = LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= 980;
        final main = _Main(d: d, showCitizen: role != UserRole.citizen);
        final side = Column(children: [
          ClassificationCard(
            title: 'ML classification',
            hasCategory: true,
            loading: false,
            result: Classification(
              category: categoryById(d.complaint.categoryId).name,
              sentiment: d.complaint.sentiment,
              priority: d.complaint.priority,
              confidence: d.confidence,
              officeId: d.complaint.officeId,
              keywords: d.keywords,
            ),
          ),
          if (canUpdate) ...[
            const SizedBox(height: 18),
            _UpdateCard(d: d, onDone: () => _load(quiet: true)),
          ],
        ]);
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.go(role.listRoute),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: Text('Back to ${role.listLabel}'),
              ),
            ),
            const SizedBox(height: 6),
            if (wide)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 6, child: main),
                const SizedBox(width: 20),
                Expanded(flex: 4, child: side),
              ])
            else ...[main, const SizedBox(height: 18), side],
          ],
        );
      });
    }
    return AppShell(title: 'Complaint #${widget.id}', activeLabel: role.listLabel, child: body);
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.line),
        ),
        child: child,
      );
}

class _Main extends StatelessWidget {
  const _Main({required this.d, required this.showCitizen});
  final ComplaintDetail d;
  final bool showCitizen;

  @override
  Widget build(BuildContext context) {
    final c = d.complaint;
    Widget kv(String k, String v) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 110, child: Text(k, style: const TextStyle(color: AppColors.muted, fontSize: 13))),
            Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5))),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, runSpacing: 6, children: [PriorityChip(c.priority), StatusChip(c.status)]),
          const SizedBox(height: 12),
          Text(c.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.25)),
          const SizedBox(height: 16),
          kv('Category', categoryById(c.categoryId).name),
          kv('Sent to', officeById(c.officeId).name),
          kv('Location', d.locationName.isEmpty ? '—' : d.locationName),
          kv('Submitted', fmtDate(c.createdAt)),
          if (showCitizen && c.citizenName.isNotEmpty) kv('Filed by', c.citizenName),
          if (c.attachmentName != null) kv('Attachment', c.attachmentName!),
          const Divider(color: AppColors.line, height: 28),
          const Text('Description', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(c.description.isEmpty ? 'No description provided.' : c.description,
              style: const TextStyle(height: 1.5)),
        ]),
      ),
      const SizedBox(height: 18),
      _Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Responses from the office', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (d.responses.isEmpty)
            const Text('No response yet. You will be notified when the office replies.',
                style: TextStyle(color: AppColors.muted))
          else
            for (final r in d.responses.reversed)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(14)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.message, style: const TextStyle(height: 1.45)),
                  const SizedBox(height: 6),
                  Text('${r.staffName} · ${fmtDate(r.createdAt)}',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                ]),
              ),
        ]),
      ),
      const SizedBox(height: 18),
      _Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Status history', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          _Timeline(items: d.history.reversed.toList()),
        ]),
      ),
    ]);
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.items});
  final List<HistoryEntry> items;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (var i = 0; i < items.length; i++)
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 22,
              child: Column(children: [
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: i == 0 ? AppColors.navy : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.navy, width: 2),
                  ),
                ),
                if (i < items.length - 1) Expanded(child: Container(width: 2, color: AppColors.line)),
              ]),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    StatusChip(items[i].status),
                    Text(fmtDate(items[i].at), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  ]),
                  if (items[i].note.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(items[i].note, style: const TextStyle(height: 1.4)),
                  ],
                  if (items[i].by.isNotEmpty)
                    Text('by ${items[i].by}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                ]),
              ),
            ),
          ]),
        ),
    ]);
  }
}

/// EP-07: PATCH /api/complaints/{id}/status. Only legal next statuses are offered.
class _UpdateCard extends StatefulWidget {
  const _UpdateCard({required this.d, required this.onDone});
  final ComplaintDetail d;
  final VoidCallback onDone;

  @override
  State<_UpdateCard> createState() => _UpdateCardState();
}

class _UpdateCardState extends State<_UpdateCard> {
  final _form = GlobalKey<FormState>();
  final _msg = TextEditingController();
  ComplaintStatus? _next;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final next = _next!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Change status to ${next.label}?', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        content: const Text('The citizen will be notified of this update.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Confirm')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final api = context.read<ApiService>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await api.updateStatus(id: widget.d.complaint.id, status: next, message: _msg.text);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Status updated to ${next.label}.')));
      _msg.clear();
      setState(() {
        _saving = false;
        _next = null;
      });
      widget.onDone();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.displayMessage;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Update failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = allowedNext(widget.d.complaint.status);
    return _Box(
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Update status and respond', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          if (options.isEmpty)
            const Text('This complaint is closed. No further updates are possible.',
                style: TextStyle(color: AppColors.muted))
          else ...[
            DropdownButtonFormField<ComplaintStatus>(
              key: ValueKey('next-${widget.d.complaint.status.name}'),
              initialValue: _next,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'New status *'),
              items: options.map((s) => DropdownMenuItem(value: s, child: Text(s.label))).toList(),
              onChanged: (v) => setState(() => _next = v),
              validator: (v) => v == null ? 'Choose the new status.' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _msg,
              minLines: 3,
              maxLines: 5,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Response to the citizen (optional)',
                alignLabelWithHint: true,
              ),
              validator: (v) => (v ?? '').length > 500 ? 'Keep the response under 500 characters.' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              MessageBanner(message: _error!),
            ],
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('Save update'),
            ),
          ],
        ]),
      ),
    );
  }
}
