import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppConfig {
  static String get supabaseUrl =>
      dotenv.maybeGet('SUPABASE_URL')?.trim() ?? '';
  static String get supabaseAnonKey =>
      dotenv.maybeGet('SUPABASE_ANON_KEY')?.trim() ?? '';

  static bool get isConfigured {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) return false;
    if (supabaseUrl.contains('YOUR_PROJECT')) return false;
    if (supabaseAnonKey.contains('YOUR_ANON_KEY')) return false;
    return true;
  }
}

class SupabaseProvider {
  static SupabaseClient get client => Supabase.instance.client;
}
