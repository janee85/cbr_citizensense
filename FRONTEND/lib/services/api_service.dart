import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../core/format.dart';
import '../models/models.dart';
import 'mock_classifier.dart';

/// Mirrors the structured error from Activity 7:
/// { "error": { "code", "message", "details" } }
class ApiException implements Exception {
  final int status;
  final String code;
  final String message;
  final Map<String, dynamic> details;
  const ApiException(this.status, this.code, this.message,
      {this.details = const <String, dynamic>{}});

  String get displayMessage => details.isEmpty
      ? message
      : '$message\n${details.values.map((v) => '• $v').join('\n')}';
}

abstract class ApiService {
  void setToken(String? token);

  Future<AuthSession> login({required String email, required String password});
  Future<void> register({
    required String name,
    required String email,
    required String password,
    int? officeId,
  });
  Future<void> changePassword({required String current, required String next});

  Future<Classification> classify({required int categoryId, required String description});
  Future<Complaint> submitComplaint({
    required String title,
    required String description,
    required int categoryId,
    required int officeId,
    required int locationId,
    PickedAttachment? attachment,
  });

  /// citizen: own (EP-04), staff: office (EP-06), admin: all.
  Future<List<Complaint>> listComplaints(UserRole role);
  Future<ComplaintDetail> getComplaint(int id); // EP-05
  Future<void> updateStatus({required int id, required ComplaintStatus status, String? message}); // EP-07

  Future<DashboardData> dashboard();
  Future<ReportData> report(ReportFilter filter); // EP-08
  Future<List<UserRecord>> adminUsers();
  Future<void> setUserActive(int id, bool active);
  Future<List<OfficeSummary>> adminOffices();
  Future<List<AppNotice>> notifications();
}

// ---------------------------------------------------------------------------
// Real implementation: talks to the Flask REST API (Activity 7 contract).
// List endpoints return { "data": { "items": [ ... ] } }.
// ---------------------------------------------------------------------------
class HttpApiService implements ApiService {
  HttpApiService(this.baseUrl);
  final String baseUrl;
  String? _token;

  /// Called when an authenticated request gets 401 (expired token).
  void Function()? onUnauthorized;

  @override
  void setToken(String? token) => _token = token;

  Map<String, String> get _auth => {if (_token != null) 'Authorization': 'Bearer $_token'};
  Map<String, String> get _headers => {'Content-Type': 'application/json', ..._auth};

  Uri _u(String path, [Map<String, String>? q]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: q);

  Future<Map<String, dynamic>> _send(Future<http.Response> Function() call) async {
    http.Response r;
    try {
      r = await call().timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const ApiException(
          0, 'TIMEOUT', 'The server took too long to respond. Please try again.');
    } on http.ClientException {
      throw const ApiException(
          0, 'NETWORK_ERROR', 'Cannot reach the server. Check your connection.');
    }

    var body = <String, dynamic>{};
    if (r.body.isNotEmpty) {
      try {
        final d = jsonDecode(r.body);
        if (d is Map<String, dynamic>) body = d;
      } catch (_) {}
    }

    if (r.statusCode >= 200 && r.statusCode < 300) {
      final data = body['data'];
      return data is Map<String, dynamic> ? data : body;
    }

    if (r.statusCode == 401 && _token != null) onUnauthorized?.call();

    final e = body['error'] is Map
        ? Map<String, dynamic>.from(body['error'] as Map)
        : <String, dynamic>{};
    throw ApiException(
      r.statusCode,
      (e['code'] as String?) ?? 'SERVER_ERROR',
      (e['message'] as String?) ?? 'Something went wrong. Please try again.',
      details: e['details'] is Map
          ? Map<String, dynamic>.from(e['details'] as Map)
          : const <String, dynamic>{},
    );
  }

  Future<Map<String, dynamic>> _get(String path, [Map<String, String>? q]) =>
      _send(() => http.get(_u(path, q), headers: _headers));
  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) =>
      _send(() => http.post(_u(path), headers: _headers, body: jsonEncode(body)));
  Future<Map<String, dynamic>> _patch(String path, Map<String, dynamic> body) =>
      _send(() => http.patch(_u(path), headers: _headers, body: jsonEncode(body)));

  List<Map<String, dynamic>> _items(Map<String, dynamic> d) =>
      ((d['items'] as List?) ?? const []).map((e) => (e as Map).cast<String, dynamic>()).toList();

  @override
  Future<AuthSession> login({required String email, required String password}) async {
    final d = await _post('/api/auth/login', {'email': email, 'password': password});
    return AuthSession(
      AppUser.fromJson((d['user'] as Map).cast<String, dynamic>()),
      d['token'] as String,
    );
  }

  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
    int? officeId,
  }) async {
    await _post('/api/auth/register', {
      'name': name,
      'email': email,
      'password': password,
      if (officeId != null) 'office_id': officeId,
    });
  }

  /// NEW: POST /api/auth/change-password
  @override
  Future<void> changePassword({required String current, required String next}) async {
    await _post('/api/auth/change-password', {'current_password': current, 'new_password': next});
  }

  /// NEW: POST /api/complaints/classify (live priority preview)
  @override
  Future<Classification> classify(
      {required int categoryId, required String description}) async {
    final d = await _post('/api/complaints/classify',
        {'category_id': categoryId, 'description': description});
    return Classification.fromJson(d);
  }

  /// EP-03. Owner comes from the JWT, never from the body.
  /// With an attachment the request is multipart/form-data.
  @override
  Future<Complaint> submitComplaint({
    required String title,
    required String description,
    required int categoryId,
    required int officeId,
    required int locationId,
    PickedAttachment? attachment,
  }) async {
    final Map<String, dynamic> d;
    if (attachment == null) {
      d = await _post('/api/complaints', {
        'title': title,
        'description': description,
        'category_id': categoryId,
        'office_id': officeId,
        'location_id': locationId,
      });
    } else {
      final req = http.MultipartRequest('POST', _u('/api/complaints'))
        ..headers.addAll(_auth)
        ..fields.addAll({
          'title': title,
          'description': description,
          'category_id': '$categoryId',
          'office_id': '$officeId',
          'location_id': '$locationId',
        })
        ..files.add(http.MultipartFile.fromBytes('attachment', attachment.bytes,
            filename: attachment.name));
      d = await _send(() async => http.Response.fromStream(await req.send()));
    }
    return Complaint(
      id: (d['id'] as num).toInt(),
      title: title,
      description: description,
      categoryId: categoryId,
      officeId: officeId,
      locationId: locationId,
      status: statusFrom(d['status'] as String?),
      priority: priorityFrom(d['priority'] as String?),
      sentiment: (d['sentiment'] as String?) ?? 'neutral',
      createdAt: DateTime.now(),
      attachmentName: attachment?.name,
    );
  }

  @override
  Future<List<Complaint>> listComplaints(UserRole role) async {
    final path = switch (role) {
      UserRole.citizen => '/api/complaints',
      UserRole.staff => '/api/staff/complaints',
      UserRole.admin => '/api/admin/complaints', // NEW
    };
    return _items(await _get(path)).map(Complaint.fromJson).toList();
  }

  @override
  Future<ComplaintDetail> getComplaint(int id) async =>
      ComplaintDetail.fromJson(await _get('/api/complaints/$id'));

  @override
  Future<void> updateStatus(
      {required int id, required ComplaintStatus status, String? message}) async {
    await _patch('/api/complaints/$id/status', {
      'status': status.apiName,
      if (message != null && message.trim().isNotEmpty) 'response_message': message.trim(),
    });
  }

  /// NEW: GET /api/dashboard/summary
  @override
  Future<DashboardData> dashboard() async =>
      DashboardData.fromJson(await _get('/api/dashboard/summary'));

  @override
  Future<ReportData> report(ReportFilter f) async => ReportData.fromJson(await _get('/api/reports', {
        'days': '${f.days}',
        if (f.officeId != null) 'office_id': '${f.officeId}',
        if (f.categoryId != null) 'category_id': '${f.categoryId}',
      }));

  /// NEW: GET /api/admin/users
  @override
  Future<List<UserRecord>> adminUsers() async =>
      _items(await _get('/api/admin/users')).map(UserRecord.fromJson).toList();

  /// NEW: PATCH /api/admin/users/{id}
  @override
  Future<void> setUserActive(int id, bool active) async {
    await _patch('/api/admin/users/$id', {'active': active});
  }

  /// NEW: GET /api/admin/offices
  @override
  Future<List<OfficeSummary>> adminOffices() async =>
      _items(await _get('/api/admin/offices')).map(OfficeSummary.fromJson).toList();

  /// NEW: GET /api/notifications
  @override
  Future<List<AppNotice>> notifications() async =>
      _items(await _get('/api/notifications')).map(AppNotice.fromJson).toList();
}

// ---------------------------------------------------------------------------
// Mock implementation: lets the whole UI run before the Flask API exists.
// Demo accounts (password123): citizen@gmail.com, staff@staff.com (Engineering),
// health@staff.com (Health), admin@admin.com
// ---------------------------------------------------------------------------
class _MockUser {
  final int id;
  final String name;
  String password;
  final UserRole role;
  final int? officeId;
  bool active;
  _MockUser(this.id, this.name, this.password, this.role, this.officeId, [this.active = true]);
}

class MockApiService implements ApiService {
  final Map<String, _MockUser> _users = {
    'citizen@gmail.com': _MockUser(1, 'Juan Dela Cruz', 'password123', UserRole.citizen, null),
    'staff@staff.com': _MockUser(2, 'Maria Santos', 'password123', UserRole.staff, 1),
    'health@staff.com': _MockUser(4, 'Pedro Reyes', 'password123', UserRole.staff, 2),
    'admin@admin.com': _MockUser(3, 'Admin CitizenSense', 'password123', UserRole.admin, null),
    'ana@gmail.com': _MockUser(5, 'Ana Lopez', 'password123', UserRole.citizen, null),
  };
  late final List<Complaint> _complaints = _seed();
  final Map<int, List<ResponseEntry>> _responses = {};
  final Map<int, List<HistoryEntry>> _history = {};
  int _nextId = 125;
  int _nextUserId = 10;
  AppUser? _me;

  MockApiService() {
    for (final c in _complaints) {
      _initTrail(c);
    }
  }

  Future<void> _lag([int ms = 500]) => Future.delayed(Duration(milliseconds: ms));

  AppUser _need() {
    final me = _me;
    if (me == null) throw const ApiException(401, 'UNAUTHORIZED', 'Please log in again.');
    return me;
  }

  Complaint? _find(int id) {
    for (final c in _complaints) {
      if (c.id == id) return c;
    }
    return null;
  }

  void _initTrail(Complaint c) {
    const chain = [
      ComplaintStatus.submitted, ComplaintStatus.received, ComplaintStatus.inProgress,
      ComplaintStatus.resolved, ComplaintStatus.closed,
    ];
    final now = DateTime.now();
    final idx = chain.indexOf(c.status);
    final hist = <HistoryEntry>[];
    for (var i = 0; i <= idx; i++) {
      var at = c.createdAt.add(Duration(hours: i * 6));
      if (at.isAfter(now)) at = now;
      hist.add(HistoryEntry(
        chain[i],
        i == 0 ? 'Complaint submitted.' : 'Status changed to ${chain[i].label}.',
        i == 0 ? (c.citizenName.isEmpty ? 'Citizen' : c.citizenName) : 'Maria Santos',
        at,
      ));
    }
    _history[c.id] = hist;
    _responses[c.id] = idx >= 2
        ? [ResponseEntry('Our team has scheduled an inspection for this concern.', 'Maria Santos', hist[2].at)]
        : <ResponseEntry>[];
  }

  Iterable<Complaint> _visible(AppUser me) {
    if (me.role == UserRole.citizen) return _complaints.where((c) => c.citizenEmail == me.email);
    if (me.role == UserRole.staff) return _complaints.where((c) => c.officeId == me.officeId);
    return _complaints;
  }

  @override
  void setToken(String? token) {
    if (token == null) _me = null;
  }

  @override
  Future<AuthSession> login({required String email, required String password}) async {
    await _lag();
    final key = email.trim().toLowerCase();
    final u = _users[key];
    if (u == null || u.password != password) {
      throw const ApiException(401, 'INVALID_CREDENTIALS', 'Incorrect email or password.');
    }
    if (!u.active) {
      throw const ApiException(403, 'ACCOUNT_DISABLED', 'This account has been deactivated. Contact an administrator.');
    }
    _me = AppUser(id: u.id, name: u.name, email: key, role: u.role, officeId: u.officeId);
    return AuthSession(_me!, 'mock-token-${u.id}');
  }

  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
    int? officeId,
  }) async {
    await _lag();
    final key = email.trim().toLowerCase();
    final errs = <String, dynamic>{};
    final role = roleFromEmail(key);
    if (name.trim().length < 2) errs['name'] = 'Enter your full name.';
    if (role == null) errs['email'] = 'Use a @gmail.com, @staff.com or @admin.com email.';
    if (password.length < 8) errs['password'] = 'Password must be at least 8 characters long.';
    if (role == UserRole.staff && officeId == null) errs['office_id'] = 'Select your assigned office.';
    if (errs.isNotEmpty) {
      throw ApiException(422, 'VALIDATION_ERROR', 'Some fields are invalid', details: errs);
    }
    if (_users.containsKey(key)) {
      throw const ApiException(409, 'EMAIL_TAKEN', 'This email is already registered. Try logging in instead.');
    }
    _users[key] = _MockUser(
        _nextUserId++, name.trim(), password, role!, role == UserRole.staff ? officeId : null);
  }

  @override
  Future<void> changePassword({required String current, required String next}) async {
    await _lag();
    final me = _need();
    final u = _users[me.email]!;
    if (u.password != current) {
      throw const ApiException(403, 'INVALID_CREDENTIALS', 'Your current password is incorrect.');
    }
    if (next.length < 8) {
      throw const ApiException(422, 'VALIDATION_ERROR', 'Password must be at least 8 characters long.');
    }
    u.password = next;
  }

  @override
  Future<Classification> classify(
      {required int categoryId, required String description}) async {
    await Future.delayed(const Duration(milliseconds: 450));
    return MockClassifier.classify(categoryId, description);
  }

  @override
  Future<Complaint> submitComplaint({
    required String title,
    required String description,
    required int categoryId,
    required int officeId,
    required int locationId,
    PickedAttachment? attachment,
  }) async {
    await _lag(900);
    final me = _need();
    if (me.role != UserRole.citizen) {
      throw const ApiException(403, 'FORBIDDEN', 'You are not authorized to perform this action.');
    }
    final errs = <String, dynamic>{};
    final t = title.trim();
    final d = description.trim();
    if (t.length < 5 || t.length > 100) {
      errs['title'] = 'Please enter a complaint title between 5 and 100 characters.';
    }
    if (d.length < 20) errs['description'] = 'Complaint description must contain at least 20 characters.';
    if (!kCategories.any((c) => c.id == categoryId)) errs['category_id'] = 'Selected category is invalid.';
    if (!kOffices.any((o) => o.id == officeId)) errs['office_id'] = 'Selected office is invalid.';
    if (!kBarangays.any((b) => b.id == locationId)) errs['location_id'] = 'Selected location is invalid.';
    if (attachment != null) {
      final ext = attachment.name.toLowerCase().split('.').last;
      if (!['jpg', 'jpeg', 'png', 'pdf'].contains(ext) || attachment.size > 5 * 1024 * 1024) {
        errs['attachment'] = 'Only JPG, PNG, or PDF files up to 5MB are allowed.';
      }
    }
    if (errs.isNotEmpty) {
      throw ApiException(422, 'VALIDATION_ERROR', 'Some fields are invalid', details: errs);
    }
    final dup = _complaints.any((c) =>
        c.citizenEmail == me.email &&
        c.title == t &&
        c.description == d &&
        DateTime.now().difference(c.createdAt).inSeconds < 60);
    if (dup) {
      throw const ApiException(409, 'DUPLICATE_SUBMISSION', 'This complaint appears to already be submitted.');
    }

    final result = MockClassifier.classify(categoryId, d);
    final c = Complaint(
      id: _nextId++,
      title: t,
      description: d,
      categoryId: categoryId,
      officeId: officeId,
      locationId: locationId,
      status: ComplaintStatus.submitted,
      priority: result.priority,
      sentiment: result.sentiment,
      createdAt: DateTime.now(),
      citizenName: me.name,
      citizenEmail: me.email,
      attachmentName: attachment?.name,
    );
    _complaints.add(c);
    _history[c.id] = [HistoryEntry(ComplaintStatus.submitted, 'Complaint submitted.', me.name, c.createdAt)];
    _responses[c.id] = <ResponseEntry>[];
    return c;
  }

  @override
  Future<List<Complaint>> listComplaints(UserRole role) async {
    await _lag(400);
    final me = _need();
    return _visible(me).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<ComplaintDetail> getComplaint(int id) async {
    await _lag(350);
    final me = _need();
    final c = _find(id);
    if (c == null || (me.role == UserRole.citizen && c.citizenEmail != me.email)) {
      throw const ApiException(404, 'NOT_FOUND', 'Complaint not found.');
    }
    if (me.role == UserRole.staff && c.officeId != me.officeId) {
      throw const ApiException(403, 'FORBIDDEN', 'This complaint is assigned to another office.');
    }
    final ml = MockClassifier.classify(c.categoryId, c.description);
    return ComplaintDetail(
      complaint: c,
      locationName: kBarangays.firstWhere((b) => b.id == c.locationId, orElse: () => kBarangays.first).name,
      confidence: ml.confidence,
      keywords: ml.keywords,
      responses: List.of(_responses[id] ?? const []),
      history: List.of(_history[id] ?? const []),
    );
  }

  @override
  Future<void> updateStatus(
      {required int id, required ComplaintStatus status, String? message}) async {
    await _lag(700);
    final me = _need();
    final c = _find(id);
    if (c == null) throw const ApiException(404, 'NOT_FOUND', 'Complaint not found.');
    if (me.role != UserRole.staff || c.officeId != me.officeId) {
      throw const ApiException(403, 'FORBIDDEN', 'You are not authorized to update this complaint.');
    }
    final msg = (message ?? '').trim();
    if (msg.length > 500) {
      throw ApiException(422, 'VALIDATION_ERROR', 'Some fields are invalid',
          details: {'response_message': 'Keep the response under 500 characters.'});
    }
    if (!allowedNext(c.status).contains(status)) {
      throw ApiException(409, 'INVALID_TRANSITION',
          'A complaint that is ${c.status.label} cannot move to ${status.label}.');
    }
    _complaints[_complaints.indexOf(c)] = c.copyWith(status: status);
    final now = DateTime.now();
    _history[id]!.add(HistoryEntry(status, msg.isEmpty ? 'Status changed to ${status.label}.' : msg, me.name, now));
    if (msg.isNotEmpty) _responses[id]!.add(ResponseEntry(msg, me.name, now));
  }

  @override
  Future<DashboardData> dashboard() async {
    await _lag(500);
    final me = _need();
    final list = _visible(me).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int backOf(Complaint c) => today
        .difference(DateTime(c.createdAt.year, c.createdAt.month, c.createdAt.day))
        .inDays;
    bool isPending(Complaint c) =>
        c.status == ComplaintStatus.submitted || c.status == ComplaintStatus.received;
    bool isProgress(Complaint c) => c.status == ComplaintStatus.inProgress;
    bool isSolved(Complaint c) => !c.status.isOpen;
    int count(bool Function(Complaint) test, int from, int to) =>
        list.where((c) => test(c) && backOf(c) >= from && backOf(c) <= to).length;
    int delta(int cur, int prev) =>
        prev == 0 ? (cur > 0 ? 100 : 0) : (((cur - prev) / prev) * 100).round();

    final labels = <String>[];
    final pendingSeries = <double>[];
    final progressSeries = <double>[];
    for (var back = 13; back >= 0; back--) {
      labels.add(shortDay(today.subtract(Duration(days: back))));
      pendingSeries.add(count(isPending, back, back).toDouble());
      progressSeries.add(count(isProgress, back, back).toDouble());
    }

    final solvedAll = list.where(isSolved).length;
    final byCat = <int, int>{};
    for (final c in list) {
      byCat[c.categoryId] = (byCat[c.categoryId] ?? 0) + 1;
    }
    final top = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return DashboardData(
      pending: count(isPending, 0, 6),
      inProgress: count(isProgress, 0, 6),
      solved: count(isSolved, 0, 6),
      pendingDelta: delta(count(isPending, 0, 6), count(isPending, 7, 13)),
      inProgressDelta: delta(count(isProgress, 0, 6), count(isProgress, 7, 13)),
      solvedDelta: delta(count(isSolved, 0, 6), count(isSolved, 7, 13)),
      serviceLevel: list.isEmpty ? 0 : double.parse((solvedAll / list.length * 100).toStringAsFixed(1)),
      serviceTarget: 75,
      feedbackRating: 4.6, // sample value until a feedback feature exists
      chartLabels: labels,
      pendingSeries: pendingSeries,
      inProgressSeries: progressSeries,
      recent: list.take(5).toList(),
      categories: top
          .take(4)
          .map((e) => CategoryShare(categoryById(e.key).name, (e.value / list.length * 100).round()))
          .toList(),
    );
  }

  @override
  Future<ReportData> report(ReportFilter f) async {
    await _lag(600);
    final me = _need();
    if (me.role != UserRole.admin) {
      throw const ApiException(403, 'FORBIDDEN', 'Only administrators can view reports.');
    }
    final since = f.days == 0 ? null : DateTime.now().subtract(Duration(days: f.days));
    final rows = _complaints.where((c) =>
        (since == null || c.createdAt.isAfter(since)) &&
        (f.officeId == null || c.officeId == f.officeId) &&
        (f.categoryId == null || c.categoryId == f.categoryId)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    List<LabelCount> tally<K>(K Function(Complaint) key, String Function(K) name, List<K> order) =>
        order
            .map((k) => LabelCount(name(k), rows.where((c) => key(c) == k).length))
            .where((e) => e.count > 0)
            .toList();

    return ReportData(
      total: rows.length,
      open: rows.where((c) => c.status.isOpen).length,
      resolved: rows.where((c) => !c.status.isOpen).length,
      byCategory: tally<int>((c) => c.categoryId, (k) => categoryById(k).name, kCategories.map((c) => c.id).toList())
        ..sort((a, b) => b.count.compareTo(a.count)),
      byOffice: tally<int>((c) => c.officeId, (k) => officeById(k).shortName, kOffices.map((o) => o.id).toList())
        ..sort((a, b) => b.count.compareTo(a.count)),
      byPriority: tally<Priority>((c) => c.priority, (k) => k.name[0].toUpperCase() + k.name.substring(1), Priority.values),
      byStatus: tally<ComplaintStatus>((c) => c.status, (k) => k.label, ComplaintStatus.values),
      rows: rows,
    );
  }

  @override
  Future<List<UserRecord>> adminUsers() async {
    await _lag(400);
    if (_need().role != UserRole.admin) {
      throw const ApiException(403, 'FORBIDDEN', 'Only administrators can manage users.');
    }
    return _users.entries
        .map((e) => UserRecord(e.value.id, e.value.name, e.key, e.value.role, e.value.officeId, e.value.active))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Future<void> setUserActive(int id, bool active) async {
    await _lag(300);
    final me = _need();
    if (me.role != UserRole.admin) {
      throw const ApiException(403, 'FORBIDDEN', 'Only administrators can manage users.');
    }
    for (final e in _users.entries) {
      if (e.value.id == id) {
        if (e.key == me.email) {
          throw const ApiException(409, 'CONFLICT', 'You cannot deactivate your own account.');
        }
        e.value.active = active;
        return;
      }
    }
    throw const ApiException(404, 'NOT_FOUND', 'User not found.');
  }

  @override
  Future<List<OfficeSummary>> adminOffices() async {
    await _lag(400);
    if (_need().role != UserRole.admin) {
      throw const ApiException(403, 'FORBIDDEN', 'Only administrators can view offices.');
    }
    return kOffices.map((o) {
      final mine = _complaints.where((c) => c.officeId == o.id);
      return OfficeSummary(
        o.id,
        o.name,
        _users.values.where((u) => u.role == UserRole.staff && u.officeId == o.id).length,
        mine.where((c) => c.status.isOpen).length,
        mine.length,
      );
    }).toList();
  }

  @override
  Future<List<AppNotice>> notifications() async {
    await _lag(300);
    final me = _need();
    final out = <AppNotice>[];
    if (me.role == UserRole.citizen) {
      for (final c in _visible(me)) {
        for (final h in _history[c.id] ?? const <HistoryEntry>[]) {
          if (h.status != ComplaintStatus.submitted) {
            out.add(AppNotice('Complaint #${c.id} is now ${h.status.label}.', h.at, c.id));
          }
        }
      }
    } else if (me.role == UserRole.staff) {
      final cutoff = DateTime.now().subtract(const Duration(days: 3));
      for (final c in _visible(me)) {
        if (c.status == ComplaintStatus.submitted && c.createdAt.isAfter(cutoff)) {
          out.add(AppNotice('New ${c.priority.name} priority complaint: ${c.title}', c.createdAt, c.id));
        }
      }
    }
    out.sort((a, b) => b.at.compareTo(a.at));
    return out.take(8).toList();
  }

  static const _sampleTitles = <int, String>{
    1: 'Pothole along the national highway',
    2: 'Streetlight not working near the plaza',
    3: 'Canal overflowing after the rain',
    4: 'Garbage not collected for days',
    5: 'Request for a health center visit',
    6: 'Suspicious activity near the market',
    7: 'Traffic jam at the school entrance',
    8: 'Assistance request for a senior citizen',
    9: 'Loud videoke past midnight',
    10: 'General concern about a public facility',
  };

  static List<Complaint> _seed() {
    const statuses = [
      ComplaintStatus.resolved, ComplaintStatus.resolved, ComplaintStatus.inProgress,
      ComplaintStatus.closed, ComplaintStatus.submitted, ComplaintStatus.resolved,
      ComplaintStatus.received, ComplaintStatus.closed, ComplaintStatus.resolved,
      ComplaintStatus.inProgress,
    ];
    final now = DateTime.now();
    return List.generate(24, (i) {
      final cat = (i * 3) % 10 + 1;
      final back = (i * 5) % 14;
      final priority = Priority.values[(i * 7) % 4];
      final title = _sampleTitles[cat]!;
      final ana = i % 6 == 5; // a few complaints belong to another citizen
      return Complaint(
        id: 100 + i,
        title: title,
        description: '$title. This has been going on for several days and residents are asking for action.',
        categoryId: cat,
        officeId: categoryById(cat).officeId,
        locationId: (i % 12) + 1,
        status: statuses[i % 10],
        priority: priority,
        sentiment: priority.index >= 2 ? 'negative' : 'neutral',
        createdAt: now.subtract(Duration(days: back, hours: (i * 7) % 9, minutes: (i * 11) % 60)),
        citizenName: ana ? 'Ana Lopez' : 'Juan Dela Cruz',
        citizenEmail: ana ? 'ana@gmail.com' : 'citizen@gmail.com',
      );
    });
  }
}
