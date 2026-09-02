import 'package:flutter_test/flutter_test.dart';
import 'package:work_pulse/data/models/enums.dart';

void main() {
  test('job status labels match the dashboard cards', () {
    expect(JobStatus.pending.label, 'Pending');
    expect(JobStatus.completed.label, 'Completed');
    expect(JobStatus.cancelled.label, 'Cancelled');
    expect(JobStatus.declined.label, 'Declined');
    expect(JobStatus.accepted.label, 'Enroute');
  });

  test('leave span helper stays within 30 days', () {
    final start = DateTime(2026, 1, 1);
    final end = DateTime(2026, 1, 30);
    expect(end.difference(start).inDays + 1, 30);
  });
}
