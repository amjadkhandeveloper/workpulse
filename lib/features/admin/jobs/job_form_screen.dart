import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/models/company.dart';
import '../../../data/supabase/app_config.dart';

class JobFormScreen extends ConsumerStatefulWidget {
  const JobFormScreen({super.key, this.jobId});

  final String? jobId;

  @override
  ConsumerState<JobFormScreen> createState() => _JobFormScreenState();
}

class _JobFormScreenState extends ConsumerState<JobFormScreen> {
  bool _isNewCompany = false;
  bool _busy = false;
  String? _companyId;
  String? _assignedTo;
  String _jobType = AppConstants.jobTypes.first;
  String _jobCategory = AppConstants.jobCategories.first;
  DateTime _date = DateTime.now();
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 18, minute: 0);

  final _companyName = TextEditingController();
  final _customer = TextEditingController();
  final _mobile = TextEditingController();
  final _purpose = TextEditingController();
  final _location = TextEditingController();
  final _work = TextEditingController();

  bool get _editing => widget.jobId != null;

  @override
  void initState() {
    super.initState();
    if (_editing) _loadJob();
  }

  Future<void> _loadJob() async {
    final job = await ref.read(jobRepositoryProvider).getById(widget.jobId!);
    if (!mounted) return;
    setState(() {
      _companyId = job.companyId;
      _assignedTo = job.assignedTo;
      _jobType = job.jobType.isEmpty ? _jobType : job.jobType;
      _jobCategory = job.jobCategory.isEmpty ? _jobCategory : job.jobCategory;
      _customer.text = job.customerName ?? '';
      _mobile.text = job.customerMobile ?? '';
      _purpose.text = job.purpose;
      _location.text = job.location ?? '';
      _companyName.text = job.company?.name ?? '';
      _date = job.startAt;
      _start = TimeOfDay.fromDateTime(job.startAt);
      _end = TimeOfDay.fromDateTime(job.endAt);
    });
  }

  @override
  void dispose() {
    _companyName.dispose();
    _customer.dispose();
    _mobile.dispose();
    _purpose.dispose();
    _location.dispose();
    _work.dispose();
    super.dispose();
  }

  void _applyCompany(Company company) {
    setState(() {
      _companyId = company.id;
      _companyName.text = company.name;
      _customer.text = company.contactName ?? _customer.text;
      _mobile.text = company.mobile ?? _mobile.text;
      _location.text = company.location ?? _location.text;
    });
  }

  DateTime _combine(DateTime date, TimeOfDay time) =>
      DateTime(date.year, date.month, date.day, time.hour, time.minute);

  Future<void> _save() async {
    if (_purpose.text.trim().isEmpty) {
      showAppSnack(context, 'Purpose is required', error: true);
      return;
    }
    if (_assignedTo == null) {
      showAppSnack(context, 'Assign a user', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final session = ref.read(sessionControllerProvider).profile;
      final users = ref.read(fieldUsersProvider).valueOrNull ?? [];
      final assignee = users.where((u) => u.id == _assignedTo).firstOrNull;
      final clientId = session?.isClient == true ? session!.id : assignee?.clientId;
      var companyId = _companyId;
      if (_isNewCompany) {
        final created = await ref.read(companyRepositoryProvider).create(
              Company(
                id: '',
                name: _companyName.text.trim(),
                location: _location.text.trim(),
                work: _work.text.trim(),
                contactName: _customer.text.trim(),
                mobile: _mobile.text.trim(),
                clientId: clientId,
                createdAt: DateTime.now(),
              ),
            );
        companyId = created.id;
        ref.invalidate(companiesProvider);
      }
      final payload = {
        'job_type': _jobType,
        'job_category': _jobCategory,
        'purpose': _purpose.text.trim(),
        'company_id': companyId,
        'assigned_to': _assignedTo,
        'customer_name': _customer.text.trim(),
        'customer_mobile': _mobile.text.trim(),
        'location': _location.text.trim(),
        'start_at': _combine(_date, _start).toUtc().toIso8601String(),
        'end_at': _combine(_date, _end).toUtc().toIso8601String(),
        'assigned_by': SupabaseProvider.client.auth.currentUser?.id,
        'client_id': ?clientId,
        if (!_editing) 'status': 'pending',
      };
      if (_editing) {
        await ref.read(jobRepositoryProvider).update(widget.jobId!, payload);
      } else {
        await ref.read(jobRepositoryProvider).create(payload);
      }
      ref.invalidate(adminJobsProvider);
      ref.invalidate(adminStatsProvider);
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) showAppSnack(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    await ref.read(jobRepositoryProvider).delete(widget.jobId!);
    ref.invalidate(adminJobsProvider);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final companies = ref.watch(companiesProvider).valueOrNull ?? [];
    final users = ref.watch(fieldUsersProvider).valueOrNull ?? [];
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Job details'),
        actions: [
          if (_editing) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
        children: [
          ExistingNewToggle(
            isNew: _isNewCompany,
            onChanged: (v) => setState(() => _isNewCompany = v),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                if (!_isNewCompany)
                  DropdownButtonFormField<String>(
                    initialValue: companies.any((c) => c.id == _companyId) ? _companyId : null,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.apartment),
                      labelText: 'Company Name',
                    ),
                    items: companies
                        .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                        .toList(),
                    onChanged: (id) {
                      final company = companies.where((c) => c.id == id).firstOrNull;
                      if (company != null) _applyCompany(company);
                    },
                  )
                else
                  IconUnderlineField(
                    icon: Icons.apartment,
                    label: 'Company Name',
                    controller: _companyName,
                    highlight: true,
                  ),
                IconUnderlineField(icon: Icons.person_outline, label: 'Customer Name', controller: _customer),
                IconUnderlineField(
                  icon: Icons.smartphone,
                  label: 'Mobile No',
                  controller: _mobile,
                  keyboardType: TextInputType.phone,
                ),
                IconUnderlineField(icon: Icons.grid_view, label: 'Purpose of Visit', controller: _purpose),
                IconUnderlineField(icon: Icons.location_on_outlined, label: 'Location', controller: _location),
                if (_isNewCompany)
                  IconUnderlineField(icon: Icons.handyman_outlined, label: 'Work', controller: _work),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month, color: Colors.grey),
                  title: const Text('Date of Visit', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  subtitle: Text(
                    dateFull.format(_date),
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                ),
                Row(
                  children: [
                    Expanded(child: _timeTile('Start Time', _start, (t) => setState(() => _start = t))),
                    const SizedBox(width: 16),
                    Expanded(child: _timeTile('End Time', _end, (t) => setState(() => _end = t))),
                  ],
                ),
                DropdownButtonFormField<String>(
                  initialValue: _jobType,
                  decoration: const InputDecoration(labelText: 'Job type'),
                  items: AppConstants.jobTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => _jobType = v ?? _jobType),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _jobCategory,
                  decoration: const InputDecoration(labelText: 'Job category'),
                  items: AppConstants.jobCategories
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => _jobCategory = v ?? _jobCategory),
                ),
                DropdownButtonFormField<String>(
                  initialValue: users.any((u) => u.id == _assignedTo) ? _assignedTo : null,
                  decoration: const InputDecoration(labelText: 'Assign user'),
                  items: users
                      .where((u) => u.isActive)
                      .map((u) => DropdownMenuItem(value: u.id, child: Text(u.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _assignedTo = v),
                ),
                const SizedBox(height: 24),
                PrimaryButton(label: 'Save', onPressed: _save, busy: _busy),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeTile(String label, TimeOfDay value, ValueChanged<TimeOfDay> onPick) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(value.format(context)),
      trailing: IconButton(
        icon: const Icon(Icons.add_circle, color: AppColors.success),
        onPressed: () async {
          final picked = await showTimePicker(context: context, initialTime: value);
          if (picked != null) onPick(picked);
        },
      ),
    );
  }
}
