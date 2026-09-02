import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/job.dart';
import '../../../data/models/records.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();
  String? _userId;
  String? _companyId;
  List<Job> _jobs = [];
  List<AttendanceRecord> _attendance = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final jobs = await ref.read(jobRepositoryProvider).report(
            from: _from,
            to: _to.add(const Duration(days: 1)),
            userId: _userId,
            companyId: _companyId,
          );
      final attendance = await ref.read(attendanceRepositoryProvider).report(
            from: _from,
            to: _to.add(const Duration(days: 1)),
            userId: _userId,
          );
      if (!mounted) return;
      setState(() {
        _jobs = jobs;
        _attendance = attendance;
      });
    } catch (error) {
      if (mounted) showAppSnack(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _from = picked);
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _to = picked);
  }

  Future<void> _exportJobs() async {
    final csv = StringBuffer('Job ID,Purpose,User,Company,Status,Start,End,Location\n');
    for (final job in _jobs) {
      csv.writeln([
        csvEscape(job.displayId),
        csvEscape(job.purpose),
        csvEscape(job.assignee?.name),
        csvEscape(job.company?.name),
        csvEscape(job.status.label),
        csvEscape(job.startAt.toIso8601String()),
        csvEscape(job.endAt.toIso8601String()),
        csvEscape(job.location),
      ].join(','));
    }
    await _share('job_report.csv', csv.toString());
  }

  Future<void> _exportAttendance() async {
    final csv = StringBuffer('User,Type,At,Lat,Lng\n');
    for (final row in _attendance) {
      csv.writeln([
        csvEscape(row.userName),
        csvEscape(row.type.label),
        csvEscape(row.at.toIso8601String()),
        csvEscape(row.lat),
        csvEscape(row.lng),
      ].join(','));
    }
    await _share('attendance_report.csv', csv.toString());
  }

  Future<void> _share(String name, String content) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsString(content);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(fieldUsersProvider).valueOrNull ?? [];
    final companies = ref.watch(companiesProvider).valueOrNull ?? [];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pickFrom,
                      child: Text('From ${dateShort.format(_from)}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pickTo,
                      child: Text('To ${dateShort.format(_to)}'),
                    ),
                  ),
                ],
              ),
              DropdownButton<String?>(
                isExpanded: true,
                value: _userId,
                hint: const Text('All users'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All users')),
                  ...users.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name))),
                ],
                onChanged: (v) => setState(() => _userId = v),
              ),
              DropdownButton<String?>(
                isExpanded: true,
                value: _companyId,
                hint: const Text('All companies'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All companies')),
                  ...companies.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                ],
                onChanged: (v) => setState(() => _companyId = v),
              ),
              PrimaryButton(label: 'Apply filters', onPressed: _load, busy: _busy),
            ],
          ),
        ),
        TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          tabs: const [Tab(text: 'Job report'), Tab(text: 'Attendance')],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _jobs.isEmpty
                  ? const EmptyView(message: 'No jobs in range.')
                  : Column(
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _exportJobs,
                            icon: const Icon(Icons.share),
                            label: const Text('CSV'),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _jobs.length,
                            itemBuilder: (context, i) {
                              final job = _jobs[i];
                              return ListTile(
                                title: Text(job.title),
                                subtitle: Text(
                                  '${job.assignee?.name ?? '-'} • ${job.status.label}\n${dateShort.format(job.startAt)}',
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
              _attendance.isEmpty
                  ? const EmptyView(message: 'No attendance in range.')
                  : Column(
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _exportAttendance,
                            icon: const Icon(Icons.share),
                            label: const Text('CSV'),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _attendance.length,
                            itemBuilder: (context, i) {
                              final row = _attendance[i];
                              return ListTile(
                                title: Text(row.userName ?? row.userId),
                                subtitle: Text('${row.type.label} • ${dateFull.format(row.at.toLocal())}'),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ],
    );
  }
}
