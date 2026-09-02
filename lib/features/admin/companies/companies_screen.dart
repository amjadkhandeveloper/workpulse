import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';

class CompaniesScreen extends ConsumerWidget {
  const CompaniesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companies = ref.watch(companiesProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => context.push('/admin/companies/new'),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: companies.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyView(message: '$e'),
        data: (items) {
          if (items.isEmpty) return const EmptyView(message: 'No companies yet.');
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(companiesProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final company = items[i];
                return ListTile(
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    child: Icon(Icons.apartment, color: AppColors.primary),
                  ),
                  title: Text(company.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(company.location ?? company.work ?? ''),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/admin/companies/${company.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
