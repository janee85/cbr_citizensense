import 'constants.dart';

String? validateEmail(String? v) {
  final e = (v ?? '').trim();
  if (e.isEmpty) return 'Enter your email address.';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) {
    return 'Enter a valid email address.';
  }
  if (roleFromEmail(e) == null) {
    return 'Use a @gmail.com, @staff.com or @admin.com email.';
  }
  return null;
}

String? validatePassword(String? v, {bool strict = false}) {
  final p = v ?? '';
  if (p.isEmpty) return 'Enter your password.';
  if (strict && p.length < 8) return 'Password must be at least 8 characters long.';
  return null;
}
