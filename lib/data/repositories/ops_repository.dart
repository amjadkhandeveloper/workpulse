import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../models/enums.dart';
import '../models/records.dart';
import '../supabase/app_config.dart';

class AttendanceRepository {
  SupabaseClient get _client => SupabaseProvider.client;

  Future<AttendanceRecord> punch({
    required String userId,
    required AttendanceType type,
    double? lat,
    double? lng,
  }) async {
    final row = await _client.from('attendance').insert({
      'user_id': userId,
      'type': type.db,
      'at': DateTime.now().toUtc().toIso8601String(),
      'lat': lat,
      'lng': lng,
    }).select().single();
    return AttendanceRecord.fromMap(row);
  }

  Future<List<AttendanceRecord>> listForUser(String userId) async {
    final from = DateTime.now().subtract(AppConstants.attendanceLookback);
    final rows = await _client
        .from('attendance')
        .select('*, profiles(name)')
        .eq('user_id', userId)
        .gte('at', from.toUtc().toIso8601String())
        .order('at', ascending: false);
    return (rows as List)
        .map((e) => AttendanceRecord.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<AttendanceRecord>> report({
    DateTime? from,
    DateTime? to,
    String? userId,
  }) async {
    var query = _client.from('attendance').select('*, profiles(name)');
    if (from != null) {
      query = query.gte('at', from.toUtc().toIso8601String());
    }
    if (to != null) {
      query = query.lte('at', to.toUtc().toIso8601String());
    }
    if (userId != null && userId.isNotEmpty) {
      query = query.eq('user_id', userId);
    }
    final rows = await query.order('at', ascending: false);
    return (rows as List)
        .map((e) => AttendanceRecord.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}

class LeaveRepository {
  SupabaseClient get _client => SupabaseProvider.client;

  Future<List<LeaveRequest>> listForUser(String userId) async {
    final rows = await _client
        .from('leaves')
        .select('*, profiles(name)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (rows as List).map((e) => LeaveRequest.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<List<LeaveRequest>> listAll() async {
    final rows = await _client
        .from('leaves')
        .select('*, profiles(name)')
        .order('created_at', ascending: false);
    return (rows as List).map((e) => LeaveRequest.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<LeaveRequest> create({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
    required LeaveDayType dayType,
    String? reason,
  }) async {
    final row = await _client.from('leaves').insert({
      'user_id': userId,
      'start_date': _date(startDate),
      'end_date': _date(endDate),
      'day_type': dayType.db,
      'reason': reason,
      'status': 'pending',
    }).select('*, profiles(name)').single();
    return LeaveRequest.fromMap(row);
  }

  Future<LeaveRequest> setStatus({
    required String id,
    required LeaveStatus status,
    String? adminNote,
  }) async {
    final row = await _client.from('leaves').update({
      'status': status.db,
      'admin_note': adminNote,
    }).eq('id', id).select('*, profiles(name)').single();
    return LeaveRequest.fromMap(row);
  }

  String _date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class LocationRepository {
  SupabaseClient get _client => SupabaseProvider.client;

  Future<void> ping({
    required String userId,
    required double lat,
    required double lng,
    double? accuracy,
    required String context,
    String? jobId,
  }) async {
    await _client.from('location_pings').insert({
      'user_id': userId,
      'lat': lat,
      'lng': lng,
      'accuracy': accuracy,
      'context': context,
      'job_id': jobId,
    });
  }

  Future<List<Map<String, dynamic>>> latestByUser() async {
    final rows = await _client
        .from('profiles')
        .select('id, name, last_lat, last_lng, last_location_at, standby_status, role')
        .eq('role', 'user')
        .not('last_lat', 'is', null);
    return (rows as List).cast<Map<String, dynamic>>();
  }
}
