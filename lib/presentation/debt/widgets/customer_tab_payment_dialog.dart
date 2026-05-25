import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:listapay/core/utils/currency_format.dart';
import 'package:listapay/core/widgets/simple_loading.dart';
import 'package:listapay/domain/repositories/debt_repository.dart';

class CustomerTabPaymentDialog extends StatefulWidget {
  const CustomerTabPaymentDialog({
    super.key,
    required this.repository,
    required this.customerId,
    required this.totalRemaining,
  });

  final DebtRepository repository;
  final int customerId;
  final double totalRemaining;

  @override
  State<CustomerTabPaymentDialog> createState() =>
      _CustomerTabPaymentDialogState();
}

class _CustomerTabPaymentDialogState extends State<CustomerTabPaymentDialog> {
  late final TextEditingController _amountController;
  late final FocusNode _amountFocusNode;
  bool _isSaving = false;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.totalRemaining.toStringAsFixed(2),
    );
    _amountController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _amountController.text.length,
    );
    _amountFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  double? _parseAmount() => double.tryParse(_amountController.text.trim());

  String? _validateAmount(double? amount) {
    if (amount == null || amount <= 0) {
      return 'Payment amount must be greater than zero.';
    }
    if (amount > widget.totalRemaining + 0.001) {
      return 'Payment cannot exceed the remaining balance.';
    }
    return null;
  }

  Future<void> _recordPayment() async {
    if (_isSaving) return;

    _amountFocusNode.unfocus();
    final amount = _parseAmount();
    final validationError = _validateAmount(amount);
    var paymentRecorded = false;

    if (validationError != null) {
      setState(() => _amountError = validationError);
      return;
    }

    final navigator = Navigator.of(context);
    setState(() {
      _isSaving = true;
      _amountError = null;
    });

    try {
      await widget.repository.recordCustomerPayment(
        customerId: widget.customerId,
        amount: amount!,
      );
      paymentRecorded = true;
      if (!mounted) return;
      navigator.pop(true);
    } on DebtException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted && !paymentRecorded) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSaving,
      child: AlertDialog(
        title: const Text('Pay whole tab'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total tab: ${formatPeso(widget.totalRemaining)}'),
            const SizedBox(height: 12),
            const Text(
              'Payment will be applied to the oldest unpaid utang first.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              focusNode: _amountFocusNode,
              autofocus: true,
              enabled: !_isSaving,
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '₱ ',
                errorText: _amountError,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              onChanged: (_) {
                if (_amountError != null) {
                  setState(() => _amountError = null);
                }
              },
              onTapOutside: (_) => _amountFocusNode.unfocus(),
              onSubmitted: (_) => _recordPayment(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _isSaving ? null : _recordPayment,
            child: _isSaving
                ? const BrandedLoadingIndicator(
                    size: 18,
                    strokeWidth: 2,
                    showHalo: false,
                  )
                : const Text('Record payment'),
          ),
        ],
      ),
    );
  }
}
