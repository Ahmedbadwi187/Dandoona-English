import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/palette.dart';
import '../../core/strings.dart';
import '../content/content_repository.dart';
import '../profiles/child_profile.dart';
import '../reminders/reminder_service.dart';
import '../settings/settings.dart';
import '../sync/sync_controller.dart';
import '../units/unit_meta.dart';
import 'onboarding_screens.dart';
import 'track_resolver.dart';

/// The answers collected by the child setup flow. They live here (not in each screen) so the back arrow keeps them.
class SetupDraft {
  const SetupDraft({this.childId, this.name = '', this.avatar, this.month, this.year, this.level, this.goal, this.reminder, this.returnTo});

  /// Set when an existing child goes through the setup again.
  final String? childId;
  final String name;
  final String? avatar;
  final int? month;
  final int? year;
  final int? level;
  final int? goal;

  /// `morning`, `afternoon`, `evening`, or null (no reminder).
  final String? reminder;

  /// Where to go when the setup is done instead of the greeting (for example the manage-children list).
  final String? returnTo;

  SetupDraft copyWith({String? name, String? avatar, int? month, int? year, int? level, int? goal, String? reminder, bool clearReminder = false}) => SetupDraft(
        childId: childId,
        name: name ?? this.name,
        avatar: avatar ?? this.avatar,
        month: month ?? this.month,
        year: year ?? this.year,
        level: level ?? this.level,
        goal: goal ?? this.goal,
        reminder: clearReminder ? null : (reminder ?? this.reminder),
        returnTo: returnTo,
      );
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

  static const order = ['name', 'age', 'level', 'goal', 'reminder', 'summary'];

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
          onBack: onBack,
        );
      case 'age':
        final content = ref.watch(contentProvider).asData?.value;
        final choice = d.year == null ? null : resolveTrack(birthYear: d.year!, birthMonth: d.month, now: now);
        return ChildAgeScreen(
          s: s,
          month: d.month,
          year: d.year,
          years: years,
          onMonth: (v) => draft.update((x) => x.copyWith(month: v)),
          onYear: (v) => draft.update((x) => x.copyWith(year: v)),
          trackLabel: choice == null || content == null ? null : _trackLabel(s, choice),
          onContinue: () => _next(context),
          onBack: onBack,
        );
      case 'level':
        return ChildLevelScreen(s: s, level: d.level, onLevel: (v) => draft.update((x) => x.copyWith(level: v)), onContinue: () => _next(context), onBack: onBack);
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
      case 'greeting':
        return ChildGreetingScreen(name: d.name, onGo: () => context.go('/map'));
      default:
        return _summary(context, ref, s, d, now);
    }
  }

  static String _trackLabel(Strings s, TrackChoice c) => c.available ? s('obTrackLL') : '${s('obTrackLL')} · ${s('obTrackSoon')}';

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
    final content = ref.watch(contentProvider).asData?.value;
    final choice = resolveTrack(birthYear: d.year ?? now.year - 4, birthMonth: d.month, now: now);
    final level = content?.placement.where((p) => p.level == (d.level ?? 0)).firstOrNull;
    final startUnit = level == null ? null : content?.unitById(level.startUnit);

    void edit(String row) => context.push('/setup/${const {'track': 'age', 'start': 'level', 'goal': 'goal', 'reminder': 'reminder'}[row]}?edit=1');

    return SummaryScreen(
      s: s,
      name: d.name,
      onBack: context.canPop() ? () => context.pop() : null,
      onEdit: edit,
      rows: [
        SummaryRow(keyName: 'track', label: s('obRowTrack'), value: _trackLabel(s, choice), icon: Icons.route_rounded, color: Palette.green),
        SummaryRow(keyName: 'start', label: s('obRowStart'), value: startUnit?.titleFor(ref.read(settingsProvider).languageCode) ?? '', icon: Icons.flag_rounded, color: Palette.orange),
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
    final content = await ref.read(contentProvider.future);
    final choice = resolveTrack(birthYear: d.year!, birthMonth: d.month, now: now);
    final goal = d.goal ?? 10;

    final String childId;
    if (d.childId == null) {
      childId = (await profiles.add(name: d.name, avatarKey: d.avatar!, birthYear: d.year!, birthMonth: d.month, goalMinutes: goal, track: choice.resolvedTrackId)).id;
    } else {
      childId = d.childId!;
      await profiles.update(childId, name: d.name, avatarKey: d.avatar, birthYear: d.year, birthMonth: d.month, goalMinutes: goal, track: choice.resolvedTrackId);
    }

    // What the parent said about the child's English decides which units count as done and where the child starts.
    final level = content.placement.where((p) => p.level == (d.level ?? 0)).firstOrNull;
    if (level != null) await ref.read(unitMetaProvider.notifier).setPlaced(childId, level.doneUnits.toSet());

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
