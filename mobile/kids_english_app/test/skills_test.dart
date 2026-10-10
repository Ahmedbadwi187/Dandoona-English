import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/features/skills/skills.dart';

import 'helpers.dart';

SkillsConfig _config() => SkillsConfig.fromJson(jsonDecode(File('assets/content/skills.json').readAsStringSync()) as Map<String, dynamic>);

List<String> _units(String track) => (track == 'explorers' ? realExplorersContent() : realContent()).units.map((u) => u.id).toList();

void main() {
  final c = _config();

  group('the config', () {
    test('every unit it names exists in that track, every skill it names is in the list, and each skill is in exactly one group', () {
      for (final t in c.skillUnits.entries) {
        for (final e in t.value.entries) {
          expect(c.allSkills, contains(e.key), reason: '${t.key}: ${e.key}');
          for (final u in e.value) {
            expect(_units(t.key), contains(u), reason: '${t.key}/${e.key} -> $u');
          }
        }
      }
      final all = c.allSkills;
      expect(all.toSet().length, all.length, reason: 'a skill is listed once');
      for (final e in c.implies.entries) {
        expect(all, contains(e.key));
        for (final i in e.value) {
          expect(all, contains(i));
        }
      }
      for (final r in c.trackUp) {
        for (final s in [...r.whenAll, ...r.orAnyOf]) {
          expect(all, contains(s));
        }
      }
      expect(c.exclusive, [skillNone, skillUnsure]);
    });

    test('no skill implies itself, directly or round a circle', () {
      for (final s in c.allSkills) {
        expect(c.impliedBy(s), isNot(contains(s)), reason: s);
      }
    });
  });

  group('implied skills and the exclusive answers', () {
    test('a higher skill checks the easier ones it implies, all the way down, and says which it checked', () {
      final t = toggleSkill(c, const {}, 'reads-words');
      expect(t.skills, {'reads-words', 'all-letters', 'letter-sounds', 'some-letters'});
      expect(t.autoChecked, {'all-letters', 'letter-sounds', 'some-letters'});
      final more = toggleSkill(c, t.skills, 'reads-sentences');
      expect(more.autoChecked, isEmpty, reason: 'reads words was already checked');
      expect(toggleSkill(c, const {}, 'writes-sentences').skills, containsAll(['reads-sentences', 'reads-words', 'all-letters', 'letter-sounds', 'some-letters']));
    });

    test('the parent can uncheck an implied skill; unchecking never touches the others', () {
      final t = toggleSkill(c, const {}, 'reads-words').skills;
      final u = toggleSkill(c, t, 'letter-sounds').skills;
      expect(u, {'reads-words', 'all-letters', 'some-letters'});
    });

    test('"None of these yet" and "I am not sure" clear every skill and each other; any skill clears them', () {
      final skills = toggleSkill(c, const {}, 'colors').skills;
      expect(toggleSkill(c, skills, skillNone).skills, {skillNone});
      expect(toggleSkill(c, {skillNone}, skillUnsure).skills, {skillUnsure});
      expect(toggleSkill(c, {skillUnsure}, 'animals').skills, {'animals'});
      expect(toggleSkill(c, {skillNone}, skillNone).skills, isEmpty, reason: 'tapping it again unchecks it');
    });
  });

  group('the track from the age and the skills', () {
    TrackSuggestion s(int age, Set<String> skills, {Set<String> available = const {'little-learners', 'explorers'}}) => suggestTrack(config: c, ageYears: age, skills: skills, available: available);

    test('age alone: 3-5 Little Learners, 6-8 Explorers, older children Explorers (the highest released track)', () {
      for (final age in [3, 4, 5]) {
        expect(s(age, const {}).trackId, 'little-learners', reason: '$age');
      }
      for (final age in [6, 7, 8, 9, 10, 12]) {
        expect(s(age, const {}).trackId, 'explorers', reason: '$age');
      }
      expect(s(4, const {}).reason, TrackReason.age);
    });

    test('the boundary of 5 and 6, with and without reading skills', () {
      expect(s(5, {'colors', 'counting'}).trackId, 'little-learners', reason: 'word skills alone do not move a child up');
      expect(s(5, {'all-letters'}).trackId, 'little-learners', reason: 'all letters but not their sounds');
      expect(s(5, {'all-letters', 'letter-sounds'}).trackId, 'explorers');
      expect(s(5, toggleSkill(c, const {}, 'reads-words').skills).trackId, 'explorers');
      expect(s(5, toggleSkill(c, const {}, 'reads-words').skills).reason, TrackReason.skills);
      expect(s(5, {'basic-grammar'}).trackId, 'explorers', reason: 'anything above the letters and sounds');
      expect(s(6, const {}).trackId, 'explorers');
      expect(s(6, {skillNone}).trackId, 'explorers', reason: 'a 6 year old with nothing is never put in Little Learners');
      expect(s(6, {skillUnsure}).trackId, 'explorers');
    });

    test('skills only move a child UP: a 7 year old with all the skills stays in Explorers, never goes back down', () {
      expect(s(7, toggleSkill(c, const {}, 'writes-sentences').skills).trackId, 'explorers');
      expect(s(7, const {}).trackId, 'explorers');
    });

    test('a build without Explorers keeps everybody in Little Learners', () {
      expect(s(7, {'reads-words'}, available: const {'little-learners'}).trackId, 'little-learners');
      expect(s(5, toggleSkill(c, const {}, 'reads-words').skills, available: const {'little-learners'}).trackId, 'little-learners');
    });
  });

  group('the starting point inside a track', () {
    SkillPlacement p(String track, Set<String> skills) => placementFor(config: c, track: track, skills: skills, unitIds: _units(track));

    test('Little Learners: colors and numbers are covered, the child continues from the first unit that is not', () {
      final r = p('little-learners', {'colors', 'counting'});
      expect(r.doneUnits, ['colors', 'numbers']);
      expect(r.startUnit, 'letters', reason: 'letters is first in path order and is not covered');
      final r2 = p('little-learners', {'all-letters', 'colors', 'counting'});
      expect(r2.doneUnits, ['letters', 'colors', 'numbers']);
      expect(r2.startUnit, 'shapes');
      expect(r2.skipped, 3);
    });

    test('Explorers: the letters and the letter sounds cover Letters and Sound Builders', () {
      final r = p('explorers', toggleSkill(c, const {}, 'letter-sounds').skills);
      expect(r.doneUnits, ['letters', 'sound-builders']);
      expect(r.startUnit, 'digraphs');
    });

    test('Explorers: a 7 year old with no skills, or "not sure", starts at the Letters unit and skips nothing', () {
      for (final skills in [<String>{}, {skillNone}, {skillUnsure}]) {
        final r = p('explorers', skills);
        expect(r.doneUnits, isEmpty);
        expect(r.startUnit, 'letters');
      }
    });

    test('Explorers: word skills (colors, counting, animals, everyday words) skip nothing', () {
      final r = p('explorers', {'colors', 'counting', 'animals', 'everyday-words'});
      expect(r.doneUnits, isEmpty);
      expect(r.startUnit, 'letters');
    });

    test('when everything is covered the child starts at the last unit', () {
      final r = placementFor(config: c, track: 'explorers', skills: {'all-letters'}, unitIds: ['letters']);
      expect(r.startUnit, 'letters');
    });
  });

  group('children made with the old single-choice answer', () {
    test('each old level becomes the matching checked skills', () {
      expect(skillsFromOldLevel(c, 0), {skillNone});
      expect(skillsFromOldLevel(c, 1), {'some-letters'});
      expect(skillsFromOldLevel(c, 2), {'all-letters', 'some-letters'});
      expect(skillsFromOldLevel(c, 3), {'reads-words', 'all-letters', 'letter-sounds', 'some-letters'});
    });
  });
}
