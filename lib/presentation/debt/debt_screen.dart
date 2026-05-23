import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:listapay/core/router/app_router.dart';
import 'package:listapay/core/widgets/empty_state.dart';
import 'package:listapay/core/widgets/simple_loading.dart';
import 'package:listapay/domain/repositories/debt_repository.dart';
import 'package:listapay/presentation/debt/debt_list_cubit.dart';
import 'package:listapay/presentation/debt/widgets/debt_tile.dart';

class DebtScreen extends StatelessWidget {
  const DebtScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DebtListCubit(context.read<DebtRepository>())..start(),
      child: const _DebtView(),
    );
  }
}

class _DebtView extends StatelessWidget {
  const _DebtView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DebtListCubit, DebtListState>(
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
            title: const Text('Utang'),
          ),
          body: Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: DebtFilter.values.map((filter) {
                    final selected = state.filter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(_filterLabel(filter)),
                        selected: selected,
                        onSelected: (_) =>
                            context.read<DebtListCubit>().setFilter(filter),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Expanded(child: _buildBody(context, state)),
            ],
          ),
        );
      },
    );
  }

  String _filterLabel(DebtFilter filter) {
    return switch (filter) {
      DebtFilter.all => 'Active',
      DebtFilter.pending => 'Pending',
      DebtFilter.overdue => 'Overdue',
      DebtFilter.paid => 'Paid',
    };
  }

  Widget _buildBody(BuildContext context, DebtListState state) {
    if (state.isLoading && state.debts.isEmpty) {
      return const SimpleLoading(message: 'Loading debts...');
    }

    if (state.debts.isEmpty) {
      return EmptyState(
        icon: Icons.account_balance_wallet,
        title: 'No debts here',
        subtitle: state.filter == DebtFilter.all
            ? 'Utang sales from POS will appear here.'
            : 'No debts match this filter.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.debts.length,
      itemBuilder: (context, index) {
        final debt = state.debts[index];
        return DebtTile(
          debt: debt,
          onTap: () => context.push(AppRoutes.debtDetail(debt.id)),
        );
      },
    );
  }
}
