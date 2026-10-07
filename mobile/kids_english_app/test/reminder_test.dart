import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/features/reminders/reminder_service.dart';
import 'package:kids_english_app/features/settings/settings.dart';

void main() {
  test('reminder times are morning, afternoon and evening', () {
    expect(reminderTimes.keys, ['morning', 'afternoon', 'evening']);
    expect(reminderTimes['morning']!.hour, 8);
    expect(reminderTimes['afternoon']!.hour, 16);
    expect(reminderTimes['evening']!.hour, 19);
  });

  test('the reminder time survives saving and can be cleared', () {
    const s = AppSettings(reminderTime: 'evening');
    final back = AppSettings.fromJson(s.toJson());
    expect(back.reminderTime, 'evening');
    expect(back.copyWith(clearReminder: true).reminderTime, isNull);
    expect(AppSettings.fromJson(const AppSettings().toJson()).reminderTime, isNull);
  });

  test('the manifest asks for notifications and boot only, and drops vibrate', () {
    final xml = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(xml, contains('android.permission.POST_NOTIFICATIONS'));
    expect(xml, contains('android.permission.RECEIVE_BOOT_COMPLETED'));
    expect(xml, contains('android.permission.VIBRATE'));
    expect(RegExp(r'VIBRATE[^>]*tools:node="remove"').hasMatch(xml), isTrue);
    expect(xml, isNot(contains('SCHEDULE_EXACT_ALARM')));
    expect(xml, isNot(contains('ACCESS_FINE_LOCATION')));
  });
}
