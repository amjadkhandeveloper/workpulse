import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';

class ClientsScreen extends ConsumerWidget {
  const ClientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clients = ref.watch(clientsProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => context.push('/admin/clients/new'),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: clients.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyView(message: '$e'),
        data: (items) {
          if (items.isEmpty) return const EmptyView(message: 'No clients yet.');
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(clientsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final client = items[i];
                return ListTile(
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    backgroundImage: client.photoUrl != null
                        ? CachedNetworkImageProvider(client.photoUrl!)
                        : null,
                    child: client.photoUrl == null
                        ? Text(client.name.isEmpty ? '?' : client.name[0])
                        : null,
                  ),
                  title: Text(client.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${client.mobile ?? 'No mobile'} • ${client.email}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/admin/clients/${client.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
