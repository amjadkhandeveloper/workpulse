import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/enums.dart';
import '../models/job.dart';
import '../supabase/app_config.dart';

const _jobSelect =
    '*, companies(*), assignee:profiles!jobs_assigned_to_fkey(*)';

class JobRepository {
  SupabaseClient get _client => SupabaseProvider.client;

  Future<List<Job>> listAll() async {
    final rows = await _client.from('jobs').select(_jobSelect).order('created_at', ascending: false);
    return (rows as List).map((e) => Job.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<List<Job>> listForUser(String userId) async {
    final rows = await _client
        .from('jobs')
        .select(_jobSelect)
        .eq('assigned_to', userId)
        .order('start_at', ascending: false);
    return (rows as List).map((e) => Job.fromMap(e as Map<String, dynamic>)).toList();
  }

  Stream<List<Job>> watchForUser(String userId) {
    return _client
        .from('jobs')
        .stream(primaryKey: ['id'])
        .eq('assigned_to', userId)
        .order('start_at', ascending: false)
        .asyncMap((rows) async {
          if (rows.isEmpty) return <Job>[];
          final ids = rows.map((e) => e['id']).toList();
          final full = await _client.from('jobs').select(_jobSelect).inFilter('id', ids);
          return (full as List).map((e) => Job.fromMap(e as Map<String, dynamic>)).toList();
        });
  }

  Future<Job> getById(String id) async {
    final row = await _client.from('jobs').select(_jobSelect).eq('id', id).single();
    return Job.fromMap(row);
  }

  Future<Job> create(Map<String, dynamic> data) async {
    final row = await _client.from('jobs').insert(data).select(_jobSelect).single();
    return Job.fromMap(row);
  }

  Future<Job> update(String id, Map<String, dynamic> data) async {
    final row = await _client.from('jobs').update(data).eq('id', id).select(_jobSelect).single();
    return Job.fromMap(row);
  }

  Future<void> delete(String id) async {
    await _client.from('jobs').delete().eq('id', id);
  }

  Future<Job> setStatus(String id, JobStatus status, {Map<String, dynamic>? extra}) async {
    return update(id, {
      'status': status.db,
      ...?extra,
    });
  }

  Future<List<JobProof>> listProofs(String jobId) async {
    final rows = await _client
        .from('job_proofs')
        .select()
        .eq('job_id', jobId)
        .order('sort_order');
    return (rows as List).map((e) => JobProof.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<String> uploadProof({
    required String jobId,
    required File file,
    required ProofKind kind,
    required int sortOrder,
  }) async {
    final ext = file.path.split('.').last.toLowerCase();
    final path = '$jobId/${kind.name}_$sortOrder${const Uuid().v4()}.$ext';
    await _client.storage.from('job-proofs').upload(path, file);
    await _client.from('job_proofs').insert({
      'job_id': jobId,
      'kind': kind == ProofKind.signature ? 'signature' : 'photo',
      'storage_path': path,
      'sort_order': sortOrder,
    });
    return path;
  }

  Future<String> signedProofUrl(String storagePath) async {
    return _client.storage.from('job-proofs').createSignedUrl(storagePath, 60 * 60);
  }

  Future<List<Job>> report({
    DateTime? from,
    DateTime? to,
    String? userId,
    String? companyId,
    String? status,
  }) async {
    final all = await listAll();
    return all.where((job) {
      if (from != null && job.startAt.isBefore(from)) return false;
      if (to != null && job.startAt.isAfter(to)) return false;
      if (userId != null && userId.isNotEmpty && job.assignedTo != userId) return false;
      if (companyId != null && companyId.isNotEmpty && job.companyId != companyId) {
        return false;
      }
      if (status != null && status.isNotEmpty && job.status.db != status) return false;
      return true;
    }).toList();
  }
}
