import 'package:listapay/data/database/app_database.dart';
import 'package:listapay/domain/entities/debt_status.dart';

class SalesPeriodStats {
  const SalesPeriodStats({
    required this.total,
    required this.count,
  });

  final double total;
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

class StoreReportSummary {
  const StoreReportSummary({
    required this.today,
    required this.last7Days,
    required this.thisMonth,
    required this.paymentBreakdown,
    required this.outstandingDebt,
    required this.activeDebtCount,
    required this.overdueDebtCount,
  });

  final SalesPeriodStats today;
  final SalesPeriodStats last7Days;
  final SalesPeriodStats thisMonth;
  final List<PaymentMethodBreakdown> paymentBreakdown;
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
    final startOf7Days = startOfToday.subtract(const Duration(days: 6));
    final startOfMonth = DateTime(now.year, now.month, 1);

    final sales = await _db.select(_db.sales).get();

    double sumSince(DateTime start, {DateTime? end}) {
      return sales
          .where((s) {
            final created = s.createdAt;
            if (created.isBefore(start)) return false;
            if (end != null && !created.isBefore(end)) return false;
            return true;
          })
          .fold<double>(0, (sum, s) => sum + s.total);
    }

    int countSince(DateTime start, {DateTime? end}) {
      return sales.where((s) {
        final created = s.createdAt;
        if (created.isBefore(start)) return false;
        if (end != null && !created.isBefore(end)) return false;
        return true;
      }).length;
    }

    final todayStats = SalesPeriodStats(
      total: sumSince(startOfToday),
      count: countSince(startOfToday),
    );
    final weekStats = SalesPeriodStats(
      total: sumSince(startOf7Days),
      count: countSince(startOf7Days),
    );
    final monthStats = SalesPeriodStats(
      total: sumSince(startOfMonth),
      count: countSince(startOfMonth),
    );

    final breakdownMap = <String, ({double total, int count})>{};
    for (final sale in sales.where((s) => !s.createdAt.isBefore(startOfToday))) {
      final entry = breakdownMap[sale.paymentMethod] ??
          (total: 0.0, count: 0);
      breakdownMap[sale.paymentMethod] = (
        total: entry.total + sale.total,
        count: entry.count + 1,
      );
    }

    final paymentBreakdown = breakdownMap.entries
        .map(
          (e) => PaymentMethodBreakdown(
            method: e.key,
            total: e.value.total,
            count: e.value.count,
          ),
        )
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));

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
      last7Days: weekStats,
      thisMonth: monthStats,
      paymentBreakdown: paymentBreakdown,
      outstandingDebt: outstanding,
      activeDebtCount: activeCount,
      overdueDebtCount: overdueCount,
    );
  }
}
