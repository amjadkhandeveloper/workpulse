import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/models/company.dart';

class CompanyFormScreen extends ConsumerStatefulWidget {
  const CompanyFormScreen({super.key, this.companyId});

  final String? companyId;

  @override
  ConsumerState<CompanyFormScreen> createState() => _CompanyFormScreenState();
}

class _CompanyFormScreenState extends ConsumerState<CompanyFormScreen> {
  final _name = TextEditingController();
  final _location = TextEditingController();
  final _work = TextEditingController();
  final _contact = TextEditingController();
  final _mobile = TextEditingController();
  bool _busy = false;

  bool get _isNew => widget.companyId == null;

  @override
  void initState() {
    super.initState();
    if (!_isNew) _load();
  }

  Future<void> _load() async {
    final list = await ref.read(companyRepositoryProvider).list();
    final company = list.where((c) => c.id == widget.companyId).firstOrNull;
    if (company == null || !mounted) return;
    setState(() {
      _name.text = company.name;
      _location.text = company.location ?? '';
      _work.text = company.work ?? '';
      _contact.text = company.contactName ?? '';
      _mobile.text = company.mobile ?? '';
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _work.dispose();
    _contact.dispose();
    _mobile.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      showAppSnack(context, 'Company name is required', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final repo = ref.read(companyRepositoryProvider);
      final data = {
        'name': _name.text.trim(),
        'location': _location.text.trim(),
        'work': _work.text.trim(),
        'contact_name': _contact.text.trim(),
        'mobile': _mobile.text.trim(),
      };
      if (_isNew) {
        await repo.create(
          Company(
            id: '',
            name: _name.text.trim(),
            location: _location.text.trim(),
            work: _work.text.trim(),
            contactName: _contact.text.trim(),
            mobile: _mobile.text.trim(),
            createdAt: DateTime.now(),
          ),
        );
      } else {
        await repo.update(widget.companyId!, data);
      }
      ref.invalidate(companiesProvider);
      ref.invalidate(adminStatsProvider);
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) showAppSnack(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete company?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(companyRepositoryProvider).delete(widget.companyId!);
    ref.invalidate(companiesProvider);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Add company' : 'Edit company'),
        actions: [
          if (!_isNew) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          IconUnderlineField(icon: Icons.apartment, label: 'Company Name', controller: _name, highlight: true),
          IconUnderlineField(icon: Icons.location_on_outlined, label: 'Location', controller: _location),
          IconUnderlineField(icon: Icons.handyman_outlined, label: 'Work', controller: _work),
          IconUnderlineField(icon: Icons.person_outline, label: 'Contact name', controller: _contact),
          IconUnderlineField(
            icon: Icons.smartphone,
            label: 'Mobile No',
            controller: _mobile,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 24),
          PrimaryButton(label: 'Save', onPressed: _save, busy: _busy),
        ],
      ),
    );
  }
}
