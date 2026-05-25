import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:listapay/core/router/app_router.dart';
import 'package:listapay/core/utils/currency_format.dart';
import 'package:listapay/core/widgets/empty_state.dart';
import 'package:listapay/core/widgets/simple_loading.dart';
import 'package:listapay/domain/entities/debt_record.dart';
import 'package:listapay/domain/repositories/debt_repository.dart';
import 'package:listapay/presentation/debt/debt_list_cubit.dart';
import 'package:listapay/presentation/debt/widgets/debt_tile.dart';
import 'package:intl/intl.dart';

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
            ? 'Customer tabs from POS utang sales will appear here.'
            : 'No debts match this filter.',
      );
    }

    if (state.filter != DebtFilter.paid) {
      final groupedDebts = _groupDebtsByCustomer(state.debts);
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: groupedDebts.length,
        itemBuilder: (context, index) {
          final group = groupedDebts[index];
          return _CustomerDebtGroupCard(group: group);
        },
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

  List<_CustomerDebtGroup> _groupDebtsByCustomer(List<DebtRecord> debts) {
    final grouped = <int, List<DebtRecord>>{};

    for (final debt in debts) {
      grouped.putIfAbsent(debt.customerId, () => []).add(debt);
    }

    final results = grouped.entries.map((entry) {
      final customerDebts = [...entry.value]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final firstDebt = customerDebts.first;
      return _CustomerDebtGroup(
        customerId: firstDebt.customerId,
        customerName: firstDebt.customerName,
        customerPhone: firstDebt.customerPhone,
        debts: customerDebts,
      );
    }).toList();

    results.sort((a, b) => a.customerName.compareTo(b.customerName));
    return results;
  }
}

class _CustomerDebtGroup {
  const _CustomerDebtGroup({
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.debts,
  });

  final int customerId;
  final String customerName;
  final String? customerPhone;
  final List<DebtRecord> debts;

  double get totalRemaining =>
      debts.fold<double>(0, (sum, debt) => sum + debt.remaining);

  int get totalItems =>
      debts.fold<int>(0, (sum, debt) => sum + debt.items.length);

  DateTime get latestAddedAt => debts
      .map((debt) => debt.createdAt)
      .reduce((latest, current) => current.isAfter(latest) ? current : latest);
}

class _CustomerDebtGroupCard extends StatelessWidget {
  const _CustomerDebtGroupCard({required this.group});

  final _CustomerDebtGroup group;

  @override
  Widget build(BuildContext context) {
    final latestFormat = DateFormat('MMM d, yyyy • h:mm a');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Expanded(
              child: Text(
                group.customerName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              formatPeso(group.totalRemaining),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (group.customerPhone != null) Text(group.customerPhone!),
              Text(
                '${group.debts.length} active utang entr${group.debts.length == 1 ? 'y' : 'ies'} • last added ${latestFormat.format(group.latestAddedAt)}',
              ),
            ],
          ),
        ),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total unpaid'),
              Text(
                formatPeso(group.totalRemaining),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Items on tab'),
              Text('${group.totalItems}'),
            ],
          ),
          const SizedBox(height: 14),
          ...group.debts.map((debt) => _DebtEntryCard(debt: debt)),
        ],
      ),
    );
  }
}

class _DebtEntryCard extends StatelessWidget {
  const _DebtEntryCard({required this.debt});

  final DebtRecord debt;

  @override
  Widget build(BuildContext context) {
    final addedFormat = DateFormat('MMM d, yyyy • h:mm a');
    final dueFormat = DateFormat('MMM d, yyyy');

    return InkWell(
      onTap: () => context.push(AppRoutes.debtDetail(debt.id)),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Added ${addedFormat.format(debt.createdAt)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Due ${dueFormat.format(debt.dueDate)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatPeso(debt.remaining),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Remaining',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Original'),
                Text(formatPeso(debt.amount)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Paid'),
                Text(formatPeso(debt.paidAmount)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Items taken',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (debt.items.isEmpty)
              const Text('No item details available.')
            else
              ...debt.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text('${item.qty} x ${item.productName}')),
                      const SizedBox(width: 12),
                      Text(
                        formatPeso(item.subtotal),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
