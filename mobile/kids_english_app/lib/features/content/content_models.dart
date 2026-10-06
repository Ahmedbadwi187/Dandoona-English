/// Models for `assets/content/little_learners.json`, written by tools/AssetGenerator (schemaVersion 1).
/// All paths are relative to `assets/`.
class TrackContent {
  const TrackContent({required this.track, required this.lessons, this.mascot});

  final String track;
  final String? mascot;
  final List<Lesson> lessons;

  static const supportedSchema = 1;

  factory TrackContent.fromJson(Map<String, dynamic> json) {
    final schema = json['schemaVersion'];
    if (schema != supportedSchema) {
      throw FormatException('Unsupported content schemaVersion: $schema');
    }
    final lessons = (json['lessons'] as List<dynamic>)
        .map((e) => Lesson.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return TrackContent(
      track: json['track'] as String,
      mascot: json['mascot'] as String?,
      lessons: lessons,
    );
  }

  Lesson? lessonById(String id) {
    for (final l in lessons) {
      if (l.id == id) return l;
    }
    return null;
  }
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
  });

  final String id;
  final int order;
  final String level;
  final String? letter;
  final String? phoneme;
  final LessonAudio audio;
  final List<LessonWord> words;

  /// trace | listen-and-tap | record-and-listen | match-picture
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
      );
}

class LessonAudio {
  const LessonAudio({required this.intro, required this.praise, this.phoneme, this.instructions = const {}});

  /// Spoken instruction per activity name, played when the activity starts. Older lesson files have none.
  final Map<String, String> instructions;

  final String intro;
  final String? phoneme;
  final List<String> praise;

  factory LessonAudio.fromJson(Map<String, dynamic> json) => LessonAudio(
        intro: json['intro'] as String,
        phoneme: json['phoneme'] as String?,
        praise: (json['praise'] as List<dynamic>).cast<String>(),
        instructions: ((json['instructions'] as Map<String, dynamic>?) ?? const {}).map((k, v) => MapEntry(k, v as String)),
      );
}

class LessonWord {
  const LessonWord({required this.word, required this.audio, required this.image});

  final String word;
  final String audio;

  /// `.svg` (self-drawn) or `.webp` (generated); both are rendered by AssetPicture.
  final String image;

  factory LessonWord.fromJson(Map<String, dynamic> json) => LessonWord(
        word: json['word'] as String,
        audio: json['audio'] as String,
        image: json['image'] as String,
      );
}
