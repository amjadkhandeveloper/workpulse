import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(sessionControllerProvider.notifier).signIn(
            _email.text,
            _password.text,
          );
    } catch (error) {
      if (mounted) showAppSnack(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = ref.watch(sessionControllerProvider).error;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 32),
                const Icon(Icons.wb_sunny_rounded, size: 72, color: AppColors.primary),
                const SizedBox(height: 12),
                const Text(
                  'WORK PULSE',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 1.4),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sign in with the email and password created for your account',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                IconUnderlineField(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                ),
                IconUnderlineField(
                  icon: Icons.lock_outline,
                  label: 'Password',
                  controller: _password,
                  obscureText: true,
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error, style: const TextStyle(color: AppColors.declined)),
                ],
                const SizedBox(height: 32),
                PrimaryButton(label: 'Login', onPressed: _submit, busy: _busy),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
