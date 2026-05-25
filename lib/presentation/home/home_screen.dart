import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:listapay/core/router/app_router.dart';
import 'package:listapay/core/theme/app_theme.dart';
import 'package:listapay/core/widgets/module_card.dart';
import 'package:listapay/core/widgets/offline_banner.dart';
import 'package:listapay/data/services/connectivity_service.dart';
import 'package:listapay/presentation/auth/auth_cubit.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthCubit>().state.user;
    if (user == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final connectivity = context.read<ConnectivityService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ListaPay'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthCubit>().logout(),
          ),
        ],
      ),
      body: Column(
        children: [
          StreamBuilder<bool>(
            stream: connectivity.onlineStream(),
            initialData: true,
            builder: (context, snapshot) {
              final online = snapshot.data ?? true;
              return online ? const SizedBox.shrink() : const OfflineBanner();
            },
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                          child: Text(
                            user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kumusta, ${user.name}',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              Text(
                                user.role.name.toUpperCase(),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Modules',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.1,
                  children: [
                    if (user.canSell)
                      ModuleCard(
                        icon: Icons.point_of_sale,
                        label: 'POS',
                        subtitle: 'Sell & checkout',
                        onTap: () => context.push(AppRoutes.pos),
                      ),
                    if (user.canAccessDebts)
                      ModuleCard(
                        icon: Icons.account_balance_wallet,
                        label: 'Utang',
                        subtitle: 'Customer debt',
                        onTap: () => context.push(AppRoutes.debt),
                      ),
                    if (user.canAccessCustomers)
                      ModuleCard(
                        icon: Icons.people_outline,
                        label: 'Customers',
                        onTap: () => context.push(AppRoutes.customers),
                      ),
                    if (user.canManageInventory)
                      ModuleCard(
                        icon: Icons.inventory_2_outlined,
                        label: 'Inventory',
                        subtitle: 'Products & stock',
                        onTap: () => context.push(AppRoutes.inventory),
                      ),
                    if (user.canAccessReports) ...[
                      ModuleCard(
                        icon: Icons.bar_chart,
                        label: 'Reports',
                        onTap: () => context.push(AppRoutes.reports),
                      ),
                    ],
                    if (user.canAccessSettings)
                      ModuleCard(
                        icon: Icons.settings_outlined,
                        label: 'Settings',
                        subtitle: 'Sync & config',
                        onTap: () => context.push(AppRoutes.settings),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}
