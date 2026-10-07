import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage.dart';
import '../../core/strings.dart';

class AppSettings {
  const AppSettings({
    this.languageCode = 'ar',
    this.sessionMinutes = defaultSessionMinutes,
    this.unlockAll = false,
    this.onboarded = false,
    this.languageChosen = false,
  });

  static const defaultSessionMinutes = 15;
  static const minSessionMinutes = 5;
  static const maxSessionMinutes = 60;

  /// Parent-area language: 'ar' (default, RTL) or 'en'. The child area is always English.
  final String languageCode;
  final int sessionMinutes;
  final bool unlockAll;
  final bool onboarded;

  /// The parent confirmed the language on the first screen. False only on a fresh install.
  final bool languageChosen;

  AppSettings copyWith({String? languageCode, int? sessionMinutes, bool? unlockAll, bool? onboarded, bool? languageChosen}) => AppSettings(
        languageCode: languageCode ?? this.languageCode,
        sessionMinutes: sessionMinutes ?? this.sessionMinutes,
        unlockAll: unlockAll ?? this.unlockAll,
        onboarded: onboarded ?? this.onboarded,
        languageChosen: languageChosen ?? this.languageChosen,
      );

  Map<String, dynamic> toJson() => {
        'languageCode': languageCode,
        'sessionMinutes': sessionMinutes,
        'unlockAll': unlockAll,
        'onboarded': onboarded,
        'languageChosen': languageChosen,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        languageCode: json['languageCode'] == 'en' ? 'en' : 'ar',
        sessionMinutes: ((json['sessionMinutes'] as int?) ?? defaultSessionMinutes)
            .clamp(minSessionMinutes, maxSessionMinutes)
            .toInt(),
        unlockAll: (json['unlockAll'] as bool?) ?? false,
        onboarded: (json['onboarded'] as bool?) ?? false,
        // Settings saved before the language screen existed count as already chosen (those parents already picked a language).
        languageChosen: (json['languageChosen'] as bool?) ?? ((json['onboarded'] as bool?) ?? false),
      );
}

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final raw = ref.read(sharedPreferencesProvider).readJson(PrefKeys.settings);
    if (raw is Map<String, dynamic>) {
      try {
        return AppSettings.fromJson(raw);
      } on Object {
        // fall through to defaults
      }
    }
    return const AppSettings();
  }

  Future<void> setLanguage(String code) => _set(state.copyWith(languageCode: code == 'en' ? 'en' : 'ar'));

  Future<void> setSessionMinutes(int minutes) => _set(
        state.copyWith(sessionMinutes: minutes.clamp(AppSettings.minSessionMinutes, AppSettings.maxSessionMinutes).toInt()),
      );

  Future<void> setUnlockAll(bool value) => _set(state.copyWith(unlockAll: value));

  Future<void> completeOnboarding() => _set(state.copyWith(onboarded: true));

  /// The first screen: the parent confirmed this language (it also sets the layout direction everywhere in the parent area).
  Future<void> chooseLanguage(String code) => _set(state.copyWith(languageCode: code == 'en' ? 'en' : 'ar', languageChosen: true));

  Future<void> _set(AppSettings next) {
    state = next;
    return ref.read(sharedPreferencesProvider).writeJson(PrefKeys.settings, next.toJson());
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

/// Strings for the parent area, in the language chosen in settings.
final stringsProvider = Provider<Strings>((ref) => Strings.forCode(ref.watch(settingsProvider).languageCode));
