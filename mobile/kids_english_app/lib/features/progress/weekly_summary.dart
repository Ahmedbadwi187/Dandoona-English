import 'progress.dart';

class DaySummary {
  const DaySummary({required this.date, required this.stars, required this.activities, required this.seconds});
  final DateTime date; // local calendar day
  final int stars;
  final int activities;
  final int seconds;

  int get minutes => (seconds / 60).round();
}

/// One child's days (a week, or any run of days such as a month), local time. Mirrors the API's weekly summary.
class WeeklySummary {
  const WeeklySummary({
    required this.weekStart,
    required this.days,
    required this.totalStars,
    required this.activitiesCompleted,
    required this.lessonsPracticed,
    required this.seconds,
    required this.activeDays,
  });

  final DateTime weekStart; // the first day, 00:00 local
  final List<DaySummary> days; // 7 for a week
  final int totalStars;
  final int activitiesCompleted;
  final int lessonsPracticed;
  final int seconds;
  final int activeDays;

  int get minutes => (seconds / 60).round();
  int get maxDayStars => days.fold(0, (m, d) => d.stars > m ? d.stars : m);
  int get maxDayMinutes => days.fold(0, (m, d) => d.minutes > m ? d.minutes : m);

  /// Nothing happened in these days: the parent screens show Dandoona waiting instead of zeros.
  bool get isEmpty => activitiesCompleted == 0 && seconds == 0;
}

DateTime mondayOf(DateTime date) => weekStartOf(date, DateTime.monday);

/// The first day of the week containing [date], where the week starts on [firstWeekday] (DateTime.monday ... sunday).
DateTime weekStartOf(DateTime date, int firstWeekday) {
  final d = DateTime(date.year, date.month, date.day);
  return DateTime(d.year, d.month, d.day - ((d.weekday - firstWeekday + 7) % 7));
}

/// The first day of the week in a language: Saturday for Arabic, Monday otherwise.
int firstWeekdayFor(String languageCode) => languageCode == 'ar' ? DateTime.saturday : DateTime.monday;

/// Summarises the records of [childId] that fall in the week containing [anyDateInWeek].
WeeklySummary summarizeWeek(List<ProgressRecord> records, String childId, DateTime anyDateInWeek, {int firstWeekday = DateTime.monday}) =>
    summarizeRange(records, childId, weekStartOf(anyDateInWeek, firstWeekday), 7);

/// Summarises [count] days starting at [start] (a calendar day).
WeeklySummary summarizeRange(List<ProgressRecord> records, String childId, DateTime start, int count) {
  final first = DateTime(start.year, start.month, start.day);
  final days = <DaySummary>[];
  var stars = 0, activities = 0, seconds = 0, active = 0;
  final lessons = <String>{};

  for (var i = 0; i < count; i++) {
    final day = DateTime(first.year, first.month, first.day + i);
    final todays = records.where((r) {
      if (r.childId != childId) return false;
      final t = r.completedAt.toLocal();
      return t.year == day.year && t.month == day.month && t.day == day.day;
    }).toList();
    final dayStars = todays.fold<int>(0, (s, r) => s + r.stars);
    final daySeconds = todays.fold<int>(0, (s, r) => s + r.timeSpentSeconds);
    for (final r in todays) {
      lessons.add(r.lessonId);
    }
    stars += dayStars;
    seconds += daySeconds;
    activities += todays.length;
    if (todays.isNotEmpty) active++;
    days.add(DaySummary(date: day, stars: dayStars, activities: todays.length, seconds: daySeconds));
  }

  return WeeklySummary(
    weekStart: first,
    days: days,
    totalStars: stars,
    activitiesCompleted: activities,
    lessonsPracticed: lessons.length,
    seconds: seconds,
    activeDays: active,
  );
}
