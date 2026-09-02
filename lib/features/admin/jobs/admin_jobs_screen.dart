import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/job_summary_card.dart';
import '../../../data/models/enums.dart';

class AdminJobsScreen extends ConsumerStatefulWidget {
  const AdminJobsScreen({super.key});

  @override
  ConsumerState<AdminJobsScreen> createState() => _AdminJobsScreenState();
}

class _AdminJobsScreenState extends ConsumerState<AdminJobsScreen> {
  JobStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final jobs = ref.watch(adminJobsProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => context.push('/admin/jobs/new'),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _chip('All', null),
                ...JobStatus.values.map((s) => _chip(s.label, s)),
              ],
            ),
          ),
          Expanded(
            child: jobs.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => EmptyView(message: '$e'),
              data: (items) {
                final filtered = _filter == null
                    ? items
                    : items.where((j) => j.status == _filter).toList();
                if (filtered.isEmpty) return const EmptyView(message: 'No jobs in this filter.');
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(adminJobsProvider),
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final job = filtered[i];
                      return JobSummaryCard(
                        job: job,
                        onTap: () {
                          if (job.status == JobStatus.pendingReview) {
                            context.push('/admin/jobs/${job.id}/review');
                          } else {
                            context.push('/admin/jobs/${job.id}');
                          }
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, JobStatus? status) {
    final selected = _filter == status;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: AppColors.primaryLight,
        onSelected: (_) => setState(() => _filter = status),
      ),
    );
  }
}
