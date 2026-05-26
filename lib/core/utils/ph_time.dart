import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

final class PhTime {
  PhTime._();

  static const zoneName = 'Asia/Manila';

  static bool _initialized = false;
  static late final tz.Location _location;

  static tz.Location get location {
    if (!_initialized) {
      tz_data.initializeTimeZones();
      _location = tz.getLocation(zoneName);
      _initialized = true;
    }
    return _location;
  }

  static tz.TZDateTime now() => tz.TZDateTime.now(location);

  static tz.TZDateTime today() {
    final now = PhTime.now();
    return tz.TZDateTime(location, now.year, now.month, now.day);
  }

  static tz.TZDateTime toDateTime(DateTime dateTime) =>
      tz.TZDateTime.from(dateTime, location);

  static tz.TZDateTime startOfDay(DateTime dateTime) {
    final value = toDateTime(dateTime);
    return tz.TZDateTime(location, value.year, value.month, value.day);
  }

  static String format(DateFormat format, DateTime dateTime) =>
      format.format(toDateTime(dateTime));
}
