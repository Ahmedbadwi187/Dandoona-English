import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/palette.dart';
import '../../core/strings.dart';
import '../../core/loading_action.dart';
import '../../core/widgets.dart';
import '../content/content_repository.dart';
import '../onboarding/setup_flow.dart';
import '../progress/progress.dart';
import '../skills/skills.dart';
import '../skills/skip_ahead.dart';
import '../skills/skills_checklist.dart';
import '../units/unit_logic.dart';
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

  /// What the parent says the child can do (the same list as in the setup).
  late Set<String> _skills;
  bool _leave = false; // saved, discarded or deleted: leaving needs no question
  bool _working = false;
  bool _discarding = false;

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
    _skills = {...?_child.skills};
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
      !_sameSet(_skills, _child.skills ?? const {});

  static bool _sameSet(Set<String> a, Set<String> b) => a.length == b.length && a.containsAll(b);

  Future<void> _runAction(LoadingCallback action) async {
    if (_working || _discarding) return;
    setState(() => _working = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _save() async {
    final s = ref.read(stringsProvider);
    final settings = ref.read(settingsProvider.notifier);
    await ref.read(profilesProvider.notifier).update(_child.id, name: _name.text, avatarKey: _avatar, birthYear: _year, birthMonth: _month, goalMinutes: _goal, track: _track, skills: _skills);
    // The skills decide which units count as done by placement. Units the child really played keep their stars and status; only marks
    // on units never played can go away; unlocked chests stay unlocked.
    final config = await ref.read(skillsConfigProvider.future);
    final content = await ref.read(trackContentProvider(_track).future);
    final meta = ref.read(unitMetaProvider);
    final progress = ref.read(progressProvider.notifier);
    final unitIds = [for (final u in content.units) u.id];
    final plan = placementFor(config: config, track: _track, skills: _skills, unitIds: unitIds);
    final played = {for (final u in content.units) if (u.lessonIds.any((l) => progress.hasProgress(_child.id, l))) u.id};
    await ref.read(unitMetaProvider.notifier).setPlaced(_child.id, placedAfterEdit(oldPlaced: meta.of(_child.id).placed, trackUnitIds: unitIds, playedUnits: played, plan: plan.doneUnits));
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

  Future<void> _back() async {
    if (_working || _discarding) return;
    if (_dirty && !_leave) {
      await _confirmDiscard();
    } else {
      await Navigator.of(context).maybePop();
    }
  }

  Future<void> _confirmDiscard() async {
    if (_working || _discarding || _leave) return;
    setState(() => _discarding = true);
    try {
      if (await _askDiscard() && mounted) {
        setState(() => _leave = true);
        _close();
      }
    } finally {
      if (mounted) setState(() => _discarding = false);
    }
  }

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

  /// "3 of 15 units": the units finished (or counted as done by placement) in one track.
  String? _trackProgress(Strings s, String track) {
    final content = ref.watch(trackContentProvider(track)).asData?.value;
    if (content == null) return null;
    ref.watch(progressProvider);
    final progress = ref.read(progressProvider.notifier);
    final placed = ref.watch(unitMetaProvider).of(_child.id).placed;
    final real = content.units.where((u) => u.lessonIds.isNotEmpty).toList();
    final done = real.where((u) => placed.contains(u.id) || isUnitFinished(u, (l) => progress.hasProgress(_child.id, l))).length;
    return s.format('pUnitsOfN', {'done': done, 'total': real.length});
  }

  /// The parent switches the active track: a short confirmation first. Progress in every track is kept.
  Future<void> _switchTrack(String track, String nameKey) async {
    if (track == _track) return;
    final s = ref.read(stringsProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: s.direction,
        child: AlertDialog(
          key: const Key('switch-track-dialog'),
          title: Text(s.format('pSwitchTrackTitle', {'name': _child.name, 'track': s(nameKey)})),
          content: Text(s('pSwitchTrackBody')),
          actions: [
            TextButton(key: const Key('switch-track-cancel'), autofocus: true, onPressed: () => Navigator.pop(ctx, false), child: Text(s('cancel'))),
            TextButton(key: const Key('switch-track-confirm'), onPressed: () => Navigator.pop(ctx, true), child: Text(s('pSwitch'))),
          ],
        ),
      ),
    );
    if (ok == true && mounted) setState(() => _track = track);
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
    final lang = ref.watch(settingsProvider).languageCode;
    final config = ref.watch(skillsConfigProvider).asData?.value;
    final primary = Theme.of(context).colorScheme.primary;

    return PopScope(
      canPop: !_dirty || _leave,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _confirmDiscard();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
                child: Row(
                  children: [
                    ParentBack(onPressed: _working ? null : _back, loading: _discarding),
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ParentCard(
                      key: const Key('edit-skills'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s('pSkillsTitle'), style: ParentText.section),
                          const SizedBox(height: 4),
                          Text(s('obSkillsHint'), style: ParentText.caption),
                          const SizedBox(height: 10),
                          if (config == null)
                            const Center(child: CircularProgressIndicator())
                          else ...[
                            SkillsChecklist(s: s, config: config, selected: _skills, onChanged: (v) => setState(() => _skills = v)),
                            _SkillsPreview(s: s, config: config, track: _track, skills: _skills, name: _name.text.trim().isEmpty ? _child.name : _name.text.trim(), lang: lang),
                            if (_skills.contains(skillUnsure) || ref.watch(skipAheadProvider)[_child.id]?.off == true)
                              SwitchListTile(
                                key: const Key('skip-suggestions'),
                                contentPadding: EdgeInsets.zero,
                                title: Text(s('pSkipSuggestions'), style: ParentText.body),
                                subtitle: Text(s('pSkipSuggestionsHint'), style: ParentText.caption),
                                value: ref.watch(skipAheadProvider)[_child.id]?.off != true,
                                onChanged: (on) => on ? ref.read(skipAheadProvider.notifier).turnOn(_child.id) : ref.read(skipAheadProvider.notifier).turnOff(_child.id),
                              ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ParentCard(
                      key: const Key('edit-tracks'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s('pTrack'), style: ParentText.section),
                          const SizedBox(height: 4),
                          Text(s('pTracksHint'), style: ParentText.caption),
                          const SizedBox(height: 8),
                          for (final t in [('little-learners', 'pTrackLL', true), ('explorers', 'pTrackExplorers', explorersEnabled), ('champions', 'pTrackChampions', false)])
                            _TrackTile(
                              key: Key('edit-track-${t.$1}'),
                              label: s(t.$2),
                              selected: _track == t.$1,
                              enabled: t.$3,
                              badge: _track == t.$1 && t.$3 ? s('pActiveTrack') : null,
                              note: !t.$3 ? s('pSoon') : _trackProgress(s, t.$1),
                              onTap: () => _switchTrack(t.$1, t.$2),
                            ),
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
                    const SizedBox(height: 8),
                    TextButton(
                      key: const Key('rerun-setup'),
                      style: TextButton.styleFrom(minimumSize: const Size.fromHeight(kParentTap)),
                      onPressed: _working || _discarding ? null : () => startChildSetup(context, ref, childId: _child.id, returnTo: '/parent/children/${_child.id}'),
                      child: Text(s('pRerunSetup')),
                    ),
                    const SizedBox(height: 24),
                    const Divider(color: parentBorder),
                    const SizedBox(height: 8),
                    LoadingAction(
                      onPressed: _working || _discarding ? null : () => _runAction(_delete),
                      builder: (onPressed, loading) => TextButton.icon(
                        key: const Key('edit-delete'),
                        style: TextButton.styleFrom(foregroundColor: Palette.red, minimumSize: const Size.fromHeight(kParentTap)),
                        onPressed: onPressed,
                        icon: LoadingContent(loading: loading, child: const Icon(Icons.delete_outline_rounded)),
                        label: Text(s('pDeleteChild')),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: LoadingAction(
                  onPressed: _dirty && _valid && !_working && !_discarding ? () => _runAction(_save) : null,
                  builder: (onPressed, loading) => FilledButton(
                    key: const Key('edit-save'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                    onPressed: onPressed,
                    child: LoadingContent(loading: loading, child: Text(s('save'))),
                  ),
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
  const _TrackTile({super.key, required this.label, required this.selected, required this.enabled, required this.onTap, this.note, this.badge});

  final String label;
  final bool selected;
  final bool enabled;
  final String? note;
  final String? badge;
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
              Expanded(child: Text(label, style: ParentText.body.copyWith(fontWeight: selected ? FontWeight.w800 : FontWeight.w400))),
              if (badge != null)
                Container(
                  margin: const EdgeInsetsDirectional.only(start: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: Text(badge!, style: ParentText.caption.copyWith(color: primary, fontWeight: FontWeight.w800)),
                ),
              if (note != null) Flexible(child: Padding(padding: const EdgeInsetsDirectional.only(start: 8), child: Text(note!, style: ParentText.caption))),
            ],
          ),
        ),
      ),
    );
  }
}

/// What saving the skills will do, in one or two sentences ("Colors and Numbers will be marked as done. Sara will continue from Shapes.").
class _SkillsPreview extends ConsumerWidget {
  const _SkillsPreview({required this.s, required this.config, required this.track, required this.skills, required this.name, required this.lang});

  final Strings s;
  final SkillsConfig config;
  final String track;
  final Set<String> skills;
  final String name;
  final String lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(trackContentProvider(track)).asData?.value;
    if (content == null || skills.isEmpty) return const SizedBox.shrink();
    final plan = placementFor(config: config, track: track, skills: skills, unitIds: [for (final u in content.units) u.id]);
    String title(String id) => content.unitById(id)?.titleFor(lang) ?? id;
    final start = plan.startUnit == null ? '' : title(plan.startUnit!);
    final text = plan.doneUnits.isEmpty
        ? s.format('pPreviewNone', {'name': name, 'start': start})
        : s.format('pPreviewDone', {'units': plan.doneUnits.map(title).join(s('pListJoin')), 'name': name, 'start': start});
    return Container(
      key: const Key('skills-preview'),
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF1E7FA), borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 20, color: Palette.plum),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: ParentText.body.copyWith(height: 1.35))),
        ],
      ),
    );
  }
}
