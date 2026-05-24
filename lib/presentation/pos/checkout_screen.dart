import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:listapay/core/router/app_router.dart';
import 'package:listapay/core/theme/app_theme.dart';
import 'package:listapay/core/utils/currency_format.dart';
import 'package:listapay/core/widgets/simple_loading.dart';
import 'package:listapay/data/services/notification_service.dart';
import 'package:listapay/data/services/payment_config_service.dart';
import 'package:listapay/data/services/receipt_service.dart';
import 'package:listapay/domain/entities/completed_sale.dart';
import 'package:listapay/domain/entities/ewallet_payment_config.dart';
import 'package:listapay/domain/entities/customer_summary.dart';
import 'package:listapay/domain/entities/payment_method.dart';
import 'package:listapay/domain/repositories/customer_repository.dart';
import 'package:listapay/domain/repositories/pos_repository.dart';
import 'package:listapay/presentation/auth/auth_cubit.dart';
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
  List<CustomerSummary> _customers = [];
  CustomerSummary? _selectedCustomer;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
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

  Future<void> _loadEwalletConfig(PaymentMethod method) async {
    if (!method.showsEwalletDetails) {
      if (mounted) setState(() => _ewalletConfig = null);
      return;
    }
    setState(() => _loadingEwallet = true);
    final config =
        await context.read<PaymentConfigService>().getConfig(method);
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
    final customers = await context.read<CustomerRepository>().getCustomerSummaries();
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
      final id = await context.read<CustomerRepository>().saveCustomer(
            name: nameController.text,
            phone: phoneController.text,
          );
      final customer = await context.read<CustomerRepository>().getCustomer(id);
      if (customer == null) return;
      setState(() {
        _customers = [..._customers, customer.summary];
        _selectedCustomer = customer.summary;
      });
    } on CustomerException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }

    nameController.dispose();
    phoneController.dispose();
  }

  Future<void> _confirmSale() async {
    final cart = context.read<CartCubit>();
    final user = context.read<AuthCubit>().state.user!;
    final posRepo = context.read<PosRepository>();
    final receiptService = context.read<ReceiptService>();

    if (_paymentMethod.requiresCustomer && _selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a customer for Utang.')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final sale = await posRepo.completeSale(
        userId: user.id,
        lines: cart.state.lines,
        paymentMethod: _paymentMethod,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
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
            if (sale.lowStockProductNames.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Low stock: ${sale.lowStockProductNames.join(', ')}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.error,
                ),
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
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartCubit>().state;
    final dateFormat = DateFormat('MMM d, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isProcessing ? null : () => context.pop(),
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
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
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
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  PaymentQrPanel(
                    method: _paymentMethod,
                    config: _ewalletConfig ?? const EwalletPaymentConfig(),
                  ),
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
                    decoration: const InputDecoration(labelText: 'Select customer'),
                    items: _customers
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(
                              c.phone != null ? '${c.name} (${c.phone})' : c.name,
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
                  subtitle: Text(dateFormat.format(_dueDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: _isProcessing ? null : _pickDueDate,
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isProcessing ? null : _confirmSale,
                child: const Text('Confirm sale'),
              ),
            ],
          ),
          if (_isProcessing) const LoadingOverlay(message: 'Processing sale...'),
        ],
      ),
    );
  }
}
