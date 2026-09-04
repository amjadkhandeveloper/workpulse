import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/api_logger.dart';
import '../models/profile.dart';
import '../supabase/app_config.dart';

class AuthRepository {
  SupabaseClient get _client => SupabaseProvider.client;

  Session? get currentSession => _client.auth.currentSession;
  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> authChanges() => _client.auth.onAuthStateChange;

  Future<void> signIn(String identifier, String password) async {
    final trimmed = identifier.trim();
    var email = trimmed;

    ApiLogger.info('LOGIN start identifier="$trimmed"');

    if (!trimmed.contains('@')) {
      ApiLogger.info('LOGIN resolve username → email via login_identifier_to_email');
      try {
        final resolved = await _client.rpc(
          'login_identifier_to_email',
          params: {'identifier': trimmed},
        );
        ApiLogger.info('LOGIN resolve response: $resolved');
        if (resolved is String && resolved.trim().isNotEmpty) {
          email = resolved.trim();
        }
      } catch (error, stack) {
        ApiLogger.error('LOGIN resolve username', error, stack);
        rethrow;
      }
    }

    ApiLogger.info(
      'LOGIN signInWithPassword email="$email" passwordLength=${password.length}',
    );
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      ApiLogger.info(
        'LOGIN success userId=${response.user?.id} '
        'email=${response.user?.email} '
        'role=${response.user?.appMetadata['role']} '
        'sessionExpires=${response.session?.expiresAt}',
      );
    } catch (error, stack) {
      ApiLogger.error('LOGIN signInWithPassword', error, stack);
      rethrow;
    }
  }

  Future<void> signOut() async {
    ApiLogger.info('LOGOUT');
    await _client.auth.signOut();
  }

  Future<Profile?> fetchProfile(String userId) async {
    ApiLogger.info('PROFILE fetch id=$userId');
    try {
      final row =
          await _client.from('profiles').select().eq('id', userId).maybeSingle();
      ApiLogger.info('PROFILE response: $row');
      if (row == null) return null;
      return Profile.fromMap(row);
    } catch (error, stack) {
      ApiLogger.error('PROFILE fetch', error, stack);
      rethrow;
    }
  }
}
