import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage.dart';

/// A word a child did not get right in a "tap the one you hear" game, and how many times.
class MissedWord {
  const MissedWord({required this.lessonId, required this.word, required this.count});
  final String lessonId;
  final String word;
  final int count;
}

/// The words each child missed, kept on the phone only (never sent anywhere): `childId -> "lessonId|word" -> times`.
/// A miss adds one; getting the word right in Practice takes one away; at zero it is gone. Practice and the parent's
/// "Practice at home" list read this.
class WordMissesNotifier extends Notifier<Map<String, Map<String, int>>> {
  @override
  Map<String, Map<String, int>> build() {
    final raw = ref.read(sharedPreferencesProvider).readJson(PrefKeys.misses);
    if (raw is Map<String, dynamic>) {
      try {
        return {for (final e in raw.entries) e.key: (e.value as Map<String, dynamic>).map((k, v) => MapEntry(k, v as int))};
      } on Object {
        // unreadable: nothing was missed yet
      }
    }
    return const {};
  }

  static String _key(String lessonId, String word) => '$lessonId|$word';

  /// Most missed first, then by word.
  List<MissedWord> of(String childId) {
    final mine = state[childId] ?? const {};
    final list = [
      for (final e in mine.entries)
        MissedWord(lessonId: e.key.split('|').first, word: e.key.split('|').skip(1).join('|'), count: e.value),
    ]..sort((a, b) => b.count != a.count ? b.count.compareTo(a.count) : a.word.compareTo(b.word));
    return list;
  }

  Future<void> miss(String childId, String lessonId, String word) => _change(childId, _key(lessonId, word), 1);

  Future<void> got(String childId, String lessonId, String word) => _change(childId, _key(lessonId, word), -1, onlyIfThere: true);

  Future<void> forget(String childId) async {
    state = {...state}..remove(childId);
    await ref.read(sharedPreferencesProvider).writeJson(PrefKeys.misses, state);
  }

  Future<void> _change(String childId, String key, int by, {bool onlyIfThere = false}) async {
    final mine = {...(state[childId] ?? const <String, int>{})};
    if (onlyIfThere && !mine.containsKey(key)) return;
    final next = (mine[key] ?? 0) + by;
    if (next <= 0) {
      mine.remove(key);
    } else {
      mine[key] = next > 9 ? 9 : next;
    }
    state = {...state, childId: mine};
    await ref.read(sharedPreferencesProvider).writeJson(PrefKeys.misses, state);
  }
}

final wordMissesProvider = NotifierProvider<WordMissesNotifier, Map<String, Map<String, int>>>(WordMissesNotifier.new);
