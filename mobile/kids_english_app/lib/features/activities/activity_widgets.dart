import 'package:flutter/material.dart';

import '../../core/palette.dart';
import '../content/content_models.dart';

/// The row of dots at the top of an activity: one per round, filled up to the current one.
class RoundDots extends StatelessWidget {
  const RoundDots({super.key, required this.total, required this.index});

  final int total;
  final int index;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < total; i++)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 16,
              height: 16,
              decoration: BoxDecoration(shape: BoxShape.circle, color: i <= index ? Palette.orange : Palette.tan),
            ),
        ],
      );
}

/// Every word of the unit [lesson] belongs to (the lesson's own words when the unit is unknown), in lesson order.
List<LessonWord> unitWordsOf(TrackContent track, Lesson lesson) {
  final unit = track.unitOfLesson(lesson.id);
  final lessons = unit == null || unit.lessons.isEmpty ? [lesson] : unit.lessons;
  return [for (final l in lessons) ...l.words];
}

/// The word called [name] in the unit of [lesson] (or anywhere in the track), or null.
LessonWord? wordNamed(TrackContent track, Lesson lesson, String name) {
  for (final w in [...unitWordsOf(track, lesson), for (final l in track.lessons) ...l.words]) {
    if (w.word.toLowerCase() == name.toLowerCase()) return w;
  }
  return null;
}

/// Icons for the sorting bins, by the `icon` key written in the lesson files (unknown keys fall back to a star).
IconData binIcon(String key) => switch (key) {
      'face' => Icons.face_rounded,
      'body' => Icons.accessibility_new_rounded,
      'fruit' => Icons.apple,
      'drink' => Icons.local_drink_rounded,
      'treat' => Icons.cake_rounded,
      'sun' => Icons.wb_sunny_rounded,
      'snow' => Icons.ac_unit_rounded,
      'road' => Icons.add_road_rounded,
      'water' => Icons.water_rounded,
      'sky' => Icons.cloud_rounded,
      'bedroom' => Icons.bed_rounded,
      'kitchen' => Icons.kitchen_rounded,
      'living' => Icons.weekend_rounded,
      'elder' => Icons.elderly_rounded,
      'parents' => Icons.supervisor_account_rounded,
      'child' => Icons.child_care_rounded,
      _ => Icons.star_rounded,
    };

/// A friendly color for a bin, by position.
Color binColor(int i) => const [Palette.orange, Palette.blue, Palette.green, Palette.yellow][i % 4];
