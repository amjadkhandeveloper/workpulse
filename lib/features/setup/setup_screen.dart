import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.settings_suggest, size: 64, color: AppColors.primary),
            const SizedBox(height: 16),
            const Text(
              'Connect Supabase',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const Text(
              'Set SUPABASE_URL and SUPABASE_ANON_KEY in assets/config.env.example, then restart the app.\n\nRun supabase/schema.sql in the SQL editor and deploy supabase/functions/admin-users.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
