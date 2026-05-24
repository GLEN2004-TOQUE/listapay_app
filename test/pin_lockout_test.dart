import 'package:flutter_test/flutter_test.dart';
import 'package:listapay/core/security/pin_lockout_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('locks out after max failed attempts', () async {
    final lockout = PinLockoutService();

    for (var i = 0; i < PinLockoutService.maxAttempts; i++) {
      await lockout.recordFailure();
    }

    final remaining = await lockout.remainingLockout();
    expect(remaining, isNotNull);
    expect(remaining!.inSeconds, greaterThan(0));
  });

  test('clears lockout on success', () async {
    final lockout = PinLockoutService();

    for (var i = 0; i < PinLockoutService.maxAttempts; i++) {
      await lockout.recordFailure();
    }
    await lockout.recordSuccess();

    expect(await lockout.remainingLockout(), isNull);
  });
}
