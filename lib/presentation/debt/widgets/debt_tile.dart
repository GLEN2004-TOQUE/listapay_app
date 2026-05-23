import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:listapay/core/theme/app_theme.dart';
import 'package:listapay/core/utils/currency_format.dart';
import 'package:listapay/domain/entities/debt_record.dart';
import 'package:listapay/domain/entities/debt_status.dart';

class DebtTile extends StatelessWidget {
  const DebtTile({
    super.key,
    required this.debt,
    required this.onTap,
  });

  final DebtRecord debt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = debt.displayStatus;
    final statusColor = switch (status) {
      DebtStatus.overdue => AppColors.error,
      DebtStatus.pending => AppColors.offline,
      DebtStatus.paid => AppColors.primary,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        title: Text(
          debt.customerName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Due ${DateFormat('MMM d, yyyy').format(debt.dueDate)}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatPeso(debt.isFullyPaid ? debt.amount : debt.remaining),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                debt.isDueSoon && status == DebtStatus.pending
                    ? 'Due soon'
                    : status.label,
                style: TextStyle(fontSize: 10, color: statusColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
