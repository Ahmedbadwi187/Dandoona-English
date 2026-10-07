/// Models for `assets/content/little_learners.json`, written by tools/AssetGenerator.
/// schemaVersion 2: the track holds units, each unit holds lessons. schemaVersion 1 (a flat lesson list, before units
/// existed) still loads, as a single unit named Letters. All paths are relative to `assets/`.
class TrackContent {
  const TrackContent({required this.track, required this.units, this.mascot, this.placement = const []});

  final String track;
  final String? mascot;

  /// In the order they open.
  final List<CourseUnit> units;

  /// What each answer to "how much English does your child know?" means (from the content file, not from code).
  final List<PlacementLevel> placement;

  static const supportedSchemas = {1, 2};

  /// Every lesson of every unit, in unit order then lesson order.
  List<Lesson> get lessons => [for (final u in units) ...u.lessons];

  factory TrackContent.fromJson(Map<String, dynamic> json) {
    final schema = json['schemaVersion'];
    if (!supportedSchemas.contains(schema)) {
      throw FormatException('Unsupported content schemaVersion: $schema');
    }
    final List<CourseUnit> units;
    if (schema == 1) {
      final lessons = _lessons(json['lessons'] as List<dynamic>);
      units = [
        CourseUnit(id: 'letters', order: 1, title: const {'en': 'Letters', 'ar': 'الحروف'}, icon: 'letters', color: 'red', lessons: lessons),
      ];
    } else {
      units = (json['units'] as List<dynamic>).map((e) => CourseUnit.fromJson(e as Map<String, dynamic>)).toList()
        ..sort((a, b) => a.order.compareTo(b.order));
    }
    final placement = ((json['placement'] as List<dynamic>?) ?? const [])
        .map((e) => PlacementLevel.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.level.compareTo(b.level));
    return TrackContent(track: json['track'] as String, mascot: json['mascot'] as String?, units: units, placement: placement);
  }

  Lesson? lessonById(String id) {
    for (final u in units) {
      for (final l in u.lessons) {
        if (l.id == id) return l;
      }
    }
    return null;
  }

  CourseUnit? unitById(String id) {
    for (final u in units) {
      if (u.id == id) return u;
    }
    return null;
  }

  CourseUnit? unitOfLesson(String lessonId) {
    for (final u in units) {
      if (u.lessons.any((l) => l.id == lessonId)) return u;
    }
    return null;
  }
}

/// One answer of the placement question: the units that count as done by placement, and where the child starts.
class PlacementLevel {
  const PlacementLevel({required this.level, required this.key, required this.doneUnits, required this.startUnit});

  final int level;
  final String key;
  final List<String> doneUnits;
  final String startUnit;

  factory PlacementLevel.fromJson(Map<String, dynamic> json) => PlacementLevel(
        level: json['level'] as int,
        key: json['key'] as String,
        doneUnits: ((json['doneUnits'] as List<dynamic>?) ?? const []).cast<String>(),
        startUnit: json['startUnit'] as String,
      );
}

List<Lesson> _lessons(List<dynamic> raw) =>
    raw.map((e) => Lesson.fromJson(e as Map<String, dynamic>)).toList()..sort((a, b) => a.order.compareTo(b.order));

/// One unit of the track (Letters, Colors, ...). A unit without lessons is shown as "coming soon".
class CourseUnit {
  const CourseUnit({
    required this.id,
    required this.order,
    required this.title,
    required this.icon,
    required this.color,
    required this.lessons,
    this.audio,
  });

  final String id;
  final int order;

  /// Title per language code (`en`, `ar`).
  final Map<String, String> title;

  /// Picture key the unit map maps to an icon; unknown keys fall back to a star.
  final String icon;

  /// A palette color name (red, orange, blue...).
  final String color;
  final UnitAudio? audio;
  final List<Lesson> lessons;

  bool get comingSoon => lessons.isEmpty;

  String titleFor(String languageCode) => title[languageCode] ?? title['en'] ?? id;

  factory CourseUnit.fromJson(Map<String, dynamic> json) => CourseUnit(
        id: json['id'] as String,
        order: json['order'] as int,
        title: (json['title'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String)),
        icon: (json['icon'] as String?) ?? '',
        color: (json['color'] as String?) ?? '',
        audio: json['audio'] == null ? null : UnitAudio.fromJson(json['audio'] as Map<String, dynamic>),
        lessons: _lessons((json['lessons'] as List<dynamic>?) ?? const []),
      );
}

class UnitAudio {
  const UnitAudio({required this.title, required this.celebration, this.welcome});

  final String title;
  final String? welcome;
  final String celebration;

  factory UnitAudio.fromJson(Map<String, dynamic> json) => UnitAudio(
        title: json['title'] as String,
        welcome: json['welcome'] as String?,
        celebration: json['celebration'] as String,
      );
}

class Lesson {
  const Lesson({
    required this.id,
    required this.order,
    required this.level,
    required this.audio,
    required this.words,
    required this.activities,
    this.letter,
    this.phoneme,
    this.color,
  });

  final String id;
  final int order;
  final String level;
  final String? letter;
  final String? phoneme;
  final LessonAudio audio;
  final List<LessonWord> words;

  /// Colors unit only: the color the lesson teaches.
  final LessonColor? color;

  /// trace | listen-and-tap | record-and-listen | match-picture | color-the-object
  final List<String> activities;

  factory Lesson.fromJson(Map<String, dynamic> json) => Lesson(
        id: json['id'] as String,
        order: json['order'] as int,
        level: json['level'] as String,
        letter: json['letter'] as String?,
        phoneme: json['phoneme'] as String?,
        audio: LessonAudio.fromJson(json['audio'] as Map<String, dynamic>),
        words: (json['words'] as List<dynamic>)
            .map((e) => LessonWord.fromJson(e as Map<String, dynamic>))
            .toList(),
        activities: (json['activities'] as List<dynamic>).cast<String>(),
        color: json['color'] == null ? null : LessonColor.fromJson(json['color'] as Map<String, dynamic>),
      );
}

/// The color a Colors lesson teaches: its name, its #RRGGBB value, the swatch picture and the drawing to color in.
class LessonColor {
  const LessonColor({required this.name, required this.hex, required this.swatch, required this.drawing});

  final String name;
  final String hex;
  final String swatch;
  final String drawing;

  factory LessonColor.fromJson(Map<String, dynamic> json) => LessonColor(
        name: json['name'] as String,
        hex: json['hex'] as String,
        swatch: json['swatch'] as String,
        drawing: json['drawing'] as String,
      );
}

class LessonAudio {
  const LessonAudio({required this.intro, required this.praise, this.phoneme, this.instructions = const {}, this.colorName});

  /// Spoken instruction per activity name, played when the activity starts. Older lesson files have none.
  final Map<String, String> instructions;

  final String intro;
  final String? phoneme;

  /// Colors unit: the lesson says its color on its own ("red").
  final String? colorName;
  final List<String> praise;

  factory LessonAudio.fromJson(Map<String, dynamic> json) => LessonAudio(
        intro: json['intro'] as String,
        phoneme: json['phoneme'] as String?,
        colorName: json['colorName'] as String?,
        praise: (json['praise'] as List<dynamic>).cast<String>(),
        instructions: ((json['instructions'] as Map<String, dynamic>?) ?? const {}).map((k, v) => MapEntry(k, v as String)),
      );
}

class LessonWord {
  const LessonWord({required this.word, required this.audio, required this.image, this.phrase});

  final String word;
  final String audio;

  /// Colors unit: the word in a phrase ("A red apple."), used by record-and-listen.
  final String? phrase;

  /// `.svg` (self-drawn) or `.webp` (generated); both are rendered by AssetPicture.
  final String image;

  factory LessonWord.fromJson(Map<String, dynamic> json) => LessonWord(
        word: json['word'] as String,
        audio: json['audio'] as String,
        image: json['image'] as String,
        phrase: json['phrase'] as String?,
      );
}
