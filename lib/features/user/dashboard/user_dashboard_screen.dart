import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/job_summary_card.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/job.dart';
import '../../../data/models/profile.dart';

class UserDashboardScreen extends ConsumerStatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  ConsumerState<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends ConsumerState<UserDashboardScreen> {
  String _address = 'Fetching location...';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshAddress());
  }

  Future<void> _refreshAddress() async {
    final profile = ref.read(sessionControllerProvider).profile;
    if (profile?.hasLocation == true) {
      try {
        final marks = await placemarkFromCoordinates(profile!.lastLat!, profile.lastLng!);
        if (marks.isNotEmpty && mounted) {
          final m = marks.first;
          setState(() {
            _address = [
              m.street,
              m.subLocality,
              m.locality,
              m.administrativeArea,
              m.postalCode,
              m.country,
            ].where((e) => e != null && e.trim().isNotEmpty).join(', ');
          });
        }
      } catch (_) {
        if (mounted) setState(() => _address = 'Current location unavailable');
      }
    } else if (mounted) {
      setState(() => _address = 'Standby in to share your location');
    }
  }

  Future<void> _toggleStandby(Profile profile, List<Job> jobs) async {
    setState(() => _busy = true);
    try {
      final turningOn = !profile.isOnStandby;
      final fix = await ref.read(locationServiceProvider).currentFix();
      await ref.read(attendanceRepositoryProvider).punch(
            userId: profile.id,
            type: turningOn ? AttendanceType.standbyIn : AttendanceType.standbyOut,
            lat: fix?.lat,
            lng: fix?.lng,
          );
      await ref.read(profileRepositoryProvider).setStandby(
            profile.id,
            turningOn ? StandbyStatus.in_ : StandbyStatus.out,
          );
      await ref.read(sessionControllerProvider.notifier).refreshProfile();
      final updated = ref.read(sessionControllerProvider).profile ?? profile;
      await ref.read(locationServiceProvider).sync(profile: updated, jobs: jobs);
      await _refreshAddress();
      ref.invalidate(userAttendanceProvider);
    } catch (error) {
      if (mounted) showAppSnack(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(sessionControllerProvider).profile;
    final jobsAsync = ref.watch(userJobsProvider);
    ref.listen(userJobsProvider, (prev, next) {
      next.whenData((jobs) {
        final current = ref.read(sessionControllerProvider).profile;
        if (current != null) {
          ref.read(locationServiceProvider).sync(profile: current, jobs: jobs);
        }
      });
    });
    return jobsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyView(message: '$e'),
      data: (jobs) {
        final pending = jobs.where((j) => j.status == JobStatus.pending).length;
        final completed = jobs.where((j) => j.status == JobStatus.completed).length;
        final cancelled = jobs.where((j) => j.status == JobStatus.cancelled).length;
        final declined = jobs.where((j) => j.status == JobStatus.declined).length;
        final enroute = jobs.where((j) => j.status == JobStatus.accepted).length;
        final checkedIn = jobs.where((j) => j.status == JobStatus.checkedIn).length;
        final idle = profile?.isOnStandby == true &&
            jobs.every((j) => !j.status.isActive);
        final assignedWhileStandby = profile?.isOnStandby == true &&
            jobs.any((j) => j.status == JobStatus.pending);

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(userJobsProvider);
            await ref.read(sessionControllerProvider.notifier).refreshProfile();
            await _refreshAddress();
          },
          child: ListView(
            children: [
              const SizedBox(height: 8),
              SizedBox(
                height: 180,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 28,
                    sections: [
                      PieChartSectionData(
                        color: AppColors.success,
                        value: (completed == 0 && pending == 0) ? 1 : completed.toDouble(),
                        title: '$completed',
                        radius: 58,
                        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                      PieChartSectionData(
                        color: AppColors.pending,
                        value: (completed == 0 && pending == 0) ? 1 : pending.toDouble(),
                        title: '$pending',
                        radius: 58,
                        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    _countCard('Pending', pending, AppColors.pending),
                    _countCard('Completed', completed, AppColors.success),
                    _countCard('Cancelled', cancelled, AppColors.cancelled),
                    _countCard('Declined', declined, AppColors.declined),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8)],
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: AppColors.primary,
                      child: Icon(Icons.location_on, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_address, maxLines: 3)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusPill(label: '$enroute Enroute'),
                    StatusPill(label: '$checkedIn Checked In'),
                    StatusPill(label: '${idle ? 1 : 0} Idle'),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: PrimaryButton(
                  label: profile?.isOnStandby == true ? 'Standby Out' : 'Standby In',
                  color: profile?.isOnStandby == true ? AppColors.success : AppColors.primary,
                  onPressed: profile == null || _busy ? null : () => _toggleStandby(profile, jobs),
                  busy: _busy,
                ),
              ),
              if (assignedWhileStandby)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.locationTint,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: const Text(
                    'A job has been assigned. Standby out to accept this job.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ...jobs.map(
                (job) => JobSummaryCard(
                  job: job,
                  onTap: () => context.push('/user/jobs/${job.id}'),
                ),
              ),
              if (jobs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: EmptyView(message: 'No jobs assigned yet.'),
                ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _countCard(String label, int value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(6),
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(6),
          ),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 6)],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('$value', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              color: color,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
