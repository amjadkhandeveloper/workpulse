import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';

class ClientFormScreen extends ConsumerStatefulWidget {
  const ClientFormScreen({super.key, this.clientId});

  final String? clientId;

  @override
  ConsumerState<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends ConsumerState<ClientFormScreen> {
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _active = true;
  bool _busy = false;
  String? _photoUrl;
  File? _photoFile;

  bool get _isNew => widget.clientId == null;

  @override
  void initState() {
    super.initState();
    if (!_isNew) _load();
  }

  Future<void> _load() async {
    final clients = await ref.read(profileRepositoryProvider).listClients();
    final client = clients.where((c) => c.id == widget.clientId).firstOrNull;
    if (client == null || !mounted) return;
    setState(() {
      _name.text = client.name;
      _mobile.text = client.mobile ?? '';
      _email.text = client.email;
      _active = client.isActive;
      _photoUrl = client.photoUrl;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (file != null) setState(() => _photoFile = File(file.path));
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      showAppSnack(context, 'Name is required', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final repo = ref.read(profileRepositoryProvider);
      var photoUrl = _photoUrl;
      if (_isNew) {
        if (_email.text.trim().isEmpty || _password.text.length < 6) {
          throw Exception('Email and a password of 6+ characters are required');
        }
        await repo.createClientViaFunction(
          email: _email.text.trim(),
          password: _password.text,
          name: _name.text.trim(),
          mobile: _mobile.text.trim(),
        );
        final created = (await repo.listClients())
            .where((c) => c.email.toLowerCase() == _email.text.trim().toLowerCase())
            .firstOrNull;
        if (_photoFile != null && created != null) {
          photoUrl = await repo.uploadAvatar(created.id, _photoFile!);
          await repo.updateProfile(
            id: created.id,
            name: _name.text.trim(),
            mobile: _mobile.text.trim(),
            photoUrl: photoUrl,
          );
        }
      } else {
        final id = widget.clientId!;
        if (_photoFile != null) {
          photoUrl = await repo.uploadAvatar(id, _photoFile!);
        }
        await repo.updateProfile(
          id: id,
          name: _name.text.trim(),
          mobile: _mobile.text.trim(),
          photoUrl: photoUrl,
          isActive: _active,
        );
      }
      ref.invalidate(clientsProvider);
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
        title: const Text('Delete client?'),
        content: const Text('This removes their login and they can no longer manage users.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(profileRepositoryProvider).deleteUserViaFunction(widget.clientId!);
      ref.invalidate(clientsProvider);
      if (mounted) context.pop();
    } catch (error) {
      try {
        await ref.read(profileRepositoryProvider).updateProfile(
              id: widget.clientId!,
              name: _name.text.trim(),
              mobile: _mobile.text.trim(),
              isActive: false,
            );
        ref.invalidate(clientsProvider);
        if (!mounted) return;
        showAppSnack(context, 'Marked inactive (delete function unavailable).');
        context.pop();
      } catch (_) {
        if (mounted) showAppSnack(context, '$error', error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Add client' : 'Edit client'),
        actions: [
          if (!_isNew)
            IconButton(onPressed: _busy ? null : _delete, icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.primaryLight,
                backgroundImage: _photoFile != null
                    ? FileImage(_photoFile!)
                    : (_photoUrl != null ? NetworkImage(_photoUrl!) as ImageProvider : null),
                child: _photoFile == null && _photoUrl == null
                    ? const Icon(Icons.camera_alt, color: AppColors.primary)
                    : null,
              ),
            ),
          ),
          IconUnderlineField(icon: Icons.person, label: 'Name', controller: _name, highlight: true),
          IconUnderlineField(
            icon: Icons.smartphone,
            label: 'Mobile No',
            controller: _mobile,
            keyboardType: TextInputType.phone,
          ),
          if (_isNew) ...[
            IconUnderlineField(
              icon: Icons.email_outlined,
              label: 'Email',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
            ),
            IconUnderlineField(
              icon: Icons.lock_outline,
              label: 'Temporary password',
              controller: _password,
              obscureText: true,
            ),
          ],
          if (!_isNew)
            SwitchListTile(
              title: const Text('Active'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
          const SizedBox(height: 24),
          PrimaryButton(label: 'Save', onPressed: _save, busy: _busy),
        ],
      ),
    );
  }
}
