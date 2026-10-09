import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/loading_action.dart';
import '../../core/palette.dart';
import '../content/content_repository.dart' show explorersEnabled;
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'onboarding_widgets.dart';
import '../../core/type.dart';

/// The first-launch screens as plain, fully controlled widgets (the answers and what happens next are passed in), so
/// each one can be shown and tested on its own. The flow that connects them lives in the onboarding controller.

// ---------------------------------------------------------------------------------------------------------- language
/// Step 1: two big options, each written in its own language. Shown only the first time.
class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key, required this.selected, required this.onSelect, required this.onContinue});

  /// `ar` or `en` (pre-selected from the phone's language).
  final String selected;
  final ValueChanged<String> onSelect;
  final LoadingCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final s = Strings.forCode(selected); // the screen already follows the choice (direction), before the parent confirms
    return OnboardingFrame(
      s: s,
      pose: DandoonaPose.waving,
      poseSize: 150,
      title: 'اختر لغتك\nChoose your language',
      // says what the choice is for: the parent area (the child's lessons are in English either way)
      subtitle: selected == 'ar' ? 'لغة واجهة ولي الأمر. سيتعلم طفلك باللغة الإنجليزية.' : 'The language of the parent area. Your child learns in English.',
      onContinue: onContinue,
      continueLabel: selected == 'ar' ? 'متابعة' : 'Continue',
      child: Column(
        children: [
          ChoiceCard(key: const Key('lang-ar'), title: 'العربية', titleStyle: parentSubtitle, titleWeight: FontWeight.w600, minHeight: 68, selected: selected == 'ar', onTap: () => onSelect('ar')),
          ChoiceCard(key: const Key('lang-en'), title: 'English', titleStyle: parentSubtitle, titleWeight: FontWeight.w600, minHeight: 68, selected: selected == 'en', onTap: () => onSelect('en')),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------------------- parent welcome
/// Step 2: start without an account (the default) or create / log in to one.
class ParentWelcomeScreen extends StatelessWidget {
  const ParentWelcomeScreen({super.key, required this.s, required this.withAccount, required this.onChoose, required this.onContinue, this.onBack});

  final Strings s;
  final bool withAccount;
  final ValueChanged<bool> onChoose;
  final LoadingCallback onContinue;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return OnboardingFrame(
      s: s,
      pose: DandoonaPose.jumping,
      poseSize: 150,
      title: s('obWelcomeTitle'),
      subtitle: s('obWelcomeBody'),
      onBack: onBack,
      onContinue: onContinue,
      child: Column(
        children: [
          ChoiceCard(
            key: const Key('welcome-no-account'),
            title: s('obNoAccount'),
            subtitle: s('obNoAccountSub'),
            leading: const _RoundIcon(Icons.phone_android_rounded, Palette.green),
            selected: !withAccount,
            onTap: () => onChoose(false),
          ),
          ChoiceCard(
            key: const Key('welcome-account'),
            title: s('obAccount'),
            subtitle: s('obAccountSub'),
            leading: const _RoundIcon(Icons.cloud_sync_rounded, Palette.blue),
            selected: withAccount,
            onTap: () => onChoose(true),
          ),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon(this.icon, this.color);
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Palette.white, size: 24),
      );
}

// ------------------------------------------------------------------------------------------------------- sign up / log in
/// Step 3 (only for parents who chose an account): sign up (email, password, optional first name, two required
/// checkboxes) or log in.
class AuthScreen extends StatelessWidget {
  const AuthScreen({
    super.key,
    required this.s,
    required this.signup,
    required this.email,
    required this.password,
    required this.firstName,
    required this.guardian,
    required this.agreed,
    required this.onToggleMode,
    required this.onEmail,
    required this.onPassword,
    required this.onFirstName,
    required this.onGuardian,
    required this.onAgreed,
    required this.onSubmit,
    this.onBack,
    this.busy = false,
    this.error,
    this.onPrivacy,
    this.onTerms,
    this.serverUrl,
    this.onServerUrl,
  });

  final Strings s;
  final bool signup;
  final String email, password, firstName;
  final bool guardian, agreed;
  final VoidCallback onToggleMode;
  final ValueChanged<String> onEmail, onPassword, onFirstName;
  final ValueChanged<bool> onGuardian, onAgreed;
  final LoadingCallback onSubmit;
  final VoidCallback? onBack;
  final bool busy;
  final String? error;

  /// Open the privacy policy / the terms (the links in the second checkbox).
  final VoidCallback? onPrivacy;
  final VoidCallback? onTerms;

  /// Only for development builds: the address of the server to talk to. Null hides the field.
  final String? serverUrl;
  final ValueChanged<String>? onServerUrl;

  bool get _valid => email.contains('@') && email.contains('.') && password.length >= 8 && (!signup || (guardian && agreed));

  @override
  Widget build(BuildContext context) {
    return OnboardingFrame(
      s: s,
      pose: signup ? DandoonaPose.pointingUp : DandoonaPose.thinking,
      poseSize: 120,
      title: s(signup ? 'obSignupTitle' : 'obLoginTitle'),
      onBack: onBack,
      onContinue: _valid && !busy ? onSubmit : null,
      continueLoading: busy,
      continueLabel: s(signup ? 'obCreate' : 'obLogin'),
      secondaryLabel: s(signup ? 'obHaveAccount' : 'obNoAccountYet'),
      onSecondary: onToggleMode,
      child: Column(
        children: [
          if (serverUrl != null) ...[
            _Field(key: const Key('auth-server'), label: s('serverUrl'), value: serverUrl!, onChanged: onServerUrl ?? (_) {}, keyboard: TextInputType.url),
            const SizedBox(height: 12),
          ],
          _Field(key: const Key('auth-email'), label: s('obEmail'), value: email, onChanged: onEmail, keyboard: TextInputType.emailAddress),
          const SizedBox(height: 12),
          _Field(key: const Key('auth-password'), label: s('obPassword'), value: password, onChanged: onPassword, obscure: true),
          if (signup) ...[
            const SizedBox(height: 12),
            _Field(key: const Key('auth-name'), label: s('obFirstName'), value: firstName, onChanged: onFirstName),
            const SizedBox(height: 8),
            _CheckRow(key: const Key('auth-guardian'), value: guardian, onChanged: onGuardian, child: Text(s('obGuardian'), style: _checkStyle)),
            _CheckRow(
              key: const Key('auth-agree'),
              value: agreed,
              onChanged: onAgreed,
              child: _AgreeText(s: s, onPrivacy: onPrivacy, onTerms: onTerms),
            ),
          ],
          if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: parentBody.copyWith(color: Palette.red))),
        ],
      ),
    );
  }
}

final _checkStyle = parentBody.copyWith(color: Palette.nightInk, height: 1.35);
final _linkStyle = _checkStyle.copyWith(color: Palette.plum, decoration: TextDecoration.underline, fontWeight: FontWeight.w800);

/// "I agree to the Privacy Policy and Terms" with both names as links.
class _AgreeText extends StatefulWidget {
  const _AgreeText({required this.s, this.onPrivacy, this.onTerms});

  final Strings s;
  final VoidCallback? onPrivacy;
  final VoidCallback? onTerms;

  @override
  State<_AgreeText> createState() => _AgreeTextState();
}

class _AgreeTextState extends State<_AgreeText> {
  late final TapGestureRecognizer _privacy = TapGestureRecognizer()..onTap = () => widget.onPrivacy?.call();
  late final TapGestureRecognizer _terms = TapGestureRecognizer()..onTap = () => widget.onTerms?.call();

  @override
  void dispose() {
    _privacy.dispose();
    _terms.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Text.rich(TextSpan(style: _checkStyle, children: [
      TextSpan(text: s('obAgreePre')),
      TextSpan(text: s('obPrivacy'), style: _linkStyle, recognizer: _privacy),
      TextSpan(text: s('obAnd')),
      TextSpan(text: s('obTerms'), style: _linkStyle, recognizer: _terms),
    ]));
  }
}

class _Field extends StatefulWidget {
  const _Field({super.key, required this.label, required this.value, required this.onChanged, this.obscure = false, this.keyboard});

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final bool obscure;
  final TextInputType? keyboard;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  late final TextEditingController _c = TextEditingController(text: widget.value);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      obscureText: widget.obscure,
      keyboardType: widget.keyboard,
      onChanged: widget.onChanged,
      style: parentSubtitle,
      decoration: InputDecoration(
        labelText: widget.label,
        filled: true,
        fillColor: Palette.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFE3D2ED), width: 1.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFE3D2ED), width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Palette.plum, width: 2)),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({super.key, required this.value, required this.onChanged, required this.child});

  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: kMinTapTarget * 0.8,
              height: kMinTapTarget * 0.8,
              child: Checkbox(value: value, activeColor: Palette.plum, onChanged: (v) => onChanged(v ?? false)),
            ),
            const SizedBox(width: 4),
            Expanded(child: Padding(padding: const EdgeInsets.only(top: 10), child: child)),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------------------------------------- 5.1 name
/// 5.1: the child's nickname (nothing else about them) and a drawn avatar.
class ChildNameScreen extends StatelessWidget {
  const ChildNameScreen({super.key, required this.s, required this.name, required this.avatarKey, required this.onName, required this.onAvatar, required this.onContinue, this.onBack, this.progress = 0.1});

  final Strings s;
  final String name;
  final String? avatarKey;
  final ValueChanged<String> onName;
  final ValueChanged<String> onAvatar;
  final LoadingCallback onContinue;
  final VoidCallback? onBack;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final ready = name.trim().isNotEmpty && name.trim().length <= 30 && avatarKey != null;
    return OnboardingFrame(
      s: s,
      pose: DandoonaPose.base,
      poseSize: 130,
      title: s('obNameTitle'),
      subtitle: s('obNameHint'),
      progress: progress,
      onBack: onBack,
      onContinue: ready ? onContinue : null,
      child: Column(
        children: [
          _Field(key: const Key('ob-name'), label: s('obNameLabel'), value: name, onChanged: onName),
          const SizedBox(height: 18),
          Text(s('obAvatarTitle'), style: parentSubtitle.copyWith(fontWeight: FontWeight.w800, color: Palette.nightInk)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              for (final a in AvatarOption.pickable)
                BigTap(
                  key: Key('avatar-${a.key}'),
                  semanticLabel: a.key,
                  onTap: () => onAvatar(a.key),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: avatarKey == a.key ? Palette.plum : Colors.transparent, width: 3)),
                    child: AvatarCircle(a.key, size: 64),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------------------------ 5.2 age
/// 5.2: birth month and year. The track follows from the age ([trackLabel] comes from the track resolver).
class ChildAgeScreen extends StatelessWidget {
  const ChildAgeScreen({super.key, required this.s, required this.month, required this.year, required this.years, required this.onMonth, required this.onYear, required this.onContinue, this.trackLabel, this.onBack, this.progress = 0.3});

  final Strings s;
  final int? month;
  final int? year;
  final List<int> years;
  final ValueChanged<int> onMonth;
  final ValueChanged<int> onYear;
  final String? trackLabel;
  final LoadingCallback onContinue;
  final VoidCallback? onBack;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return OnboardingFrame(
      s: s,
      pose: DandoonaPose.thinking,
      poseSize: 140,
      title: s('obAgeTitle'),
      progress: progress,
      onBack: onBack,
      onContinue: month != null && year != null ? onContinue : null,
      child: Column(
        children: [
          _Picker<int>(
            key: const Key('ob-month'),
            label: s('obMonth'),
            value: month,
            items: {for (var m = 1; m <= 12; m++) m: s('obMonth$m')},
            onChanged: onMonth,
          ),
          const SizedBox(height: 12),
          _Picker<int>(key: const Key('ob-year'), label: s('obYear'), value: year, items: {for (final y in years) y: '$y'}, onChanged: onYear),
          if (trackLabel != null && month != null && year != null) ...[
            const SizedBox(height: 16),
            Container(
              key: const Key('ob-track'),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFE9F6E2), borderRadius: BorderRadius.circular(20), border: Border.all(color: Palette.green, width: 3)),
              child: Row(
                children: [
                  const Icon(Icons.route_rounded, color: Palette.darkGreen, size: 30),
                  const SizedBox(width: 10),
                  Expanded(child: Text('${s('obTrackFor')} $trackLabel', style: parentBody.copyWith(fontWeight: FontWeight.w800, color: Palette.nightInk))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Picker<T> extends StatelessWidget {
  const _Picker({super.key, required this.label, required this.value, required this.items, required this.onChanged});

  final String label;
  final T? value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
      style: DefaultTextStyle.of(context).style.merge(parentSubtitle).copyWith(color: Palette.nightInk),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Palette.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFE3D2ED), width: 1.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFE3D2ED), width: 1.5)),
      ),
      items: [for (final e in items.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

// ---------------------------------------------------------------------------------------------------------- 5.3 level
/// 5.3: how much English the child knows, in parent-friendly words (the starting unit comes from the placement config).
class ChildLevelScreen extends StatelessWidget {
  const ChildLevelScreen({super.key, required this.s, required this.level, required this.onLevel, required this.onContinue, this.onBack, this.progress = 0.5});

  final Strings s;
  final int? level;
  final ValueChanged<int> onLevel;
  final LoadingCallback onContinue;
  final VoidCallback? onBack;
  final double progress;

  static const _icons = [Icons.child_care_rounded, Icons.abc_rounded, Icons.sort_by_alpha_rounded, Icons.menu_book_rounded];

  @override
  Widget build(BuildContext context) {
    return OnboardingFrame(
      s: s,
      pose: DandoonaPose.pointingUp,
      accessory: 'glasses',
      poseSize: 130,
      title: s('obLevelTitle'),
      progress: progress,
      onBack: onBack,
      onContinue: level == null ? null : onContinue,
      child: Column(
        children: [
          for (var i = 0; i < 4; i++)
            ChoiceCard(
              key: Key('level-$i'),
              title: s('obLevel$i'),
              leading: _RoundIcon(_icons[i], Palette.nodeColors[(i * 2 + 1) % Palette.nodeColors.length]),
              selected: level == i,
              onTap: () => onLevel(i),
            ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------------------------------------- 5.4 goal
/// 5.4: the daily goal in minutes (it becomes the session timer).
class DailyGoalScreen extends StatelessWidget {
  const DailyGoalScreen({super.key, required this.s, required this.minutes, required this.onMinutes, required this.onContinue, this.onBack, this.progress = 0.7});

  final Strings s;
  final int? minutes;
  final ValueChanged<int> onMinutes;
  final LoadingCallback onContinue;
  final VoidCallback? onBack;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return OnboardingFrame(
      s: s,
      pose: DandoonaPose.clapping,
      poseSize: 140,
      title: s('obGoalTitle'),
      subtitle: s('obGoalHint'),
      progress: progress,
      onBack: onBack,
      onContinue: minutes == null ? null : onContinue,
      child: Column(
        children: [
          for (final m in const [5, 10, 15])
            ChoiceCard(
              key: Key('goal-$m'),
              title: s('obGoal$m'),
              subtitle: s('obGoal${m}Sub'),
              leading: _RoundIcon(Icons.timer_rounded, m == 5 ? Palette.teal : (m == 10 ? Palette.orange : Palette.pink)),
              selected: minutes == m,
              onTap: () => onMinutes(m),
            ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------------------------------- 5.5 reminders
/// 5.5: a daily reminder on this phone (no push service). The notification permission is asked only when the parent taps
/// "Remind me", never before.
class ReminderScreen extends StatelessWidget {
  const ReminderScreen({super.key, required this.s, required this.time, required this.onTime, required this.onRemind, required this.onLater, this.onBack, this.progress = 0.9});

  /// `morning`, `afternoon`, `evening` or null.
  final String? time;
  final Strings s;
  final ValueChanged<String> onTime;
  final LoadingCallback onRemind;
  final LoadingCallback onLater;
  final VoidCallback? onBack;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return OnboardingFrame(
      s: s,
      pose: DandoonaPose.waving,
      poseSize: 130,
      title: s('obRemindTitle'),
      subtitle: s('obRemindBody'),
      progress: progress,
      onBack: onBack,
      continueLabel: s('obRemindMe'),
      onContinue: time == null ? null : onRemind,
      secondaryLabel: s('obRemindLater'),
      onSecondary: onLater,
      child: Column(
        children: [
          for (final t in const ['morning', 'afternoon', 'evening'])
            ChoiceCard(
              key: Key('time-$t'),
              title: s('obTime${t[0].toUpperCase()}${t.substring(1)}'),
              leading: _RoundIcon(t == 'morning' ? Icons.wb_sunny_rounded : (t == 'afternoon' ? Icons.wb_twilight_rounded : Icons.nightlight_round), t == 'morning' ? Palette.orange : (t == 'afternoon' ? Palette.teal : Palette.purple)),
              selected: time == t,
              onTap: () => onTime(t),
            ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------------------------------------------- 6 summary
class SummaryRow {
  const SummaryRow({required this.keyName, required this.label, required this.value, required this.icon, required this.color});
  final String keyName;
  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

/// 6: "[Name]'s path is ready!" with the track, the starting unit and the daily goal; each row goes back to edit.
class SummaryScreen extends StatelessWidget {
  const SummaryScreen({super.key, required this.s, required this.name, required this.rows, required this.onEdit, required this.onStart, this.onBack});

  final Strings s;
  final String name;
  final List<SummaryRow> rows;
  final ValueChanged<String> onEdit;
  final LoadingCallback onStart;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return OnboardingFrame(
      s: s,
      pose: DandoonaPose.clapping,
      accessory: 'party-hat',
      poseSize: 150,
      title: s('obPathReady').replaceAll('{name}', name),
      progress: 1,
      onBack: onBack,
      onContinue: onStart,
      continueLabel: s('obStartLearning'),
      child: Column(
        children: [
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                key: Key('summary-${r.keyName}'),
                onTap: () => onEdit(r.keyName),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 80),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: Palette.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFDDD5E5), width: 1.5)),
                  child: Row(
                    children: [
                      _RoundIcon(r.icon, r.color),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.label, style: parentCaption.copyWith(color: Palette.brown)),
                            const SizedBox(height: 4),
                            Text(r.value, style: parentSubtitle.copyWith(fontWeight: FontWeight.w800, color: Palette.nightInk)),
                          ],
                        ),
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(color: Color(0xFFF1E7FA), shape: BoxShape.circle),
                        child: const Icon(Icons.edit_rounded, color: Palette.plum, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------------------------------------- 7 child greeting
/// 7: Dandoona greets the child in English (the child area is always English and left-to-right).
class ChildGreetingScreen extends StatelessWidget {
  const ChildGreetingScreen({super.key, required this.name, required this.onGo});

  final String name;
  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) {
    final s = Strings.en;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFBDE6FA), Color(0xFFE9F6FB), Palette.cream])),
          child: SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),
                const DandoonaView(pose: DandoonaPose.jumping, size: 260),
                const SizedBox(height: 10),
                Text('${s('hi')}, $name!', key: const Key('greeting-name'), style: parentStat.copyWith(fontWeight: FontWeight.w900, color: Palette.nightInk)),
                const SizedBox(height: 4),
                Text(s('obGreetIam'), style: parentStat.copyWith(fontWeight: FontWeight.w800, color: Palette.plum)),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Text(s('obGreetLets'), textAlign: TextAlign.center, style: parentTitle.copyWith(color: Palette.nightInk)),
                ),
                const Spacer(flex: 2),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const Key('greeting-go'),
                      style: FilledButton.styleFrom(backgroundColor: Palette.green, minimumSize: const Size.fromHeight(kMinTapTarget * 1.2)),
                      onPressed: onGo,
                      child: Text(s('obLetsGo'), style: parentStat.copyWith(fontWeight: FontWeight.w900)),
                    ),
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

// ----------------------------------------------------------------------------------------------------------- track
/// The track, chosen from the age; the parent may change it here (from the summary). Little Learners 3-5, Explorers 6-8.
class ChildTrackScreen extends StatelessWidget {
  const ChildTrackScreen({super.key, required this.s, required this.track, required this.onTrack, required this.onContinue, this.onBack});

  final Strings s;
  final String track;
  final ValueChanged<String> onTrack;
  final LoadingCallback onContinue;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return OnboardingFrame(
      s: s,
      pose: DandoonaPose.pointingUp,
      poseSize: 130,
      title: s('obTrackTitle'),
      progress: 1,
      onBack: onBack,
      onContinue: onContinue,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(s('obTrackAuto'), textAlign: TextAlign.center, style: parentBody.copyWith(color: Palette.ink)),
          ),
          for (final (id, label, icon, color) in [
            ('little-learners', 'obTrackLL', Icons.child_care_rounded, Palette.green),
            if (explorersEnabled) ('explorers', 'obTrackExplorers', Icons.explore_rounded, Palette.blue),
          ])
            ChoiceCard(
              key: Key('track-$id'),
              title: s(label),
              leading: _RoundIcon(icon, color),
              selected: track == id,
              onTap: () => onTrack(id),
            ),
        ],
      ),
    );
  }
}
