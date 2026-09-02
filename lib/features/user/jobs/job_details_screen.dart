import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/job.dart';

class JobDetailsScreen extends ConsumerStatefulWidget {
  const JobDetailsScreen({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends ConsumerState<JobDetailsScreen> {
  bool _busy = false;

  bool _needsStandbyOut(Job job) {
    final profile = ref.read(sessionControllerProvider).profile;
    return profile?.isOnStandby == true && job.status == JobStatus.pending;
  }

  Future<void> _setStatus(Job job, JobStatus status) async {
    if (status == JobStatus.accepted && _needsStandbyOut(job)) {
      showAppSnack(context, 'Standby out to accept this job.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final extra = <String, dynamic>{};
      if (status == JobStatus.checkedIn || status == JobStatus.accepted) {
        final fix = await ref.read(locationServiceProvider).currentFix();
        if (fix != null) {
          extra['lat'] = fix.lat;
          extra['lng'] = fix.lng;
        }
      }
      await ref.read(jobRepositoryProvider).setStatus(job.id, status, extra: extra);
      final profile = ref.read(sessionControllerProvider).profile;
      if (profile != null) {
        final jobs = await ref.read(jobRepositoryProvider).listForUser(profile.id);
        await ref.read(locationServiceProvider).sync(profile: profile, jobs: jobs);
      }
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) showAppSnack(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openMap(Job job) async {
    final query = job.lat != null
        ? '${job.lat},${job.lng}'
        : Uri.encodeComponent(job.location ?? '');
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Job>(
      future: ref.read(jobRepositoryProvider).getById(widget.jobId),
      builder: (context, snapshot) {
        final job = snapshot.data;
        if (job == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final blocked = _needsStandbyOut(job);
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: MediaQuery.paddingOf(context).top + 8,
                  left: 8,
                  right: 16,
                  bottom: 28,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => context.pop(),
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                        ),
                        const Expanded(
                          child: Text(
                            'Job Details',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const Icon(Icons.wb_sunny, color: Colors.white, size: 36),
                    const SizedBox(height: 8),
                    const Text(
                      'Have a nice day...',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (blocked)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.locationTint,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Standby out to accept this job.'),
                      ),
                    AsymmetricCard(
                      child: Column(
                        children: [
                          _row('Job ID:', job.displayId),
                          _row('Mobile Number:', job.customerMobile ?? '-'),
                          const Divider(),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    const Text('Planned Date', style: TextStyle(color: AppColors.primary)),
                                    Text(dateShort.format(job.startAt.toLocal())),
                                  ],
                                ),
                              ),
                              Container(width: 1, height: 36, color: Colors.grey.shade300),
                              Expanded(
                                child: Column(
                                  children: [
                                    const Text('Planned Time', style: TextStyle(color: AppColors.primary)),
                                    Text(timeHm.format(job.startAt.toLocal())),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    AsymmetricCard(
                      child: Column(
                        children: [
                          _row('Customer Name:', job.customerName ?? '-'),
                          _row('Company Name:', job.company?.name ?? '-'),
                          _row('Purpose:', job.purpose),
                          Row(
                            children: [
                              Expanded(child: _row('Address:', job.location ?? '-')),
                              IconButton(
                                onPressed: () => _openMap(job),
                                icon: const CircleAvatar(
                                  backgroundColor: AppColors.primary,
                                  child: Icon(Icons.send, color: Colors.white, size: 18),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: _actions(job, blocked),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _actions(Job job, bool blocked) {
    switch (job.status) {
      case JobStatus.pending:
        return Row(
          children: [
            Expanded(
              child: OutlineActionButton(
                label: 'Reject',
                onPressed: _busy ? null : () => _setStatus(job, JobStatus.declined),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PrimaryButton(
                label: 'Accept',
                color: AppColors.success,
                onPressed: blocked || _busy ? null : () => _setStatus(job, JobStatus.accepted),
                busy: _busy,
              ),
            ),
          ],
        );
      case JobStatus.accepted:
        return PrimaryButton(
          label: 'Check in',
          onPressed: _busy ? null : () => _setStatus(job, JobStatus.checkedIn),
          busy: _busy,
        );
      case JobStatus.checkedIn:
        return PrimaryButton(
          label: 'Check out',
          onPressed: () => context.push('/user/jobs/${job.id}/checkout'),
        );
      default:
        return Center(child: Text('Status: ${job.status.label}'));
    }
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(color: AppColors.textMuted)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
