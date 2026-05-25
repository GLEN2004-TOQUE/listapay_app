import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:listapay/core/router/app_router.dart';
import 'package:listapay/core/theme/app_theme.dart';
import 'package:listapay/core/utils/currency_format.dart';
import 'package:listapay/core/widgets/empty_state.dart';
import 'package:listapay/domain/repositories/inventory_repository.dart';
import 'package:listapay/presentation/auth/auth_cubit.dart';
import 'package:listapay/presentation/pos/cart_cubit.dart';
import 'package:listapay/presentation/pos/widgets/cart_line_tile.dart';

class PosScreen extends StatelessWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PosView();
  }
}

class _PosView extends StatelessWidget {
  const _PosView();

  @override
  Widget build(BuildContext context) {
    final canSell = context.watch<AuthCubit>().state.user?.canSell ?? false;

    if (!canSell) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: const Text('POS'),
        ),
        body: const EmptyState(
          icon: Icons.point_of_sale,
          title: 'View only',
          subtitle: 'Your role cannot process sales.',
        ),
      );
    }

    return BlocConsumer<CartCubit, CartState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
          context.read<CartCubit>().clearError();
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            title: const Text('POS'),
            actions: [
              if (!state.isEmpty)
                TextButton(
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Clear cart?'),
                        content: const Text('Remove all items from the cart?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              context.read<CartCubit>().clear();
                              Navigator.pop(ctx);
                            },
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Clear'),
                ),
            ],
          ),
          bottomNavigationBar: _buildCheckoutBar(context, state),
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                heroTag: 'browse',
                onPressed: () => context.push(AppRoutes.posProducts),
                child: const Icon(Icons.list),
              ),
              const SizedBox(height: 8),
              FloatingActionButton(
                heroTag: 'scan',
                onPressed: () => _scanBarcode(context),
                child: const Icon(Icons.qr_code_scanner),
              ),
            ],
          ),
          body: _buildCartBody(context, state),
        );
      },
    );
  }

  Widget _buildCartBody(BuildContext context, CartState state) {
    if (state.isEmpty) {
      return const EmptyState(
        icon: Icons.shopping_cart_outlined,
        title: 'Cart is empty',
        subtitle: 'Scan a barcode or tap the list icon to add products.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.lines.length,
      itemBuilder: (context, index) {
        final line = state.lines[index];
        final cubit = context.read<CartCubit>();
        return CartLineTile(
          line: line,
          onQtyChanged: (qty) => cubit.setQty(line.productId, qty),
          onRemove: () => cubit.removeLine(line.productId),
        );
      },
    );
  }

  Widget _buildCheckoutBar(BuildContext context, CartState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${state.itemCount} item(s)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  Text(
                    formatPeso(state.total),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: state.isEmpty
                  ? null
                  : () => context.push(AppRoutes.posCheckout),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(140, 48),
              ),
              child: const Text('Checkout'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanBarcode(BuildContext context) async {
    final inventory = context.read<InventoryRepository>();
    final cart = context.read<CartCubit>();

    final code = await context.push<String>(AppRoutes.posScan);
    if (!context.mounted || code == null) return;

    final product = await inventory.findByBarcode(code);
    if (!context.mounted) return;

    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No product found for barcode $code')),
      );
      return;
    }

    cart.addProduct(product);
  }
}
