import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage.dart';
import '../progress/progress.dart';
import '../settings/settings.dart';
import '../units/unit_meta.dart';
import '../units/word_misses.dart';

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
    this.skills,
    this.updatedAt,
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

  /// What the parent said the child can already do (ids from assets/content/skills.json, or `none` / `unsure`); null = never asked.
  final Set<String>? skills;

  /// When the profile fields (name, avatar, birth, track, goal, skills) last changed on a device; sync keeps the most recent change. Null = old data.
  final DateTime? updatedAt;

  /// Age in whole years (the birth month is used when it is known).
  int ageYears(DateTime now) {
    final a = now.year - birthYear - (birthMonth != null && now.month < birthMonth! ? 1 : 0);
    return a < 0 ? 0 : a;
  }

  /// Accessory id from rewards/accessories.dart currently worn by the mascot for this child (null = none).
  final String? equippedAccessory;

  ChildProfile copyWith({String? name, String? avatarKey, int? birthYear, int? birthMonth, int? goalMinutes, String? track, Set<String>? skills, DateTime? updatedAt, String? equippedAccessory, bool clearAccessory = false}) =>
      ChildProfile(
        id: id,
        name: name ?? this.name,
        avatarKey: avatarKey ?? this.avatarKey,
        birthYear: birthYear ?? this.birthYear,
        birthMonth: birthMonth ?? this.birthMonth,
        goalMinutes: goalMinutes ?? this.goalMinutes,
        track: track ?? this.track,
        skills: skills ?? this.skills,
        updatedAt: updatedAt ?? this.updatedAt,
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
        if (skills != null) 'skills': (skills!.toList()..sort()),
        if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
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
        skills: (json['skills'] as List<dynamic>?)?.cast<String>().toSet(),
        updatedAt: json['updatedAt'] == null ? null : DateTime.parse(json['updatedAt'] as String),
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

  Future<ChildProfile> add({required String name, required String avatarKey, required int birthYear, int? birthMonth, int? goalMinutes, String track = 'little-learners', Set<String>? skills}) async {
    final now = ref.read(clockProvider)();
    final profile = ChildProfile(
      id: '${now.microsecondsSinceEpoch.toRadixString(36)}${Random().nextInt(1 << 20).toRadixString(36)}',
      name: name.trim(),
      avatarKey: avatarKey,
      birthYear: birthYear,
      birthMonth: birthMonth,
      goalMinutes: goalMinutes,
      track: track,
      skills: skills,
      updatedAt: now,
      createdAt: now,
    );
    state = [...state, profile];
    await _save();
    return profile;
  }

  Future<void> update(String id, {String? name, String? avatarKey, int? birthYear, int? birthMonth, int? goalMinutes, String? track, Set<String>? skills}) async {
    state = [
      for (final p in state)
        if (p.id == id) p.copyWith(name: name?.trim(), avatarKey: avatarKey, birthYear: birthYear, birthMonth: birthMonth, goalMinutes: goalMinutes, track: track, skills: skills, updatedAt: ref.read(clockProvider)()) else p,
    ];
    await _save();
  }

  /// Gives a child made before the skills list the skills that match the old answer. The time of the last change is left as it is (this is not an edit by the parent).
  Future<void> setSkillsQuietly(String id, Set<String> skills) async {
    state = [for (final p in state) if (p.id == id && p.skills == null) p.copyWith(skills: skills) else p];
    await _save();
  }

  /// A change that came from the server (the most recent one wins): applied as it is, with the time it was made, without stamping "now".
  Future<void> applyFromServer(String id, {required String name, required String avatarKey, required int birthYear, int? birthMonth, int? goalMinutes, String? track, Set<String>? skills, required DateTime updatedAt}) async {
    state = [
      for (final p in state)
        if (p.id == id) p.copyWith(name: name, avatarKey: avatarKey, birthYear: birthYear, birthMonth: birthMonth, goalMinutes: goalMinutes, track: track, skills: skills, updatedAt: updatedAt) else p,
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
    await ref.read(wordMissesProvider.notifier).forget(id);
  }

  Future<void> _save() =>
      ref.read(sharedPreferencesProvider).writeJson(PrefKeys.children, state.map((p) => p.toJson()).toList());
}

final profilesProvider = NotifierProvider<ProfilesNotifier, List<ChildProfile>>(ProfilesNotifier.new);

/// The child currently playing (in memory only). On a returning launch with exactly one child that child is already the
/// active one, so the app opens straight on their unit map.
class ActiveChildNotifier extends Notifier<String?> {
  @override
  String? build() {
    final profiles = ref.read(profilesProvider);
    return profiles.length == 1 && ref.read(settingsProvider).onboarded ? profiles.first.id : null;
  }
  void select(String? id) => state = id;
}

final activeChildIdProvider = NotifierProvider<ActiveChildNotifier, String?>(ActiveChildNotifier.new);
