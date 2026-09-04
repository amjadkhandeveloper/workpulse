import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:signature/signature.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _note = TextEditingController();
  final _signature = SignatureController(penStrokeWidth: 3, penColor: Colors.black);
  final List<File?> _photos = List<File?>.filled(AppConstants.checkoutPhotoCount, null);
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    _signature.dispose();
    super.dispose();
  }

  Future<void> _pick(int index) async {
    final file = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70);
    if (file != null) setState(() => _photos[index] = File(file.path));
  }

  Future<void> _submit() async {
    if (_photos.any((p) => p == null)) {
      showAppSnack(context, 'Upload all 5 work photos', error: true);
      return;
    }
    if (_signature.isEmpty) {
      showAppSnack(context, 'Signature is required', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final repo = ref.read(jobRepositoryProvider);
      final photoPaths = <String>[];
      for (var i = 0; i < _photos.length; i++) {
        photoPaths.add(
          await repo.uploadCheckoutFile(
            jobId: widget.jobId,
            file: _photos[i]!,
            label: 'photo_$i',
          ),
        );
      }
      final bytes = await _signature.toPngBytes(height: 400, width: 700);
      if (bytes == null) throw Exception('Could not capture signature');
      final sigFile = await _writeBytes(bytes);
      final signaturePath = await repo.uploadCheckoutFile(
        jobId: widget.jobId,
        file: sigFile,
        label: 'signature',
      );
      await repo.submitCheckout(
        jobId: widget.jobId,
        note: _note.text.trim(),
        signaturePath: signaturePath,
        photoPaths: photoPaths,
      );
      final profile = ref.read(sessionControllerProvider).profile;
      if (profile != null) {
        final jobs = await repo.listForUser(profile.id);
        await ref.read(locationServiceProvider).sync(profile: profile, jobs: jobs);
      }
      if (mounted) {
        showAppSnack(context, 'Sent for admin review');
        context.go('/user');
      }
    } catch (error) {
      if (mounted) showAppSnack(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<File> _writeBytes(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/signature_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(bytes);
    return file;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout proof')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Upload 5 photos of completed work', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(
              AppConstants.checkoutPhotoCount,
              (i) => GestureDetector(
                onTap: () => _pick(i),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.locationTint,
                    borderRadius: BorderRadius.circular(12),
                    image: _photos[i] != null
                        ? DecorationImage(image: FileImage(_photos[i]!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _photos[i] == null
                      ? const Icon(Icons.add_a_photo, color: AppColors.primary)
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Customer / technician signature', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Container(
            height: 180,
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400)),
            child: Signature(controller: _signature, backgroundColor: Colors.white),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: _signature.clear, child: const Text('Clear')),
          ),
          IconUnderlineField(icon: Icons.notes, label: 'Notes (optional)', controller: _note),
          const SizedBox(height: 16),
          PrimaryButton(label: 'Submit checkout', onPressed: _submit, busy: _busy),
        ],
      ),
    );
  }
}
