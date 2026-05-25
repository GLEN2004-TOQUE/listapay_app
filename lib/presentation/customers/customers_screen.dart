import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:listapay/core/router/app_router.dart';
import 'package:listapay/core/widgets/empty_state.dart';
import 'package:listapay/core/widgets/simple_loading.dart';
import 'package:listapay/domain/repositories/customer_repository.dart';
import 'package:listapay/presentation/auth/auth_cubit.dart';
import 'package:listapay/presentation/customers/customer_list_cubit.dart';
import 'package:listapay/presentation/customers/widgets/customer_tile.dart';

class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          CustomerListCubit(context.read<CustomerRepository>())..start(),
      child: const _CustomersView(),
    );
  }
}

class _CustomersView extends StatefulWidget {
  const _CustomersView();

  @override
  State<_CustomersView> createState() => _CustomersViewState();
}

class _CustomersViewState extends State<_CustomersView> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthCubit>().state.user!;
    final canEdit = user.canAccessCustomers;
    final canDelete = user.isAdmin;

    return BlocConsumer<CustomerListCubit, CustomerListState>(
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
            title: const Text('Customers'),
          ),
          floatingActionButton: canEdit
              ? FloatingActionButton(
                  onPressed: () => context.push(AppRoutes.customerNew),
                  child: const Icon(Icons.person_add),
                )
              : null,
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search name, phone, address...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) =>
                      context.read<CustomerListCubit>().setSearch(v),
                ),
              ),
              Expanded(child: _buildBody(context, state, canEdit, canDelete)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    CustomerListState state,
    bool canEdit,
    bool canDelete,
  ) {
    if (state.isLoading && state.customers.isEmpty) {
      return const SimpleLoading(message: 'Loading customers...');
    }

    if (state.customers.isEmpty) {
      return EmptyState(
        icon: Icons.people_outline,
        title: state.searchQuery.isEmpty ? 'No customers yet' : 'No matches',
        subtitle: state.searchQuery.isEmpty
            ? 'Add customers for Utang and SMS reminders.'
            : 'Try a different search.',
      );
    }

    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: state.customers.length,
          itemBuilder: (context, index) {
            final customer = state.customers[index];
            return CustomerTile(
              customer: customer,
              onTap: canEdit
                  ? () => context.push(AppRoutes.customerEdit(customer.id))
                  : () {},
              onDelete: canDelete
                  ? () => _confirmDelete(context, customer.id, customer.name)
                  : null,
            );
          },
        ),
        if (state.isDeleting) const LoadingOverlay(message: 'Deleting...'),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete customer?'),
        content: Text('Remove "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<CustomerListCubit>().deleteCustomer(id);
    }
  }
}
