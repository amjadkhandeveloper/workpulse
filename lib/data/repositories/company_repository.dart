import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/company.dart';
import '../supabase/app_config.dart';

class CompanyRepository {
  SupabaseClient get _client => SupabaseProvider.client;

  Future<List<Company>> list() async {
    final rows = await _client.from('companies').select().order('name');
    return (rows as List).map((e) => Company.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<Company> create(Company company) async {
    final row = await _client.from('companies').insert(company.toInsert()).select().single();
    return Company.fromMap(row);
  }

  Future<Company> update(String id, Map<String, dynamic> data) async {
    final row = await _client.from('companies').update(data).eq('id', id).select().single();
    return Company.fromMap(row);
  }

  Future<void> delete(String id) async {
    await _client.from('companies').delete().eq('id', id);
  }
}
