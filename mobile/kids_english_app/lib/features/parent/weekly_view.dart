import 'package:flutter/material.dart';

import '../../core/palette.dart';
import '../../core/strings.dart';
import '../progress/weekly_summary.dart';

/// "This week": totals and a 7-day star chart (no chart library; just bars).
class WeeklyView extends StatelessWidget {
  const WeeklyView({super.key, required this.summary, required this.s});

  final WeeklySummary summary;
  final Strings s;

  @override
  Widget build(BuildContext context) {
    final maxStars = summary.maxDayStars == 0 ? 1 : summary.maxDayStars;
    return Column(
      key: const Key('weekly-view'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s('thisWeek'), style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 20,
          runSpacing: 6,
          children: [
            _stat(Icons.star_rounded, Palette.yellow, '${summary.totalStars}', s('stars')),
            _stat(Icons.extension_rounded, Palette.blue, '${summary.activitiesCompleted}', s('activities')),
            _stat(Icons.timer_rounded, Palette.teal, '${summary.minutes}', s('minutes')),
            _stat(Icons.event_available_rounded, Palette.green, '${summary.activeDays}/7', s('activeDays')),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 84,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        key: Key('week-bar-$i'),
                        width: 18,
                        height: summary.days[i].stars == 0 ? 3 : 8 + 52 * summary.days[i].stars / maxStars,
                        decoration: BoxDecoration(
                          color: summary.days[i].stars == 0 ? Palette.tan : Palette.orange,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(s('d$i'), style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stat(IconData icon, Color color, String value, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      );
}
