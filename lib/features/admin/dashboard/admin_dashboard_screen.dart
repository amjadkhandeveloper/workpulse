import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(adminStatsProvider);
    return stats.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyView(message: '$e'),
      data: (data) {
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(adminStatsProvider);
            ref.invalidate(liveUsersProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _stat('Users', data['totalUsers'], Icons.people, AppColors.primary),
                  _stat('Active', data['activeUsers'], Icons.check_circle, AppColors.success),
                  _stat('Inactive', data['inactiveUsers'], Icons.person_off, AppColors.declined),
                  _stat('On duty', data['onDuty'], Icons.wifi_tethering, AppColors.pending),
                  _stat('Jobs', data['jobs'], Icons.work, AppColors.cancelled),
                  _stat('Companies', data['companies'], Icons.apartment, AppColors.primaryDark),
                  _stat('Review', data['pendingReview'], Icons.rate_review, AppColors.primary),
                  _stat('Leaves', data['pendingLeaves'], Icons.event, AppColors.pending),
                ],
              ),
              const SizedBox(height: 20),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                tileColor: Colors.white,
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  child: Icon(Icons.map, color: AppColors.primary),
                ),
                title: const Text('Live field map'),
                subtitle: const Text('See where users are right now'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/admin/map'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _stat(String label, Object? value, IconData icon, Color color) {
    return SizedBox(
      width: 160,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text('$value', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            Text(label, style: const TextStyle(color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
