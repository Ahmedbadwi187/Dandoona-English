import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "What can your child already do?": the list, its rules (from `assets/content/skills.json`, never from code) and what the answer
/// decides: the track and the units that count as done by placement.
const skillNone = 'none';
const skillUnsure = 'unsure';

class SkillGroup {
  const SkillGroup(this.id, this.skills);
  final String id;
  final List<String> skills;
}

class TrackUpRule {
  const TrackUpRule({required this.from, required this.to, required this.whenAll, required this.orAnyOf});
  final String from;
  final String to;
  final Set<String> whenAll;
  final Set<String> orAnyOf;

  bool applies(Set<String> skills) => (whenAll.isNotEmpty && whenAll.every(skills.contains)) || orAnyOf.any(skills.contains);
}

class SkillsConfig {
  const SkillsConfig({
    required this.littleLearnersUpTo,
    required this.explorersUpTo,
    required this.above,
    required this.groups,
    required this.exclusive,
    required this.implies,
    required this.trackUp,
    required this.championsSkills,
    required this.skillUnits,
  });

  final int littleLearnersUpTo;
  final int explorersUpTo;
  final String above;
  final List<SkillGroup> groups;
  final List<String> exclusive;
  final Map<String, List<String>> implies;
  final List<TrackUpRule> trackUp;
  final Set<String> championsSkills;

  /// track -> skill -> the units that skill covers in that track.
  final Map<String, Map<String, List<String>>> skillUnits;

  factory SkillsConfig.fromJson(Map<String, dynamic> j) {
    List<String> strings(Object? o) => ((o as List<dynamic>?) ?? const []).cast<String>();
    final age = j['age'] as Map<String, dynamic>;
    return SkillsConfig(
      littleLearnersUpTo: age['littleLearnersUpTo'] as int,
      explorersUpTo: age['explorersUpTo'] as int,
      above: age['above'] as String,
      groups: [for (final g in (j['groups'] as List<dynamic>).cast<Map<String, dynamic>>()) SkillGroup(g['id'] as String, strings(g['skills']))],
      exclusive: strings(j['exclusive']),
      implies: {for (final e in (j['implies'] as Map<String, dynamic>).entries) e.key: strings(e.value)},
      trackUp: [
        for (final r in (j['trackUp'] as List<dynamic>).cast<Map<String, dynamic>>())
          TrackUpRule(from: r['from'] as String, to: r['to'] as String, whenAll: strings(r['whenAll']).toSet(), orAnyOf: strings(r['orAnyOf']).toSet()),
      ],
      championsSkills: strings(j['championsSkills']).toSet(),
      skillUnits: {
        for (final t in (j['skillUnits'] as Map<String, dynamic>).entries)
          t.key: {for (final s in (t.value as Map<String, dynamic>).entries) s.key: strings(s.value)},
      },
    );
  }

  /// Every real skill of the list (not the two exclusive answers), in the order of the list.
  List<String> get allSkills => [for (final g in groups) ...g.skills];

  /// The easier skills a skill brings with it, all the way down (reads sentences -> reads words -> all letters, letter sounds -> some letters).
  Set<String> impliedBy(String skill) {
    final out = <String>{};
    void walk(String s) {
      for (final i in implies[s] ?? const <String>[]) {
        if (out.add(i)) walk(i);
      }
    }

    walk(skill);
    return out;
  }
}

/// What one tap did to the selection.
class SkillsToggle {
  const SkillsToggle(this.skills, this.autoChecked);

  final Set<String> skills;

  /// Skills that were checked by themselves because the tapped one implies them (shown with a short animation).
  final Set<String> autoChecked;
}

/// Taps [id]: the two exclusive answers clear everything else (and each other); any real skill clears them; checking a skill checks
/// the easier ones it implies; unchecking only unchecks that one (the parent may uncheck an implied one).
SkillsToggle toggleSkill(SkillsConfig config, Set<String> current, String id) {
  if (config.exclusive.contains(id)) {
    return SkillsToggle(current.contains(id) ? <String>{} : {id}, const {});
  }
  if (current.contains(id)) return SkillsToggle({...current}..remove(id), const {});
  final next = {...current}..removeAll(config.exclusive);
  final implied = config.impliedBy(id).difference(next);
  next
    ..add(id)
    ..addAll(implied);
  return SkillsToggle(next, implied);
}

/// The skills that are real answers (not none/unsure).
Set<String> realSkills(SkillsConfig config, Set<String> skills) => skills.where((s) => !config.exclusive.contains(s)).toSet();

enum TrackReason { age, skills }

class TrackSuggestion {
  const TrackSuggestion(this.trackId, this.reason, this.ageTrackId);
  final String trackId;
  final TrackReason reason;

  /// The track the age alone gives.
  final String ageTrackId;
}

/// The default track comes from the age (3-5 Little Learners, 6-8 Explorers; older children use the highest released track).
/// Skills can only move it UP: a child under 6 who knows all letters and their sounds, or anything above that, is suggested the next track.
/// A child of 6 or more is never put in Little Learners here. [available] is the set of tracks that exist in this build.
TrackSuggestion suggestTrack({
  required SkillsConfig config,
  required int ageYears,
  required Set<String> skills,
  Set<String> available = const {'little-learners', 'explorers'},
}) {
  var byAge = ageYears <= config.littleLearnersUpTo ? 'little-learners' : (ageYears <= config.explorersUpTo ? 'explorers' : config.above);
  if (!available.contains(byAge)) byAge = byAge == 'little-learners' || !available.contains('explorers') ? 'little-learners' : 'explorers';
  var track = byAge;
  var reason = TrackReason.age;
  final real = realSkills(config, skills);
  for (final rule in config.trackUp) {
    if (rule.from == track && available.contains(rule.to) && rule.applies(real)) {
      track = rule.to;
      reason = TrackReason.skills;
    }
  }
  return TrackSuggestion(track, reason, byAge);
}

/// What the answer decides inside one track: the units that count as done by placement (in path order) and where the child starts.
class SkillPlacement {
  const SkillPlacement({required this.doneUnits, required this.startUnit});

  /// Done by placement: finished on the map, still open to play, no stars, chests unlocked. In path order.
  final List<String> doneUnits;

  /// The first unit in path order that is not covered (the last unit when everything is).
  final String? startUnit;

  int get skipped => doneUnits.length;
}

/// [unitIds] is the path order of the track. "None of these yet" and "I'm not sure" cover nothing, so the child starts at the beginning.
SkillPlacement placementFor({required SkillsConfig config, required String track, required Set<String> skills, required List<String> unitIds}) {
  final map = config.skillUnits[track] ?? const <String, List<String>>{};
  final covered = <String>{for (final s in realSkills(config, skills)) ...(map[s] ?? const <String>[])};
  final done = [for (final u in unitIds) if (covered.contains(u)) u];
  final start = unitIds.where((u) => !covered.contains(u)).firstOrNull ?? unitIds.lastOrNull;
  return SkillPlacement(doneUnits: done, startUnit: start);
}

/// The old single-choice answer (0 none, 1 some letters, 2 all letters, 3 reads simple words) as checked skills.
Set<String> skillsFromOldLevel(SkillsConfig config, int level) {
  switch (level) {
    case 1:
      return {'some-letters'};
    case 2:
      return toggleSkill(config, const {}, 'all-letters').skills;
    case 3:
      return toggleSkill(config, const {}, 'reads-words').skills;
    default:
      return {skillNone};
  }
}

final skillsConfigProvider = FutureProvider<SkillsConfig>((ref) async {
  final raw = await rootBundle.loadString('assets/content/skills.json');
  return SkillsConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
});
