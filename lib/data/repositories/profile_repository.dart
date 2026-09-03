import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/enums.dart';
import '../models/profile.dart';
import '../supabase/app_config.dart';

class ProfileRepository {
  SupabaseClient get _client => SupabaseProvider.client;

  Future<Profile?> getById(String id) async {
    final row = await _client.from('profiles').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return Profile.fromMap(row);
  }

  Future<List<Profile>> listUsers({String? clientId}) async {
    var query = _client.from('profiles').select().eq('role', 'user');
    if (clientId != null) {
      query = query.eq('client_id', clientId);
    }
    final rows = await query.order('created_at', ascending: false);
    return (rows as List).map((e) => Profile.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<List<Profile>> listClients() async {
    final rows = await _client
        .from('profiles')
        .select()
        .eq('role', 'client')
        .order('name');
    return (rows as List).map((e) => Profile.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<List<Profile>> listAllProfiles() async {
    final rows = await _client.from('profiles').select().order('name');
    return (rows as List).map((e) => Profile.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<Profile> updateProfile({
    required String id,
    required String name,
    String? mobile,
    String? photoUrl,
    String? clientId,
    bool? isActive,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'mobile': mobile,
    };
    if (photoUrl != null) payload['photo_url'] = photoUrl;
    if (clientId != null) payload['client_id'] = clientId;
    if (isActive != null) payload['is_active'] = isActive;
    final row = await _client.from('profiles').update(payload).eq('id', id).select().single();
    return Profile.fromMap(row);
  }

  Future<void> setStandby(String id, StandbyStatus status) async {
    await _client.from('profiles').update({
      'standby_status': status.db,
    }).eq('id', id);
  }

  Future<void> setLocation({
    required String id,
    required double lat,
    required double lng,
  }) async {
    await _client.from('profiles').update({
      'last_lat': lat,
      'last_lng': lng,
      'last_location_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  Future<String> uploadAvatar(String userId, File file) async {
    final ext = file.path.split('.').last.toLowerCase();
    final path = '$userId/${const Uuid().v4()}.$ext';
    await _client.storage.from('avatars').upload(
          path,
          file,
          fileOptions: const FileOptions(upsert: true),
        );
    return _client.storage.from('avatars').getPublicUrl(path);
  }

  Future<Map<String, dynamic>> dashboardStats({String? clientId}) async {
    var usersQuery = _client.from('profiles').select('id, is_active, standby_status, role, client_id');
    var jobsQuery = _client.from('jobs').select('id, status, client_id');
    var companiesQuery = _client.from('companies').select('id, client_id');
    var leavesQuery = _client.from('leaves').select('id, status, user_id');

    if (clientId != null) {
      usersQuery = usersQuery.eq('client_id', clientId);
      jobsQuery = jobsQuery.eq('client_id', clientId);
      companiesQuery = companiesQuery.eq('client_id', clientId);
    }

    final users = await usersQuery;
    final jobs = await jobsQuery;
    final companies = await companiesQuery;
    final leaves = await leavesQuery;

    final userRows = (users as List).cast<Map<String, dynamic>>();
    final fieldUsers = userRows.where((u) => u['role'] == 'user').toList();
    final jobRows = (jobs as List).cast<Map<String, dynamic>>();
    final leaveRows = (leaves as List).cast<Map<String, dynamic>>();

    final fieldIds = fieldUsers.map((u) => u['id'] as String).toSet();
    final scopedLeaves = clientId == null
        ? leaveRows
        : leaveRows.where((l) => fieldIds.contains(l['user_id'])).toList();

    return {
      'totalUsers': fieldUsers.length,
      'activeUsers': fieldUsers.where((u) => u['is_active'] == true).length,
      'inactiveUsers': fieldUsers.where((u) => u['is_active'] != true).length,
      'onDuty': fieldUsers.where((u) => u['standby_status'] == 'in').length,
      'jobs': jobRows.length,
      'pendingReview': jobRows.where((j) => j['status'] == 'pending_review').length,
      'companies': (companies as List).length,
      'pendingLeaves': scopedLeaves.where((l) => l['status'] == 'pending').length,
    };
  }

  Future<void> createUserViaFunction({
    required String email,
    required String password,
    required String name,
    String? mobile,
    String? photoUrl,
    String? clientId,
  }) async {
    final response = await _client.functions.invoke(
      'admin-users',
      body: {
        'action': 'create',
        'email': email,
        'password': password,
        'name': name,
        'mobile': mobile,
        'photo_url': photoUrl,
        'client_id': ?clientId,
      },
    );
    if (response.status >= 400) {
      throw Exception(_functionError(response.data) ?? 'Failed to create user');
    }
  }

  Future<void> createClientViaFunction({
    required String email,
    required String password,
    required String name,
    String? mobile,
    String? photoUrl,
  }) async {
    final response = await _client.functions.invoke(
      'admin-users',
      body: {
        'action': 'create_client',
        'email': email,
        'password': password,
        'name': name,
        'mobile': mobile,
        'photo_url': photoUrl,
      },
    );
    if (response.status >= 400) {
      throw Exception(_functionError(response.data) ?? 'Failed to create client');
    }
  }

  Future<void> deleteUserViaFunction(String userId) async {
    final response = await _client.functions.invoke(
      'admin-users',
      body: {'action': 'delete', 'user_id': userId},
    );
    if (response.status >= 400) {
      throw Exception(_functionError(response.data) ?? 'Failed to delete user');
    }
  }

  String? _functionError(dynamic data) {
    if (data is Map && data['error'] != null) return data['error'].toString();
    return data?.toString();
  }
}
