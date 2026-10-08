/// Models for `assets/content/little_learners.json`, written by tools/AssetGenerator.
/// schemaVersion 2: the track holds units, each unit holds lessons. schemaVersion 1 (a flat lesson list, before units
/// existed) still loads, as a single unit named Letters. All paths are relative to `assets/`.
class TrackContent {
  const TrackContent({required this.track, required this.units, this.mascot, this.placement = const [], this.appAudio, this.reviews = const []});

  final String track;
  final String? mascot;

  /// In the order they open.
  final List<CourseUnit> units;

  /// What each answer to "how much English does your child know?" means (from the content file, not from code).
  final List<PlacementLevel> placement;

  /// Dandoona's own lines: "Who is playing?" (title), the first greeting (welcome), "Welcome back!" (celebration).
  final UnitAudio? appAudio;

  /// Review stops on the map, each after a group of units (in path order). Older content files have none.
  final List<ReviewStop> reviews;

  static const supportedSchemas = {1, 2};

  TrackContent withUnits(List<CourseUnit> units) =>
      TrackContent(track: track, units: units, mascot: mascot, placement: placement, appAudio: appAudio, reviews: reviews);

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
    final app = json['app'];
    final reviews = ((json['reviews'] as List<dynamic>?) ?? const []).map((e) => ReviewStop.fromJson(e as Map<String, dynamic>)).toList();
    return TrackContent(
      track: json['track'] as String,
      mascot: json['mascot'] as String?,
      units: units,
      placement: placement,
      appAudio: app is Map<String, dynamic> ? UnitAudio.fromJson(app) : null,
      reviews: reviews,
    );
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

/// A review on the map: a quick game with the words of [units]; it sits after the last of them and must be passed
/// before the next unit opens.
class ReviewStop {
  const ReviewStop({required this.id, required this.units});

  final String id;
  final List<String> units;

  String get after => units.last;

  factory ReviewStop.fromJson(Map<String, dynamic> json) =>
      ReviewStop(id: json['id'] as String, units: (json['units'] as List<dynamic>).cast<String>());
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
    this.hasStory = false,
    this.pack,
    this.chest,
    this.story,
  });

  /// The picture story after this unit (null when it has none yet).
  final StoryContent? story;

  /// What the treasure chest after this unit holds (fixed per unit; see docs/chest-rewards.md). Null in older content.
  final ChestReward? chest;

  /// A downloadable unit: its pack (lessons, audio, pictures) comes from our server; [lessons] stay empty until the pack is
  /// on the device. Null for a bundled unit.
  final PackRef? pack;

  final String id;
  final int order;

  /// The unit has a picture story (a book stop after it on the map).
  final bool hasStory;

  /// Title per language code (`en`, `ar`).
  final Map<String, String> title;

  /// Picture key the unit map maps to an icon; unknown keys fall back to a star.
  final String icon;

  /// A palette color name (red, orange, blue...).
  final String color;
  final UnitAudio? audio;
  final List<Lesson> lessons;

  /// No lessons and no pack yet: shown as "Soon".
  bool get comingSoon => lessons.isEmpty && pack == null;

  /// A pack unit whose pack is not on this device yet.
  bool get needsDownload => lessons.isEmpty && pack != null;

  /// The unit's lesson ids, also before its pack is downloaded (so progress made on another phone still counts).
  List<String> get lessonIds => lessons.isNotEmpty ? [for (final l in lessons) l.id] : (pack?.lessonIds ?? const []);

  CourseUnit withLessons(List<Lesson> lessons) =>
      CourseUnit(id: id, order: order, title: title, icon: icon, color: color, audio: audio, hasStory: hasStory, pack: pack, chest: chest, story: story, lessons: lessons);

  String titleFor(String languageCode) => title[languageCode] ?? title['en'] ?? id;

  factory CourseUnit.fromJson(Map<String, dynamic> json) => CourseUnit(
        id: json['id'] as String,
        order: json['order'] as int,
        title: (json['title'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String)),
        icon: (json['icon'] as String?) ?? '',
        color: (json['color'] as String?) ?? '',
        audio: json['audio'] == null ? null : UnitAudio.fromJson(json['audio'] as Map<String, dynamic>),
        lessons: _lessons((json['lessons'] as List<dynamic>?) ?? const []),
        hasStory: json['story'] != null,
        pack: json['pack'] == null ? null : PackRef.fromJson(json['pack'] as Map<String, dynamic>),
        chest: json['chest'] == null ? null : ChestReward.fromJson(json['chest'] as Map<String, dynamic>),
        story: json['story'] == null ? null : StoryContent.fromJson(json['story'] as Map<String, dynamic>),
      );
}

/// A unit's picture story: pages Dandoona reads, each with some of the unit's pictures.
class StoryContent {
  const StoryContent({required this.pages});

  final List<StoryPage> pages;

  factory StoryContent.fromJson(Map<String, dynamic> json) => StoryContent(pages: [for (final p in json['pages'] as List<dynamic>) StoryPage.fromJson(p as Map<String, dynamic>)]);
}

class StoryPage {
  const StoryPage({required this.text, required this.audio, this.words = const [], this.pose});

  final String text;
  final String audio;

  /// Words of the unit whose pictures the page shows.
  final List<String> words;

  /// waving, jumping, clapping, thinking, pointing-up or base.
  final String? pose;

  factory StoryPage.fromJson(Map<String, dynamic> json) => StoryPage(
        text: json['text'] as String,
        audio: json['audio'] as String,
        words: ((json['words'] as List<dynamic>?) ?? const []).cast<String>(),
        pose: json['pose'] as String?,
      );
}

/// A unit's treasure chest: the outfit it gives Dandoona and the words that become stickers.
class ChestReward {
  const ChestReward({required this.accessory, required this.stickers});

  /// An accessory id (`assets/images/accessories/<id>.svg`).
  final String accessory;

  /// Words of the unit, in the order of the Sticker Book.
  final List<String> stickers;

  factory ChestReward.fromJson(Map<String, dynamic> json) => ChestReward(accessory: json['accessory'] as String, stickers: (json['stickers'] as List<dynamic>).cast<String>());
}

/// Where a unit's content pack is: its version, the manifest's checksum, its size, the manifest path on the server
/// (relative to /packs/<track>/) and the lesson ids inside it.
class PackRef {
  const PackRef({required this.version, required this.sha256, required this.bytes, required this.manifest, this.lessonIds = const []});

  final int version;
  final String sha256;
  final int bytes;
  final String manifest;
  final List<String> lessonIds;

  factory PackRef.fromJson(Map<String, dynamic> json) => PackRef(
        version: json['version'] as int,
        sha256: json['sha256'] as String,
        bytes: (json['bytes'] as num).toInt(),
        manifest: json['manifest'] as String,
        lessonIds: ((json['lessonIds'] as List<dynamic>?) ?? const []).cast<String>(),
      );
}

class UnitAudio {
  const UnitAudio({required this.title, required this.celebration, this.welcome, this.lines = const {}});

  final String title;
  final String? welcome;
  final String celebration;

  /// Short extra lines by key: a unit's "locked" ("Finish Letters first!"); the app's "coming-soon", "puzzle-first",
  /// "almost-ready". A line whose audio is not made yet is simply missing (the bubble still shows the words).
  final Map<String, String> lines;

  /// "Finish Letters first!": said when a child taps a closed stop while this unit is the one to finish.
  String? get locked => lines['locked'];

  factory UnitAudio.fromJson(Map<String, dynamic> json) => UnitAudio(
        title: json['title'] as String,
        welcome: json['welcome'] as String?,
        celebration: json['celebration'] as String,
        lines: ((json['lines'] as Map<String, dynamic>?) ?? const {}).map((k, v) => MapEntry(k, v as String)),
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
    this.counting = false,
    this.ownWordsOnly = false,
    this.bins = const [],
    this.odd = const [],
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

  /// Numbers unit: each word is a number and its picture shows that many things.
  final bool counting;

  /// The wrong pictures of the hear-and-tap game come only from this lesson's own words.
  final bool ownWordsOnly;

  /// Sorting game: the bins; a word whose `group` is a bin key belongs in it (words of the whole unit are used).
  final List<LessonBin> bins;

  /// Odd one out: words of the Letters unit that do not belong to this unit's theme.
  final List<String> odd;

  /// The number a counting word stands for ('three' is 3), or null.
  static int? numberOf(String word) {
    final n = _numerals[word.toLowerCase()];
    return n == null ? null : int.parse(n);
  }

  static const _numerals = {'one': '1', 'two': '2', 'three': '3', 'four': '4', 'five': '5', 'six': '6', 'seven': '7', 'eight': '8', 'nine': '9', 'ten': '10'};

  /// A counting lesson's numerals for the big circle: "1 2 3". Unknown words show a question mark.
  String get digits => words.map((w) => _numerals[w.word.toLowerCase()] ?? '?').join(' ');

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
        counting: (json['counting'] as bool?) ?? false,
        ownWordsOnly: (json['ownWordsOnly'] as bool?) ?? false,
        bins: [for (final b in (json['bins'] as List<dynamic>?) ?? const []) LessonBin.fromJson(b as Map<String, dynamic>)],
        odd: ((json['odd'] as List<dynamic>?) ?? const []).cast<String>(),
      );
}

class LessonBin {
  const LessonBin({required this.key, required this.icon});
  final String key;
  final String icon;
  factory LessonBin.fromJson(Map<String, dynamic> json) => LessonBin(key: json['key'] as String, icon: json['icon'] as String);
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
  const LessonWord({required this.word, required this.audio, required this.image, this.phrase, this.sound, this.lives, this.home, this.says, this.group, this.opposite, this.phraseText});

  final String word;
  final String audio;

  /// Colors unit: the word in a phrase ("A red apple."), used by record-and-listen.
  final String? phrase;

  /// Animals: what the animal says (audio of "Meow! Meow!"), for animal-sounds; null for an animal that is quiet.
  final String? sound;

  /// Animals: audio of "A cow lives on the farm.", said when the animal is put in its home.
  final String? lives;

  /// Animals: where it lives, one of house, farm, water, wild.
  final String? home;

  /// Actions: audio of "Dandoona says, jump!", for the Dandoona-says activity.
  final String? says;

  /// Sorting game: the key of the bin it belongs in.
  final String? group;

  /// Memory game: the word it is paired with (big and small) instead of itself.
  final String? opposite;

  /// The words of its phrase ("I like pizza."), shown with a gap in the sentence game.
  final String? phraseText;

  /// `.svg` (self-drawn) or `.webp` (generated); both are rendered by AssetPicture.
  final String image;

  factory LessonWord.fromJson(Map<String, dynamic> json) => LessonWord(
        word: json['word'] as String,
        audio: json['audio'] as String,
        image: json['image'] as String,
        phrase: json['phrase'] as String?,
        sound: json['sound'] as String?,
        lives: json['lives'] as String?,
        home: json['home'] as String?,
        says: json['says'] as String?,
        group: json['group'] as String?,
        opposite: json['opposite'] as String?,
        phraseText: json['phraseText'] as String?,
      );
}
