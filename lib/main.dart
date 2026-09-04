import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/utils/api_logger.dart';
import 'data/supabase/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: 'assets/config.env');
  } catch (_) {
    await dotenv.load(fileName: 'assets/config.env.example');
  }

  if (AppConfig.isConfigured) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
      debug: kDebugMode,
      httpClient: kDebugMode ? LoggingHttpClient() : null,
    );
    ApiLogger.info('Supabase initialized → ${AppConfig.supabaseUrl}');
  }

  runApp(const ProviderScope(child: WorkPulseApp()));
}
