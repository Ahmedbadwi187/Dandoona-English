import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/palette.dart';
import '../../core/strings.dart';
import '../../core/type.dart';
import 'skills.dart';

const _icons = <String, IconData>{
  'colors': Icons.palette_rounded,
  'counting': Icons.looks_one_rounded,
  'animals': Icons.pets_rounded,
  'everyday-words': Icons.forum_rounded,
  'some-letters': Icons.abc_rounded,
  'all-letters': Icons.sort_by_alpha_rounded,
  'letter-sounds': Icons.graphic_eq_rounded,
  'reads-words': Icons.menu_book_rounded,
  'reads-sentences': Icons.chrome_reader_mode_rounded,
  'writes-sentences': Icons.edit_rounded,
  'basic-grammar': Icons.rule_rounded,
  'understands-spoken': Icons.hearing_rounded,
  'talks-about-self': Icons.record_voice_over_rounded,
  skillNone: Icons.child_care_rounded,
  skillUnsure: Icons.help_outline_rounded,
};

const _groupColors = <String, Color>{
  'words': Palette.orange,
  'letters': Palette.green,
  'reading': Palette.blue,
  'speaking': Palette.pink,
};

/// The multi-select list of "What can your child already do?": checkboxes in rounded cards, grouped under small headers (easiest to hardest),
/// then the two exclusive answers. The rules (implied skills, exclusive answers) come from [config]. Checking a skill checks the easier
/// ones it implies, and those rows pulse for a moment so the parent sees it happen; the parent can uncheck them.
class SkillsChecklist extends StatefulWidget {
  const SkillsChecklist({super.key, required this.s, required this.config, required this.selected, required this.onChanged});

  final Strings s;
  final SkillsConfig config;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  State<SkillsChecklist> createState() => _SkillsChecklistState();
}

class _SkillsChecklistState extends State<SkillsChecklist> {
  Set<String> _pulse = const {};
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tap(String id) {
    final t = toggleSkill(widget.config, widget.selected, id);
    widget.onChanged(t.skills);
    if (t.autoChecked.isEmpty) return;
    _timer?.cancel();
    setState(() => _pulse = t.autoChecked);
    _timer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _pulse = const {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final g in widget.config.groups) ...[
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, top: 6, bottom: 8),
            child: Text(s('skGroup_${g.id}'), key: Key('skills-group-${g.id}'), style: parentCaption.copyWith(fontWeight: FontWeight.w800, color: Palette.brown, letterSpacing: 0.3)),
          ),
          for (final id in g.skills) _SkillRow(key: Key('skill-$id'), id: id, label: s('sk_$id'), color: _groupColors[g.id] ?? Palette.plum, checked: widget.selected.contains(id), pulse: _pulse.contains(id), onTap: () => _tap(id)),
        ],
        const SizedBox(height: 6),
        for (final id in widget.config.exclusive)
          _SkillRow(key: Key('skill-$id'), id: id, label: s('sk_$id'), color: Palette.purple, checked: widget.selected.contains(id), pulse: false, onTap: () => _tap(id)),
      ],
    );
  }
}

class _SkillRow extends StatelessWidget {
  const _SkillRow({super.key, required this.id, required this.label, required this.color, required this.checked, required this.pulse, required this.onTap});

  final String id;
  final String label;
  final Color color;
  final bool checked;
  final bool pulse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        checked: checked,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: pulse ? const Color(0xFFFFF3CF) : (checked ? const Color(0xFFF1E7FA) : Palette.white),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: pulse ? Palette.sunflower : (checked ? Palette.plum : const Color(0xFFDDD5E5)), width: checked || pulse ? 2 : 1.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  child: Icon(_icons[id] ?? Icons.star_rounded, color: Palette.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(label, style: parentBody.copyWith(fontWeight: FontWeight.w700, color: Palette.nightInk, height: 1.25))),
                const SizedBox(width: 8),
                AnimatedScale(
                  scale: pulse ? 1.35 : 1,
                  duration: const Duration(milliseconds: 360),
                  curve: Curves.elasticOut,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: checked ? Palette.plum : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: checked ? Palette.plum : const Color(0xFFBDB3CB), width: 2),
                    ),
                    child: checked ? const Icon(Icons.check_rounded, size: 20, color: Palette.white) : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
