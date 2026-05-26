import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:ListaPay/core/utils/ph_time.dart';
import 'package:ListaPay/core/utils/phone_format.dart';
import 'package:ListaPay/core/utils/sms_templates.dart';
import 'package:ListaPay/data/database/app_database.dart';
import 'package:ListaPay/data/services/connectivity_service.dart';
import 'package:ListaPay/data/services/notification_service.dart';
import 'package:ListaPay/data/services/sms_service.dart';
import 'package:ListaPay/domain/repositories/debt_repository.dart';

class DebtSmsReminderResult {
  const DebtSmsReminderResult({
    this.sent = 0,
    this.skipped = 0,
    this.failed = 0,
    this.queued = 0,
  });

  final int sent;
  final int skipped;
  final int failed;
  final int queued;
}

class DebtSmsReminderService {
  DebtSmsReminderService(
    this._db,
    this._debtRepository,
    this._connectivity,
    this._smsService,
    this._notificationService,
  );

  final AppDatabase _db;
  final DebtRepository _debtRepository;
  final ConnectivityService _connectivity;
  final SmsService _smsService;
  final NotificationService _notificationService;

  static const _maxRetries = 3;
  static const _cooldownHours = 24;

  Future<DebtSmsReminderResult> processReminders() async {
    if (!await _connectivity.isOnline()) {
      return const DebtSmsReminderResult(skipped: 0);
    }
    if (!await _smsService.hasApiKey()) {
      return const DebtSmsReminderResult(skipped: 0);
    }

    await _debtRepository.refreshOverdueStatuses();

    var sent = 0;
    var skipped = 0;
    var failed = 0;
    var queued = 0;

    final targets = await _findSmsTargets();

    for (final target in targets) {
      if (target.phone == null ||
          normalizePhilippinePhone(target.phone) == null) {
        skipped++;
        continue;
      }

      if (await _wasSentRecently(target.debtId, target.smsType)) {
        skipped++;
        continue;
      }

      final result = await _smsService.sendMessage(
        phone: target.phone!,
        message: target.message,
      );

      if (result.success) {
        await _logSms(
          debtId: target.debtId,
          smsType: target.smsType,
          message: target.message,
          phone: target.phone!,
        );
        sent++;
      } else {
        await _enqueueRetry(
          debtId: target.debtId,
          phone: target.phone!,
          message: target.message,
          smsType: target.smsType,
          customerName: target.customerName,
        );
        failed++;
        queued++;
      }
    }

    return DebtSmsReminderResult(
      sent: sent,
      skipped: skipped,
      failed: failed,
      queued: queued,
    );
  }

  Future<DebtSmsReminderResult> processRetryQueue() async {
    if (!await _connectivity.isOnline()) {
      return const DebtSmsReminderResult();
    }
    if (!await _smsService.hasApiKey()) {
      return const DebtSmsReminderResult();
    }

    final pending =
        await (_db.select(_db.syncQueue)
              ..where(
                (q) =>
                    q.entityTable.equals('sms') &
                    q.retries.isSmallerThanValue(_maxRetries),
              )
              ..orderBy([(q) => OrderingTerm.asc(q.createdAt)]))
            .get();

    var sent = 0;
    var failed = 0;

    for (final item in pending) {
      final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
      final phone = payload['phone'] as String;
      final message = payload['message'] as String;
      final debtId = int.parse(item.recordId);
      final smsType = payload['smsType'] as String? ?? 'sms';

      final result = await _smsService.sendMessage(
        phone: phone,
        message: message,
      );

      if (result.success) {
        await (_db.delete(
          _db.syncQueue,
        )..where((q) => q.id.equals(item.id))).go();
        await _logSms(
          debtId: debtId,
          smsType: smsType,
          message: message,
          phone: phone,
        );
        sent++;
      } else {
        final newRetries = item.retries + 1;
        if (newRetries >= _maxRetries) {
          await (_db.delete(
            _db.syncQueue,
          )..where((q) => q.id.equals(item.id))).go();
          await _notificationService.notifySmsFailure(
            customerName: payload['customerName'] as String? ?? 'Customer',
          );
          failed++;
        } else {
          await (_db.update(_db.syncQueue)..where((q) => q.id.equals(item.id)))
              .write(SyncQueueCompanion(retries: Value(newRetries)));
          failed++;
        }
      }
    }

    return DebtSmsReminderResult(sent: sent, failed: failed, queued: failed);
  }

  Future<List<_SmsTarget>> _findSmsTargets() async {
    final today = PhTime.today();
    final dueSoonLimit = today.add(const Duration(days: 3));

    final query = _db.select(_db.debts).join([
      innerJoin(
        _db.customers,
        _db.customers.id.equalsExp(_db.debts.customerId),
      ),
    ])..where(_db.debts.status.isNotIn(['paid']));

    final rows = await query.get();
    final targets = <_SmsTarget>[];

    for (final row in rows) {
      final debt = row.readTable(_db.debts);
      final customer = row.readTable(_db.customers);

      final payments = await (_db.select(
        _db.payments,
      )..where((p) => p.debtId.equals(debt.id))).get();
      final paid = payments.fold<double>(0, (s, p) => s + p.amount);
      final remaining = debt.amount - paid;
      if (remaining <= 0.001) continue;

      final dueDay = PhTime.startOfDay(debt.dueDate);

      if (dueDay.isBefore(today)) {
        targets.add(
          _SmsTarget(
            debtId: debt.id,
            phone: customer.phone,
            customerName: customer.name,
            smsType: 'sms_overdue',
            message: buildOverdueSms(
              customerName: customer.name,
              remaining: remaining,
            ),
          ),
        );
      } else if (!dueDay.isBefore(today) && !dueDay.isAfter(dueSoonLimit)) {
        targets.add(
          _SmsTarget(
            debtId: debt.id,
            phone: customer.phone,
            customerName: customer.name,
            smsType: 'sms_due_soon',
            message: buildDueSoonSms(
              customerName: customer.name,
              amount: remaining,
              dueDate: debt.dueDate,
            ),
          ),
        );
      }
    }

    return targets;
  }

  Future<bool> _wasSentRecently(int debtId, String smsType) async {
    final since = PhTime.now().subtract(const Duration(hours: _cooldownHours));
    final existing =
        await (_db.select(_db.notificationLog)..where(
              (n) =>
                  n.type.equals(smsType) &
                  n.refId.equals(debtId.toString()) &
                  n.sentAt.isBiggerOrEqualValue(since),
            ))
            .get();
    return existing.isNotEmpty;
  }

  Future<void> _logSms({
    required int debtId,
    required String smsType,
    required String message,
    required String phone,
  }) async {
    await _db
        .into(_db.notificationLog)
        .insert(
          NotificationLogCompanion.insert(
            type: smsType,
            refId: Value(debtId.toString()),
            message: 'To $phone: $message',
            sentVia: 'semaphore',
          ),
        );
  }

  Future<void> _enqueueRetry({
    required int debtId,
    required String phone,
    required String message,
    required String smsType,
    String? customerName,
  }) async {
    final existing =
        await (_db.select(_db.syncQueue)..where(
              (q) =>
                  q.entityTable.equals('sms') &
                  q.recordId.equals(debtId.toString()) &
                  q.operation.equals('send'),
            ))
            .getSingleOrNull();

    final payload = jsonEncode({
      'phone': phone,
      'message': message,
      'smsType': smsType,
      'customerName': customerName,
    });

    if (existing != null) {
      await (_db.update(_db.syncQueue)..where((q) => q.id.equals(existing.id)))
          .write(SyncQueueCompanion(payloadJson: Value(payload)));
      return;
    }

    await _db
        .into(_db.syncQueue)
        .insert(
          SyncQueueCompanion.insert(
            entityTable: 'sms',
            recordId: debtId.toString(),
            operation: 'send',
            payloadJson: payload,
          ),
        );
  }
}

class _SmsTarget {
  const _SmsTarget({
    required this.debtId,
    required this.phone,
    required this.customerName,
    required this.smsType,
    required this.message,
  });

  final int debtId;
  final String? phone;
  final String customerName;
  final String smsType;
  final String message;
}
