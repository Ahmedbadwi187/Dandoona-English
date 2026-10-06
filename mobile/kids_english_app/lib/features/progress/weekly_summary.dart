import 'progress.dart';

class DaySummary {
  const DaySummary({required this.date, required this.stars, required this.activities, required this.seconds});
  final DateTime date; // local calendar day
  final int stars;
  final int activities;
  final int seconds;
}

/// One child's week (Monday to Sunday, local time). Mirrors the API's weekly summary.
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

  final DateTime weekStart; // Monday 00:00 local
  final List<DaySummary> days; // always 7
  final int totalStars;
  final int activitiesCompleted;
  final int lessonsPracticed;
  final int seconds;
  final int activeDays;

  int get minutes => (seconds / 60).round();
  int get maxDayStars => days.fold(0, (m, d) => d.stars > m ? d.stars : m);
}

DateTime mondayOf(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  return d.subtract(Duration(days: d.weekday - DateTime.monday));
}

/// Summarises the records of [childId] that fall in the week containing [anyDateInWeek].
WeeklySummary summarizeWeek(List<ProgressRecord> records, String childId, DateTime anyDateInWeek) {
  final monday = mondayOf(anyDateInWeek);
  final days = <DaySummary>[];
  var stars = 0, activities = 0, seconds = 0, active = 0;
  final lessons = <String>{};

  for (var i = 0; i < 7; i++) {
    final day = DateTime(monday.year, monday.month, monday.day + i);
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
    weekStart: monday,
    days: days,
    totalStars: stars,
    activitiesCompleted: activities,
    lessonsPracticed: lessons.length,
    seconds: seconds,
    activeDays: active,
  );
}
