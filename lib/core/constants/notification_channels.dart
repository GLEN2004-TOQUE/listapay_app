abstract final class NotificationChannels {
  static const inventory = 'inventory_alerts';
  static const debt = 'debt_reminders';
  static const system = 'system_alerts';
}

abstract final class NotificationIds {
  static const dailyDebtCheck = 1;
  static const lowStock = 100;
  static const overdueDebts = 200;
  static const dueSoonDebts = 201;
}
