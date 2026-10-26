import 'package:flutter/material.dart';

/// Run with: flutter run -d chrome --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=https://your-api
const bool kUseMockApi = bool.fromEnvironment('USE_MOCK', defaultValue: true);
const String kApiBaseUrl =
    String.fromEnvironment('API_BASE_URL', defaultValue: 'http://127.0.0.1:8000');

enum UserRole { citizen, staff, admin }

extension UserRoleX on UserRole {
  String get label => switch (this) {
        UserRole.citizen => 'Citizen',
        UserRole.staff => 'Office Staff',
        UserRole.admin => 'Administrator',
      };

  /// Email domain that decides the role.
  String get domain => switch (this) {
        UserRole.citizen => '@gmail.com',
        UserRole.staff => '@staff.com',
        UserRole.admin => '@admin.com',
      };

  String get home => switch (this) {
        UserRole.citizen => '/citizen/dashboard',
        UserRole.staff => '/staff/dashboard',
        UserRole.admin => '/admin/dashboard',
      };

  /// List screen for this role (Activity 6 routes).
  String get listRoute => switch (this) {
        UserRole.citizen => '/complaint-tracking',
        UserRole.staff => '/complaint-review',
        UserRole.admin => '/admin/complaints',
      };

  String get listLabel => switch (this) {
        UserRole.citizen => 'My Complaints',
        UserRole.staff => 'Assigned Complaints',
        UserRole.admin => 'Complaints',
      };

  IconData get icon => switch (this) {
        UserRole.citizen => Icons.person_outline_rounded,
        UserRole.staff => Icons.badge_outlined,
        UserRole.admin => Icons.admin_panel_settings_outlined,
      };
}

/// @gmail.com -> citizen, @staff.com -> staff, @admin.com -> admin.
UserRole? roleFromEmail(String email) {
  final e = email.trim().toLowerCase();
  for (final r in UserRole.values) {
    if (e.endsWith(r.domain) && e.length > r.domain.length) return r;
  }
  return null;
}

class Office {
  final int id;
  final String name;
  final String shortName;
  const Office(this.id, this.name, this.shortName);
}

// Replace with offices_tbl data (IT 108) once the API serves them.
const kOffices = <Office>[
  Office(1, 'City Engineering Office', 'Engineering'),
  Office(2, 'City Health Office', 'Health'),
  Office(3, 'City Environment and Natural Resources Office', 'CENRO'),
  Office(4, 'City Social Welfare and Development Office', 'Social Welfare'),
  Office(5, 'City Disaster Risk Reduction and Management Office', 'DRRMO'),
  Office(6, 'City Public Safety Office', 'Public Safety'),
  Office(7, "City Mayor's Office (General Concerns)", "Mayor's Office"),
];

Office officeById(int id) =>
    kOffices.firstWhere((o) => o.id == id, orElse: () => kOffices.last);

class ComplaintCategory {
  final int id;
  final String name;
  final IconData icon;
  final int officeId; // default office for this category
  const ComplaintCategory(this.id, this.name, this.icon, this.officeId);
}

// Replace with categories_tbl data (IT 108).
const kCategories = <ComplaintCategory>[
  ComplaintCategory(1, 'Roads & Infrastructure', Icons.construction_rounded, 1),
  ComplaintCategory(2, 'Streetlights & Electricity', Icons.lightbulb_outline_rounded, 1),
  ComplaintCategory(3, 'Drainage & Flooding', Icons.water_drop_outlined, 5),
  ComplaintCategory(4, 'Garbage & Sanitation', Icons.delete_outline_rounded, 3),
  ComplaintCategory(5, 'Health Concerns', Icons.medical_services_outlined, 2),
  ComplaintCategory(6, 'Peace, Order & Public Safety', Icons.shield_outlined, 6),
  ComplaintCategory(7, 'Traffic & Transport', Icons.traffic_outlined, 6),
  ComplaintCategory(8, 'Social Welfare & Assistance', Icons.volunteer_activism_outlined, 4),
  ComplaintCategory(9, 'Noise & Public Nuisance', Icons.volume_up_outlined, 6),
  ComplaintCategory(10, 'Other Concerns', Icons.help_outline_rounded, 7),
];

ComplaintCategory categoryById(int id) =>
    kCategories.firstWhere((c) => c.id == id, orElse: () => kCategories.last);

class Barangay {
  final int id;
  final String name;
  const Barangay(this.id, this.name);
}

// SAMPLE ONLY - replace with locations_tbl from IT 108.
const kBarangays = <Barangay>[
  Barangay(1, 'Poblacion 1'),
  Barangay(2, 'Poblacion 2'),
  Barangay(3, 'Poblacion 3'),
  Barangay(4, 'Calamba'),
  Barangay(5, 'Comagascas'),
  Barangay(6, 'Del Pilar'),
  Barangay(7, 'Katugasan'),
  Barangay(8, 'La Union'),
  Barangay(9, 'Mabini'),
  Barangay(10, 'Paraiso'),
  Barangay(11, 'Soriano'),
  Barangay(12, 'Zamora'),
];
