import 'package:flutter_timezone/flutter_timezone.dart';

/// The device's IANA timezone, e.g. "Australia/Sydney". functions/index.js
/// reads it from users/{uid}.timezone to send notifications at local time.
///
/// flutter_timezone 5.x returns a TimezoneInfo whose toString() is just
/// "TimezoneInfo" — the name is in `.identifier`. Parsing toString() saved
/// "TimezoneInfo" for every user, which the server rejects.
Future<String> deviceTimezone() async {
  final tz = await FlutterTimezone.getLocalTimezone();
  return tz.identifier;
}
