import 'package:flutter/material.dart';

import '../../data/models/enums.dart';
import '../../data/models/job.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';

class JobSummaryCard extends StatelessWidget {
  const JobSummaryCard({super.key, required this.job, required this.onTap});

  final Job job;
  final VoidCallback onTap;

  Color get _headerColor {
    if (job.status == JobStatus.completed) return AppColors.success;
    if (job.status == JobStatus.declined) return AppColors.declined;
    if (job.status == JobStatus.cancelled) return AppColors.cancelled;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Material(
        color: Colors.white,
        elevation: 3,
        shadowColor: const Color(0x22000000),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                decoration: BoxDecoration(
                  color: _headerColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(22),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.calendar_month, color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  formatJobWindow(job.startAt, job.endAt),
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Icon(Icons.chevron_right, color: _headerColor),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.apartment, color: Colors.grey.shade700),
                    const SizedBox(width: 10),
                    Text(job.customerName ?? 'Customer'),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.business, color: Colors.grey.shade800),
                    const SizedBox(width: 10),
                    Expanded(child: Text(job.company?.name ?? 'Company')),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.locationTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(child: Text(job.location ?? 'Location')),
                  ],
                ),
              ),
              if (job.status == JobStatus.completed)
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Completed',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
