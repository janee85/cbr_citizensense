import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/api_service.dart';

class DashboardProvider extends ChangeNotifier {
  DashboardProvider(this._api);
  final ApiService _api;

  DashboardData? data;
  bool loading = false;
  String? error;

  Future<void> load() async {
    data = null; // never show the previous user's numbers
    loading = true;
    error = null;
    notifyListeners();
    try {
      data = await _api.dashboard();
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Unable to load the dashboard. Please try again.';
    }
    loading = false;
    notifyListeners();
  }
}
