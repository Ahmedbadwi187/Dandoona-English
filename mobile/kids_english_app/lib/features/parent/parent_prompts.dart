import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/palette.dart';
import '../../core/storage.dart';
import '../content/content_repository.dart';
import '../onboarding/track_resolver.dart';
import '../profiles/child_profile.dart';
import '../settings/settings.dart';
import '../units/map_path.dart' show castleId;
import '../units/unit_meta.dart';
import 'parent_ui.dart';

/// Questions the parent area asks once per child, and remembers the answer (on the phone only, `asks.v1`):
/// - the birth month, for a child saved with the year only (the month is required for new children);
/// - the Explorers track, offered (never switched automatically) when a Little Learners child turns 6 or finishes the castle.
class ParentAsks {
  const ParentAsks({this.monthAsked = const {}, this.explorersAnswered = const {}});

  /// Children whose parent already answered the month question ("Add" or "Not now").
  final Set<String> monthAsked;

  /// Children whose parent already answered the Explorers offer (accepted or stayed).
  final Set<String> explorersAnswered;

  Map<String, dynamic> toJson() => {'monthAsked': monthAsked.toList()..sort(), 'explorersAnswered': explorersAnswered.toList()..sort()};

  factory ParentAsks.fromJson(Map<String, dynamic> json) => ParentAsks(
        monthAsked: ((json['monthAsked'] as List<dynamic>?) ?? const []).cast<String>().toSet(),
        explorersAnswered: ((json['explorersAnswered'] as List<dynamic>?) ?? const []).cast<String>().toSet(),
      );
}

class ParentAsksNotifier extends Notifier<ParentAsks> {
  static const key = 'asks.v1';

  @override
  ParentAsks build() {
    final raw = ref.read(sharedPreferencesProvider).readJson(key);
    if (raw is Map<String, dynamic>) {
      try {
        return ParentAsks.fromJson(raw);
      } on Object {
        // unreadable: ask again
      }
    }
    return const ParentAsks();
  }

  Future<void> monthAnswered(String childId) => _save(ParentAsks(monthAsked: {...state.monthAsked, childId}, explorersAnswered: state.explorersAnswered));

  Future<void> explorersAnswered(String childId) => _save(ParentAsks(monthAsked: state.monthAsked, explorersAnswered: {...state.explorersAnswered, childId}));

  Future<void> _save(ParentAsks next) async {
    state = next;
    await ref.read(sharedPreferencesProvider).writeJson(key, next.toJson());
  }
}

final parentAsksProvider = NotifierProvider<ParentAsksNotifier, ParentAsks>(ParentAsksNotifier.new);

/// A child saved with the birth year only, whose parent has not been asked for the month yet.
bool needsMonthAsk(ChildProfile c, ParentAsks asks) => c.birthMonth == null && !asks.monthAsked.contains(c.id);

/// The Explorers offer is due for a Little Learners child who is 6 or older, or who finished the Little Learners castle
/// (whichever comes first), unless the parent already answered. It is only an offer: nothing changes until they accept.
bool explorersOfferDue(ChildProfile c, ParentAsks asks, {required DateTime now, required bool castleDone}) {
  if (!explorersEnabled || c.track != littleLearnersTrack || asks.explorersAnswered.contains(c.id)) return false;
  final age = resolveTrack(birthYear: c.birthYear, birthMonth: c.birthMonth, now: now).ageYears;
  return age >= 6 || castleDone;
}

/// The cards above a child's card in the parent area (none, one or both).
class ParentPrompts extends ConsumerWidget {
  const ParentPrompts({super.key, required this.child});

  final ChildProfile child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final asks = ref.watch(parentAsksProvider);
    final now = ref.read(clockProvider)();
    final castleDone = ref.watch(unitMetaProvider).of(child.id).reviews.contains(castleId);
    return Column(
      children: [
        if (explorersOfferDue(child, asks, now: now, castleDone: castleDone))
          _PromptCard(
            key: Key('offer-explorers-${child.id}'),
            icon: Icons.explore_rounded,
            color: Palette.blue,
            text: s.format('pExplorersOffer', {'name': child.name}),
            note: s('pExplorersKeeps'),
            yes: s('pExplorersYes'),
            no: s('pExplorersStay'),
            yesKey: Key('offer-explorers-yes-${child.id}'),
            noKey: Key('offer-explorers-stay-${child.id}'),
            // Only the track changes: certificates, chests, outfits and progress stay with the child.
            onYes: () async {
              await ref.read(profilesProvider.notifier).update(child.id, track: explorersTrack);
              await ref.read(parentAsksProvider.notifier).explorersAnswered(child.id);
            },
            onNo: () => ref.read(parentAsksProvider.notifier).explorersAnswered(child.id),
          ),
        if (needsMonthAsk(child, asks))
          _PromptCard(
            key: Key('ask-month-${child.id}'),
            icon: Icons.cake_rounded,
            color: Palette.orange,
            text: s.format('pAskMonth', {'name': child.name}),
            yes: s('pAskMonthAdd'),
            no: s('pNotNow'),
            yesKey: Key('ask-month-add-${child.id}'),
            noKey: Key('ask-month-later-${child.id}'),
            onYes: () async {
              await ref.read(parentAsksProvider.notifier).monthAnswered(child.id);
              if (context.mounted) context.push('/parent/children/${child.id}');
            },
            onNo: () => ref.read(parentAsksProvider.notifier).monthAnswered(child.id),
          ),
      ],
    );
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({
    super.key,
    required this.icon,
    required this.color,
    required this.text,
    required this.yes,
    required this.no,
    required this.yesKey,
    required this.noKey,
    required this.onYes,
    required this.onNo,
    this.note,
  });

  final IconData icon;
  final Color color;
  final String text;
  final String? note;
  final String yes;
  final String no;
  final Key yesKey;
  final Key noKey;
  final VoidCallback onYes;
  final VoidCallback onNo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ParentCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(text, style: ParentText.body.copyWith(fontWeight: FontWeight.w700)),
                      if (note != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(note!, style: ParentText.caption)),
                    ],
                  ),
                ),
              ],
            ),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                TextButton(key: noKey, onPressed: onNo, child: Text(no)),
                FilledButton(key: yesKey, onPressed: onYes, child: Text(yes)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
