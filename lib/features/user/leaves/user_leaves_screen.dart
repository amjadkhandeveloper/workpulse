import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/models/enums.dart';

class UserLeavesScreen extends ConsumerWidget {
  const UserLeavesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaves = ref.watch(userLeavesProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => context.push('/user/leaves/apply'),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: leaves.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyView(message: '$e'),
        data: (items) {
          if (items.isEmpty) return const EmptyView(message: 'No leave applications yet.');
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(userLeavesProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final leave = items[i];
                final color = switch (leave.status) {
                  LeaveStatus.approved => AppColors.success,
                  LeaveStatus.rejected => AppColors.declined,
                  LeaveStatus.pending => AppColors.pending,
                };
                return Card(
                  child: ListTile(
                    title: Text('${dateShort.format(leave.startDate)} – ${dateShort.format(leave.endDate)}'),
                    subtitle: Text('${leave.dayType.label} • ${leave.reason ?? ''}'),
                    trailing: Text(
                      leave.status.name,
                      style: TextStyle(color: color, fontWeight: FontWeight.w700),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
