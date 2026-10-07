import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

/// The times a parent can pick on the reminder screen.
const reminderTimes = <String, ({int hour, int minute})>{
  'morning': (hour: 8, minute: 0),
  'afternoon': (hour: 16, minute: 0),
  'evening': (hour: 19, minute: 0),
};

/// A daily reminder for the parent, shown by the phone itself (local notifications only: no push service, no outside SDK).
/// Behind an interface so tests use a fake.
abstract class ReminderService {
  /// Asks the system for permission to show notifications. Called only after the parent taps "Remind me".
  Future<bool> requestPermission();

  /// Schedules the reminder every day at this time (replacing an earlier one).
  Future<void> schedule({required int hour, required int minute, required String title, required String body});

  Future<void> cancel();
}

class LocalNotificationReminderService implements ReminderService {
  static const _id = 1;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Nothing is asked at start-up: the permission prompt comes only from requestPermission().
        iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
      ),
    );
    _ready = true;
  }

  @override
  Future<bool> requestPermission() async {
    try {
      await _init();
      if (!kIsWeb && Platform.isAndroid) {
        return await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission() ?? false;
      }
      if (!kIsWeb && Platform.isIOS) {
        return await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, sound: true) ?? false;
      }
      return false;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> schedule({required int hour, required int minute, required String title, required String body}) async {
    await _init();
    final now = DateTime.now();
    var first = DateTime(now.year, now.month, now.day, hour, minute);
    if (!first.isAfter(now)) first = first.add(const Duration(days: 1));
    // A fixed-offset zone for this phone: no time-zone database to ship. It is rebuilt every time the app starts, so a change
    // of time zone or daylight saving is picked up at the next launch.
    final zone = tz.Location('device', const [-8640000000000000], const [0], [tz.TimeZone(now.timeZoneOffset, isDst: false, abbreviation: 'LOC')]);
    await _plugin.zonedSchedule(
      id: _id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(first, zone),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails('daily_reminder', 'Daily reminder', channelDescription: 'A daily reminder to learn with Dandoona'),
        iOS: DarwinNotificationDetails(),
      ),
      // inexact: no exact-alarm permission needed; the reminder may be a few minutes late
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Future<void> cancel() async {
    await _init();
    await _plugin.cancel(id: _id);
  }
}

final reminderServiceProvider = Provider<ReminderService>((ref) => LocalNotificationReminderService());
