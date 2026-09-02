import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/models/enums.dart';

class ApplyLeaveScreen extends ConsumerStatefulWidget {
  const ApplyLeaveScreen({super.key});

  @override
  ConsumerState<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends ConsumerState<ApplyLeaveScreen> {
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now();
  LeaveDayType _dayType = LeaveDayType.full;
  final _reason = TextEditingController();
  bool _busy = false;

  DateTime get _min => DateTime.now().subtract(const Duration(days: AppConstants.leavePastDays));
  DateTime get _max => DateTime.now().add(const Duration(days: AppConstants.leaveFutureDays));

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: _min,
      lastDate: _max,
    );
    if (picked != null) {
      setState(() {
        _start = picked;
        if (_end.isBefore(_start)) _end = _start;
      });
    }
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _end.isBefore(_start) ? _start : _end,
      firstDate: _start,
      lastDate: _max,
    );
    if (picked != null) setState(() => _end = picked);
  }

  Future<void> _submit() async {
    final days = _end.difference(_start).inDays + 1;
    if (days > AppConstants.leaveMaxDays) {
      showAppSnack(context, 'You can apply for a maximum of ${AppConstants.leaveMaxDays} days.', error: true);
      return;
    }
    final profile = ref.read(sessionControllerProvider).profile;
    if (profile == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(leaveRepositoryProvider).create(
            userId: profile.id,
            startDate: _start,
            endDate: _end,
            dayType: _dayType,
            reason: _reason.text.trim(),
          );
      ref.invalidate(userLeavesProvider);
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) showAppSnack(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Apply leave')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ListTile(
            title: const Text('Start date'),
            subtitle: Text(dateFull.format(_start)),
            onTap: _pickStart,
          ),
          ListTile(
            title: const Text('End date'),
            subtitle: Text(dateFull.format(_end)),
            onTap: _pickEnd,
          ),
          const SizedBox(height: 8),
          const Text('Day type'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: LeaveDayType.values
                .map(
                  (type) => ChoiceChip(
                    label: Text(type.label),
                    selected: _dayType == type,
                    onSelected: (_) => setState(() => _dayType = type),
                  ),
                )
                .toList(),
          ),
          IconUnderlineField(icon: Icons.notes, label: 'Reason', controller: _reason),
          const SizedBox(height: 24),
          PrimaryButton(label: 'Submit', onPressed: _submit, busy: _busy),
        ],
      ),
    );
  }
}
