import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/features/content/content_repository.dart';
import 'package:kids_english_app/features/onboarding/track_resolver.dart';
import 'package:kids_english_app/features/parent/parent_prompts.dart';
import 'package:kids_english_app/features/profiles/child_profile.dart';

import 'helpers.dart';

/// Explorers can be built out of the app for a Little Learners only release: `--dart-define=ENABLE_EXPLORERS=false`.
/// The normal run checks the default (Explorers on); the other half runs with the switch off:
///   flutter test --dart-define=ENABLE_EXPLORERS=false test/explorers_switch_test.dart
const _explorersChild = '{"id":"e1","name":"Lina","avatarKey":"star","birthYear":2019,"birthMonth":2,"track":"explorers","createdAt":"2026-01-01T00:00:00Z"}';
const _littleChild = '{"id":"l1","name":"Omar","avatarKey":"star","birthYear":2019,"birthMonth":2,"track":"little-learners","createdAt":"2026-01-01T00:00:00Z"}';

Future<ProviderContainer> _open(String child) async {
  final overrides = await testOverrides(content: realContent(), explorers: realExplorersContent(), prefs: {'children.v1': '[$child]'});
  final c = ProviderContainer(overrides: overrides);
  addTearDown(c.dispose);
  c.read(activeChildIdProvider.notifier).select(c.read(profilesProvider).first.id);
  return c;
}

void main() {
  final now = DateTime(2026, 10, 8);

  group('Explorers on (the default)', () {
    test('an Explorers child uses the Explorers catalog; a 7 year old is placed in Explorers and offered it', () async {
      final c = await _open(_explorersChild);
      expect(c.read(activeTrackProvider), explorersTrack);
      expect((await c.read(activeContentProvider.future)).track, 'explorers');
      expect(availableTracks, {littleLearnersTrack, explorersTrack});
      expect(resolveTrack(birthYear: 2019, birthMonth: 2, now: now, available: availableTracks).resolvedTrackId, explorersTrack);
      final l = (await _open(_littleChild)).read(profilesProvider).first;
      expect(explorersOfferDue(l, const ParentAsks(), now: now, castleDone: false), isTrue);
    });
  }, skip: explorersEnabled ? false : 'the switch is off in this run');

  group('Explorers off (a Little Learners only release)', () {
    test('every child uses the Little Learners catalog, nobody is placed in Explorers or offered it', () async {
      final c = await _open(_explorersChild);
      expect(c.read(activeTrackProvider), littleLearnersTrack);
      expect((await c.read(activeContentProvider.future)).track, 'little-learners');
      expect((await c.read(trackContentProvider(explorersTrack).future)).track, 'little-learners');
      expect(availableTracks, {littleLearnersTrack});
      final choice = resolveTrack(birthYear: 2019, birthMonth: 2, now: now, available: availableTracks);
      expect(choice.resolvedTrackId, littleLearnersTrack);
      expect(choice.available, isFalse);
      final l = (await _open(_littleChild)).read(profilesProvider).first;
      expect(explorersOfferDue(l, const ParentAsks(), now: now, castleDone: true), isFalse);
    });
  }, skip: explorersEnabled ? 'run with --dart-define=ENABLE_EXPLORERS=false' : false);
}
