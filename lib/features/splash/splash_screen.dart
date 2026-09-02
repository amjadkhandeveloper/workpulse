import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wb_sunny_rounded, color: Colors.white, size: 88),
            SizedBox(height: 16),
            Text(
              'WORK PULSE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Know where the work is happening',
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
