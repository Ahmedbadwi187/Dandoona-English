import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/palette.dart';
import '../../core/strings.dart';
import '../audio/audio_service.dart';
import '../content/content_repository.dart';
import '../profiles/child_profile.dart';
import '../reminders/reminder_service.dart';
import '../settings/settings.dart';
import '../skills/skills.dart';
import '../sync/sync_controller.dart';
import '../units/unit_meta.dart';
import 'onboarding_screens.dart';
import 'track_resolver.dart';

/// The answers collected by the child setup flow. They live here (not in each screen) so the back arrow keeps them.
class SetupDraft {
  const SetupDraft({this.childId, this.name = '', this.avatar, this.month, this.year, this.skills = const {}, this.goal, this.reminder, this.returnTo, this.track});

  /// Set when an existing child goes through the setup again.
  final String? childId;
  final String name;
  final String? avatar;
  final int? month;
  final int? year;

  /// What the parent checked in "What can your child already do?" (skill ids, or `none` / `unsure`).
  final Set<String> skills;
  final int? goal;

  /// `morning`, `afternoon`, `evening`, or null (no reminder).
  final String? reminder;

  /// Where to go when the setup is done instead of the greeting (for example the manage-children list).
  final String? returnTo;

  /// The track the parent chose on the summary; null = the one that fits the age.
  final String? track;

  SetupDraft copyWith({String? name, String? avatar, int? month, int? year, Set<String>? skills, int? goal, String? reminder, bool clearReminder = false, String? track}) => SetupDraft(
        childId: childId,
        name: name ?? this.name,
        avatar: avatar ?? this.avatar,
        month: month ?? this.month,
        year: year ?? this.year,
        skills: skills ?? this.skills,
        goal: goal ?? this.goal,
        reminder: clearReminder ? null : (reminder ?? this.reminder),
        returnTo: returnTo,
        track: track ?? this.track,
      );

  /// The age in whole years (with the month when it is known).
  int ageAt(DateTime now) {
    final a = now.year - (year ?? now.year - 4) - (month != null && now.month < month! ? 1 : 0);
    return a < 0 ? 0 : a;
  }

  /// The track this child will use: the parent's choice, else the suggestion from the age and the skills ([config] null = the age alone).
  String trackAt(DateTime now, [SkillsConfig? config]) {
    if (track != null) return track!;
    if (config == null) return resolveTrack(birthYear: year ?? now.year - 4, birthMonth: month, now: now, available: availableTracks).resolvedTrackId;
    return suggestTrack(config: config, ageYears: ageAt(now), skills: skills, available: availableTracks).trackId;
  }
}

class SetupDraftNotifier extends Notifier<SetupDraft> {
  @override
  SetupDraft build() => const SetupDraft();

  /// Starts a fresh setup, or one filled from an existing child ([childId]).
  void start({String? childId, String? returnTo}) {
    final c = childId == null ? null : ref.read(profilesProvider).where((p) => p.id == childId).firstOrNull;
    state = SetupDraft(
      childId: c?.id,
      name: c?.name ?? '',
      avatar: c?.avatarKey,
      month: c?.birthMonth,
      year: c?.birthYear,
      goal: c?.goalMinutes,
      skills: c?.skills ?? const {},
      track: c?.track,
      reminder: ref.read(settingsProvider).reminderTime,
      returnTo: returnTo,
    );
  }

  void update(SetupDraft Function(SetupDraft d) f) => state = f(state);
}

final setupDraftProvider = NotifierProvider<SetupDraftNotifier, SetupDraft>(SetupDraftNotifier.new);

/// Opens the child setup. [childId] reruns it for an existing child; [returnTo] is where it ends.
void startChildSetup(BuildContext context, WidgetRef ref, {String? childId, String? returnTo}) {
  ref.read(setupDraftProvider.notifier).start(childId: childId, returnTo: returnTo);
  context.push('/setup/name');
}

/// One screen of the child setup, chosen by the route (`/setup/:step`). `?edit=1` = opened from the summary, so
/// Continue goes back to the summary.
class SetupRoute extends ConsumerWidget {
  const SetupRoute({super.key, required this.step, this.fromSummary = false});

  final String step;
  final bool fromSummary;

  static const order = ['name', 'age', 'skills', 'goal', 'reminder', 'summary'];

  void _next(BuildContext context) {
    if (fromSummary) {
      context.pop();
      return;
    }
    context.push('/setup/${order[order.indexOf(step) + 1]}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final d = ref.watch(setupDraftProvider);
    final draft = ref.read(setupDraftProvider.notifier);
    final now = ref.read(clockProvider)();
    final onBack = context.canPop() ? () => context.pop() : null;
    final years = [for (var y = now.year - 2; y >= now.year - 13; y--) y];

    switch (step) {
      case 'name':
        return ChildNameScreen(
          s: s,
          name: d.name,
          avatarKey: d.avatar,
          onName: (v) => draft.update((x) => x.copyWith(name: v)),
          onAvatar: (v) => draft.update((x) => x.copyWith(avatar: v)),
          onContinue: () => _next(context),
          // the first question has nothing to pop to when the parent just came from the welcome screen: back goes there, so the account choice can be changed
          onBack: onBack ?? (d.childId == null && d.returnTo == null ? () => context.go('/onboarding') : null),
        );
      case 'age':
        return ChildAgeScreen(
          s: s,
          month: d.month,
          year: d.year,
          years: years,
          onMonth: (v) => draft.update((x) => x.copyWith(month: v)),
          onYear: (v) => draft.update((x) => x.copyWith(year: v)),
          onContinue: () => _next(context),
          onBack: onBack,
        );
      case 'skills':
        return ChildSkillsScreen(
          s: s,
          config: ref.watch(skillsConfigProvider).asData?.value,
          skills: d.skills,
          onSkills: (v) => draft.update((x) => x.copyWith(skills: v)),
          onContinue: () => _next(context),
          onBack: onBack,
        );
      case 'goal':
        return DailyGoalScreen(s: s, minutes: d.goal, onMinutes: (v) => draft.update((x) => x.copyWith(goal: v)), onContinue: () => _next(context), onBack: onBack);
      case 'reminder':
        return ReminderScreen(
          s: s,
          time: d.reminder,
          onTime: (v) => draft.update((x) => x.copyWith(reminder: v)),
          onRemind: () => _remind(context, ref),
          onLater: () {
            draft.update((x) => x.copyWith(clearReminder: true));
            _next(context);
          },
          onBack: onBack,
        );
      case 'track':
        return ChildTrackScreen(s: s, track: d.trackAt(now, ref.watch(skillsConfigProvider).asData?.value), onTrack: (v) => draft.update((x) => x.copyWith(track: v)), onContinue: () => _next(context), onBack: onBack);
      case 'greeting':
        return _GreetingRoute(name: d.name);
      default:
        return _summary(context, ref, s, d, now);
    }
  }

  static String _trackName(Strings s, String track) => track == explorersTrack ? s('obTrackExplorers') : s('obTrackLL');

  Future<void> _remind(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    // The notification permission is asked here, after the parent tapped "Remind me", and nowhere else.
    final granted = await ref.read(reminderServiceProvider).requestPermission();
    if (!context.mounted) return;
    if (!granted) {
      ref.read(setupDraftProvider.notifier).update((x) => x.copyWith(clearReminder: true));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s('obReminderDenied'))));
    }
    _next(context);
  }

  Widget _summary(BuildContext context, WidgetRef ref, Strings s, SetupDraft d, DateTime now) {
    // The track (from the age, or the parent's choice) decides which placement table gives the start unit.
    final config = ref.watch(skillsConfigProvider).asData?.value;
    final track = d.trackAt(now, config);
    final content = ref.watch(trackContentProvider(track)).asData?.value;
    final lang = ref.read(settingsProvider).languageCode;
    final placement = config == null || content == null ? null : placementFor(config: config, track: track, skills: d.skills, unitIds: [for (final u in content.units) u.id]);
    final startUnit = placement?.startUnit == null ? null : content?.unitById(placement!.startUnit!);
    final skipped = placement?.skipped ?? 0;
    // why this track: the age alone, or what the child can do
    final suggestion = config == null ? null : suggestTrack(config: config, ageYears: d.ageAt(now), skills: d.skills, available: availableTracks);
    final reason = suggestion == null || d.track != null
        ? null
        : s(suggestion.reason == TrackReason.skills ? 'obReasonSkills' : 'obReasonAge').replaceAll('{name}', d.name).replaceAll('{track}', _trackName(s, track).replaceAll(RegExp(r'\s*[(（].*$'), ''));

    void edit(String row) => context.push('/setup/${const {'track': 'track', 'start': 'skills', 'goal': 'goal', 'reminder': 'reminder'}[row]}?edit=1');

    return SummaryScreen(
      s: s,
      name: d.name,
      onBack: context.canPop() ? () => context.pop() : null,
      onEdit: edit,
      reason: reason,
      rows: [

        SummaryRow(keyName: 'track', label: s('obRowTrack'), value: _trackName(s, track), icon: Icons.route_rounded, color: Palette.green),
        SummaryRow(keyName: 'start', label: s('obRowStart'), value: (startUnit?.titleFor(lang) ?? '') + (skipped == 0 ? '' : ' · ${s(skipped == 1 ? 'obSkipped1' : 'obSkippedN').replaceAll('{n}', '$skipped')}'), icon: Icons.flag_rounded, color: Palette.orange),
        SummaryRow(keyName: 'goal', label: s('obRowGoal'), value: s('obGoal${d.goal ?? 10}'), icon: Icons.timer_rounded, color: Palette.teal),
        SummaryRow(
          keyName: 'reminder',
          label: s('obRowReminder'),
          value: d.reminder == null ? s('obNoReminder') : s('obTime${d.reminder![0].toUpperCase()}${d.reminder!.substring(1)}'),
          icon: Icons.notifications_rounded,
          color: Palette.purple,
        ),
      ],
      onStart: () => _finish(context, ref),
    );
  }

  /// Saves the child and everything the answers decide, then leaves the flow.
  Future<void> _finish(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    final d = ref.read(setupDraftProvider);
    final now = ref.read(clockProvider)();
    final profiles = ref.read(profilesProvider.notifier);
    final config = await ref.read(skillsConfigProvider.future);
    final track = d.trackAt(now, config);
    final content = await ref.read(trackContentProvider(track).future);
    final goal = d.goal ?? 10;

    final String childId;
    if (d.childId == null) {
      childId = (await profiles.add(name: d.name, avatarKey: d.avatar!, birthYear: d.year!, birthMonth: d.month, goalMinutes: goal, track: track, skills: d.skills)).id;
    } else {
      childId = d.childId!;
      await profiles.update(childId, name: d.name, avatarKey: d.avatar, birthYear: d.year, birthMonth: d.month, goalMinutes: goal, track: track, skills: d.skills);
    }

    // What the parent said about the child's English decides which units count as done and where the child starts.
    // The skills decide which units count as done by placement and where the child starts. Units of the other track keep their marks.
    final unitIds = [for (final u in content.units) u.id];
    final placement = placementFor(config: config, track: track, skills: d.skills, unitIds: unitIds);
    final others = ref.read(unitMetaProvider).of(childId).placed.where((u) => !unitIds.contains(u));
    await ref.read(unitMetaProvider.notifier).setPlaced(childId, {...others, ...placement.doneUnits});

    final settings = ref.read(settingsProvider.notifier);
    await settings.setSessionMinutes(goal); // the daily goal is the session timer
    await settings.setReminder(d.reminder);
    final reminders = ref.read(reminderServiceProvider);
    try {
      final time = d.reminder == null ? null : reminderTimes[d.reminder];
      if (time == null) {
        await reminders.cancel();
      } else {
        await reminders.schedule(hour: time.hour, minute: time.minute, title: s('obReminderTitle'), body: s('obReminderBody'));
      }
    } on Object {
      // A phone that refuses notifications must not stop the child from starting.
    }
    await settings.completeOnboarding();
    unawaited(ref.read(syncControllerProvider.notifier).syncQuietly());

    if (!context.mounted) return;
    if (d.returnTo != null) {
      context.go(d.returnTo!);
    } else {
      ref.read(activeChildIdProvider.notifier).select(childId);
      context.go('/setup/greeting');
    }
  }
}

/// The greeting: Dandoona says hello in her voice (silent when the line is not in the content), then "Let's go!" opens the map.
class _GreetingRoute extends ConsumerStatefulWidget {
  const _GreetingRoute({required this.name});

  final String name;

  @override
  ConsumerState<_GreetingRoute> createState() => _GreetingRouteState();
}

class _GreetingRouteState extends ConsumerState<_GreetingRoute> {
  late final AudioService _audio;

  @override
  void initState() {
    super.initState();
    _audio = ref.read(audioServiceProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final path = (await ref.read(contentProvider.future)).appAudio?.welcome;
        if (path != null && mounted) await _audio.playAsset(path);
      } on Object {
        // no voice: the words are on the screen
      }
    });
  }

  @override
  void dispose() {
    unawaited(_audio.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChildGreetingScreen(name: widget.name, onGo: () => context.go('/map'));
}
