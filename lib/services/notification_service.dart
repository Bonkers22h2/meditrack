// services/notification_service.dart
import 'dart:typed_data';
import 'package:flutter/material.dart'; // ADD THIS IMPORT FOR TimeOfDay

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static const int _escalationAttempts = 3;
  static const int _continuousLevel3Retries = 12;
  static const int _totalReminderAttempts =
      _escalationAttempts + _continuousLevel3Retries;
  static const Duration _escalationInterval = Duration(minutes: 2);
  static const String _defaultChannelId = 'medicine_reminders_v3';
  static const String _level1ChannelId = 'medicine_reminders_level_1_v3';
  static const String _level2ChannelId = 'medicine_reminders_level_2_v3';
  static const String _level3ChannelId = 'medicine_reminders_level_3_v3';
  static const String _level1Sound = 'reminder_level_1';
  static const String _level2Sound = 'reminder_level_2';
  static const String _level3Sound = 'reminder_level_3';
  static const String _notificationIcon = 'logo';

  static const NotificationDetails _defaultNotificationDetails =
      NotificationDetails(
        android: AndroidNotificationDetails(
          _defaultChannelId,
          'Medicine Reminders',
          channelDescription: 'Reminder notifications for medicine intake',
          icon: _notificationIcon,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(_level1Sound),
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
        AndroidInitializationSettings('@drawable/logo');
    const DarwinInitializationSettings iosInitSettings =
        DarwinInitializationSettings();

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInitSettings,
      iOS: iosInitSettings,
    );

    await _plugin.initialize(initSettings);
    await _createAndroidChannels();
    await _requestPermissions();
    _initialized = true;
  }

  static Future<bool> ensureNotificationAccess() async {
    if (!_initialized) {
      await initialize();
    } else {
      await _requestPermissions();
    }

    return areNotificationsEnabled();
  }

  static Future<void> scheduleMedicineReminder({
    required int medicineCreatedAtMillis,
    required String medicineName,
    required DateTime scheduledAt,
    String? patientName,
    String? doseAmount,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    final tz.TZDateTime? scheduledDate = _coerceToFutureSchedule(
      tz.TZDateTime.from(scheduledAt, tz.local),
    );

    if (scheduledDate == null) {
      return;
    }

    await _scheduleEscalatingReminder(
      medicineCreatedAtMillis: medicineCreatedAtMillis,
      scheduledDate: scheduledDate,
      medicineName: medicineName,
      patientName: patientName,
      doseAmount: doseAmount,
    );
  }

  static Future<int> scheduleMedicineReminderRange({
    required int medicineCreatedAtMillis,
    required String medicineName,
    required DateTime startDate,
    required DateTime endDate,
    required int hour,
    required int minute,
    String? frequency,
    String? patientName,
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

    final Set<int>? allowedWeekdays = _parseAllowedWeekdaysFromFrequency(
      frequency,
    );

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

      final bool weekdayAllowed =
          allowedWeekdays == null ||
          allowedWeekdays.contains(scheduledAt.weekday);

      if (weekdayAllowed) {
        final tz.TZDateTime? scheduledDate = _coerceToFutureSchedule(
          tz.TZDateTime.from(scheduledAt, tz.local),
          now: tz.TZDateTime.from(now, tz.local),
        );
        if (scheduledDate == null) {
          idOffset += 1;
          cursor = cursor.add(const Duration(days: 1));
          continue;
        }
        await _scheduleEscalatingReminder(
          medicineCreatedAtMillis: medicineCreatedAtMillis,
          scheduledDate: scheduledDate,
          medicineName: medicineName,
          patientName: patientName,
          doseAmount: doseAmount,
        );
        scheduledCount += 1;
      }

      idOffset += 1;
      cursor = cursor.add(const Duration(days: 1));
    }

    return scheduledCount;
  }

  static Set<int>? _parseAllowedWeekdaysFromFrequency(String? frequency) {
    if (frequency == null || frequency.trim().isEmpty) {
      return null;
    }

    final RegExp onDaysRegex = RegExp(
      r'^Every \d+(?:\.\d+)? hours on (.+)$',
      caseSensitive: false,
    );
    final Match? match = onDaysRegex.firstMatch(frequency.trim());
    if (match == null) {
      return null;
    }

    final String daysText = (match.group(1) ?? '').trim();
    if (daysText.isEmpty) {
      return null;
    }

    const Map<String, int> weekdayByToken = <String, int>{
      'mon': DateTime.monday,
      'monday': DateTime.monday,
      'tue': DateTime.tuesday,
      'tues': DateTime.tuesday,
      'tuesday': DateTime.tuesday,
      'wed': DateTime.wednesday,
      'wednesday': DateTime.wednesday,
      'thu': DateTime.thursday,
      'thur': DateTime.thursday,
      'thurs': DateTime.thursday,
      'thursday': DateTime.thursday,
      'fri': DateTime.friday,
      'friday': DateTime.friday,
      'sat': DateTime.saturday,
      'saturday': DateTime.saturday,
      'sun': DateTime.sunday,
      'sunday': DateTime.sunday,
    };

    final Set<int> allowedWeekdays = daysText
        .split(',')
        .map(
          (String token) => token
              .trim()
              .toLowerCase()
              .replaceAll('.', '')
              .replaceAll(';', ''),
        )
        .map((String token) => weekdayByToken[token])
        .whereType<int>()
        .toSet();

    if (allowedWeekdays.isEmpty) {
      return null;
    }

    return allowedWeekdays;
  }

  static tz.TZDateTime? _coerceToFutureSchedule(
    tz.TZDateTime scheduledDate, {
    tz.TZDateTime? now,
  }) {
    final tz.TZDateTime current = now ?? tz.TZDateTime.now(tz.local);

    // If already in the future, keep it unchanged.
    if (scheduledDate.isAfter(current)) {
      return scheduledDate;
    }

    final Duration lag = current.difference(scheduledDate);

    // Guard against minute-level race conditions while saving reminders.
    if (lag <= const Duration(minutes: 1)) {
      return current.add(const Duration(seconds: 5));
    }

    // Old past reminders should not be rescheduled automatically.
    return null;
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
      notificationDetails: _defaultNotificationDetails,
    );
  }

  static Future<void> scheduleEscalationTestSequence({
    required int baseNotificationId,
    Duration initialDelay = const Duration(seconds: 5),
    Duration stepDelay = const Duration(seconds: 10),
  }) async {
    if (!_initialized) {
      await initialize();
    }

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    for (int attempt = 0; attempt < _escalationAttempts; attempt += 1) {
      final int alertLevel = _alertLevelForAttempt(attempt);
      await _zonedScheduleWithFallback(
        notificationId: baseNotificationId + attempt,
        title: 'Reminder Test',
        body:
            "This is a preview of reminder style $alertLevel. Attempt ${attempt + 1} of $_escalationAttempts.",
        scheduledDate: now.add(initialDelay + (stepDelay * attempt)),
        notificationDetails: _notificationDetailsForAttempt(attempt),
      );
    }
  }

  static Future<void> cancelEscalatingReminderAttempts({
    required int medicineCreatedAtMillis,
    required DateTime scheduledAt,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    final String reminderIdentity = _buildReminderIdentity(
      medicineCreatedAtMillis: medicineCreatedAtMillis,
      scheduledAt: scheduledAt,
    );

    final List<Future<void>> cancelOperations = <Future<void>>[];
    for (int attempt = 0; attempt < _totalReminderAttempts; attempt += 1) {
      cancelOperations.add(
        _plugin.cancel(
          _notificationIdForAttempt(
            reminderIdentity: reminderIdentity,
            attempt: attempt,
          ),
        ),
      );
    }
    await Future.wait(cancelOperations);
  }

  /// CANCEL ALL NOTIFICATIONS FOR A MEDICINE (NEW METHOD)
  /// Used when deleting a medicine record
  static Future<void> cancelAllRemindersForMedicine({
    required int medicineCreatedAtMillis,
    required DateTime? reminderStartDate,
    required DateTime? reminderEndDate,
    required TimeOfDay? reminderTime,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    final List<Future<void>> cancelOperations = [];

    // If there's a date range, prepare cancellation futures for each day
    if (reminderStartDate != null &&
        reminderEndDate != null &&
        reminderTime != null) {
      DateTime cursor = DateTime(
        reminderStartDate.year,
        reminderStartDate.month,
        reminderStartDate.day,
      );

      final DateTime end = DateTime(
        reminderEndDate.year,
        reminderEndDate.month,
        reminderEndDate.day,
        23,
        59,
        59,
      );

      while (!cursor.isAfter(end)) {
        final DateTime scheduledAt = DateTime(
          cursor.year,
          cursor.month,
          cursor.day,
          reminderTime.hour,
          reminderTime.minute,
        );

        // We collect the futures without 'await' to start them all at once
        cancelOperations.add(
          cancelEscalatingReminderAttempts(
            medicineCreatedAtMillis: medicineCreatedAtMillis,
            scheduledAt: scheduledAt,
          ),
        );

        cursor = cursor.add(const Duration(days: 1));
      }
    }
    // Handle single reminder instances (when no range is provided)
    else if (reminderTime != null) {
      final DateTime today = DateTime.now();
      final DateTime scheduledAt = DateTime(
        today.year,
        today.month,
        today.day,
        reminderTime.hour,
        reminderTime.minute,
      );

      cancelOperations.add(
        cancelEscalatingReminderAttempts(
          medicineCreatedAtMillis: medicineCreatedAtMillis,
          scheduledAt: scheduledAt,
        ),
      );
    }

    // Await all collected operations to complete together
    if (cancelOperations.isNotEmpty) {
      await Future.wait(cancelOperations);
    }
  }

  static Future<void> _scheduleEscalatingReminder({
    required int medicineCreatedAtMillis,
    required tz.TZDateTime scheduledDate,
    required String medicineName,
    String? patientName,
    String? doseAmount,
  }) async {
    final String reminderIdentity = _buildReminderIdentity(
      medicineCreatedAtMillis: medicineCreatedAtMillis,
      scheduledAt: scheduledDate,
    );

    final List<Future<void>> scheduleOperations = <Future<void>>[];
    for (int attempt = 0; attempt < _totalReminderAttempts; attempt += 1) {
      final _NotificationContent content = _notificationContentForAttempt(
        attempt: attempt,
        medicineName: medicineName,
        patientName: patientName,
        doseAmount: doseAmount,
        scheduledDate: scheduledDate,
      );
      scheduleOperations.add(
        _zonedScheduleWithFallback(
          notificationId: _notificationIdForAttempt(
            reminderIdentity: reminderIdentity,
            attempt: attempt,
          ),
          title: content.title,
          body: content.body,
          scheduledDate: scheduledDate.add(
            Duration(minutes: _escalationInterval.inMinutes * attempt),
          ),
          notificationDetails: _notificationDetailsForAttempt(attempt),
        ),
      );
    }
    await Future.wait(scheduleOperations);
  }

  static Future<void> _zonedScheduleWithFallback({
    required int notificationId,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
  }) async {
    try {
      await _plugin.zonedSchedule(
        notificationId,
        title,
        body,
        scheduledDate,
        notificationDetails,
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
        notificationDetails,
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
    await androidPlatform?.requestExactAlarmsPermission();

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

  static Future<void> _createAndroidChannels() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlatform = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlatform == null) {
      return;
    }

    await androidPlatform.createNotificationChannel(
      const AndroidNotificationChannel(
        _defaultChannelId,
        'Medicine Reminders',
        description: 'Reminder notifications for medicine intake',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(_level1Sound),
      ),
    );

    await androidPlatform.createNotificationChannel(
      const AndroidNotificationChannel(
        _level1ChannelId,
        'Medicine Reminders Level 1',
        description: 'Initial medicine reminder alert',
        importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(_level1Sound),
      ),
    );

    await androidPlatform.createNotificationChannel(
      const AndroidNotificationChannel(
        _level2ChannelId,
        'Medicine Reminders Level 2',
        description: 'Follow-up medicine reminder alert',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(_level2Sound),
      ),
    );

    await androidPlatform.createNotificationChannel(
      const AndroidNotificationChannel(
        _level3ChannelId,
        'Medicine Reminders Level 3',
        description: 'Urgent follow-up medicine reminder alert',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(_level3Sound),
      ),
    );
  }

  static NotificationDetails _notificationDetailsForAttempt(int attempt) {
    final int alertLevel = _alertLevelForAttempt(attempt);
    if (alertLevel == 1) {
      return NotificationDetails(
        android: AndroidNotificationDetails(
          _level1ChannelId,
          'Medicine Reminders Level 1',
          channelDescription: 'Initial medicine reminder alert',
          icon: _notificationIcon,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(_level1Sound),
          enableVibration: true,
          vibrationPattern: Int64List.fromList(<int>[0, 250, 200, 250]),
        ),
        iOS: const DarwinNotificationDetails(),
      );
    }

    if (alertLevel == 2) {
      return NotificationDetails(
        android: AndroidNotificationDetails(
          _level2ChannelId,
          'Medicine Reminders Level 2',
          channelDescription: 'Follow-up medicine reminder alert',
          icon: _notificationIcon,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(_level2Sound),
          enableVibration: true,
          vibrationPattern: Int64List.fromList(<int>[
            0,
            350,
            150,
            350,
            150,
            350,
          ]),
        ),
        iOS: const DarwinNotificationDetails(
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      );
    }

    return NotificationDetails(
      android: AndroidNotificationDetails(
        _level3ChannelId,
        'Medicine Reminders Level 3',
        channelDescription: 'Urgent follow-up medicine reminder alert',
        icon: _notificationIcon,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(_level3Sound),
        enableVibration: true,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        vibrationPattern: Int64List.fromList(<int>[
          0,
          500,
          100,
          500,
          100,
          500,
          100,
          500,
        ]),
      ),
      iOS: const DarwinNotificationDetails(
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }

  static _NotificationContent _notificationContentForAttempt({
    required int attempt,
    required String medicineName,
    String? patientName,
    String? doseAmount,
    required tz.TZDateTime scheduledDate,
  }) {
    final int alertLevel = _alertLevelForAttempt(attempt);
    final String trimmedDose = doseAmount?.trim() ?? '';
    final String doseText = trimmedDose.isEmpty
        ? 'Dose: as prescribed.'
        : 'Dose: $trimmedDose.';
    final String normalizedPatientName = (patientName ?? '').trim();
    final String patientText = normalizedPatientName.isEmpty
        ? ''
        : 'Patient: $normalizedPatientName. ';
    final String scheduledTime = _formatClockTime(scheduledDate);

    if (alertLevel == 1) {
      return _NotificationContent(
        title: 'Reminder: $medicineName',
        body:
            '${patientText}Scheduled for $scheduledTime. $doseText Please take it now and mark it as taken in MediTrack.',
      );
    }

    if (alertLevel == 2) {
      return _NotificationContent(
        title: 'Reminder Follow-up: $medicineName',
        body:
            '${patientText}Still pending since $scheduledTime. $doseText Please take it as soon as possible and confirm in the app.',
      );
    }

    return _NotificationContent(
      title: 'Urgent Reminder: $medicineName',
      body:
          '${patientText}Urgent: this dose remains unconfirmed since $scheduledTime. $doseText Take it immediately and update your medication log.',
    );
  }

  static int _alertLevelForAttempt(int attempt) {
    if (attempt <= 0) {
      return 1;
    }
    if (attempt == 1) {
      return 2;
    }
    return 3;
  }

  static String _formatClockTime(DateTime dateTime) {
    int hour = dateTime.hour;
    final String period = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) {
      hour = 12;
    }
    final String minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  static String _buildReminderIdentity({
    required int medicineCreatedAtMillis,
    required DateTime scheduledAt,
  }) {
    final String month = scheduledAt.month.toString().padLeft(2, '0');
    final String day = scheduledAt.day.toString().padLeft(2, '0');
    final String hour = scheduledAt.hour.toString().padLeft(2, '0');
    final String minute = scheduledAt.minute.toString().padLeft(2, '0');
    return '${medicineCreatedAtMillis}_${scheduledAt.year}$month$day$hour$minute';
  }

  static int _notificationIdForAttempt({
    required String reminderIdentity,
    required int attempt,
  }) {
    final int base = 100000000 + (_fnv1a32(reminderIdentity) % 700000000);
    return base + attempt;
  }

  static int _fnv1a32(String input) {
    int hash = 0x811C9DC5;
    for (int i = 0; i < input.length; i += 1) {
      hash ^= input.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash & 0x7FFFFFFF;
  }
}

class _NotificationContent {
  const _NotificationContent({required this.title, required this.body});

  final String title;
  final String body;
}
