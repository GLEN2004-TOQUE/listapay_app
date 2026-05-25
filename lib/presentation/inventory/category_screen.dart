import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:listapay/core/theme/app_theme.dart';
import 'package:listapay/core/widgets/empty_state.dart';
import 'package:listapay/core/widgets/simple_loading.dart';
import 'package:listapay/domain/entities/product_category.dart';
import 'package:listapay/domain/repositories/inventory_repository.dart';
import 'package:listapay/presentation/auth/auth_cubit.dart';
import 'package:listapay/presentation/inventory/category_list_cubit.dart';

class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          CategoryListCubit(context.read<InventoryRepository>())..start(),
      child: const _CategoryView(),
    );
  }
}

class _CategoryView extends StatelessWidget {
  const _CategoryView();

  static const _colorOptions = [
    '#0D7C4E',
    '#E65100',
    '#1565C0',
    '#6A1B9A',
    '#C62828',
    '#455A64',
  ];

  @override
  Widget build(BuildContext context) {
    final canEdit = context.watch<AuthCubit>().state.user!.canManageInventory;

    return BlocConsumer<CategoryListCubit, CategoryListState>(
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
            title: const Text('Categories'),
          ),
          floatingActionButton: canEdit
              ? FloatingActionButton(
                  onPressed: () => _showForm(context),
                  child: const Icon(Icons.add),
                )
              : null,
          body: Stack(
            children: [
              if (state.isLoading && state.categories.isEmpty)
                const SimpleLoading(message: 'Loading categories...')
              else if (state.categories.isEmpty)
                const EmptyState(
                  icon: Icons.category_outlined,
                  title: 'No categories',
                  subtitle: 'Add categories to organize products.',
                )
              else
                ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.categories.length,
                  itemBuilder: (context, index) {
                    final category = state.categories[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: category.displayColor,
                          radius: 16,
                        ),
                        title: Text(category.name),
                        trailing: canEdit
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () => _showForm(
                                      context,
                                      category: category,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _confirmDelete(
                                      context,
                                      category,
                                    ),
                                  ),
                                ],
                              )
                            : null,
                      ),
                    );
                  },
                ),
              if (state.isSaving)
                const LoadingOverlay(message: 'Saving...'),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showForm(
    BuildContext context, {
    ProductCategory? category,
  }) async {
    final nameController = TextEditingController(text: category?.name ?? '');
    var selectedColor = category?.color ?? _colorOptions.first;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (ctx, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    category == null ? 'Add category' : 'Edit category',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: _colorOptions.map((hex) {
                      final color = Color(
                        int.parse('FF${hex.replaceFirst('#', '')}', radix: 16),
                      );
                      final selected = selectedColor == hex;
                      return GestureDetector(
                        onTap: () =>
                            setModalState(() => selectedColor = hex),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: selected
                                ? Border.all(color: AppColors.textPrimary, width: 3)
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.trim().isEmpty) return;
                      await context.read<CategoryListCubit>().saveCategory(
                            id: category?.id,
                            name: nameController.text,
                            color: selectedColor,
                          );
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    },
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    if (saved == true && context.mounted) {
      nameController.dispose();
    } else {
      nameController.dispose();
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ProductCategory category,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text('Remove "${category.name}"?'),
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
      context.read<CategoryListCubit>().deleteCategory(category.id);
    }
  }
}
