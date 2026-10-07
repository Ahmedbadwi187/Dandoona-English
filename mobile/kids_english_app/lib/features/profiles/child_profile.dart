import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage.dart';
import '../progress/progress.dart';
import '../units/unit_meta.dart';

/// A child profile. A nickname, a drawn avatar, the birth month and year, and the daily goal the parent chose: no photo, no
/// email, no real name, nothing else (see docs/privacy-data-map.md).
class ChildProfile {
  const ChildProfile({
    required this.id,
    required this.name,
    required this.avatarKey,
    required this.birthYear,
    required this.createdAt,
    this.track = 'little-learners',
    this.equippedAccessory,
    this.birthMonth,
    this.goalMinutes,
  });

  final String id;
  final String name;
  final String avatarKey;
  final int birthYear;
  final String track;
  final DateTime createdAt;

  /// 1-12; with the year it gives the exact age. Null for children made before the first-launch flow asked for it.
  final int? birthMonth;

  /// The daily goal in minutes chosen by the parent (5, 10 or 15); null when none was chosen.
  final int? goalMinutes;

  /// Accessory id from rewards/accessories.dart currently worn by the mascot for this child (null = none).
  final String? equippedAccessory;

  ChildProfile copyWith({String? name, String? avatarKey, int? birthYear, int? birthMonth, int? goalMinutes, String? track, String? equippedAccessory, bool clearAccessory = false}) =>
      ChildProfile(
        id: id,
        name: name ?? this.name,
        avatarKey: avatarKey ?? this.avatarKey,
        birthYear: birthYear ?? this.birthYear,
        birthMonth: birthMonth ?? this.birthMonth,
        goalMinutes: goalMinutes ?? this.goalMinutes,
        track: track ?? this.track,
        createdAt: createdAt,
        equippedAccessory: clearAccessory ? null : (equippedAccessory ?? this.equippedAccessory),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatarKey': avatarKey,
        'birthYear': birthYear,
        if (birthMonth != null) 'birthMonth': birthMonth,
        if (goalMinutes != null) 'goalMinutes': goalMinutes,
        'track': track,
        'createdAt': createdAt.toUtc().toIso8601String(),
        if (equippedAccessory != null) 'equippedAccessory': equippedAccessory,
      };

  factory ChildProfile.fromJson(Map<String, dynamic> json) => ChildProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        avatarKey: json['avatarKey'] as String,
        birthYear: json['birthYear'] as int,
        birthMonth: json['birthMonth'] as int?,
        goalMinutes: json['goalMinutes'] as int?,
        track: (json['track'] as String?) ?? 'little-learners',
        createdAt: DateTime.parse(json['createdAt'] as String),
        equippedAccessory: json['equippedAccessory'] as String?,
      );
}

/// Same rules as the API (name 1-30 chars, age 2-13), returning a strings key or null when valid.
abstract final class ChildValidation {
  static const maxName = 30;

  static String? name(String? value) {
    final v = value?.trim() ?? '';
    return v.isEmpty || v.length > maxName ? 'errName' : null;
  }

  static String? birthYear(int? year, DateTime now) {
    if (year == null || year < now.year - 13 || year > now.year - 2) return 'errBirthYear';
    return null;
  }
}

final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

class ProfilesNotifier extends Notifier<List<ChildProfile>> {
  @override
  List<ChildProfile> build() {
    final raw = ref.read(sharedPreferencesProvider).readJson(PrefKeys.children);
    if (raw is! List) return const [];
    final profiles = <ChildProfile>[];
    for (final e in raw) {
      try {
        profiles.add(ChildProfile.fromJson(e as Map<String, dynamic>));
      } on Object {
        // Skip an unreadable entry instead of losing every profile.
      }
    }
    return profiles;
  }

  Future<ChildProfile> add({required String name, required String avatarKey, required int birthYear, int? birthMonth, int? goalMinutes, String track = 'little-learners'}) async {
    final now = ref.read(clockProvider)();
    final profile = ChildProfile(
      id: '${now.microsecondsSinceEpoch.toRadixString(36)}${Random().nextInt(1 << 20).toRadixString(36)}',
      name: name.trim(),
      avatarKey: avatarKey,
      birthYear: birthYear,
      birthMonth: birthMonth,
      goalMinutes: goalMinutes,
      track: track,
      createdAt: now,
    );
    state = [...state, profile];
    await _save();
    return profile;
  }

  Future<void> update(String id, {String? name, String? avatarKey, int? birthYear, int? birthMonth, int? goalMinutes, String? track}) async {
    state = [
      for (final p in state)
        if (p.id == id) p.copyWith(name: name?.trim(), avatarKey: avatarKey, birthYear: birthYear, birthMonth: birthMonth, goalMinutes: goalMinutes, track: track) else p,
    ];
    await _save();
  }

  Future<void> equip(String id, String? accessoryId) async {
    state = [
      for (final p in state)
        if (p.id == id) p.copyWith(equippedAccessory: accessoryId, clearAccessory: accessoryId == null) else p,
    ];
    await _save();
  }

  /// Removes the profile and that child's progress from this device.
  Future<void> remove(String id) async {
    state = state.where((p) => p.id != id).toList();
    await _save();
    await ref.read(progressProvider.notifier).removeForChild(id);
    await ref.read(unitMetaProvider.notifier).removeForChild(id);
  }

  Future<void> _save() =>
      ref.read(sharedPreferencesProvider).writeJson(PrefKeys.children, state.map((p) => p.toJson()).toList());
}

final profilesProvider = NotifierProvider<ProfilesNotifier, List<ChildProfile>>(ProfilesNotifier.new);

/// The child currently playing (in memory only).
class ActiveChildNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? id) => state = id;
}

final activeChildIdProvider = NotifierProvider<ActiveChildNotifier, String?>(ActiveChildNotifier.new);
