import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in main() (and in tests) with the real, already-loaded instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

/// Small JSON helpers over SharedPreferences. All data stays on the device (see docs/privacy-data-map.md).
extension JsonPrefs on SharedPreferences {
  Object? readJson(String key) {
    final raw = getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null; // corrupted value: behave as if absent rather than crash the app
    }
  }

  Future<bool> writeJson(String key, Object value) => setString(key, jsonEncode(value));
}

/// Storage keys in one place.
abstract final class PrefKeys {
  static const settings = 'settings.v1';
  static const children = 'children.v1';
  static const progress = 'progress.v1';
  static const unitMeta = 'meta.v2';
}
