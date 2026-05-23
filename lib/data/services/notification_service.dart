import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:listapay/core/constants/notification_channels.dart';
import 'package:listapay/data/database/app_database.dart';
import 'package:listapay/domain/repositories/debt_repository.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService(this._db, this._debtRepository);

  final AppDatabase _db;
  final DebtRepository _debtRepository;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  void Function(String route)? onNavigate;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Manila'));
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    await _createChannels();
    await requestPermissions();
    await scheduleDailyDebtReminder();

    _initialized = true;
  }

  Future<void> requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

  if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  Future<void> notifyLowStock(List<String> productNames) async {
    if (productNames.isEmpty) return;

    final names = productNames.take(5).join(', ');
    final suffix = productNames.length > 5 ? '…' : '';
    final message = 'Low stock: $names$suffix';

    await _show(
      id: NotificationIds.lowStock,
      channelId: NotificationChannels.inventory,
      title: 'Low stock alert',
      body: message,
      importance: Importance.high,
      priority: Priority.high,
      payload: 'inventory',
    );

    await _log(type: 'low_stock', message: message);
  }

  Future<void> runDebtChecks() async {
    await _debtRepository.refreshOverdueStatuses();

    final overdue = await _countDebts(overdueOnly: true);
    final dueSoon = await _countDebts(dueSoonOnly: true);

    if (overdue > 0) {
      final message = overdue == 1
          ? 'You have 1 overdue customer debt.'
          : 'You have $overdue overdue customer debts.';
      await _show(
        id: NotificationIds.overdueDebts,
        channelId: NotificationChannels.debt,
        title: 'Overdue debts',
        body: message,
        importance: Importance.high,
        priority: Priority.high,
        payload: 'debt',
      );
      await _log(type: 'debt_overdue', message: message);
    }

    if (dueSoon > 0) {
      final message = dueSoon == 1
          ? '1 debt is due within 3 days.'
          : '$dueSoon debts are due within 3 days.';
      await _show(
        id: NotificationIds.dueSoonDebts,
        channelId: NotificationChannels.debt,
        title: 'Debts due soon',
        body: message,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        payload: 'debt',
      );
      await _log(type: 'debt_due_soon', message: message);
    }
  }

  Future<void> scheduleDailyDebtReminder() async {
    await _plugin.zonedSchedule(
      NotificationIds.dailyDebtCheck,
      'ListaPay daily check',
      'Review overdue debts and low stock.',
      _next8Am(),
      NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationChannels.system,
          'System',
          channelDescription: 'Scheduled reminders and sync status',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'debt',
    );
  }

  Future<void> notifySmsFailure({required String customerName}) async {
    final message = 'Failed to send SMS to $customerName after 3 retries.';
    await _show(
      id: 300,
      channelId: NotificationChannels.system,
      title: 'SMS send failed',
      body: message,
      importance: Importance.high,
      priority: Priority.high,
      payload: 'system',
    );
    await _log(type: 'sms_failure', message: message);
  }

  Future<void> showTestNotification() async {
    await _show(
      id: 9999,
      channelId: NotificationChannels.system,
      title: 'ListaPay notifications',
      body: 'Local alerts are working.',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      payload: 'system',
    );
    await _log(type: 'test', message: 'Test notification sent');
  }

  Future<int> _countDebts({
    bool overdueOnly = false,
    bool dueSoonOnly = false,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueSoonLimit = today.add(const Duration(days: 3));

    final debts = await (_db.select(_db.debts)
          ..where((d) => d.status.isNotIn(['paid'])))
        .get();

    var count = 0;
    for (final debt in debts) {
      final payments = await (_db.select(_db.payments)
            ..where((p) => p.debtId.equals(debt.id)))
          .get();
      final paid = payments.fold<double>(0, (s, p) => s + p.amount);
      if (paid >= debt.amount - 0.001) continue;

      final dueDay = DateTime(
        debt.dueDate.year,
        debt.dueDate.month,
        debt.dueDate.day,
      );

      if (overdueOnly && dueDay.isBefore(today)) {
        count++;
      } else if (dueSoonOnly &&
          !dueDay.isBefore(today) &&
          !dueDay.isAfter(dueSoonLimit)) {
        count++;
      }
    }
    return count;
  }

  Future<void> _show({
    required int id,
    required String channelId,
    required String title,
    required String body,
    required Importance importance,
    required Priority priority,
    String? payload,
  }) async {
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          _channelName(channelId),
          channelDescription: _channelDescription(channelId),
          importance: importance,
          priority: priority,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  Future<void> _log({
    required String type,
    required String message,
    String? refId,
  }) async {
    await _db.into(_db.notificationLog).insert(
          NotificationLogCompanion.insert(
            type: type,
            refId: Value(refId),
            message: message,
            sentVia: 'local',
          ),
        );
  }

  Future<void> _createChannels() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    const channels = [
      AndroidNotificationChannel(
        NotificationChannels.inventory,
        'Inventory',
        description: 'Low stock alerts after sales',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        NotificationChannels.debt,
        'Debt Reminders',
        description: 'Overdue and upcoming debt alerts',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        NotificationChannels.system,
        'System',
        description: 'Scheduled checks and app status',
        importance: Importance.defaultImportance,
      ),
    ];

    for (final channel in channels) {
      await android.createNotificationChannel(channel);
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == 'debt') {
      onNavigate?.call('/debt');
    } else if (payload == 'inventory') {
      onNavigate?.call('/inventory');
    }
  }

  tz.TZDateTime _next8Am() {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 8);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  String _channelName(String id) => switch (id) {
        NotificationChannels.inventory => 'Inventory',
        NotificationChannels.debt => 'Debt Reminders',
        _ => 'System',
      };

  String _channelDescription(String id) => switch (id) {
        NotificationChannels.inventory => 'Low stock alerts',
        NotificationChannels.debt => 'Debt due and overdue alerts',
        _ => 'System notifications',
      };
}
