import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:listapay/core/theme/app_theme.dart';
import 'package:listapay/core/utils/currency_format.dart';
import 'package:listapay/core/widgets/empty_state.dart';
import 'package:listapay/data/services/reports_service.dart';
import 'package:listapay/domain/entities/payment_method.dart';
import 'package:listapay/presentation/modules/module_scaffold.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late Future<StoreReportSummary> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future = context.read<ReportsService>().loadSummary();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = context.read<ReportsService>().loadSummary();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return ModuleScaffold(
      title: 'Reports',
      icon: Icons.bar_chart,
      emptyTitle: '',
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<StoreReportSummary>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 48),
                  EmptyState(
                    icon: Icons.error_outline,
                    title: 'Could not load reports',
                    subtitle: snapshot.error.toString(),
                  ),
                ],
              );
            }

            final report = snapshot.data!;
            final hasSales = report.thisYear.count > 0;

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _SectionTitle('Analytics'),
                if (!hasSales)
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.query_stats),
                      title: Text('No earnings data yet'),
                      subtitle: Text(
                        'Complete a sale in POS to see daily, weekly, monthly, and yearly analytics.',
                      ),
                    ),
                  )
                else ...[
                  _EarningsCard(label: 'Today', stats: report.todayEarnings),
                  const SizedBox(height: 8),
                  _EarningsCard(
                    label: 'This week',
                    stats: report.thisWeekEarnings,
                  ),
                  const SizedBox(height: 8),
                  _EarningsCard(
                    label: 'This month',
                    stats: report.thisMonthEarnings,
                  ),
                  const SizedBox(height: 8),
                  _EarningsCard(
                    label: 'This year',
                    stats: report.thisYearEarnings,
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Earnings are computed as sales minus product cost using the costs currently saved in Inventory.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                _SectionTitle('Sales'),
                _StatCard(
                  label: 'Today',
                  total: report.today.total,
                  count: report.today.count,
                ),
                const SizedBox(height: 8),
                _StatCard(
                  label: 'This week',
                  total: report.thisWeek.total,
                  count: report.thisWeek.count,
                ),
                const SizedBox(height: 8),
                _StatCard(
                  label: 'This month',
                  total: report.thisMonth.total,
                  count: report.thisMonth.count,
                ),
                const SizedBox(height: 8),
                _StatCard(
                  label: 'This year',
                  total: report.thisYear.total,
                  count: report.thisYear.count,
                ),
                const SizedBox(height: 20),
                _SectionTitle('Today by payment'),
                if (report.paymentBreakdown.isEmpty)
                  const Card(
                    child: ListTile(
                      title: Text('No sales today'),
                      subtitle: Text(
                        'Complete a sale in POS to see breakdown.',
                      ),
                    ),
                  )
                else
                  ...report.paymentBreakdown.map((row) {
                    final method = PaymentMethod.fromValue(row.method);
                    return Card(
                      child: ListTile(
                        title: Text(method.label),
                        subtitle: Text(
                          '${row.count} transaction${row.count == 1 ? '' : 's'}',
                        ),
                        trailing: Text(
                          formatPeso(row.total),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 20),
                _SectionTitle('Utang'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _DebtRow(
                          label: 'Outstanding balance',
                          value: formatPeso(report.outstandingDebt),
                          emphasized: true,
                        ),
                        const Divider(height: 24),
                        _DebtRow(
                          label: 'Active debts',
                          value: '${report.activeDebtCount}',
                        ),
                        const SizedBox(height: 8),
                        _DebtRow(
                          label: 'Overdue',
                          value: '${report.overdueDebtCount}',
                          valueColor: report.overdueDebtCount > 0
                              ? AppColors.offline
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.total,
    required this.count,
  });

  final String label;
  final double total;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(label),
        subtitle: Text('$count sale${count == 1 ? '' : 's'}'),
        trailing: Text(
          formatPeso(total),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _EarningsCard extends StatelessWidget {
  const _EarningsCard({required this.label, required this.stats});

  final String label;
  final EarningsPeriodStats stats;

  @override
  Widget build(BuildContext context) {
    final color = switch (stats.earnings) {
      > 0 => AppColors.primary,
      < 0 => AppColors.error,
      _ => AppColors.textSecondary,
    };
    final icon = switch (stats.earnings) {
      > 0 => Icons.trending_up,
      < 0 => Icons.trending_down,
      _ => Icons.trending_flat,
    };
    final status = switch (stats.earnings) {
      > 0 => 'Earning',
      < 0 => 'Losing',
      _ => 'Break-even',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16, color: color),
                      const SizedBox(width: 4),
                      Text(
                        status,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              formatPeso(stats.earnings),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${stats.count} sale${stats.count == 1 ? '' : 's'} in this period',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _AnalyticsMetric(
                    label: 'Revenue',
                    value: formatPeso(stats.revenue),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AnalyticsMetric(
                    label: 'Cost',
                    value: formatPeso(stats.cost),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsMetric extends StatelessWidget {
  const _AnalyticsMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _DebtRow extends StatelessWidget {
  const _DebtRow({
    required this.label,
    required this.value,
    this.emphasized = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool emphasized;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final style = emphasized
        ? Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor ?? AppColors.primary,
          )
        : Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor,
          );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(value, style: style),
      ],
    );
  }
}
