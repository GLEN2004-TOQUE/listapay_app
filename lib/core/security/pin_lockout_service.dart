import 'package:shared_preferences/shared_preferences.dart';

/// Tracks failed PIN attempts and temporary lockout on this device.
class PinLockoutService {
  PinLockoutService();

  static const maxAttempts = 5;
  static const lockoutDuration = Duration(minutes: 5);

  static const _failuresKey = 'pin_failed_attempts';
  static const _lockoutUntilKey = 'pin_lockout_until_ms';

  Future<Duration?> remainingLockout() async {
    final prefs = await SharedPreferences.getInstance();
    final untilMs = prefs.getInt(_lockoutUntilKey);
    if (untilMs == null) return null;

    final remaining = DateTime.fromMillisecondsSinceEpoch(untilMs).difference(
      DateTime.now(),
    );
    if (remaining.isNegative) {
      await _clearLockout(prefs);
      return null;
    }
    return remaining;
  }

  Future<void> recordFailure() async {
    final prefs = await SharedPreferences.getInstance();
    final failures = (prefs.getInt(_failuresKey) ?? 0) + 1;
    await prefs.setInt(_failuresKey, failures);

    if (failures >= maxAttempts) {
      final until = DateTime.now().add(lockoutDuration);
      await prefs.setInt(_lockoutUntilKey, until.millisecondsSinceEpoch);
      await prefs.setInt(_failuresKey, 0);
    }
  }

  Future<void> recordSuccess() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_failuresKey);
    await prefs.remove(_lockoutUntilKey);
  }

  Future<void> _clearLockout(SharedPreferences prefs) async {
    await prefs.remove(_lockoutUntilKey);
    await prefs.remove(_failuresKey);
  }
}
