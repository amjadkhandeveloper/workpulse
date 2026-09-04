import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';

class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(fieldUsersProvider);
    final isAdmin = ref.watch(sessionControllerProvider).isAdmin;
    final clients = [
      if (isAdmin) ...?ref.watch(clientsProvider).valueOrNull,
    ];
    final clientNames = {for (final c in clients) c.orgId ?? c.id: c.name};
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => context.push('/admin/users/new'),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: users.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyView(message: '$e'),
        data: (items) {
          if (items.isEmpty) return const EmptyView(message: 'No field users yet.');
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(fieldUsersProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final user = items[i];
                return ListTile(
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    backgroundImage: user.photoUrl != null
                        ? CachedNetworkImageProvider(user.photoUrl!)
                        : null,
                    child: user.photoUrl == null ? Text(user.name.isEmpty ? '?' : user.name[0]) : null,
                  ),
                  title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    [
                      user.username ?? user.email,
                      user.mobile ?? 'No mobile',
                      user.isActive ? 'Active' : 'Inactive',
                      if (isAdmin) clientNames[user.clientId] ?? 'No client',
                    ].join(' • '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/admin/users/${user.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
