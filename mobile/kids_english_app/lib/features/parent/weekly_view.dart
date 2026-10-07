import 'package:flutter/material.dart';

import '../../core/palette.dart';
import '../../core/strings.dart';
import '../progress/weekly_summary.dart';
import 'parent_ui.dart';

/// "This week" as four small tiles in a 2x2 grid: stars, activities, minutes, active days (4/7).
class WeekTiles extends StatelessWidget {
  const WeekTiles({super.key, required this.summary, required this.s});

  final WeeklySummary summary;
  final Strings s;

  @override
  Widget build(BuildContext context) {
    Widget tile(String keyName, IconData icon, Color color, String value, String label) => Expanded(
          child: Container(
            key: Key('tile-$keyName'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: Palette.cream, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(value, style: ParentText.section),
                      Text(label, style: ParentText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

    return Column(
      key: const Key('week-tiles'),
      children: [
        Row(children: [
          tile('stars', Icons.star_rounded, Palette.yellow, s.number(summary.totalStars), s('stars')),
          const SizedBox(width: 8),
          tile('activities', Icons.extension_rounded, Palette.blue, s.number(summary.activitiesCompleted), s('activities')),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          tile('minutes', Icons.timer_rounded, Palette.teal, s.number(summary.minutes), s('minutes')),
          const SizedBox(width: 8),
          tile('days', Icons.event_available_rounded, Palette.green, '${s.number(summary.activeDays)}/${s.number(summary.days.length)}', s('activeDays')),
        ]),
      ],
    );
  }
}

/// Real bars for the minutes of each day, the daily goal as a thin dashed line, today's bar highlighted. No chart library.
class WeekChart extends StatelessWidget {
  const WeekChart({super.key, required this.summary, required this.s, required this.goalMinutes, required this.today, this.height = 72});

  final WeeklySummary summary;
  final Strings s;
  final int goalMinutes;
  final DateTime today;
  final double height;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    // the scale holds the tallest day and the goal line, with a little room above
    final top = [summary.maxDayMinutes, goalMinutes].reduce((a, b) => a > b ? a : b) * 1.15;
    final dense = summary.days.length > 10; // a month: thin bars, a label every few days
    final todayDate = DateTime(today.year, today.month, today.day);

    return Column(
      key: const Key('week-chart'),
      children: [
        SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < summary.days.length; i++)
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            key: Key('week-bar-$i'),
                            width: dense ? 6 : 22,
                            height: summary.days[i].minutes == 0 ? 3 : (height * summary.days[i].minutes / top).clamp(6, height).toDouble(),
                            decoration: BoxDecoration(
                              color: summary.days[i].minutes == 0
                                  ? parentBorder
                                  : (summary.days[i].date == todayDate ? primary : primary.withValues(alpha: 0.35)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: height * goalMinutes / top,
                child: const CustomPaint(key: Key('goal-line'), size: Size.fromHeight(1.5), painter: _DashedLine(Palette.orange)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (var i = 0; i < summary.days.length; i++)
              Expanded(
                child: Text(
                  dense ? (i % 5 == 0 ? s.number(summary.days[i].date.day) : '') : s('d${summary.days[i].date.weekday - 1}'),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: ParentText.caption.copyWith(
                    fontSize: 11,
                    fontWeight: summary.days[i].date == todayDate ? FontWeight.w800 : FontWeight.w400,
                    color: summary.days[i].date == todayDate ? primary : null,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _DashedLine extends CustomPainter {
  const _DashedLine(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    for (double x = 0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, 0), Offset((x + 4).clamp(0, size.width), 0), paint);
    }
  }

  @override
  bool shouldRepaint(_DashedLine old) => old.color != color;
}
