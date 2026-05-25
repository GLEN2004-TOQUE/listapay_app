import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listapay/domain/entities/debt_record.dart';
import 'package:listapay/domain/entities/debt_status.dart';
import 'package:listapay/domain/repositories/debt_repository.dart';
import 'package:listapay/presentation/debt/widgets/customer_tab_payment_dialog.dart';

void main() {
  testWidgets('records partial tab payment and closes dialog', (tester) async {
    final completer = Completer<void>();
    double? recordedAmount;
    bool? dialogResult;
    final repository = _FakeDebtRepository(
      onRecordCustomerPayment: (customerId, amount) async {
        recordedAmount = amount;
        await completer.future;
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () async {
                  dialogResult = await showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => CustomerTabPaymentDialog(
                      repository: repository,
                      customerId: 1,
                      totalRemaining: 20,
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '5');
    await tester.tap(find.text('Record payment'));
    await tester.pump();

    expect(recordedAmount, 5);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);

    completer.complete();
    await tester.pumpAndSettle();

    expect(dialogResult, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('blocks amounts above remaining balance', (tester) async {
    final repository = _FakeDebtRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () {
                  showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => CustomerTabPaymentDialog(
                      repository: repository,
                      customerId: 1,
                      totalRemaining: 20,
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '25');
    await tester.tap(find.text('Record payment'));
    await tester.pumpAndSettle();

    expect(
      find.text('Payment cannot exceed the remaining balance.'),
      findsOneWidget,
    );
    expect(repository.recordedAmounts, isEmpty);
    expect(find.byType(AlertDialog), findsOneWidget);
  });
}

typedef _RecordCustomerPaymentCallback =
    Future<void> Function(int customerId, double amount);

class _FakeDebtRepository implements DebtRepository {
  _FakeDebtRepository({this.onRecordCustomerPayment});

  final _RecordCustomerPaymentCallback? onRecordCustomerPayment;
  final List<double> recordedAmounts = [];

  @override
  Future<DebtRecord?> getDebt(int id) async => null;

  @override
  Future<void> deleteDebt(int debtId) async => throw UnimplementedError();

  @override
  Future<void> markAsPaid(int debtId) async => throw UnimplementedError();

  @override
  Future<void> recordCustomerPayment({
    required int customerId,
    required double amount,
  }) async {
    recordedAmounts.add(amount);
    await onRecordCustomerPayment?.call(customerId, amount);
  }

  @override
  Future<void> recordPayment({
    required int debtId,
    required double amount,
  }) async => throw UnimplementedError();

  @override
  Future<void> refreshOverdueStatuses() async {}

  @override
  Future<void> updateDebt({
    required int debtId,
    required int customerId,
    required DateTime dueDate,
  }) async => throw UnimplementedError();

  @override
  Stream<List<DebtRecord>> watchDebts({DebtStatus? filter}) =>
      const Stream.empty();
}
