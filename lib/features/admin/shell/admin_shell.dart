import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';

const _tabTitles = {
  '/admin': 'DASHBOARD',
  '/admin/clients': 'CLIENTS',
  '/admin/users': 'USERS',
  '/admin/companies': 'COMPANIES',
  '/admin/jobs': 'JOBS',
  '/admin/leaves': 'LEAVE',
  '/admin/reports': 'REPORTS',
  '/admin/map': 'LIVE MAP',
};

class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final isTab = _tabTitles.containsKey(location);
    if (!isTab) return child;

    final profile = ref.watch(sessionControllerProvider).profile;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_tabTitles[location] ?? 'ADMIN')),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: AppColors.primary),
                accountName: Text(profile?.name ?? 'Manager'),
                accountEmail: Text(
                  [
                    if (profile?.isAdmin == true) 'Admin',
                    if (profile?.isClient == true) 'Client',
                    profile?.email ?? '',
                  ].where((s) => s.isNotEmpty).join(' • '),
                ),
                currentAccountPicture: const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.admin_panel_settings, color: AppColors.primary),
                ),
              ),
              _item(context, Icons.dashboard_outlined, 'Dashboard', '/admin'),
              if (profile?.isAdmin == true)
                _item(context, Icons.business_center_outlined, 'Clients', '/admin/clients'),
              _item(context, Icons.people_outline, 'User management', '/admin/users'),
              _item(context, Icons.apartment_outlined, 'Companies', '/admin/companies'),
              _item(context, Icons.work_outline, 'Job management', '/admin/jobs'),
              _item(context, Icons.event_available_outlined, 'Leave', '/admin/leaves'),
              _item(context, Icons.assessment_outlined, 'Reports', '/admin/reports'),
              _item(context, Icons.map_outlined, 'Live map', '/admin/map'),
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
