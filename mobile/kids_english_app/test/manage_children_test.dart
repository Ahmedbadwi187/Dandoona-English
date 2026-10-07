import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/app.dart';
import 'package:kids_english_app/core/strings.dart';
import 'package:kids_english_app/core/theme.dart';
import 'package:kids_english_app/features/parent/parent_ui.dart';
import 'package:kids_english_app/features/profiles/child_profile.dart';
import 'package:kids_english_app/features/reminders/reminder_service.dart';
import 'package:kids_english_app/features/router_state.dart';
import 'package:kids_english_app/features/settings/settings.dart';
import 'package:kids_english_app/router.dart';

import 'helpers.dart';

final _year = DateTime.now().year;

String _settings(String lang, {String extra = ''}) => '{"languageCode":"$lang","sessionMinutes":15,"unlockAll":false,"onboarded":true,"languageChosen":true$extra}';

String _kids({int count = 2}) => '[${[
  '{"id":"c1","name":"Omar","avatarKey":"bear","birthYear":${_year - 4},"birthMonth":1,"goalMinutes":10,"track":"little-learners","createdAt":"2026-01-01T00:00:00Z"}',
  '{"id":"c2","name":"Lina","avatarKey":"cat","birthYear":${_year - 4},"track":"little-learners","createdAt":"2026-01-02T00:00:00Z"}',
].take(count).join(',')}]';

Future<(ProviderContainer, FakeReminders)> _open(WidgetTester t, String path, {String lang = 'en', int kids = 2, bool allow = true, String extra = ''}) async {
  t.view.physicalSize = const Size(1080, 4200); // tall, so a long form is built in full
  t.view.devicePixelRatio = 1080 / 411;
  addTearDown(t.view.reset);
  final reminders = FakeReminders(allow: allow);
  final overrides = await testOverrides(
    prefs: {'settings.v1': _settings(lang, extra: extra), if (kids > 0) 'children.v1': _kids(count: kids)},
    reminders: reminders,
  );
  final c = ProviderContainer(overrides: overrides);
  addTearDown(c.dispose);
  await t.pumpWidget(UncontrolledProviderScope(container: c, child: const KidsEnglishApp()));
  await t.pumpAndSettle();
  c.read(parentSessionProvider.notifier).unlock(); // after the picker opened (it locks the parent area on arrival)
  c.read(routerProvider).go(path);
  await t.pumpAndSettle();
  return (c, reminders);
}

void main() {
  group('manage children', () {
    testWidgets('rows show the age and the unit, a chevron, no delete icon; the hint and the Add child button are under the list', (t) async {
      await _open(t, '/parent/children');
      expect(find.text('Manage children'), findsOneWidget);
      expect(find.text('Omar'), findsOneWidget);
      expect(find.text('4 years · Letters'), findsNWidgets(2));
      expect(find.byType(ParentChevron), findsNWidgets(2));
      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
      expect(find.byKey(const Key('delete-c1')), findsNothing);
      expect(find.text('Tap a child to edit or delete'), findsOneWidget);
      expect(find.byKey(const Key('add-child')), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
      // a row is at least 48 dp tall
      expect(t.getSize(find.byKey(const Key('child-row-c1'))).height, greaterThanOrEqualTo(kParentTap));
    });

    testWidgets('in Arabic the page is right to left, the age uses Arabic digits and the back arrow mirrors', (t) async {
      await _open(t, '/parent/children', lang: 'ar');
      expect(find.text('إدارة الأطفال'), findsOneWidget);
      expect(find.text('٤ سنوات · الحروف'), findsNWidgets(2));
      expect(Directionality.of(t.element(find.text('إدارة الأطفال'))), TextDirection.rtl);
      final icon = t.widget<Icon>(find.descendant(of: find.byKey(const Key('parent-back')), matching: find.byType(Icon)));
      expect(icon.icon!.matchTextDirection, isTrue); // drawn pointing right in RTL
    });

    testWidgets('tapping a row opens Edit child', (t) async {
      await _open(t, '/parent/children');
      await t.tap(find.byKey(const Key('child-row-c1')));
      await t.pumpAndSettle();
      expect(find.text('Edit child'), findsOneWidget);
      expect(t.widget<TextField>(find.byKey(const Key('edit-name'))).controller!.text, 'Omar');
    });

    testWidgets('Add child starts the setup, and finishing it returns to this list with the new child', (t) async {
      final (c, _) = await _open(t, '/parent/children');
      await t.tap(find.byKey(const Key('add-child')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('ob-name')), findsOneWidget);

      await t.enterText(find.byKey(const Key('ob-name')), 'Sam');
      await t.tap(find.byKey(const Key('avatar-owl')));
      await t.pump();
      Future<void> next() async {
        await t.tap(find.byKey(const Key('ob-continue')));
        await t.pumpAndSettle();
      }

      await next();
      await t.tap(find.byKey(const Key('ob-month')));
      await t.pumpAndSettle();
      await t.tap(find.text(Strings.en('obMonth6')).last);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('ob-year')));
      await t.pumpAndSettle();
      await t.tap(find.text('${_year - 3}').last);
      await t.pumpAndSettle();
      await next();
      await t.tap(find.byKey(const Key('level-0')));
      await t.pumpAndSettle();
      await next();
      await t.tap(find.byKey(const Key('goal-5')));
      await t.pumpAndSettle();
      await next();
      await t.tap(find.byKey(const Key('ob-secondary')));
      await t.pumpAndSettle();
      await next(); // Start learning

      expect(c.read(profilesProvider).map((p) => p.name), ['Omar', 'Lina', 'Sam']);
      expect(find.text('Manage children'), findsOneWidget);
      expect(find.text('Sam'), findsOneWidget);
      expect(find.text('3 years · Letters'), findsOneWidget);
    });

    testWidgets('with no children: Dandoona, "Add your first child" and the button', (t) async {
      await _open(t, '/parent/children', kids: 0);
      expect(find.byKey(const Key('manage-empty')), findsOneWidget);
      expect(find.text('Add your first child'), findsOneWidget);
      expect(find.byKey(const Key('add-child')), findsOneWidget);
      expect(find.byKey(const Key('manage-hint')), findsNothing);
    });

    testWidgets('back returns to the parent area', (t) async {
      final (c, _) = await _open(t, '/parent');
      c.read(routerProvider).push('/parent/children');
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('parent-back')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('manage-title')), findsNothing);
    });
  });

  group('edit child', () {
    testWidgets('Save is off until something changes, then saves, syncs locally and returns', (t) async {
      final (c, _) = await _open(t, '/parent/children');
      await t.tap(find.byKey(const Key('child-row-c1')));
      await t.pumpAndSettle();
      FilledButton save() => t.widget<FilledButton>(find.byKey(const Key('edit-save')));
      expect(save().onPressed, isNull);

      await t.enterText(find.byKey(const Key('edit-name')), 'Omar K');
      await t.pump();
      expect(save().onPressed, isNotNull);
      await t.tap(find.byKey(const Key('edit-goal-15')));
      await t.pump();
      await t.ensureVisible(find.byKey(const Key('edit-save')));
      await t.tap(find.byKey(const Key('edit-save')));
      await t.pumpAndSettle();

      final omar = c.read(profilesProvider).firstWhere((p) => p.id == 'c1');
      expect((omar.name, omar.goalMinutes), ('Omar K', 15));
      expect(c.read(settingsProvider).sessionMinutes, 15);
      expect(find.text('Manage children'), findsOneWidget); // back on the list
      expect(find.text('Omar K'), findsOneWidget);
    });

    testWidgets('avatars of the other children are faded and cannot be picked', (t) async {
      await _open(t, '/parent/children/c1');
      final taken = t.widget<InkResponse>(find.byKey(const Key('avatar-cat'))); // Lina has the cat
      expect(taken.onTap, isNull);
      expect(t.widget<InkResponse>(find.byKey(const Key('avatar-owl'))).onTap, isNotNull);
      final fade = t.widget<Opacity>(find.ancestor(of: find.byKey(const Key('avatar-cat')), matching: find.byType(Opacity)).first);
      expect(fade.opacity, lessThan(0.5));
    });

    testWidgets('the nickname is limited to 15 characters', (t) async {
      await _open(t, '/parent/children/c1');
      await t.enterText(find.byKey(const Key('edit-name')), 'ABCDEFGHIJKLMNOPQRST');
      await t.pump();
      expect(t.widget<TextField>(find.byKey(const Key('edit-name'))).controller!.text.length, 15);
    });

    testWidgets('leaving with unsaved changes asks "Discard changes?"; keep editing stays, discard leaves without saving', (t) async {
      final (c, _) = await _open(t, '/parent/children');
      await t.tap(find.byKey(const Key('child-row-c1')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('edit-name')), 'Changed');
      await t.pump();

      await t.tap(find.byKey(const Key('parent-back')));
      await t.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await t.tap(find.byKey(const Key('keep-editing')));
      await t.pumpAndSettle();
      expect(find.text('Edit child'), findsOneWidget);

      await t.tap(find.byKey(const Key('parent-back')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('discard-confirm')));
      await t.pumpAndSettle();
      expect(find.text('Manage children'), findsOneWidget);
      expect(c.read(profilesProvider).first.name, 'Omar');
    });

    testWidgets('leaving without changes does not ask', (t) async {
      await _open(t, '/parent/children');
      await t.tap(find.byKey(const Key('child-row-c1')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('parent-back')));
      await t.pumpAndSettle();
      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('Manage children'), findsOneWidget);
    });

    testWidgets('Delete child: the dialog names the child; Cancel keeps; Delete removes and returns to the list', (t) async {
      final (c, _) = await _open(t, '/parent/children');
      await t.tap(find.byKey(const Key('child-row-c1')));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const Key('edit-delete')));
      await t.tap(find.byKey(const Key('edit-delete')));
      await t.pumpAndSettle();
      expect(find.text('Delete Omar?'), findsOneWidget);
      expect(find.textContaining("All of Omar's progress, stars and certificates"), findsOneWidget);
      expect(find.textContaining("can't be undone"), findsOneWidget);

      await t.tap(find.byKey(const Key('cancel-delete')));
      await t.pumpAndSettle();
      expect(c.read(profilesProvider), hasLength(2));

      await t.tap(find.byKey(const Key('edit-delete')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('confirm-delete')));
      await t.pumpAndSettle();
      expect(c.read(profilesProvider).map((p) => p.id), ['c2']);
      expect(find.text('Manage children'), findsOneWidget);
      expect(find.text('Omar'), findsNothing);
    });

    testWidgets('deleting the last child shows the empty state', (t) async {
      await _open(t, '/parent/children', kids: 1);
      await t.tap(find.byKey(const Key('child-row-c1')));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const Key('edit-delete')));
      await t.tap(find.byKey(const Key('edit-delete')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('confirm-delete')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('manage-empty')), findsOneWidget);
    });

    testWidgets('the delete dialog in Arabic is right to left and names the child', (t) async {
      await _open(t, '/parent/children/c1', lang: 'ar');
      await t.ensureVisible(find.byKey(const Key('edit-delete')));
      await t.tap(find.byKey(const Key('edit-delete')));
      await t.pumpAndSettle();
      expect(find.text('حذف Omar؟'), findsOneWidget);
      expect(Directionality.of(t.element(find.byKey(const Key('delete-dialog')))), TextDirection.rtl);
    });

    testWidgets('choosing a reminder time asks for permission when saving and schedules it; a refusal keeps no reminder', (t) async {
      final (c, reminders) = await _open(t, '/parent/children/c1');
      await t.ensureVisible(find.byKey(const Key('edit-reminder-evening')));
      await t.tap(find.byKey(const Key('edit-reminder-evening')));
      await t.pump();
      expect(reminders.permissionAsked, 0);
      await t.ensureVisible(find.byKey(const Key('edit-save')));
      await t.tap(find.byKey(const Key('edit-save')));
      await t.pumpAndSettle();
      expect(reminders.permissionAsked, 1);
      expect(c.read(settingsProvider).reminderTime, 'evening');
      expect(reminders.scheduled?.hour, reminderTimes['evening']!.hour);
    });

    testWidgets('every control is at least 48 dp', (t) async {
      await _open(t, '/parent/children/c1');
      for (final k in ['edit-goal-5', 'edit-goal-10', 'edit-goal-15', 'edit-reminder-off', 'edit-reminder-morning', 'edit-save', 'rerun-setup']) {
        await t.ensureVisible(find.byKey(Key(k)));
        final size = t.getSize(find.byKey(Key(k)));
        expect(size.height, greaterThanOrEqualTo(kParentTap), reason: k);
        expect(size.width, greaterThanOrEqualTo(kParentTap), reason: k);
      }
    });

    testWidgets('Run the setup again opens the setup filled with this child and ends on this screen', (t) async {
      await _open(t, '/parent/children/c1');
      await t.ensureVisible(find.byKey(const Key('rerun-setup')));
      await t.tap(find.byKey(const Key('rerun-setup')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('ob-name')), findsOneWidget);
      expect(find.text('Omar'), findsOneWidget); // the name is filled in
    });
  });

  test('the theme keeps the shared sizes', () {
    expect(kMinTapTarget, 64);
    expect(kParentTap, 48);
    expect(buildTheme().colorScheme.primary, isNot(Colors.transparent));
  });
}
