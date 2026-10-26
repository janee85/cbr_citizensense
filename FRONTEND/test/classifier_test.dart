import 'package:cbr_citizensense/core/constants.dart';
import 'package:cbr_citizensense/models/models.dart';
import 'package:cbr_citizensense/services/mock_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  statusTests();
  test('role is decided by email domain', () {
    expect(roleFromEmail('juan@gmail.com'), UserRole.citizen);
    expect(roleFromEmail('maria@staff.com'), UserRole.staff);
    expect(roleFromEmail('boss@admin.com'), UserRole.admin);
    expect(roleFromEmail('x@yahoo.com'), isNull);
    expect(roleFromEmail('@gmail.com'), isNull);
  });

  test('streetlight off for a week and unsafe is High', () {
    final r = MockClassifier.classify(2,
        'The streetlight near the barangay hall has been off for a week, making the area unsafe at night.');
    expect(r.priority, Priority.high);
    expect(r.officeId, 1);
  });

  test('fire report is Critical', () {
    final r = MockClassifier.classify(6, 'May sunog sa palengke, delikado kaayo');
    expect(r.priority, Priority.critical);
  });

  test('plain noise complaint is Low', () {
    final r = MockClassifier.classify(9, 'Medyo kusog ang tugtog sa kasilinganan karon.');
    expect(r.priority, Priority.low);
  });

  test('category alone gives a baseline result', () {
    final r = MockClassifier.classify(3, '');
    expect(r.categoryOnly, isTrue);
  });
}

void statusTests() {
  group('status transitions', () {
    test('closed has no next status', () {
      expect(allowedNext(ComplaintStatus.closed), isEmpty);
    });
    test('submitted cannot jump straight to closed', () {
      expect(allowedNext(ComplaintStatus.submitted), isNot(contains(ComplaintStatus.closed)));
    });
    test('in progress can only be resolved', () {
      expect(allowedNext(ComplaintStatus.inProgress), [ComplaintStatus.resolved]);
    });
  });
}
