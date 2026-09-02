import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/models/enums.dart';

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(userAttendanceProvider);
    return records.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyView(message: '$e'),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyView(message: 'No attendance in the last 2 months.');
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(userAttendanceProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final row = items[i];
              final inPunch = row.type.db == 'standby_in';
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: inPunch ? AppColors.success : AppColors.primary,
                    child: Icon(inPunch ? Icons.login : Icons.logout, color: Colors.white),
                  ),
                  title: Text(row.type.label),
                  subtitle: Text(dateFull.format(row.at.toLocal())),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
