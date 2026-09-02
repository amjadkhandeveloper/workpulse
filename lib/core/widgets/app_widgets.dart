import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color ?? AppColors.primary,
          shape: const StadiumBorder(),
        ),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(label.toUpperCase()),
      ),
    );
  }
}

class OutlineActionButton extends StatelessWidget {
  const OutlineActionButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textDark,
          side: const BorderSide(color: Color(0xFFBDBDBD)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label.toUpperCase()),
      ),
    );
  }
}

class IconUnderlineField extends StatelessWidget {
  const IconUnderlineField({
    super.key,
    required this.icon,
    required this.label,
    this.controller,
    this.onTap,
    this.readOnly = false,
    this.keyboardType,
    this.obscureText = false,
    this.initialValue,
    this.onChanged,
    this.highlight = false,
    this.suffix,
  });

  final IconData icon;
  final String label;
  final TextEditingController? controller;
  final VoidCallback? onTap;
  final bool readOnly;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final bool highlight;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12, right: 16),
            child: Icon(icon, color: Colors.grey.shade500),
          ),
          Expanded(
            child: TextFormField(
              controller: controller,
              initialValue: controller == null ? initialValue : null,
              readOnly: readOnly,
              onTap: onTap,
              keyboardType: keyboardType,
              obscureText: obscureText,
              onChanged: onChanged,
              style: TextStyle(
                color: highlight ? AppColors.primary : AppColors.textDark,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: TextStyle(
                  color: highlight ? AppColors.primary : AppColors.textMuted,
                ),
                suffixIcon: suffix,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ExistingNewToggle extends StatelessWidget {
  const ExistingNewToggle({
    super.key,
    required this.isNew,
    required this.onChanged,
  });

  final bool isNew;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          _tab('Existing', !isNew, () => onChanged(false)),
          _tab('New', isNew, () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _tab(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: label == 'Existing' ? const Radius.circular(16) : Radius.zero,
              topRight: label == 'New' ? const Radius.circular(16) : Radius.zero,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
        boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Text(
        label,
        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.message, this.icon = Icons.inbox_outlined});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

class AsymmetricCard extends StatelessWidget {
  const AsymmetricCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(36),
          topRight: Radius.circular(8),
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(36),
        ),
        boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: child,
    );
  }
}

void showAppSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.declined : AppColors.textDark,
    ),
  );
}
