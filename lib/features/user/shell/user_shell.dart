import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';

const _tabTitles = {
  '/user': 'JOB SUMMARY',
  '/user/attendance': 'ATTENDANCE',
  '/user/leaves': 'LEAVE',
};

class UserShell extends ConsumerWidget {
  const UserShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final isTab = _tabTitles.containsKey(location);
    if (!isTab) return child;

    final profile = ref.watch(sessionControllerProvider).profile;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_tabTitles[location] ?? 'WORK PULSE')),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: AppColors.primary),
                accountName: Text(profile?.name ?? 'User'),
                accountEmail: Text(profile?.email ?? ''),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  backgroundImage:
                      profile?.photoUrl != null ? NetworkImage(profile!.photoUrl!) : null,
                  child: profile?.photoUrl == null
                      ? const Icon(Icons.person, color: AppColors.primary)
                      : null,
                ),
              ),
              _item(context, Icons.dashboard_outlined, 'Dashboard', '/user'),
              _item(context, Icons.access_time, 'Attendance', '/user/attendance'),
              _item(context, Icons.event_available_outlined, 'Leave', '/user/leaves'),
              const Spacer(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () => ref.read(sessionControllerProvider.notifier).signOut(),
              ),
            ],
          ),
        ),
      ),
      body: child,
    );
  }

  Widget _item(BuildContext context, IconData icon, String label, String path) {
    final selected = GoRouterState.of(context).uri.path == path;
    return ListTile(
      leading: Icon(icon, color: selected ? AppColors.primary : null),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? AppColors.primary : null,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      selected: selected,
      onTap: () {
        Navigator.pop(context);
        context.go(path);
      },
    );
  }
}
