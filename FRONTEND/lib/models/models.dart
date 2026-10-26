import 'dart:typed_data';

import '../core/constants.dart';

DateTime _dt(dynamic v) =>
    DateTime.tryParse((v as String?) ?? '')?.toLocal() ?? DateTime.now();

class AppUser {
  final int id;
  final String name;
  final String email;
  final UserRole role;
  final int? officeId; // staff only: assigned office

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.officeId,
  });

  String get firstName {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? name : parts.first;
  }

  String get initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String,
        email: j['email'] as String,
        role: UserRole.values.firstWhere((r) => r.name == j['role'],
            orElse: () => UserRole.citizen),
        officeId: (j['office_id'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role.name,
        if (officeId != null) 'office_id': officeId,
      };
}

class AuthSession {
  final AppUser user;
  final String token;
  const AuthSession(this.user, this.token);
}

/// A file chosen for upload (JPG/PNG/PDF, max 5 MB).
class PickedAttachment {
  final String name;
  final Uint8List bytes;
  const PickedAttachment(this.name, this.bytes);
  int get size => bytes.length;
}

enum Priority { low, medium, high, critical }

Priority priorityFrom(String? s) => Priority.values.firstWhere(
    (p) => p.name == (s ?? '').toLowerCase(),
    orElse: () => Priority.low);

enum ComplaintStatus { submitted, received, inProgress, resolved, closed }

extension ComplaintStatusX on ComplaintStatus {
  String get label => switch (this) {
        ComplaintStatus.submitted => 'Submitted',
        ComplaintStatus.received => 'Received',
        ComplaintStatus.inProgress => 'In Progress',
        ComplaintStatus.resolved => 'Resolved',
        ComplaintStatus.closed => 'Closed',
      };
  String get apiName => this == ComplaintStatus.inProgress ? 'in_progress' : name;
  bool get isOpen => this != ComplaintStatus.resolved && this != ComplaintStatus.closed;
}

ComplaintStatus statusFrom(String? s) => ComplaintStatus.values.firstWhere(
    (x) => x.apiName == s,
    orElse: () => ComplaintStatus.submitted);

/// Legal status transitions (used by EP-07; the server enforces them too with 409).
List<ComplaintStatus> allowedNext(ComplaintStatus s) => switch (s) {
      ComplaintStatus.submitted => const [ComplaintStatus.received, ComplaintStatus.inProgress],
      ComplaintStatus.received => const [ComplaintStatus.inProgress, ComplaintStatus.resolved],
      ComplaintStatus.inProgress => const [ComplaintStatus.resolved],
      ComplaintStatus.resolved => const [ComplaintStatus.closed, ComplaintStatus.inProgress],
      ComplaintStatus.closed => const <ComplaintStatus>[],
    };

/// Result of the NLP/ML component: category, sentiment, priority.
class Classification {
  final String category;
  final String sentiment; // negative | neutral | positive
  final Priority priority;
  final double confidence; // 0..1
  final int? officeId;
  final List<String> keywords;
  final bool categoryOnly;

  const Classification({
    required this.category,
    required this.sentiment,
    required this.priority,
    required this.confidence,
    this.officeId,
    this.keywords = const [],
    this.categoryOnly = false,
  });

  factory Classification.fromJson(Map<String, dynamic> j) => Classification(
        category: (j['category'] as String?) ?? '',
        sentiment: (j['sentiment'] as String?) ?? 'neutral',
        priority: priorityFrom(j['priority'] as String?),
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0,
        officeId: (j['office_id'] as num?)?.toInt(),
        keywords: List<String>.from((j['keywords'] as List?) ?? const []),
        categoryOnly: (j['category_only'] as bool?) ?? false,
      );
}

class Complaint {
  final int id;
  final String title;
  final String description;
  final int categoryId;
  final int officeId;
  final int locationId;
  final ComplaintStatus status;
  final Priority priority;
  final String sentiment;
  final DateTime createdAt;
  final String citizenName;
  final String citizenEmail;
  final String? attachmentName;

  const Complaint({
    required this.id,
    required this.title,
    required this.description,
    required this.categoryId,
    required this.officeId,
    required this.status,
    required this.priority,
    required this.sentiment,
    required this.createdAt,
    this.locationId = 0,
    this.citizenName = '',
    this.citizenEmail = '',
    this.attachmentName,
  });

  Complaint copyWith({ComplaintStatus? status}) => Complaint(
        id: id,
        title: title,
        description: description,
        categoryId: categoryId,
        officeId: officeId,
        locationId: locationId,
        status: status ?? this.status,
        priority: priority,
        sentiment: sentiment,
        createdAt: createdAt,
        citizenName: citizenName,
        citizenEmail: citizenEmail,
        attachmentName: attachmentName,
      );

  factory Complaint.fromJson(Map<String, dynamic> j) => Complaint(
        id: (j['id'] as num).toInt(),
        title: (j['title'] as String?) ?? '',
        description: (j['description'] as String?) ?? '',
        categoryId: (j['category_id'] as num?)?.toInt() ?? 10,
        officeId: (j['office_id'] as num?)?.toInt() ?? 7,
        locationId: (j['location_id'] as num?)?.toInt() ?? 0,
        status: statusFrom(j['status'] as String?),
        priority: priorityFrom(j['priority'] as String?),
        sentiment: (j['sentiment'] as String?) ?? 'neutral',
        createdAt: _dt(j['created_at']),
        citizenName: (j['citizen_name'] as String?) ?? '',
        attachmentName: j['attachment_name'] as String?,
      );
}

class ResponseEntry {
  final String message;
  final String staffName;
  final DateTime createdAt;
  const ResponseEntry(this.message, this.staffName, this.createdAt);

  factory ResponseEntry.fromJson(Map<String, dynamic> j) => ResponseEntry(
        (j['message'] as String?) ?? '',
        (j['staff_name'] as String?) ?? 'Office staff',
        _dt(j['created_at']),
      );
}

class HistoryEntry {
  final ComplaintStatus status;
  final String note;
  final String by;
  final DateTime at;
  const HistoryEntry(this.status, this.note, this.by, this.at);

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
        statusFrom(j['status'] as String?),
        (j['note'] as String?) ?? '',
        (j['by'] as String?) ?? '',
        _dt(j['at']),
      );
}

/// EP-05: complaint + ML result + responses + status history.
class ComplaintDetail {
  final Complaint complaint;
  final String locationName;
  final double confidence;
  final List<String> keywords;
  final List<ResponseEntry> responses;
  final List<HistoryEntry> history;

  const ComplaintDetail({
    required this.complaint,
    required this.locationName,
    required this.confidence,
    required this.keywords,
    required this.responses,
    required this.history,
  });

  factory ComplaintDetail.fromJson(Map<String, dynamic> j) => ComplaintDetail(
        complaint: Complaint.fromJson(j),
        locationName: (j['location'] as String?) ?? '',
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0,
        keywords: List<String>.from((j['keywords'] as List?) ?? const []),
        responses: ((j['responses'] as List?) ?? const [])
            .map((e) => ResponseEntry.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        history: ((j['history'] as List?) ?? const [])
            .map((e) => HistoryEntry.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

class CategoryShare {
  final String name;
  final int percent;
  const CategoryShare(this.name, this.percent);
}

class LabelCount {
  final String label;
  final int count;
  const LabelCount(this.label, this.count);
}

class DashboardData {
  final int pending, inProgress, solved;
  final int pendingDelta, inProgressDelta, solvedDelta;
  final double serviceLevel, serviceTarget, feedbackRating;
  final List<String> chartLabels;
  final List<double> pendingSeries, inProgressSeries;
  final List<Complaint> recent;
  final List<CategoryShare> categories;

  const DashboardData({
    required this.pending,
    required this.inProgress,
    required this.solved,
    required this.pendingDelta,
    required this.inProgressDelta,
    required this.solvedDelta,
    required this.serviceLevel,
    required this.serviceTarget,
    required this.feedbackRating,
    required this.chartLabels,
    required this.pendingSeries,
    required this.inProgressSeries,
    required this.recent,
    required this.categories,
  });

  factory DashboardData.fromJson(Map<String, dynamic> j) {
    final chart = (j['chart'] as Map?)?.cast<String, dynamic>() ?? const {};
    List<double> nums(dynamic v) =>
        ((v as List?) ?? const []).map((e) => (e as num).toDouble()).toList();
    return DashboardData(
      pending: (j['pending'] as num?)?.toInt() ?? 0,
      inProgress: (j['in_progress'] as num?)?.toInt() ?? 0,
      solved: (j['solved'] as num?)?.toInt() ?? 0,
      pendingDelta: (j['pending_delta'] as num?)?.toInt() ?? 0,
      inProgressDelta: (j['in_progress_delta'] as num?)?.toInt() ?? 0,
      solvedDelta: (j['solved_delta'] as num?)?.toInt() ?? 0,
      serviceLevel: (j['service_level'] as num?)?.toDouble() ?? 0,
      serviceTarget: (j['service_target'] as num?)?.toDouble() ?? 75,
      feedbackRating: (j['feedback_rating'] as num?)?.toDouble() ?? 0,
      chartLabels: List<String>.from((chart['labels'] as List?) ?? const []),
      pendingSeries: nums(chart['pending']),
      inProgressSeries: nums(chart['in_progress']),
      recent: ((j['recent'] as List?) ?? const [])
          .map((e) => Complaint.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      categories: ((j['categories'] as List?) ?? const [])
          .map((e) => CategoryShare(
              (e as Map)['name'] as String, (e['percent'] as num).toInt()))
          .toList(),
    );
  }
}

/// Filters for GET /api/reports (EP-08).
class ReportFilter {
  final int days; // 0 = all time
  final int? officeId;
  final int? categoryId;
  const ReportFilter({this.days = 30, this.officeId, this.categoryId});
}

class ReportData {
  final int total, open, resolved;
  final List<LabelCount> byCategory, byOffice, byPriority, byStatus;
  final List<Complaint> rows;

  const ReportData({
    required this.total,
    required this.open,
    required this.resolved,
    required this.byCategory,
    required this.byOffice,
    required this.byPriority,
    required this.byStatus,
    required this.rows,
  });

  double get serviceLevel => total == 0 ? 0 : resolved / total * 100;

  factory ReportData.fromJson(Map<String, dynamic> j) {
    List<LabelCount> lc(dynamic v) => ((v as List?) ?? const [])
        .map((e) => LabelCount((e as Map)['label'] as String, (e['count'] as num).toInt()))
        .toList();
    return ReportData(
      total: (j['total'] as num?)?.toInt() ?? 0,
      open: (j['open'] as num?)?.toInt() ?? 0,
      resolved: (j['resolved'] as num?)?.toInt() ?? 0,
      byCategory: lc(j['by_category']),
      byOffice: lc(j['by_office']),
      byPriority: lc(j['by_priority']),
      byStatus: lc(j['by_status']),
      rows: ((j['rows'] as List?) ?? const [])
          .map((e) => Complaint.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

class UserRecord {
  final int id;
  final String name;
  final String email;
  final UserRole role;
  final int? officeId;
  final bool active;
  const UserRecord(this.id, this.name, this.email, this.role, this.officeId, this.active);

  factory UserRecord.fromJson(Map<String, dynamic> j) => UserRecord(
        (j['id'] as num).toInt(),
        (j['name'] as String?) ?? '',
        (j['email'] as String?) ?? '',
        UserRole.values.firstWhere((r) => r.name == j['role'], orElse: () => UserRole.citizen),
        (j['office_id'] as num?)?.toInt(),
        (j['active'] as bool?) ?? true,
      );
}

class OfficeSummary {
  final int id;
  final String name;
  final int staffCount, openCount, totalCount;
  const OfficeSummary(this.id, this.name, this.staffCount, this.openCount, this.totalCount);

  factory OfficeSummary.fromJson(Map<String, dynamic> j) => OfficeSummary(
        (j['id'] as num).toInt(),
        (j['name'] as String?) ?? '',
        (j['staff_count'] as num?)?.toInt() ?? 0,
        (j['open_count'] as num?)?.toInt() ?? 0,
        (j['total_count'] as num?)?.toInt() ?? 0,
      );
}

class AppNotice {
  final String text;
  final DateTime at;
  final int? complaintId;
  const AppNotice(this.text, this.at, this.complaintId);

  factory AppNotice.fromJson(Map<String, dynamic> j) => AppNotice(
        (j['text'] as String?) ?? '',
        _dt(j['at']),
        (j['complaint_id'] as num?)?.toInt(),
      );
}
