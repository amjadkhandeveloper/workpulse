import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/models/enums.dart';

class AdminLeavesScreen extends ConsumerWidget {
  const AdminLeavesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaves = ref.watch(adminLeavesProvider);
    return leaves.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyView(message: '$e'),
      data: (items) {
        if (items.isEmpty) return const EmptyView(message: 'No leave requests.');
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(adminLeavesProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final leave = items[i];
              return Card(
                child: ListTile(
                  title: Text(leave.userName ?? 'User'),
                  subtitle: Text(
                    '${dateShort.format(leave.startDate)} – ${dateShort.format(leave.endDate)}\n'
                    '${leave.dayType.label} • ${leave.status.name}\n${leave.reason ?? ''}',
                  ),
                  isThreeLine: true,
                  trailing: leave.status == LeaveStatus.pending
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.close, color: AppColors.declined),
                              onPressed: () => _set(ref, leave.id, LeaveStatus.rejected),
                            ),
                            IconButton(
                              icon: const Icon(Icons.check, color: AppColors.success),
                              onPressed: () => _set(ref, leave.id, LeaveStatus.approved),
                            ),
                          ],
                        )
                      : Text(leave.status.name),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _set(WidgetRef ref, String id, LeaveStatus status) async {
    await ref.read(leaveRepositoryProvider).setStatus(id: id, status: status);
    ref.invalidate(adminLeavesProvider);
    ref.invalidate(adminStatsProvider);
  }
}
