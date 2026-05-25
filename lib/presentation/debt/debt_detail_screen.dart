import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:listapay/core/theme/app_theme.dart';
import 'package:listapay/core/utils/currency_format.dart';
import 'package:listapay/core/widgets/simple_loading.dart';
import 'package:listapay/data/services/receipt_service.dart';
import 'package:listapay/domain/entities/app_user.dart';
import 'package:listapay/domain/entities/customer_summary.dart';
import 'package:listapay/domain/entities/debt_record.dart';
import 'package:listapay/domain/entities/debt_status.dart';
import 'package:listapay/domain/repositories/customer_repository.dart';
import 'package:listapay/domain/repositories/debt_repository.dart';
import 'package:listapay/presentation/auth/auth_cubit.dart';

class DebtDetailScreen extends StatefulWidget {
  const DebtDetailScreen({super.key, required this.debtId});

  final int debtId;

  @override
  State<DebtDetailScreen> createState() => _DebtDetailScreenState();
}

class _DebtDetailScreenState extends State<DebtDetailScreen> {
  DebtRecord? _debt;
  bool _isLoading = true;
  bool _isProcessing = false;
  final _paymentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final debt = await context.read<DebtRepository>().getDebt(widget.debtId);
    if (mounted) {
      setState(() {
        _debt = debt;
        _isLoading = false;
        if (debt != null && !debt.isFullyPaid) {
          _paymentController.text = debt.remaining.toStringAsFixed(2);
        }
      });
    }
  }

  @override
  void dispose() {
    _paymentController.dispose();
    super.dispose();
  }

  Future<void> _recordPayment({bool fullAmount = false}) async {
    final debt = _debt;
    if (debt == null || debt.isFullyPaid) return;

    final amount = fullAmount
        ? debt.remaining
        : double.tryParse(_paymentController.text) ?? 0;

    setState(() => _isProcessing = true);
    try {
      if (fullAmount) {
        await context.read<DebtRepository>().markAsPaid(debt.id);
      } else {
        await context.read<DebtRepository>().recordPayment(
          debtId: debt.id,
          amount: amount,
        );
      }
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Payment recorded.')));
      }
    } on DebtException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _exportDebtStatement({required bool print}) async {
    final debt = _debt;
    if (debt == null) return;

    final receiptService = context.read<ReceiptService>();
    setState(() => _isProcessing = true);
    try {
      if (print) {
        await receiptService.printDebtStatement(debt);
      } else {
        await receiptService.shareDebtStatement(debt);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              print
                  ? 'Could not open the print dialog.'
                  : 'Could not generate the PDF file.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  CustomerSummary? _findCustomerSummary(
    List<CustomerSummary> customers,
    int customerId,
  ) {
    for (final customer in customers) {
      if (customer.id == customerId) return customer;
    }
    return null;
  }

  Future<void> _editDebt() async {
    final debt = _debt;
    if (debt == null) return;

    setState(() => _isProcessing = true);
    List<CustomerSummary> customers;
    try {
      customers = await context.read<CustomerRepository>().getCustomerSummaries();
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }

    if (!mounted) return;
    if (customers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a customer first before editing.')),
      );
      return;
    }

    var selectedCustomer =
        _findCustomerSummary(customers, debt.customerId) ?? customers.first;
    var selectedDueDate = DateTime(
      debt.dueDate.year,
      debt.dueDate.month,
      debt.dueDate.day,
    );
    final dateFormat = DateFormat('MMM d, yyyy');

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> pickDueDate() async {
            final picked = await showDatePicker(
              context: dialogContext,
              initialDate: selectedDueDate,
              firstDate: DateTime.now().subtract(const Duration(days: 3650)),
              lastDate: DateTime.now().add(const Duration(days: 3650)),
            );
            if (picked != null) {
              setDialogState(() {
                selectedDueDate = DateTime(
                  picked.year,
                  picked.month,
                  picked.day,
                );
              });
            }
          }

          return AlertDialog(
            title: const Text('Edit debt info'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<CustomerSummary>(
                  initialValue: selectedCustomer,
                  decoration: const InputDecoration(labelText: 'Customer'),
                  items: customers
                      .map(
                        (customer) => DropdownMenuItem(
                          value: customer,
                          child: Text(
                            customer.phone != null
                                ? '${customer.name} (${customer.phone})'
                                : customer.name,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => selectedCustomer = value);
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Due date'),
                  subtitle: Text(dateFormat.format(selectedDueDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: pickDueDate,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    if (saved != true || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      await context.read<DebtRepository>().updateDebt(
        debtId: debt.id,
        customerId: selectedCustomer.id,
        dueDate: selectedDueDate,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Debt info updated.')));
      }
    } on DebtException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _deleteDebt() async {
    final debt = _debt;
    if (debt == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete debt?'),
        content: const Text(
          'This will delete the utang entry and remove the linked sale. Stock will be restored. You can only do this before any payment is recorded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    setState(() => _isProcessing = true);
    try {
      await context.read<DebtRepository>().deleteDebt(debt.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Debt deleted.')));
      context.pop();
    } on DebtException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final dateTimeFormat = DateFormat('MMM d, yyyy • h:mm a');
    final role = context.watch<AuthCubit>().state.user?.role;
    final canEdit = role == UserRole.admin || role == UserRole.cashier;
    final canDelete = role == UserRole.admin && (_debt?.payments.isEmpty ?? false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debt detail'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_debt != null && canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: _isProcessing ? null : _editDebt,
            ),
          if (_debt != null && canDelete)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _isProcessing ? null : _deleteDebt,
            ),
        ],
      ),
      body: Stack(
        children: [
          if (_isLoading)
            const SimpleLoading(message: 'Loading...')
          else if (_debt == null)
            const Center(child: Text('Debt not found'))
          else
            _buildContent(context, _debt!, dateFormat, dateTimeFormat),
          if (_isProcessing) const LoadingOverlay(message: 'Processing...'),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    DebtRecord debt,
    DateFormat dateFormat,
    DateFormat dateTimeFormat,
  ) {
    final role = context.watch<AuthCubit>().state.user?.role;
    final canPay = role == UserRole.admin || role == UserRole.cashier;
    final status = debt.displayStatus;
    final statusColor = switch (status) {
      DebtStatus.overdue => AppColors.error,
      DebtStatus.pending => AppColors.offline,
      DebtStatus.paid => AppColors.primary,
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  debt.customerName,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (debt.customerPhone != null) ...[
                  const SizedBox(height: 4),
                  Text(debt.customerPhone!),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Original amount'),
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
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Remaining',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      formatPeso(debt.remaining),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Created: ${dateTimeFormat.format(debt.createdAt)}'),
                Text('Due: ${dateFormat.format(debt.dueDate)}'),
                Text('Status: ${status.label}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Statement',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: _isProcessing
                  ? null
                  : () => _exportDebtStatement(print: true),
              icon: const Icon(Icons.print_outlined),
              label: const Text('Print'),
            ),
            OutlinedButton.icon(
              onPressed: _isProcessing
                  ? null
                  : () => _exportDebtStatement(print: false),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Download PDF'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Debt items',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (debt.items.isEmpty)
          const Text('No item details available for this debt.')
        else
          ...debt.items.map(
            (item) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: Text(item.productName),
                subtitle: Text('${item.qty} x ${formatPeso(item.unitPrice)}'),
                trailing: Text(
                  formatPeso(item.subtotal),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        if (!debt.isFullyPaid && canPay) ...[
          const SizedBox(height: 16),
          Text(
            'Record payment',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _paymentController,
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixText: '₱ ',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _isProcessing ? null : () => _recordPayment(),
            child: const Text('Record partial payment'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _isProcessing
                ? null
                : () => _recordPayment(fullAmount: true),
            child: Text('Mark fully paid (${formatPeso(debt.remaining)})'),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          'Payment history',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (debt.payments.isEmpty)
          const Text('No payments yet.')
        else
          ...debt.payments.map(
            (p) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(formatPeso(p.amount)),
                subtitle: Text(dateFormat.format(p.paidAt)),
                leading: const Icon(Icons.payments_outlined),
              ),
            ),
          ),
      ],
    );
  }
}
