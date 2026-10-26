import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/auth_layout.dart' show MessageBanner;
import '../widgets/chips.dart';
import '../widgets/classification_card.dart';
import '../widgets/terms_dialog.dart';

class SubmitComplaintScreen extends StatefulWidget {
  const SubmitComplaintScreen({super.key});

  @override
  State<SubmitComplaintScreen> createState() => _SubmitComplaintScreenState();
}

class _SubmitComplaintScreenState extends State<SubmitComplaintScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  late final TapGestureRecognizer _termsTap;

  int? _categoryId;
  int? _officeId;
  int? _locationId;
  bool _officeTouched = false; // true once the citizen picks an office manually
  int _officeVersion = 0; // forces the dropdown to show a programmatic change

  PickedAttachment? _attachment;
  String? _attachmentError;

  bool _agreed = false;
  bool _termsError = false;
  bool _sending = false;
  String? _submitError;

  Classification? _result;
  bool _classifying = false;
  String? _classifyError;
  Timer? _debounce;
  int _reqId = 0;

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()..onTap = _openTerms;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _termsTap.dispose();
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _openTerms() async {
    final ok = await showTermsDialog(context);
    if (ok == true && mounted) {
      setState(() {
        _agreed = true;
        _termsError = false;
      });
    }
  }

  Future<void> _pickFile() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
        withData: true,
      );
      if (res == null || res.files.isEmpty) return;
      final f = res.files.single;
      final bytes = f.bytes;
      if (bytes == null) return;
      if (bytes.length > 5 * 1024 * 1024) {
        setState(() {
          _attachment = null;
          _attachmentError = 'Only JPG, PNG, or PDF files up to 5MB are allowed.';
        });
        return;
      }
      setState(() {
        _attachment = PickedAttachment(f.name, bytes);
        _attachmentError = null;
      });
    } catch (_) {
      setState(() => _attachmentError = 'Could not open the file picker.');
    }
  }

  String _size(int b) => b < 1024 * 1024 ? '${(b / 1024).ceil()} KB' : '${(b / 1024 / 1024).toStringAsFixed(1)} MB';

  /// Runs the ML check. Fires as soon as a category is picked, and again
  /// (debounced) while the citizen types the description.
  Future<void> _classify() async {
    final cat = _categoryId;
    if (cat == null) return;
    final api = context.read<ApiService>();
    final id = ++_reqId;
    setState(() {
      _classifying = true;
      _classifyError = null;
    });
    try {
      final r = await api.classify(categoryId: cat, description: _desc.text.trim());
      if (!mounted || id != _reqId) return;
      setState(() {
        _result = r;
        _classifying = false;
        if (!_officeTouched && r.officeId != null && r.officeId != _officeId) {
          _officeId = r.officeId;
          _officeVersion++;
        }
      });
    } on ApiException catch (e) {
      if (!mounted || id != _reqId) return;
      setState(() {
        _classifying = false;
        _classifyError = e.message;
      });
    } catch (_) {
      if (!mounted || id != _reqId) return;
      setState(() {
        _classifying = false;
        _classifyError = 'Classification failed.';
      });
    }
  }

  void _onCategoryChanged(int? v) {
    if (v == null) return;
    _debounce?.cancel();
    setState(() {
      _categoryId = v;
      if (!_officeTouched) {
        _officeId = categoryById(v).officeId;
        _officeVersion++;
      }
    });
    _classify();
  }

  void _onDescChanged(String _) {
    setState(() {}); // refresh the character counter
    if (_categoryId == null) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), _classify);
  }

  Future<void> _submit() async {
    setState(() => _submitError = null);
    final valid = _form.currentState!.validate();
    if (!_agreed) setState(() => _termsError = true);
    if (!valid || !_agreed) return;

    final api = context.read<ApiService>();
    setState(() => _sending = true);
    try {
      final c = await api.submitComplaint(
        title: _title.text.trim(),
        description: _desc.text.trim(),
        categoryId: _categoryId!,
        officeId: _officeId!,
        locationId: _locationId!,
        attachment: _attachment,
      );
      if (!mounted) return;
      setState(() => _sending = false);
      await _showSuccess(c);
      if (mounted) context.go(UserRole.citizen.home);
    } on ApiException catch (e) {
      if (!mounted) return;
      // Entered data is kept so the citizen can fix it and resubmit.
      setState(() {
        _sending = false;
        _submitError = e.displayMessage;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _submitError = 'Submission failed. Your details are still here, please try again.';
      });
    }
  }

  Future<void> _showSuccess(Complaint c) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.forest, size: 28),
          const SizedBox(width: 10),
          Expanded(child: Text('Complaint #${c.id} submitted', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _kv('Priority', PriorityChip(c.priority)),
          _kv('Sent to', Text(officeById(c.officeId).name, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
          _kv('Status', StatusChip(c.status)),
          if (c.priority == Priority.critical) ...[
            const SizedBox(height: 8),
            const Text('This looks like an emergency. Please also call 911.',
                style: TextStyle(color: AppColors.star, fontWeight: FontWeight.w700)),
          ],
        ]),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Back to dashboard')),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, Widget v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: SizedBox(
          width: 300,
          child: Row(children: [
            Expanded(child: Text(k, style: const TextStyle(color: AppColors.muted))),
            Flexible(child: v),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Submit Complaint',
      activeLabel: 'Submit Complaint',
      child: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= 980;
        final card = ClassificationCard(
          hasCategory: _categoryId != null,
          loading: _classifying,
          result: _result,
          error: _classifyError,
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          child: wide
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 6, child: _formCard(inlineCard: null)),
                  const SizedBox(width: 20),
                  Expanded(flex: 4, child: card),
                ])
              : _formCard(inlineCard: card),
        );
      }),
    );
  }

  Widget _formCard({required Widget? inlineCard}) {
    final space = const SizedBox(height: 16);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('File a complaint', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Fire, injury, or danger to life? Call 911 first, then file here.',
              style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 22),

          DropdownButtonFormField<int>(
            initialValue: _categoryId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Category *'),
            items: kCategories
                .map((c) => DropdownMenuItem(
                      value: c.id,
                      child: Row(children: [
                        Icon(c.icon, size: 18, color: AppColors.navy),
                        const SizedBox(width: 10),
                        Flexible(child: Text(c.name, overflow: TextOverflow.ellipsis)),
                      ]),
                    ))
                .toList(),
            onChanged: _onCategoryChanged,
            validator: (v) => v == null ? 'Select a category.' : null,
          ),
          if (inlineCard != null) ...[space, inlineCard],
          space,
          TextFormField(
            controller: _title,
            maxLength: 100,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Complaint title *'),
            validator: (v) {
              final n = (v ?? '').trim().length;
              return n < 5 || n > 100 ? 'Please enter a complaint title between 5 and 100 characters.' : null;
            },
          ),
          space,
          TextFormField(
            controller: _desc,
            minLines: 5,
            maxLines: 8,
            maxLength: 1000,
            onChanged: _onDescChanged,
            decoration: const InputDecoration(
              labelText: 'What happened? *',
              alignLabelWithHint: true,
              helperText: 'Say what, where exactly, and since when. More detail gives a more accurate priority.',
              helperMaxLines: 2,
            ),
            validator: (v) => (v ?? '').trim().length < 20
                ? 'Complaint description must contain at least 20 characters.'
                : null,
          ),
          space,
          DropdownButtonFormField<int>(
            initialValue: _locationId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Barangay / location *'),
            items: kBarangays.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
            onChanged: (v) => setState(() => _locationId = v),
            validator: (v) => v == null ? 'Select where this happened.' : null,
          ),
          space,
          DropdownButtonFormField<int>(
            key: ValueKey('office-$_officeVersion'),
            initialValue: _officeId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Send to office *',
              helperText: _officeTouched
                  ? 'You chose this office.'
                  : 'Suggested from your category. Change it if another office should handle this.',
              helperMaxLines: 2,
            ),
            items: kOffices
                .map((o) => DropdownMenuItem(value: o.id, child: Text(o.name, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (v) => setState(() {
              _officeId = v;
              _officeTouched = true;
            }),
            validator: (v) => v == null ? 'Select the office that should receive this.' : null,
          ),
          space,
          Text('Photo or document (optional)', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 8),
          if (_attachment == null)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.attach_file_rounded, size: 18),
                label: const Text('Attach JPG, PNG or PDF (max 5MB)'),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.insert_drive_file_outlined, color: AppColors.navy),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('${_attachment!.name} · ${_size(_attachment!.size)}',
                      overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  tooltip: 'Remove file',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() => _attachment = null),
                ),
              ]),
            ),
          if (_attachmentError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_attachmentError!, style: const TextStyle(color: AppColors.star, fontSize: 12.5)),
            ),
          const SizedBox(height: 18),

          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Checkbox(
              value: _agreed,
              onChanged: (v) => setState(() {
                _agreed = v ?? false;
                if (_agreed) _termsError = false;
              }),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text.rich(TextSpan(style: const TextStyle(height: 1.4), children: [
                  const TextSpan(text: 'I confirm these details are true and I agree to the '),
                  TextSpan(
                    text: 'Terms of Use and Data Privacy Notice',
                    recognizer: _termsTap,
                    style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w700, decoration: TextDecoration.underline),
                  ),
                  const TextSpan(text: ', including automatic classification of my complaint.'),
                ])),
              ),
            ),
          ]),
          if (_termsError)
            const Padding(
              padding: EdgeInsets.only(left: 12, bottom: 4),
              child: Text('You need to agree before submitting.', style: TextStyle(color: AppColors.star, fontSize: 12.5)),
            ),
          if (_submitError != null) ...[
            const SizedBox(height: 12),
            MessageBanner(message: _submitError!),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _sending ? null : _submit,
            child: _sending
                ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
                    SizedBox(width: 12),
                    Text('Submitting…'),
                  ])
                : const Text('Submit complaint'),
          ),
        ]),
      ),
    );
  }
}
