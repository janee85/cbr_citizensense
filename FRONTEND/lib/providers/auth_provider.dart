import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._api);
  final ApiService _api;

  AppUser? user;
  bool busy = false;
  String? error;

  /// Real-API mode only: bring back the saved session after a page refresh.
  /// The API still rejects an expired token with 401, which logs the user out.
  Future<void> restore() async {
    if (kUseMockApi) return;
    try {
      final p = await SharedPreferences.getInstance();
      final token = p.getString('token');
      final saved = p.getString('user');
      if (token != null && saved != null) {
        _api.setToken(token);
        user = AppUser.fromJson(jsonDecode(saved) as Map<String, dynamic>);
      }
    } catch (_) {}
  }

  Future<void> _save(String token, AppUser u) async {
    if (kUseMockApi) return;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('token', token);
      await p.setString('user', jsonEncode(u.toJson()));
    } catch (_) {}
  }

  Future<void> _clearSaved() async {
    if (kUseMockApi) return;
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove('token');
      await p.remove('user');
    } catch (_) {}
  }

  void clearError() {
    if (error != null) {
      error = null;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final s = await _api.login(email: email.trim(), password: password);
      _api.setToken(s.token);
      await _save(s.token, s.user);
      user = s.user;
      busy = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      error = e.displayMessage;
    } catch (_) {
      error = 'Something went wrong. Please try again.';
    }
    busy = false;
    notifyListeners();
    return false;
  }

  /// Registration does not log the user in: the flow ends on the Login screen
  /// (Activity 6, route /register).
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    int? officeId,
  }) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await _api.register(
          name: name.trim(), email: email.trim(), password: password, officeId: officeId);
      busy = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      error = e.displayMessage;
    } catch (_) {
      error = 'Something went wrong. Please try again.';
    }
    busy = false;
    notifyListeners();
    return false;
  }

  void logout() {
    _api.setToken(null);
    _clearSaved();
    user = null;
    error = null;
    notifyListeners();
  }
}
