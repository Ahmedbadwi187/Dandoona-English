import 'dart:async';

import 'package:kids_english_app/core/sky.dart';

/// Every test file runs through here first. The drifting clouds repeat forever, which would keep widget tests from ever
/// settling, so they stand still unless a test turns them on.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  SkyBackground.drift = false;
  await testMain();
}
