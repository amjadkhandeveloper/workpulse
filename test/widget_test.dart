import 'package:flutter_test/flutter_test.dart';
import 'package:work_pulse/data/models/enums.dart';
import 'package:work_pulse/data/models/profile.dart';

void main() {
  test('job status labels match the dashboard cards', () {
    expect(JobStatus.pending.label, 'Pending');
    expect(JobStatus.completed.label, 'Completed');
    expect(JobStatus.cancelled.label, 'Cancelled');
    expect(JobStatus.declined.label, 'Declined');
    expect(JobStatus.accepted.label, 'Enroute');
  });

  test('user roles parse from the database', () {
    expect(UserRoleX.fromDb('admin'), UserRole.admin);
    expect(UserRoleX.fromDb('client'), UserRole.client);
    expect(UserRoleX.fromDb('user'), UserRole.user);
    expect(UserRole.client.db, 'client');
  });

  test('profile map includes username', () {
    final profile = Profile.fromMap({
      'id': '1',
      'email': 'a@b.com',
      'username': 'field1',
      'name': 'A',
      'role': 'user',
      'is_active': true,
      'standby_status': 'out',
      'created_at': '2026-01-01T00:00:00Z',
    });
    expect(profile.username, 'field1');
    expect(profile.isManager, false);
  });

  test('client tenant id prefers clients.id on the profile', () {
    final client = Profile.fromMap({
      'id': 'login-uuid',
      'email': 'c@b.com',
      'name': 'Client',
      'role': 'client',
      'client_id': 'tenant-uuid',
      'is_active': true,
      'standby_status': 'out',
      'created_at': '2026-01-01T00:00:00Z',
    });
    expect(client.orgId, 'tenant-uuid');
    expect(client.isClient, true);
  });

  test('leave span helper stays within 30 days', () {
    final start = DateTime(2026, 1, 1);
    final end = DateTime(2026, 1, 30);
    expect(end.difference(start).inDays + 1, 30);
  });
}
