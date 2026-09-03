import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import '../supabase/app_config.dart';

class AuthRepository {
  SupabaseClient get _client => SupabaseProvider.client;

  Session? get currentSession => _client.auth.currentSession;
  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> authChanges() => _client.auth.onAuthStateChange;

  Future<void> signIn(String email, String password) async {
    await _client.auth.signInWithPassword(email: email.trim(), password: password);
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<Profile?> fetchProfile(String userId) async {
    final row = await _client.from('profiles').select().eq('id', userId).maybeSingle();
    if (row == null) return null;
    return Profile.fromMap(row);
  }
}
