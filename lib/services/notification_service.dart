import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static const NotificationDetails _defaultNotificationDetails =
      NotificationDetails(
        android: AndroidNotificationDetails(
          'medicine_reminders',
          'Medicine Reminders',
          channelDescription: 'Reminder notifications for medicine intake',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

  static Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    tz.initializeTimeZones();
    await _configureLocalTimezone();

    const AndroidInitializationSettings androidInitSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInitSettings =
        DarwinInitializationSettings();

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInitSettings,
      iOS: iosInitSettings,
    );

    await _plugin.initialize(initSettings);
    await _requestPermissions();
    _initialized = true;
  }

  static Future<void> scheduleMedicineReminder({
    required int notificationId,
    required String medicineName,
    required DateTime scheduledAt,
    String? doseAmount,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    final tz.TZDateTime scheduledDate = tz.TZDateTime.from(
      scheduledAt,
      tz.local,
    );

    final String body = (doseAmount == null || doseAmount.trim().isEmpty)
        ? 'Time to take your medicine.'
        : 'Time to take $doseAmount of your medicine.';

    await _zonedScheduleWithFallback(
      notificationId: notificationId,
      title: 'Medicine Reminder: $medicineName',
      body: body,
      scheduledDate: scheduledDate,
    );
  }

  static Future<int> scheduleMedicineReminderRange({
    required int baseNotificationId,
    required String medicineName,
    required DateTime startDate,
    required DateTime endDate,
    required int hour,
    required int minute,
    String? doseAmount,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    final DateTime normalizedStart = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );
    final DateTime normalizedEnd = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
    );

    if (normalizedEnd.isBefore(normalizedStart)) {
      return 0;
    }

    final String body = (doseAmount == null || doseAmount.trim().isEmpty)
        ? 'Time to take your medicine.'
        : 'Time to take $doseAmount of your medicine.';

    DateTime cursor = normalizedStart;
    final DateTime now = DateTime.now();
    int scheduledCount = 0;
    int idOffset = 0;

    // Guard against accidentally scheduling an excessively large date span.
    while (!cursor.isAfter(normalizedEnd) && idOffset < 731) {
      final DateTime scheduledAt = DateTime(
        cursor.year,
        cursor.month,
        cursor.day,
        hour,
        minute,
      );

      if (scheduledAt.isAfter(now)) {
        final tz.TZDateTime scheduledDate = tz.TZDateTime.from(
          scheduledAt,
          tz.local,
        );
        await _zonedScheduleWithFallback(
          notificationId: baseNotificationId + idOffset,
          title: 'Medicine Reminder: $medicineName',
          body: body,
          scheduledDate: scheduledDate,
        );
        scheduledCount += 1;
      }

      idOffset += 1;
      cursor = cursor.add(const Duration(days: 1));
    }

    return scheduledCount;
  }

  static Future<void> showInstantTestNotification({
    required int notificationId,
    required String title,
    required String body,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    await _plugin.show(
      notificationId,
      title,
      body,
      _defaultNotificationDetails,
    );
  }

  static Future<void> scheduleTestNotificationInSeconds({
    required int notificationId,
    required int seconds,
    required String title,
    required String body,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    final tz.TZDateTime scheduledDate = tz.TZDateTime.now(
      tz.local,
    ).add(Duration(seconds: seconds));

    await _zonedScheduleWithFallback(
      notificationId: notificationId,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
    );
  }

  static Future<void> _zonedScheduleWithFallback({
    required int notificationId,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
  }) async {
    try {
      await _plugin.zonedSchedule(
        notificationId,
        title,
        body,
        scheduledDate,
        _defaultNotificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      await _plugin.zonedSchedule(
        notificationId,
        title,
        body,
        scheduledDate,
        _defaultNotificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  static Future<bool> areNotificationsEnabled() async {
    if (!_initialized) {
      await initialize();
    }

    final AndroidFlutterLocalNotificationsPlugin? androidPlatform = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final bool? androidEnabled = await androidPlatform
        ?.areNotificationsEnabled();
    if (androidEnabled != null) {
      return androidEnabled;
    }

    return true;
  }

  static Future<void> _configureLocalTimezone() async {
    try {
      final String timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  static Future<void> _requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlatform = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlatform?.requestNotificationsPermission();

    final IOSFlutterLocalNotificationsPlugin? iosPlatform = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await iosPlatform?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    final MacOSFlutterLocalNotificationsPlugin? macosPlatform = _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    await macosPlatform?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }
}
