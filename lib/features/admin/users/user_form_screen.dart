import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';

class UserFormScreen extends ConsumerStatefulWidget {
  const UserFormScreen({super.key, this.userId});

  final String? userId;

  @override
  ConsumerState<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends ConsumerState<UserFormScreen> {
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _active = true;
  bool _busy = false;
  String? _photoUrl;
  File? _photoFile;

  bool get _isNew => widget.userId == null;

  @override
  void initState() {
    super.initState();
    if (!_isNew) _load();
  }

  Future<void> _load() async {
    final users = await ref.read(profileRepositoryProvider).listUsers();
    final user = users.where((u) => u.id == widget.userId).firstOrNull;
    if (user == null || !mounted) return;
    setState(() {
      _name.text = user.name;
      _mobile.text = user.mobile ?? '';
      _email.text = user.email;
      _active = user.isActive;
      _photoUrl = user.photoUrl;
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
        await repo.createUserViaFunction(
          email: _email.text.trim(),
          password: _password.text,
          name: _name.text.trim(),
          mobile: _mobile.text.trim(),
        );
        final created = (await repo.listUsers())
            .where((u) => u.email.toLowerCase() == _email.text.trim().toLowerCase())
            .firstOrNull;
        if (_photoFile != null && created != null) {
          photoUrl = await repo.uploadAvatar(created.id, _photoFile!);
          await repo.updateProfile(id: created.id, name: _name.text.trim(), mobile: _mobile.text.trim(), photoUrl: photoUrl);
        }
      } else {
        final id = widget.userId!;
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
      ref.invalidate(fieldUsersProvider);
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
        title: const Text('Delete user?'),
        content: const Text('This removes their login. You can also deactivate instead.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(profileRepositoryProvider).deleteUserViaFunction(widget.userId!);
      ref.invalidate(fieldUsersProvider);
      if (mounted) context.pop();
    } catch (error) {
      try {
        await ref.read(profileRepositoryProvider).updateProfile(
              id: widget.userId!,
              name: _name.text.trim(),
              mobile: _mobile.text.trim(),
              isActive: false,
            );
        ref.invalidate(fieldUsersProvider);
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
        title: Text(_isNew ? 'Add user' : 'Edit user'),
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
