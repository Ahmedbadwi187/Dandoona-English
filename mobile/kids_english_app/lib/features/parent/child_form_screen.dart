import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/palette.dart';
import '../../core/widgets.dart';
import '../profiles/child_profile.dart';
import '../settings/settings.dart';

/// Create or edit a child profile. [childId] null = create. [firstRun] = part of onboarding.
class ChildFormScreen extends ConsumerStatefulWidget {
  const ChildFormScreen({super.key, this.childId, this.firstRun = false});

  final String? childId;
  final bool firstRun;

  @override
  ConsumerState<ChildFormScreen> createState() => _ChildFormScreenState();
}

class _ChildFormScreenState extends ConsumerState<ChildFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late int _birthYear;
  late String _avatar;

  @override
  void initState() {
    super.initState();
    final now = ref.read(clockProvider)();
    final existing = widget.childId == null
        ? null
        : ref.read(profilesProvider).where((p) => p.id == widget.childId).firstOrNull;
    _name = TextEditingController(text: existing?.name ?? '');
    _birthYear = existing?.birthYear ?? now.year - 4; // 3-5 track default
    _avatar = existing?.avatarKey ?? AvatarOption.all.first.key;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final profiles = ref.read(profilesProvider.notifier);
    if (widget.childId == null) {
      await profiles.add(name: _name.text, avatarKey: _avatar, birthYear: _birthYear);
    } else {
      await profiles.update(widget.childId!, name: _name.text, avatarKey: _avatar, birthYear: _birthYear);
    }
    if (!mounted) return;
    if (widget.firstRun) {
      await ref.read(settingsProvider.notifier).completeOnboarding();
      if (mounted) context.go('/who');
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final now = ref.read(clockProvider)();
    final years = [for (var y = now.year - 2; y >= now.year - 13; y--) y];

    return Scaffold(
      appBar: AppBar(title: Text(widget.childId == null ? s('addChild') : s('editChild'))),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      key: const Key('child-name'),
                      controller: _name,
                      maxLength: ChildValidation.maxName,
                      decoration: InputDecoration(labelText: s('childName'), helperText: s('nameHint')),
                      validator: (v) => ChildValidation.name(v) == null ? null : s(ChildValidation.name(v)!),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      key: const Key('child-birth-year'),
                      initialValue: _birthYear,
                      decoration: InputDecoration(labelText: s('birthYear')),
                      items: [for (final y in years) DropdownMenuItem(value: y, child: Text('$y'))],
                      onChanged: (v) => setState(() => _birthYear = v ?? _birthYear),
                      validator: (v) =>
                          ChildValidation.birthYear(v, now) == null ? null : s(ChildValidation.birthYear(v, now)!),
                    ),
                    const SizedBox(height: 20),
                    Text(s('chooseAvatar'), style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final a in AvatarOption.all)
                          InkResponse(
                            key: Key('avatar-${a.key}'),
                            onTap: () => setState(() => _avatar = a.key),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: _avatar == a.key ? Palette.ink : Colors.transparent, width: 4),
                              ),
                              child: AvatarCircle(a.key, size: 64),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    FilledButton(key: const Key('child-save'), onPressed: _save, child: Text(s('save'))),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
