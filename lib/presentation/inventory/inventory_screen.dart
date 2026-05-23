import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:listapay/core/router/app_router.dart';
import 'package:listapay/core/theme/app_theme.dart';
import 'package:listapay/core/widgets/empty_state.dart';
import 'package:listapay/core/widgets/simple_loading.dart';
import 'package:listapay/domain/entities/app_user.dart';
import 'package:listapay/domain/repositories/inventory_repository.dart';
import 'package:listapay/presentation/auth/auth_cubit.dart';
import 'package:listapay/presentation/inventory/product_list_cubit.dart';
import 'package:listapay/presentation/inventory/widgets/product_tile.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          ProductListCubit(context.read<InventoryRepository>())..start(),
      child: const _InventoryView(),
    );
  }
}

class _InventoryView extends StatefulWidget {
  const _InventoryView();

  @override
  State<_InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends State<_InventoryView> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _canEdit(UserRole role) =>
      role == UserRole.admin || role == UserRole.cashier;

  bool _canDelete(UserRole role) => role == UserRole.admin;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthCubit>().state.user!;
    final canEdit = _canEdit(user.role);
    final canDelete = _canDelete(user.role);

    return BlocConsumer<ProductListCubit, ProductListState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            title: const Text('Inventory'),
            actions: [
              IconButton(
                icon: const Icon(Icons.category_outlined),
                tooltip: 'Categories',
                onPressed: () => context.push(AppRoutes.categories),
              ),
            ],
          ),
          floatingActionButton: canEdit
              ? FloatingActionButton(
                  onPressed: () => context.push(AppRoutes.productNew),
                  child: const Icon(Icons.add),
                )
              : null,
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search name or barcode...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: state.searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              context.read<ProductListCubit>().setSearch('');
                            },
                          )
                        : IconButton(
                            icon: const Icon(Icons.qr_code_scanner),
                            onPressed: canEdit
                                ? () async {
                                    final cubit = context.read<ProductListCubit>();
                                    final code = await context.push<String>(
                                      AppRoutes.barcodeScan,
                                    );
                                    if (!mounted || code == null) return;
                                    _searchController.text = code;
                                    cubit.setSearch(code);
                                  }
                                : null,
                          ),
                  ),
                  onChanged: (value) =>
                      context.read<ProductListCubit>().setSearch(value),
                ),
              ),
              Expanded(
                child: _buildBody(context, state, canEdit, canDelete),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    ProductListState state,
    bool canEdit,
    bool canDelete,
  ) {
    if (state.isLoading && state.products.isEmpty) {
      return const SimpleLoading(message: 'Loading products...');
    }

    if (state.products.isEmpty) {
      return EmptyState(
        icon: Icons.inventory_2_outlined,
        title: state.searchQuery.isEmpty
            ? 'No products yet'
            : 'No matches found',
        subtitle: state.searchQuery.isEmpty
            ? 'Tap + to add your first product.'
            : 'Try a different search term.',
      );
    }

    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: state.products.length,
          itemBuilder: (context, index) {
            final product = state.products[index];
            return ProductTile(
              product: product,
              onTap: canEdit
                  ? () => context.push(
                        AppRoutes.productEdit(product.id),
                      )
                  : () {},
              onDelete: canDelete
                  ? () => _confirmDelete(context, product.id, product.name)
                  : null,
            );
          },
        ),
        if (state.isDeleting)
          const LoadingOverlay(message: 'Deleting...'),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    int id,
    String name,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text('Remove "$name" from inventory?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<ProductListCubit>().deleteProduct(id);
    }
  }
}
