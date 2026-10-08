import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/palette.dart';
import '../../core/widgets.dart';
import '../content/content_models.dart';
import '../content/content_repository.dart';
import '../onboarding/setup_flow.dart';
import '../onboarding/track_resolver.dart';
import '../profiles/child_profile.dart';
import '../reminders/reminder_service.dart';
import '../settings/settings.dart';
import '../sync/sync_controller.dart';
import '../units/unit_meta.dart';
import 'parent_ui.dart';

/// Edit one child: nickname, avatar, birth month and year, track, daily goal and reminder; "Save" is on only when
/// something changed; leaving with changes asks first; "Delete child" is separate, at the bottom.
class EditChildScreen extends ConsumerStatefulWidget {
  const EditChildScreen({super.key, required this.childId});

  final String childId;

  @override
  ConsumerState<EditChildScreen> createState() => _EditChildScreenState();
}

class _EditChildScreenState extends ConsumerState<EditChildScreen> {
  static const maxNickname = 15;

  late final ChildProfile _child;
  late final TextEditingController _name;
  late String _avatar;
  int? _month;
  late int _year;
  late String _track;
  late int _goal;
  String? _reminder;

  /// The units counted as done by placement (the "starting point"); null = unchanged.
  Set<String>? _placed;
  bool _leave = false; // saved, discarded or deleted: leaving needs no question

  @override
  void initState() {
    super.initState();
    _child = ref.read(profilesProvider).firstWhere((p) => p.id == widget.childId);
    _name = TextEditingController(text: _child.name)..addListener(() => setState(() {}));
    _avatar = _child.avatarKey;
    _month = _child.birthMonth;
    _year = _child.birthYear;
    _track = _child.track;
    _goal = _child.goalMinutes ?? 10;
    _reminder = ref.read(settingsProvider).reminderTime;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _valid => ChildValidation.name(_name.text) == null;

  bool get _dirty =>
      _name.text.trim() != _child.name ||
      _avatar != _child.avatarKey ||
      _month != _child.birthMonth ||
      _year != _child.birthYear ||
      _track != _child.track ||
      _goal != (_child.goalMinutes ?? 10) ||
      _reminder != ref.read(settingsProvider).reminderTime ||
      (_placed != null && !_sameSet(_placed!, ref.read(unitMetaProvider).of(_child.id).placed));

  static bool _sameSet(Set<String> a, Set<String> b) => a.length == b.length && a.containsAll(b);

  Future<void> _save() async {
    final s = ref.read(stringsProvider);
    final settings = ref.read(settingsProvider.notifier);
    await ref.read(profilesProvider.notifier).update(_child.id, name: _name.text, avatarKey: _avatar, birthYear: _year, birthMonth: _month, goalMinutes: _goal, track: _track);
    // A new starting point only adds units counted as done; nothing the child did is taken away.
    if (_placed != null) await ref.read(unitMetaProvider.notifier).setPlaced(_child.id, _placed!);
    await settings.setSessionMinutes(_goal);
    if (_reminder != ref.read(settingsProvider).reminderTime) {
      final reminders = ref.read(reminderServiceProvider);
      final time = _reminder == null ? null : reminderTimes[_reminder];
      try {
        if (time == null) {
          await settings.setReminder(null);
          await reminders.cancel();
        } else if (await reminders.requestPermission()) {
          await settings.setReminder(_reminder);
          await reminders.schedule(hour: time.hour, minute: time.minute, title: s('obReminderTitle'), body: s('obReminderBody'));
        } else {
          await settings.setReminder(null);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s('obReminderDenied'))));
        }
      } on Object {
        // A phone that refuses notifications must not lose the other changes.
      }
    }
    unawaited(ref.read(syncControllerProvider.notifier).syncQuietly());
    if (!mounted) return;
    setState(() => _leave = true);
    _close();
  }

  /// Back to where the parent came from (the list, when this screen was opened directly).
  void _close() => context.canPop() ? context.pop() : context.go('/parent/children');

  Future<bool> _askDiscard() async {
    final s = ref.read(stringsProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: s.direction,
        child: AlertDialog(
          title: Text(s('pDiscardTitle')),
          content: Text(s('pDiscardBody')),
          actions: [
            TextButton(key: const Key('keep-editing'), autofocus: true, onPressed: () => Navigator.pop(ctx, false), child: Text(s('pKeepEditing'))),
            TextButton(key: const Key('discard-confirm'), onPressed: () => Navigator.pop(ctx, true), child: Text(s('pDiscard'), style: const TextStyle(color: Palette.red))),
          ],
        ),
      ),
    );
    return ok == true;
  }

  Future<void> _delete() async {
    final s = ref.read(stringsProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: s.direction,
        child: AlertDialog(
          key: const Key('delete-dialog'),
          title: Text(s.format('pDeleteTitle', {'name': _child.name})),
          content: Text(s.format('pDeleteBody', {'name': _child.name})),
          actions: [
            TextButton(key: const Key('cancel-delete'), autofocus: true, onPressed: () => Navigator.pop(ctx, false), child: Text(s('cancel'))),
            TextButton(key: const Key('confirm-delete'), onPressed: () => Navigator.pop(ctx, true), child: Text(s('delete'), style: const TextStyle(color: Palette.red, fontWeight: FontWeight.w700))),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _leave = true);
    await ref.read(profilesProvider.notifier).remove(_child.id);
    // Also hard-delete the child on the server (profile + all progress); queued if offline.
    await ref.read(syncControllerProvider.notifier).childDeleted(_child.id);
    if (mounted) context.go('/parent/children');
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final now = ref.read(clockProvider)();
    final others = {for (final p in ref.watch(profilesProvider)) if (p.id != _child.id) p.avatarKey};
    final avatars = [
      if (!AvatarOption.pickable.any((a) => a.key == _child.avatarKey)) _child.avatarKey, // an older icon avatar keeps working
      for (final a in AvatarOption.pickable) a.key,
    ];
    final years = {for (var y = now.year - 2; y >= now.year - 13; y--) y, _year}.toList()..sort((a, b) => b.compareTo(a));
    final suggested = resolveTrack(birthYear: _year, birthMonth: _month, now: now).trackId;
    // Starting points of the chosen track: one per placement answer with its own start unit.
    final trackContent = ref.watch(trackContentProvider(_track)).asData?.value;
    final placed = _placed ?? ref.watch(unitMetaProvider).of(_child.id).placed;
    final starts = <String, PlacementLevel>{for (final p in trackContent?.placement ?? const <PlacementLevel>[]) p.startUnit: p};
    final currentStart = starts.values.where((p) => _sameSet(p.doneUnits.toSet(), placed)).firstOrNull?.startUnit ?? starts.keys.firstOrNull;
    final primary = Theme.of(context).colorScheme.primary;

    return PopScope(
      canPop: !_dirty || _leave,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _askDiscard() && mounted) {
          setState(() => _leave = true);
          this.context.canPop() ? this.context.pop() : this.context.go('/parent/children');
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
                child: Row(
                  children: [
                    ParentBack(onPressed: () => Navigator.of(context).maybePop()),
                    const SizedBox(width: 4),
                    Expanded(child: Text(s('pEditChild'), style: ParentText.screenTitle)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    ParentCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            key: const Key('edit-name'),
                            controller: _name,
                            maxLength: maxNickname,
                            decoration: InputDecoration(labelText: s('pNickname'), helperText: s('nameHint'), helperMaxLines: 2),
                          ),
                          const SizedBox(height: 12),
                          Text(s('chooseAvatar'), style: ParentText.section),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final key in avatars)
                                Opacity(
                                  opacity: others.contains(key) ? 0.35 : 1,
                                  child: InkResponse(
                                    key: Key('avatar-$key'),
                                    onTap: others.contains(key) ? null : () => setState(() => _avatar = key),
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _avatar == key ? primary : Colors.transparent, width: 3)),
                                      child: AvatarCircle(key, size: 52),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ParentCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  key: const Key('edit-month'),
                                  initialValue: _month,
                                  isExpanded: true,
                                  decoration: InputDecoration(labelText: s('obMonth')),
                                  items: [for (var m = 1; m <= 12; m++) DropdownMenuItem(value: m, child: Text(s('obMonth$m')))],
                                  onChanged: (v) => setState(() => _month = v),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  key: const Key('edit-year'),
                                  initialValue: _year,
                                  isExpanded: true,
                                  decoration: InputDecoration(labelText: s('obYear')),
                                  items: [for (final y in years) DropdownMenuItem(value: y, child: Text(s.number(y)))],
                                  onChanged: (v) => setState(() => _year = v ?? _year),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(s('pTrack'), style: ParentText.section),
                          const SizedBox(height: 8),
                          for (final t in [('little-learners', 'pTrackLL', true), ('explorers', 'pTrackExplorers', explorersEnabled), ('champions', 'pTrackChampions', false)])
                            _TrackTile(
                              key: Key('edit-track-${t.$1}'),
                              label: s(t.$2),
                              selected: _track == t.$1,
                              enabled: t.$3,
                              note: !t.$3 ? s('pSoon') : (suggested == t.$1 ? s('pSuggested') : null),
                              onTap: () => setState(() => _track = t.$1),
                            ),
                          if (starts.length > 1) ...[
                            const SizedBox(height: 16),
                            Text(s('pStartUnit'), style: ParentText.section),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final e in starts.entries)
                                  _Pill(
                                    key: Key('edit-start-${e.key}'),
                                    label: trackContent!.unitById(e.key)?.titleFor(ref.read(settingsProvider).languageCode) ?? e.key,
                                    selected: currentStart == e.key,
                                    onTap: () => setState(() => _placed = e.value.doneUnits.toSet()),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ParentCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s('pDailyGoal'), style: ParentText.section),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final m in const [5, 10, 15]) _Pill(key: Key('edit-goal-$m'), label: s.format('pMinutesShort', {'n': m}), selected: _goal == m, onTap: () => setState(() => _goal = m)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(s('pReminderTime'), style: ParentText.section),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _Pill(key: const Key('edit-reminder-off'), label: s('pReminderOff'), selected: _reminder == null, onTap: () => setState(() => _reminder = null)),
                              for (final t in reminderTimes.keys)
                                _Pill(key: Key('edit-reminder-$t'), label: s('obTime${t[0].toUpperCase()}${t.substring(1)}'), selected: _reminder == t, onTap: () => setState(() => _reminder = t)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      key: const Key('edit-save'),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                      onPressed: _dirty && _valid ? _save : null,
                      child: Text(s('save')),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      key: const Key('rerun-setup'),
                      style: TextButton.styleFrom(minimumSize: const Size.fromHeight(kParentTap)),
                      onPressed: () => startChildSetup(context, ref, childId: _child.id, returnTo: '/parent/children/${_child.id}'),
                      child: Text(s('pRerunSetup')),
                    ),
                    const SizedBox(height: 24),
                    const Divider(color: parentBorder),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      key: const Key('edit-delete'),
                      style: TextButton.styleFrom(foregroundColor: Palette.red, minimumSize: const Size.fromHeight(kParentTap)),
                      onPressed: _delete,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: Text(s('pDeleteChild')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: selected ? primary : Palette.white,
      shape: StadiumBorder(side: BorderSide(color: selected ? primary : parentBorder, width: 1.5)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kParentTap, minWidth: kParentTap),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Center(widthFactor: 1, child: Text(label, style: ParentText.body.copyWith(color: selected ? Colors.white : Palette.ink, fontWeight: FontWeight.w600))),
          ),
        ),
      ),
    );
  }
}

class _TrackTile extends StatelessWidget {
  const _TrackTile({super.key, required this.label, required this.selected, required this.enabled, required this.onTap, this.note});

  final String label;
  final bool selected;
  final bool enabled;
  final String? note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kParentTap),
          child: Row(
            children: [
              Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded, color: selected ? primary : Palette.ink),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: ParentText.body)),
              if (note != null) Text(note!, style: ParentText.caption),
            ],
          ),
        ),
      ),
    );
  }
}
