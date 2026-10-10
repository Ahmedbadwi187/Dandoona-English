import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_english_app/core/loading_action.dart';
import 'package:kids_english_app/core/widgets.dart';

const _buttonKey = Key('loading-save');

Widget _button(LoadingCallback? action, {bool loading = false}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: LoadingAction(
        onPressed: action,
        loading: loading,
        builder: (onPressed, pending) => FilledButton(
          key: _buttonKey,
          onPressed: onPressed,
          child: LoadingContent(loading: pending, child: const Text('Save')),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'pending press keeps label and size, blocks repeats, then recovers',
    (tester) async {
      final done = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        _button(() {
          calls++;
          return done.future;
        }),
      );
      final before = tester.getSize(find.byKey(_buttonKey));
      final stalePress = tester
          .widget<FilledButton>(find.byKey(_buttonKey))
          .onPressed!;
      stalePress();
      stalePress();
      await tester.pump();

      expect(calls, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(tester.getSize(find.byKey(_buttonKey)), before);
      expect(
        tester.widget<FilledButton>(find.byKey(_buttonKey)).onPressed,
        isNull,
      );

      done.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byKey(_buttonKey)).onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'failed operation clears progress and keeps the error visible to its caller',
    (tester) async {
      final done = Completer<void>();
      await tester.pumpWidget(_button(() => done.future));
      final press = tester
          .widget<FilledButton>(find.byKey(_buttonKey))
          .onPressed!;
      final pending = Function.apply(press, const []) as Future<void>;
      final errorCheck = expectLater(pending, throwsStateError);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      done.completeError(StateError('save failed'));
      await errorCheck;
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byKey(_buttonKey)).onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('completion after disposal does not update a removed widget', (
    tester,
  ) async {
    final done = Completer<void>();
    await tester.pumpWidget(_button(() => done.future));
    await tester.tap(find.byKey(_buttonKey));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    done.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('instant selection has no artificial loading delay', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      _button(() {
        calls++;
      }),
    );
    await tester.tap(find.byKey(_buttonKey));
    await tester.pump();
    expect(calls, 1);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byKey(_buttonKey)).onPressed,
      isNotNull,
    );
  });

  testWidgets('external busy state blocks presses and displays progress', (
    tester,
  ) async {
    var calls = 0;
    void action() {
      calls++;
    }

    await tester.pumpWidget(_button(action, loading: true));
    expect(
      tester.widget<FilledButton>(find.byKey(_buttonKey)).onPressed,
      isNull,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(calls, 0);
    await tester.pumpWidget(_button(action));
    await tester.tap(find.byKey(_buttonKey));
    expect(calls, 1);
  });

  testWidgets(
    'a picture tap opens at once: no spinner, nothing held back while its sound plays',
    (tester) async {
      final done = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: BigTap(
                key: const Key('picture-tap'),
                onTap: () {
                  calls++;
                  return done.future;
                },
                child: const SizedBox.square(
                  dimension: 96,
                  child: Icon(Icons.pets),
                ),
              ),
            ),
          ),
        ),
      );
      final before = tester.getSize(find.byKey(const Key('picture-tap')));
      await tester.tap(find.byKey(const Key('picture-tap')));
      await tester.pump();
      expect(find.byIcon(Icons.pets), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing); // the loader belongs to real buttons, not to pictures
      expect(tester.getSize(find.byKey(const Key('picture-tap'))), before);
      await tester.tap(find.byKey(const Key('picture-tap')));
      expect(calls, 2); // a second tap while the sound still plays is not ignored
      done.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('TapToHear plays at once, with no spinner, and every tap counts', (tester) async {
    final done = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: TapToHear(
              onTap: () {
                calls++;
                return done.future;
              },
              child: const SizedBox.square(
                dimension: 96,
                child: Icon(Icons.pets),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TapToHear));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.byType(TapToHear));
    expect(calls, 2);
    done.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
    'a pending confirmation pauses the covered loader and recovers after cancel',
    (tester) async {
      late BuildContext buttonContext;
      await tester.pumpWidget(
        _button(
          () => showDialog<void>(
            context: buttonContext,
            builder: (context) => AlertDialog(
              actions: [
                TextButton(
                  key: const Key('cancel-loading-dialog'),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      );
      buttonContext = tester.element(find.byKey(_buttonKey));
      await tester.tap(find.byKey(_buttonKey));
      await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 2));
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byKey(_buttonKey)).onPressed,
        isNull,
      );
      final spinner = find.byType(CircularProgressIndicator);
      expect(TickerMode.valuesOf(tester.element(spinner)).enabled, isFalse);
      await tester.tap(find.byKey(const Key('cancel-loading-dialog')));
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byKey(_buttonKey)).onPressed,
        isNotNull,
      );
    },
  );
}
