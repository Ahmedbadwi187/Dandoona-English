import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/app.dart';
import 'package:kids_english_app/core/sky.dart';
import 'package:kids_english_app/core/theme.dart';
import 'package:kids_english_app/core/widgets.dart';
import 'package:kids_english_app/features/audio/audio_service.dart';
import 'package:kids_english_app/features/content/content_models.dart';
import 'package:kids_english_app/features/profiles/child_profile.dart';
import 'package:kids_english_app/router.dart';

import 'helpers.dart';

const _titleAudio = 'asset:audio/little_learners/unit_app/instr_title.mp3';

TrackContent _content({bool withApp = true}) => TrackContent.fromJson({
      'schemaVersion': 2,
      'track': 'little-learners',
      'units': [
        {
          'id': 'letters',
          'order': 1,
          'title': {'en': 'Letters', 'ar': 'الحروف'},
          'icon': 'letters',
          'color': 'blue',
          'lessons': [
            {
              'id': 'letter-a',
              'order': 1,
              'level': 'pre-a1',
              'letter': 'A',
              'phoneme': '/a/',
              'audio': {'intro': 'a.mp3', 'praise': ['p.mp3']},
              'words': [
                {'word': 'apple', 'audio': 'apple.mp3', 'image': 'images/x/w.svg'},
              ],
              'activities': ['trace'],
            },
          ],
        },
      ],
      if (withApp) 'app': {'title': 'audio/little_learners/unit_app/instr_title.mp3', 'welcome': 'audio/little_learners/unit_app/intro.mp3', 'celebration': 'audio/little_learners/unit_app/instr_celebration.mp3'},
    });

String _kid(String id, String name, String avatar) => '{"id":"$id","name":"$name","avatarKey":"$avatar","birthYear":2022,"track":"little-learners","createdAt":"2026-01-0${id.length}T00:00:00Z"}';

String _stars(String child, int stars) =>
    '{"clientRecordId":"r-$child","childId":"$child","lessonId":"letter-a","activity":"trace","stars":$stars,"attempts":1,"timeSpentSeconds":60,"completedAt":"2026-10-01T09:00:00Z"}';

Future<(ProviderContainer, FakeAudio)> _open(
  WidgetTester t, {
  List<String> kids = const ['a', 'b'],
  Size size = const Size(1080, 2400),
  bool withApp = true,
  String progress = '[]',
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1080 / 411;
  addTearDown(t.view.reset);
  final avatars = ['bear', 'frog', 'cat', 'rocket', 'owl', 'bunny'];
  final names = ['Omar', 'Lina', 'Sam', 'Mia', 'Zed', 'Kai'];
  final children = [for (var i = 0; i < kids.length; i++) _kid(kids[i], names[i], avatars[i == 1 ? 3 : i == 3 ? 1 : i])];
  final audio = FakeAudio();
  final overrides = await testOverrides(
    content: _content(withApp: withApp),
    prefs: {
      'settings.v1': '{"languageCode":"en","sessionMinutes":15,"unlockAll":false,"onboarded":true,"languageChosen":true}',
      'children.v1': '[${children.join(',')}]',
      'progress.v1': progress,
    },
  );
  final c = ProviderContainer(overrides: [...overrides, audioServiceProvider.overrideWithValue(audio)]);
  addTearDown(c.dispose);
  await t.pumpWidget(UncontrolledProviderScope(container: c, child: const KidsEnglishApp()));
  await t.pumpAndSettle();
  return (c, audio);
}

BoxDecoration _decoration(WidgetTester t, String key) => t.widget<Container>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(Container)).first).decoration! as BoxDecoration;

void main() {
  _singleChildRegression();
  testWidgets('Dandoona\'s sky is the background: gradient and clouds (no plain cream page)', (t) async {
    await _open(t);
    expect(find.byKey(const Key('sky')), findsOneWidget);
    expect(find.byKey(const Key('clouds')), findsOneWidget);
    final sky = t.widget<DecoratedBox>(find.byKey(const Key('sky'))).decoration as BoxDecoration;
    expect(sky.gradient, isNotNull);
  });

  testWidgets('the clouds drift slowly when motion is on, and stand still when the phone asks for less motion', (t) async {
    SkyBackground.drift = true;
    addTearDown(() => SkyBackground.drift = false);
    await t.pumpWidget(const MaterialApp(home: SkyBackground(child: SizedBox())));
    expect(t.hasRunningAnimations, isTrue);
    await t.pumpWidget(const MediaQuery(data: MediaQueryData(disableAnimations: true), child: MaterialApp(home: SkyBackground(child: SizedBox()))));
    await t.pump();
    expect(t.hasRunningAnimations, isFalse);
  });

  testWidgets('Dandoona waves at the top and the question is in her speech bubble with a speaker', (t) async {
    await _open(t);
    expect(find.text('Who is playing?'), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    final dandoona = t.widget<Image>(find.byWidgetPredicate((w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName.contains('waving')));
    expect(dandoona, isNotNull);
    expect(Directionality.of(t.element(find.text('Who is playing?'))), TextDirection.ltr);
    // she is above the cards, in the middle
    expect(t.getCenter(find.byKey(const Key('who-bubble'))).dx, closeTo(t.view.physicalSize.width / t.view.devicePixelRatio / 2, 2));
    expect(t.getBottomLeft(find.byKey(const Key('who-bubble'))).dy, lessThan(t.getTopLeft(find.byKey(const Key('pick-a'))).dy));
  });

  testWidgets('she says "Who is playing?" in her voice when the screen opens; tapping the bubble says it again', (t) async {
    final (_, audio) = await _open(t);
    expect(audio.played, [_titleAudio]);
    await t.tap(find.byKey(const Key('who-bubble')));
    await t.pump();
    expect(audio.played, [_titleAudio, _titleAudio]);
  });

  testWidgets('without the voice line the screen stays quiet and still works', (t) async {
    final (_, audio) = await _open(t, withApp: false);
    expect(audio.played, isEmpty);
    expect(find.byKey(const Key('pick-a')), findsOneWidget);
  });

  testWidgets('each child is a white card with a border in the avatar color, a big avatar, the name and the stars', (t) async {
    final (_, _) = await _open(t, progress: '[${_stars('a', 3)}]');
    final omar = AvatarOption.byKey('bear');
    final card = _decoration(t, 'pick-a');
    expect(card.color, Colors.white);
    expect((card.border! as Border).top.color, isNot(Colors.transparent));
    expect(HSLColor.fromColor((card.border! as Border).top.color).hue, closeTo(HSLColor.fromColor(omar.color).hue, 2));
    expect(t.getSize(find.descendant(of: find.byKey(const Key('pick-a')), matching: find.byType(AvatarCircle))).width, greaterThanOrEqualTo(64)); // small cards, still a big enough picture to tap
    final name = t.widget<Text>(find.descendant(of: find.byKey(const Key('pick-a')), matching: find.text('Omar')));
    expect(HSLColor.fromColor(name.style!.color!).lightness, lessThan(0.3)); // the avatar's dark shade
    expect(find.descendant(of: find.byKey(const Key('stars-a')), matching: find.text('3')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('stars-b')), matching: find.text('0')), findsOneWidget);
  });

  testWidgets('two children sit side by side, all cards the same size', (t) async {
    await _open(t);
    final a = t.getRect(find.byKey(const Key('pick-a')));
    final b = t.getRect(find.byKey(const Key('pick-b')));
    expect(a.top, b.top);
    expect(a.right, lessThan(b.left));
    expect(a.size, b.size);
  });

  testWidgets('three children sit in one row, the fourth starts a second row in the middle; all the same size', (t) async {
    await _open(t, kids: const ['a', 'b', 'c', 'd']);
    final a = t.getRect(find.byKey(const Key('pick-a')));
    final b = t.getRect(find.byKey(const Key('pick-b')));
    final c = t.getRect(find.byKey(const Key('pick-c')));
    final d = t.getRect(find.byKey(const Key('pick-d')));
    expect(b.top, a.top);
    expect(c.top, a.top);
    expect(a.right, lessThan(b.left));
    expect(b.right, lessThan(c.left));
    expect(d.top, greaterThan(a.bottom)); // a second row
    expect(d.center.dx, closeTo(t.view.physicalSize.width / t.view.devicePixelRatio / 2, 1)); // the odd one out sits in the middle
    expect(a.size, b.size);
    expect(d.width, closeTo(a.width, 0.01));
    expect(d.height, closeTo(a.height, 0.01));
    expect(a.width, lessThan(150)); // small cards
  });

  testWidgets('with many children the grid scrolls', (t) async {
    await _open(t, kids: const ['a', 'b', 'c', 'd', 'e', 'f'], size: const Size(1080, 1500));
    await t.drag(find.byType(SingleChildScrollView), const Offset(0, -600));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('pick-f')), findsOneWidget);
    expect(t.getRect(find.byKey(const Key('pick-f'))).bottom, lessThan(t.view.physicalSize.height / t.view.devicePixelRatio));
  });

  testWidgets('the content is centered vertically: no big empty area at the bottom', (t) async {
    await _open(t);
    final screen = t.view.physicalSize.height / t.view.devicePixelRatio;
    final top = t.getTopLeft(find.byKey(const Key('who-bubble'))).dy;
    final bottom = screen - t.getBottomLeft(find.byKey(const Key('pick-a'))).dy;
    expect(bottom, lessThan(top + 80));
    expect(bottom, lessThan(280));
  });

  testWidgets('tapping a card: the avatar bounces, a cheerful sound plays, then that child\'s unit map opens', (t) async {
    final (c, audio) = await _open(t);
    audio.played.clear();
    await t.tap(find.byKey(const Key('pick-a')));
    await t.pump(); // the animation starts on this frame
    await t.pump(const Duration(milliseconds: 250));
    final scale = t.widget<ScaleTransition>(find.descendant(of: find.byKey(const Key('pick-a')), matching: find.byType(ScaleTransition))).scale.value;
    expect(scale, isNot(1.0)); // mid-bounce
    expect(audio.played, ['asset:audio/ui/cheer.wav']);
    expect(c.read(activeChildIdProvider), isNull); // not yet
    await t.pump(const Duration(milliseconds: 700));
    await t.pumpAndSettle();
    expect(c.read(activeChildIdProvider), 'a');
    expect(c.read(routerProvider).routerDelegate.currentConfiguration.last.matchedLocation, '/map');
  });

  testWidgets('a second tap while leaving does nothing', (t) async {
    final (_, audio) = await _open(t);
    audio.played.clear();
    await t.tap(find.byKey(const Key('pick-a')));
    await t.pump(const Duration(milliseconds: 100));
    await t.tap(find.byKey(const Key('pick-b')), warnIfMissed: false);
    await t.pump(const Duration(milliseconds: 100));
    expect(audio.played, ['asset:audio/ui/cheer.wav']);
    await t.pumpAndSettle();
  });

  testWidgets('the lock button stays top-right, at least 64 dp, on a white round base', (t) async {
    await _open(t);
    final lock = find.byKey(const Key('open-parent-area'));
    expect(t.getSize(lock).width, greaterThanOrEqualTo(kMinTapTarget));
    expect(t.getSize(lock).height, greaterThanOrEqualTo(kMinTapTarget));
    expect(t.getTopRight(lock).dx, greaterThan(t.view.physicalSize.width / t.view.devicePixelRatio - 24));
    final base = t.widget<Material>(find.ancestor(of: lock, matching: find.byType(Material)).first);
    expect(base.color, Colors.white);
    expect(base.shape, isA<CircleBorder>());
  });

  testWidgets('children with the older icon avatars keep their color and show a character', (t) async {
    await _open(t, kids: const ['a', 'b']); // the second child has the rocket avatar
    final rocket = AvatarOption.byKey('rocket');
    expect(rocket.color, const Color(0xFFE5524A));
    expect(find.descendant(of: find.byKey(const Key('pick-b')), matching: find.byType(Image)), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('pick-b')), matching: find.byIcon(Icons.rocket_launch_rounded)), findsNothing);
  });
}

void _singleChildRegression() {
  testWidgets('one child: the picker still fills the screen width and the content is centered (not squeezed to the left)', (t) async {
    final (c, _) = await _open(t, kids: const ['a']);
    c.read(routerProvider).go('/who'); // with one child the app opens the map; the avatar there leads back to the picker
    await t.pumpAndSettle();
    final width = t.view.physicalSize.width / t.view.devicePixelRatio;
    expect(t.getSize(find.byType(SkyBackground).last).width, closeTo(width, 1));
    expect(t.getCenter(find.byKey(const Key('who-bubble'))).dx, closeTo(width / 2, 2));
    expect(t.getCenter(find.byKey(const Key('pick-a'))).dx, closeTo(width / 2, 2));
  });
}
