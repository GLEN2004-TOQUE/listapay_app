import 'package:listapay/data/database/app_database.dart';
import 'package:listapay/domain/entities/debt_status.dart';

class SalesPeriodStats {
  const SalesPeriodStats({required this.total, required this.count});

  final double total;
  final int count;
}

class EarningsPeriodStats {
  const EarningsPeriodStats({
    required this.revenue,
    required this.cost,
    required this.earnings,
    required this.count,
  });

  final double revenue;
  final double cost;
  final double earnings;
  final int count;
}

class PaymentMethodBreakdown {
  const PaymentMethodBreakdown({
    required this.method,
    required this.total,
    required this.count,
  });

  final String method;
  final double total;
  final int count;
}

class PurchaseHistoryItem {
  const PurchaseHistoryItem({
    required this.productName,
    required this.qty,
    required this.unitPrice,
    required this.subtotal,
  });

  final String productName;
  final int qty;
  final double unitPrice;
  final double subtotal;
}

class PurchaseHistoryEntry {
  const PurchaseHistoryEntry({
    required this.saleId,
    required this.createdAt,
    required this.paymentMethod,
    required this.total,
    required this.amountPaid,
    required this.changeAmount,
    required this.items,
    this.customerName,
  });

  final int saleId;
  final DateTime createdAt;
  final String paymentMethod;
  final double total;
  final double amountPaid;
  final double changeAmount;
  final List<PurchaseHistoryItem> items;
  final String? customerName;
}

class StoreReportSummary {
  const StoreReportSummary({
    required this.today,
    required this.thisWeek,
    required this.thisMonth,
    required this.thisYear,
    required this.todayEarnings,
    required this.thisWeekEarnings,
    required this.thisMonthEarnings,
    required this.thisYearEarnings,
    required this.paymentBreakdown,
    required this.purchaseHistory,
    required this.outstandingDebt,
    required this.activeDebtCount,
    required this.overdueDebtCount,
  });

  final SalesPeriodStats today;
  final SalesPeriodStats thisWeek;
  final SalesPeriodStats thisMonth;
  final SalesPeriodStats thisYear;
  final EarningsPeriodStats todayEarnings;
  final EarningsPeriodStats thisWeekEarnings;
  final EarningsPeriodStats thisMonthEarnings;
  final EarningsPeriodStats thisYearEarnings;
  final List<PaymentMethodBreakdown> paymentBreakdown;
  final List<PurchaseHistoryEntry> purchaseHistory;
  final double outstandingDebt;
  final int activeDebtCount;
  final int overdueDebtCount;
}

/// Aggregates local SQLite sales and debt data for the Reports screen.
class ReportsService {
  ReportsService(this._db);

  final AppDatabase _db;

  Future<StoreReportSummary> loadSummary() async {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfWeek = startOfToday.subtract(
      Duration(days: now.weekday - DateTime.monday),
    );
    final startOfMonth = DateTime(now.year, now.month, 1);
    final startOfYear = DateTime(now.year, 1, 1);

    final sales = await _db.select(_db.sales).get();
    final saleItems = await _db.select(_db.saleItems).get();
    final products = await _db.select(_db.products).get();
    final customers = await _db.select(_db.customers).get();

    final productCosts = {
      for (final product in products) product.id: product.cost,
    };
    final productNames = {
      for (final product in products) product.id: product.name,
    };
    final customerNames = {
      for (final customer in customers) customer.id: customer.name,
    };
    final saleCostTotals = <int, double>{};
    final saleItemsBySaleId = <int, List<PurchaseHistoryItem>>{};

    for (final item in saleItems) {
      final itemCost = (productCosts[item.productId] ?? 0) * item.qty;
      saleCostTotals[item.saleId] =
          (saleCostTotals[item.saleId] ?? 0) + itemCost;
      final items = saleItemsBySaleId.putIfAbsent(item.saleId, () => []);
      items.add(
        PurchaseHistoryItem(
          productName: productNames[item.productId] ?? 'Unknown item',
          qty: item.qty,
          unitPrice: item.unitPrice,
          subtotal: item.subtotal,
        ),
      );
    }

    bool isWithin(DateTime createdAt, DateTime start, {DateTime? end}) {
      if (createdAt.isBefore(start)) return false;
      if (end != null && !createdAt.isBefore(end)) return false;
      return true;
    }

    double sumSince(DateTime start, {DateTime? end}) {
      return sales
          .where((s) {
            final created = s.createdAt;
            return isWithin(created, start, end: end);
          })
          .fold<double>(0, (sum, s) => sum + s.total);
    }

    int countSince(DateTime start, {DateTime? end}) {
      return sales.where((s) {
        final created = s.createdAt;
        return isWithin(created, start, end: end);
      }).length;
    }

    double costSince(DateTime start, {DateTime? end}) {
      return sales
          .where((s) => isWithin(s.createdAt, start, end: end))
          .fold<double>(0, (sum, s) => sum + (saleCostTotals[s.id] ?? 0));
    }

    SalesPeriodStats salesStatsSince(DateTime start, {DateTime? end}) {
      return SalesPeriodStats(
        total: sumSince(start, end: end),
        count: countSince(start, end: end),
      );
    }

    EarningsPeriodStats earningsStatsSince(DateTime start, {DateTime? end}) {
      final revenue = sumSince(start, end: end);
      final cost = costSince(start, end: end);
      return EarningsPeriodStats(
        revenue: revenue,
        cost: cost,
        earnings: revenue - cost,
        count: countSince(start, end: end),
      );
    }

    final todayStats = salesStatsSince(startOfToday);
    final weekStats = salesStatsSince(startOfWeek);
    final monthStats = salesStatsSince(startOfMonth);
    final yearStats = salesStatsSince(startOfYear);
    final todayEarnings = earningsStatsSince(startOfToday);
    final weekEarnings = earningsStatsSince(startOfWeek);
    final monthEarnings = earningsStatsSince(startOfMonth);
    final yearEarnings = earningsStatsSince(startOfYear);

    final breakdownMap = <String, ({double total, int count})>{};
    for (final sale in sales.where(
      (s) => !s.createdAt.isBefore(startOfToday),
    )) {
      final entry = breakdownMap[sale.paymentMethod] ?? (total: 0.0, count: 0);
      breakdownMap[sale.paymentMethod] = (
        total: entry.total + sale.total,
        count: entry.count + 1,
      );
    }

    final paymentBreakdown =
        breakdownMap.entries
            .map(
              (e) => PaymentMethodBreakdown(
                method: e.key,
                total: e.value.total,
                count: e.value.count,
              ),
            )
            .toList()
          ..sort((a, b) => b.total.compareTo(a.total));

    final purchaseHistory = sales.map((sale) {
      final defaultAmountPaid = sale.paymentMethod == 'utang'
          ? 0.0
          : sale.total;
      final amountPaid = sale.amountPaid > 0
          ? sale.amountPaid
          : defaultAmountPaid;
      return PurchaseHistoryEntry(
        saleId: sale.id,
        createdAt: sale.createdAt,
        paymentMethod: sale.paymentMethod,
        total: sale.total,
        amountPaid: amountPaid,
        changeAmount: sale.changeAmount,
        customerName: sale.customerId == null
            ? null
            : customerNames[sale.customerId!],
        items: List.unmodifiable(saleItemsBySaleId[sale.id] ?? const []),
      );
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final debts = await _db.select(_db.debts).get();
    final payments = await _db.select(_db.payments).get();

    final paidByDebt = <int, double>{};
    for (final p in payments) {
      paidByDebt[p.debtId] = (paidByDebt[p.debtId] ?? 0) + p.amount;
    }

    var outstanding = 0.0;
    var activeCount = 0;
    var overdueCount = 0;
    final todayDate = DateTime(now.year, now.month, now.day);

    for (final debt in debts) {
      if (debt.status == DebtStatus.paid.value) continue;

      final paid = paidByDebt[debt.id] ?? 0;
      final remaining = debt.amount - paid;
      if (remaining <= 0) continue;

      activeCount++;
      outstanding += remaining;

      final dueDay = DateTime(
        debt.dueDate.year,
        debt.dueDate.month,
        debt.dueDate.day,
      );
      if (dueDay.isBefore(todayDate)) overdueCount++;
    }

    return StoreReportSummary(
      today: todayStats,
      thisWeek: weekStats,
      thisMonth: monthStats,
      thisYear: yearStats,
      todayEarnings: todayEarnings,
      thisWeekEarnings: weekEarnings,
      thisMonthEarnings: monthEarnings,
      thisYearEarnings: yearEarnings,
      paymentBreakdown: paymentBreakdown,
      purchaseHistory: purchaseHistory,
      outstandingDebt: outstanding,
      activeDebtCount: activeCount,
      overdueDebtCount: overdueCount,
    );
  }
}
