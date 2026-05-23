import 'package:flutter_test/flutter_test.dart';
import 'package:listapay/core/constants/notification_channels.dart';

void main() {
  test('notification channel ids are defined', () {
    expect(NotificationChannels.inventory, isNotEmpty);
    expect(NotificationChannels.debt, isNotEmpty);
    expect(NotificationChannels.system, isNotEmpty);
  });

  test('notification ids are unique', () {
    const ids = [
      NotificationIds.dailyDebtCheck,
      NotificationIds.lowStock,
      NotificationIds.overdueDebts,
      NotificationIds.dueSoonDebts,
    ];
    expect(ids.toSet().length, ids.length);
  });
}
