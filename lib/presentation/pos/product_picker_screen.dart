import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ListaPay/core/utils/currency_format.dart';
import 'package:ListaPay/core/widgets/simple_loading.dart';
import 'package:ListaPay/domain/repositories/inventory_repository.dart';
import 'package:ListaPay/presentation/inventory/product_list_cubit.dart';
import 'package:ListaPay/presentation/pos/cart_cubit.dart';

class ProductPickerScreen extends StatelessWidget {
  const ProductPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          ProductListCubit(context.read<InventoryRepository>())..start(),
      child: const _ProductPickerView(),
    );
  }
}

class _ProductPickerView extends StatefulWidget {
  const _ProductPickerView();

  @override
  State<_ProductPickerView> createState() => _ProductPickerViewState();
}

class _ProductPickerViewState extends State<_ProductPickerView> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add product'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search products...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => context.read<ProductListCubit>().setSearch(v),
            ),
          ),
          Expanded(
            child: BlocBuilder<ProductListCubit, ProductListState>(
              builder: (context, state) {
                if (state.isLoading && state.products.isEmpty) {
                  return const SimpleLoading(message: 'Loading products...');
                }

                if (state.products.isEmpty) {
                  return const Center(child: Text('No products found'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: state.products.length,
                  itemBuilder: (context, index) {
                    final product = state.products[index];
                    final outOfStock = product.isOutOfStock;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(product.name),
                        subtitle: Text(
                          outOfStock
                              ? '${formatPeso(product.price)} · Out of stock'
                              : '${formatPeso(product.price)} · Stock: ${product.stockQty}',
                        ),
                        trailing: outOfStock
                            ? const Text(
                                'Out',
                                style: TextStyle(color: Colors.red),
                              )
                            : const Icon(Icons.add),
                        enabled: !outOfStock,
                        onTap: outOfStock
                            ? null
                            : () {
                                context.read<CartCubit>().addProduct(product);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Added ${product.name}'),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
