import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/auth_layout.dart' show MessageBanner;
import '../widgets/terms_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  bool _obscure = true;
  String? _error;
  String? _ok;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _change() async {
    if (!_form.currentState!.validate()) return;
    final api = context.read<ApiService>();
    setState(() {
      _saving = true;
      _error = null;
      _ok = null;
    });
    try {
      await api.changePassword(current: _current.text, next: _new.text);
      if (!mounted) return;
      _current.clear();
      _new.clear();
      _confirm.clear();
      setState(() {
        _saving = false;
        _ok = 'Password updated.';
      });
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
        _error = 'Could not update the password. Please try again.';
      });
    }
  }

  Widget _card(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.line),
        ),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const SizedBox.shrink();

    return AppShell(
      title: 'Settings',
      activeLabel: 'Settings',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(children: [
                _card(Row(children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.navy,
                    child: Text(user.initials,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(user.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      Text(user.email, style: const TextStyle(color: AppColors.muted)),
                      const SizedBox(height: 6),
                      Text(
                        user.role == UserRole.staff && user.officeId != null
                            ? '${user.role.label} · ${officeById(user.officeId!).name}'
                            : user.role.label,
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy, fontSize: 13),
                      ),
                    ]),
                  ),
                ])),
                const SizedBox(height: 18),
                _card(Form(
                  key: _form,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Text('Change password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 14),
                    if (_error != null) ...[MessageBanner(message: _error!), const SizedBox(height: 12)],
                    if (_ok != null) ...[MessageBanner(message: _ok!, good: true), const SizedBox(height: 12)],
                    TextFormField(
                      controller: _current,
                      obscureText: _obscure,
                      decoration: const InputDecoration(labelText: 'Current password'),
                      validator: (v) => (v ?? '').isEmpty ? 'Enter your current password.' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _new,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'New password',
                        helperText: 'At least 8 characters.',
                        suffixIcon: IconButton(
                          tooltip: _obscure ? 'Show passwords' : 'Hide passwords',
                          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v ?? '').length < 8 ? 'Password must be at least 8 characters long.' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirm,
                      obscureText: _obscure,
                      decoration: const InputDecoration(labelText: 'Confirm new password'),
                      validator: (v) => v != _new.text ? 'Passwords do not match.' : null,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _saving ? null : _change,
                      child: _saving
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : const Text('Update password'),
                    ),
                  ]),
                )),
                const SizedBox(height: 18),
                _card(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('Privacy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text('How CitizenSense uses and protects your data.', style: TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => showTermsDialog(context),
                      icon: const Icon(Icons.privacy_tip_outlined, size: 18),
                      label: const Text('View Terms of Use and Data Privacy Notice'),
                    ),
                  ),
                ])),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: () => context.read<AuthProvider>().logout(),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Log out'),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
