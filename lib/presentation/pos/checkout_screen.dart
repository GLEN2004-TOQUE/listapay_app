import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:listapay/core/router/app_router.dart';
import 'package:listapay/core/theme/app_theme.dart';
import 'package:listapay/core/utils/currency_format.dart';
import 'package:listapay/core/utils/ph_time.dart';
import 'package:listapay/core/widgets/simple_loading.dart';
import 'package:listapay/data/services/notification_service.dart';
import 'package:listapay/data/services/payment_config_service.dart';
import 'package:listapay/data/services/receipt_service.dart';
import 'package:listapay/domain/entities/completed_sale.dart';
import 'package:listapay/domain/entities/debt_record.dart';
import 'package:listapay/domain/entities/ewallet_payment_config.dart';
import 'package:listapay/domain/entities/customer_summary.dart';
import 'package:listapay/domain/entities/payment_method.dart';
import 'package:listapay/domain/repositories/customer_repository.dart';
import 'package:listapay/domain/repositories/debt_repository.dart';
import 'package:listapay/domain/repositories/pos_repository.dart';
import 'package:listapay/presentation/auth/auth_cubit.dart';
import 'package:listapay/presentation/debt/widgets/customer_tab_payment_dialog.dart';
import 'package:listapay/presentation/pos/cart_cubit.dart';
import 'package:listapay/presentation/pos/widgets/payment_method_tile.dart';
import 'package:listapay/presentation/pos/widgets/payment_qr_panel.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  final TextEditingController _cashPaidController = TextEditingController();
  List<CustomerSummary> _customers = [];
  CustomerSummary? _selectedCustomer;
  DateTime _dueDate = PhTime.today().add(const Duration(days: 30));
  bool _loadingCustomers = true;
  bool _isProcessing = false;
  EwalletPaymentConfig? _ewalletConfig;
  bool _loadingEwallet = false;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    _loadEwalletConfig(_paymentMethod);
  }

  @override
  void dispose() {
    _cashPaidController.dispose();
    super.dispose();
  }

  Future<void> _loadEwalletConfig(PaymentMethod method) async {
    if (!method.showsEwalletDetails) {
      if (mounted) setState(() => _ewalletConfig = null);
      return;
    }
    setState(() => _loadingEwallet = true);
    final config = await context.read<PaymentConfigService>().getConfig(method);
    if (mounted) {
      setState(() {
        _ewalletConfig = config;
        _loadingEwallet = false;
      });
    }
  }

  void _selectPaymentMethod(PaymentMethod method) {
    setState(() => _paymentMethod = method);
    _loadEwalletConfig(method);
  }

  Future<void> _loadCustomers() async {
    final customers = await context
        .read<CustomerRepository>()
        .getCustomerSummaries();
    if (mounted) {
      setState(() {
        _customers = customers;
        _loadingCustomers = false;
      });
    }
  }

  Future<void> _quickAddCustomer() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final customerRepository = context.read<CustomerRepository>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quick add customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name *'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Phone'),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved != true || !mounted) {
      nameController.dispose();
      phoneController.dispose();
      return;
    }

    try {
      final id = await customerRepository.saveCustomer(
        name: nameController.text,
        phone: phoneController.text,
      );
      final customer = await customerRepository.getCustomer(id);
      if (!mounted || customer == null) return;
      setState(() {
        _customers = [..._customers, customer.summary];
        _selectedCustomer = customer.summary;
      });
    } on CustomerException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }

    nameController.dispose();
    phoneController.dispose();
  }

  Future<void> _confirmSale() async {
    final cart = context.read<CartCubit>();
    final user = context.read<AuthCubit>().state.user!;
    final posRepo = context.read<PosRepository>();
    final receiptService = context.read<ReceiptService>();
    final amountPaid = _paymentMethod == PaymentMethod.cash
        ? _parseAmount(_cashPaidController.text)
        : null;

    if (_paymentMethod.requiresCustomer && _selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a customer for Utang.')),
      );
      return;
    }
    if (_paymentMethod == PaymentMethod.cash) {
      if (amountPaid == null || amountPaid <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter the amount paid by the customer.'),
          ),
        );
        return;
      }
      if (amountPaid < cart.state.total) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Amount paid is less than the sale total.'),
          ),
        );
        return;
      }
    }

    setState(() => _isProcessing = true);

    try {
      final sale = await posRepo.completeSale(
        userId: user.id,
        lines: cart.state.lines,
        paymentMethod: _paymentMethod,
        amountPaid: amountPaid,
        customerId: _selectedCustomer?.id,
        debtDueDate: _paymentMethod == PaymentMethod.utang ? _dueDate : null,
      );

      if (!mounted) return;

      await context.read<NotificationService>().notifyLowStock(
        sale.lowStockProductNames,
      );

      cart.clear();
      await _showSuccessDialog(sale, receiptService);
      if (mounted) context.go(AppRoutes.pos);
    } on PosException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not complete sale.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _showSuccessDialog(
    CompletedSale sale,
    ReceiptService receiptService,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Sale complete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sale #${sale.saleId} · ${formatPeso(sale.total)}'),
            Text('Paid via ${sale.paymentMethod.label}'),
            if (sale.paymentMethod == PaymentMethod.cash) ...[
              const SizedBox(height: 12),
              _CheckoutSummaryRow(
                label: 'Amount paid',
                value: formatPeso(sale.amountPaid),
              ),
              const SizedBox(height: 6),
              _CheckoutSummaryRow(
                label: 'Change',
                value: formatPeso(sale.changeAmount),
                valueColor: AppColors.primary,
              ),
            ],
            if (sale.lowStockProductNames.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Low stock: ${sale.lowStockProductNames.join(', ')}',
                style: const TextStyle(fontSize: 12, color: AppColors.error),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await receiptService.shareReceipt(sale);
            },
            child: const Text('Share PDF'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await receiptService.printReceipt(sale);
            },
            child: const Text('Print'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: PhTime.today(),
      lastDate: PhTime.today().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  void _handleBackNavigation() {
    if (_isProcessing || !mounted) return;

    GoRouter.of(context).go(AppRoutes.pos);
  }

  List<DebtRecord> _activeDebtsForCustomer(List<DebtRecord> debts) {
    final customerId = _selectedCustomer?.id;
    if (customerId == null) return const [];

    final customerDebts = debts
        .where((debt) => debt.customerId == customerId && !debt.isFullyPaid)
        .toList();
    customerDebts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return customerDebts;
  }

  double _customerBalance(List<DebtRecord> debts) {
    return debts.fold<double>(0, (sum, debt) => sum + debt.remaining);
  }

  double? _parseAmount(String raw) {
    final sanitized = raw.replaceAll(',', '').trim();
    if (sanitized.isEmpty) return null;
    return double.tryParse(sanitized);
  }

  Widget _buildCashPaymentSection({
    required BuildContext context,
    required CartState cart,
  }) {
    final amountPaid = _parseAmount(_cashPaidController.text) ?? 0;
    final shortfall = amountPaid < cart.total ? cart.total - amountPaid : 0.0;
    final changeAmount = amountPaid > cart.total
        ? amountPaid - cart.total
        : 0.0;
    final hasEnoughCash = amountPaid >= cart.total && amountPaid > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cash payment',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cashPaidController,
              enabled: !_isProcessing,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
              ],
              decoration: const InputDecoration(
                labelText: 'Amount paid by customer',
                hintText: '0.00',
                prefixText: 'PHP ',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _CheckoutSummaryRow(
                    label: 'Total due',
                    value: formatPeso(cart.total),
                    valueColor: AppColors.primary,
                  ),
                  const SizedBox(height: 8),
                  _CheckoutSummaryRow(
                    label: 'Amount paid',
                    value: amountPaid > 0
                        ? formatPeso(amountPaid)
                        : 'Waiting for entry',
                  ),
                  const SizedBox(height: 8),
                  _CheckoutSummaryRow(
                    label: hasEnoughCash ? 'Customer change' : 'Still due',
                    value: formatPeso(hasEnoughCash ? changeAmount : shortfall),
                    valueColor: hasEnoughCash
                        ? AppColors.primary
                        : AppColors.error,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasEnoughCash
                  ? 'Change is calculated automatically before the sale is completed.'
                  : 'Enter the cash received to see the customer\'s change before confirming the sale.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportCustomerTab({
    required CustomerSummary customer,
    required List<DebtRecord> debts,
    required bool print,
  }) async {
    final receiptService = context.read<ReceiptService>();
    setState(() => _isProcessing = true);
    try {
      if (print) {
        await receiptService.printCustomerDebtStatement(
          customerName: customer.name,
          customerPhone: customer.phone,
          debts: debts,
        );
      } else {
        await receiptService.shareCustomerDebtStatement(
          customerName: customer.name,
          customerPhone: customer.phone,
          debts: debts,
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            print
                ? 'Could not open the print dialog.'
                : 'Could not generate the PDF file.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _collectWholeTabPayment({
    required CustomerSummary customer,
    required List<DebtRecord> debts,
  }) async {
    final repository = context.read<DebtRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final recorded = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CustomerTabPaymentDialog(
        repository: repository,
        customerId: customer.id,
        totalRemaining: _customerBalance(debts),
      ),
    );

    if (!mounted || recorded != true) return;

    navigator.pop();
    if (!mounted) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Payment recorded and applied to ${customer.name}\'s oldest unpaid debts.',
        ),
      ),
    );
  }

  Future<void> _showCustomerTabSheet({
    required CustomerSummary customer,
    required List<DebtRecord> debts,
    required double pendingSaleTotal,
  }) async {
    final dateFormat = DateFormat('MMM d, yyyy');
    final dateTimeFormat = DateFormat('MMM d, yyyy • h:mm a');
    final balance = _customerBalance(debts);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.9,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${customer.name} tab',
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (customer.phone != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    customer.phone!,
                    style: Theme.of(sheetContext).textTheme.bodyMedium
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Current unpaid tab'),
                            Text(
                              formatPeso(balance),
                              style: Theme.of(sheetContext)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('After this sale'),
                            Text(
                              formatPeso(balance + pendingSaleTotal),
                              style: Theme.of(sheetContext)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isProcessing
                          ? null
                          : () => _exportCustomerTab(
                              customer: customer,
                              debts: debts,
                              print: true,
                            ),
                      icon: const Icon(Icons.print_outlined),
                      label: const Text('Print tab'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isProcessing
                          ? null
                          : () => _exportCustomerTab(
                              customer: customer,
                              debts: debts,
                              print: false,
                            ),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Download PDF'),
                    ),
                    FilledButton.icon(
                      onPressed: _isProcessing
                          ? null
                          : () => _collectWholeTabPayment(
                              customer: customer,
                              debts: debts,
                            ),
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Pay tab'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Active utang entries',
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (debts.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text('This customer has no unpaid utang yet.'),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: debts.length,
                      itemBuilder: (context, index) {
                        final debt = debts[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Added ${PhTime.format(dateTimeFormat, debt.createdAt)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Due ${PhTime.format(dateFormat, debt.dueDate)}',
                                            style: Theme.of(
                                              sheetContext,
                                            ).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      formatPeso(debt.remaining),
                                      style: Theme.of(sheetContext)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: debt.isDueSoon
                                                ? AppColors.offline
                                                : AppColors.primary,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Original'),
                                    Text(formatPeso(debt.amount)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Paid'),
                                    Text(formatPeso(debt.paidAmount)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Items',
                                  style: Theme.of(sheetContext)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 8),
                                if (debt.items.isEmpty)
                                  const Text('No item details available.')
                                else
                                  ...debt.items.map(
                                    (item) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(item.productName),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            '${item.qty} x ${formatPeso(item.unitPrice)}',
                                            style: Theme.of(
                                              sheetContext,
                                            ).textTheme.bodySmall,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            formatPeso(item.subtotal),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerTabSection({
    required BuildContext context,
    required CartState cart,
  }) {
    final customer = _selectedCustomer;
    if (customer == null) return const SizedBox.shrink();

    final dateTimeFormat = DateFormat('MMM d, yyyy • h:mm a');

    return StreamBuilder<List<DebtRecord>>(
      stream: context.read<DebtRepository>().watchDebts(),
      builder: (context, snapshot) {
        final debts = _activeDebtsForCustomer(snapshot.data ?? const []);
        final currentBalance = _customerBalance(debts);
        final projectedBalance = currentBalance + cart.total;

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: SimpleLoading(message: 'Loading customer tab...'),
            ),
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Current tab',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showCustomerTabSheet(
                        customer: customer,
                        debts: debts,
                        pendingSaleTotal: cart.total,
                      ),
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: const Text('View full tab'),
                    ),
                  ],
                ),
                Text(
                  debts.isEmpty
                      ? 'This customer has no unpaid utang yet.'
                      : 'All unpaid utang for ${customer.name} is shown here before adding this sale.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Current unpaid balance'),
                    Text(
                      formatPeso(currentBalance),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('After this sale'),
                    Text(
                      formatPeso(projectedBalance),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                if (debts.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Recent unpaid entries',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...debts
                      .take(2)
                      .map(
                        (debt) => Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      PhTime.format(
                                        dateTimeFormat,
                                        debt.createdAt,
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    formatPeso(debt.remaining),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                debt.items.isEmpty
                                    ? 'No item details available.'
                                    : debt.items
                                          .map(
                                            (item) =>
                                                '${item.qty} x ${item.productName}',
                                          )
                                          .join(', '),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartCubit>().state;
    final dateFormat = DateFormat('MMM d, yyyy');

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_isProcessing) _handleBackNavigation();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Checkout'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _isProcessing ? null : _handleBackNavigation,
          ),
        ),
        body: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          formatPeso(cart.total),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Payment method',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...PaymentMethod.values.map((method) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: PaymentMethodTile(
                      method: method,
                      selected: _paymentMethod == method,
                      enabled: !_isProcessing,
                      onTap: () => _selectPaymentMethod(method),
                    ),
                  );
                }),
                if (_paymentMethod.showsEwalletDetails) ...[
                  const SizedBox(height: 12),
                  if (_loadingEwallet)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: SimpleLoading(
                        message: 'Loading payment details...',
                      ),
                    )
                  else
                    PaymentQrPanel(
                      method: _paymentMethod,
                      config: _ewalletConfig ?? const EwalletPaymentConfig(),
                    ),
                ],
                if (_paymentMethod == PaymentMethod.cash) ...[
                  const SizedBox(height: 12),
                  _buildCashPaymentSection(context: context, cart: cart),
                ],
                if (_paymentMethod.requiresCustomer) ...[
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Customer',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton(
                        onPressed: _quickAddCustomer,
                        child: const Text('+ Add'),
                      ),
                    ],
                  ),
                  if (_loadingCustomers)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: SimpleLoading(message: 'Loading customers...'),
                    )
                  else if (_customers.isEmpty)
                    const Text('No customers yet. Add one to continue.')
                  else
                    DropdownButtonFormField<CustomerSummary>(
                      initialValue: _selectedCustomer,
                      decoration: const InputDecoration(
                        labelText: 'Select customer',
                      ),
                      items: _customers
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(
                                c.phone != null
                                    ? '${c.name} (${c.phone})'
                                    : c.name,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _isProcessing
                          ? null
                          : (v) => setState(() => _selectedCustomer = v),
                    ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Due date'),
                    subtitle: Text(PhTime.format(dateFormat, _dueDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: _isProcessing ? null : _pickDueDate,
                  ),
                  const SizedBox(height: 8),
                  _buildCustomerTabSection(context: context, cart: cart),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isProcessing ? null : _confirmSale,
                  child: const Text('Confirm sale'),
                ),
              ],
            ),
            if (_isProcessing)
              const LoadingOverlay(message: 'Processing sale...'),
          ],
        ),
      ),
    );
  }
}

class _CheckoutSummaryRow extends StatelessWidget {
  const _CheckoutSummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
