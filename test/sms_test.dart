import 'package:flutter_test/flutter_test.dart';
import 'package:listapay/core/utils/phone_format.dart';
import 'package:listapay/core/utils/sms_templates.dart';

void main() {
  group('normalizePhilippinePhone', () {
    test('normalizes 09xx format', () {
      expect(normalizePhilippinePhone('09171234567'), '639171234567');
    });

    test('normalizes +63 format', () {
      expect(normalizePhilippinePhone('+63 917 123 4567'), '639171234567');
    });

    test('returns null for invalid', () {
      expect(normalizePhilippinePhone('12345'), isNull);
    });
  });

  group('sms templates', () {
    test('due soon message includes amount and date', () {
      final msg = buildDueSoonSms(
        customerName: 'Juan',
        amount: 500,
        dueDate: DateTime(2026, 6, 1),
      );
      expect(msg, contains('Juan'));
      expect(msg, contains('500'));
      expect(msg, contains('ListaPay'));
    });

    test('overdue message includes remaining', () {
      final msg = buildOverdueSms(
        customerName: 'Maria',
        remaining: 250,
      );
      expect(msg, contains('Maria'));
      expect(msg, contains('overdue'));
    });
  });
}
