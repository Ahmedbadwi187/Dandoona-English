import 'dart:convert';
import 'dart:io';

import 'package:kids_english_app/features/content/content_models.dart';

/// The newest real pack of [unit] (folders are snake_case: `my-body` -> `my_body`), as the app downloads it.
Directory packDir(String unit) {
  final index = jsonDecode(File('../../packs/little_learners/index.json').readAsStringSync()) as Map<String, dynamic>;
  final entry = (index['packs'] as List<dynamic>).cast<Map<String, dynamic>>().firstWhere((p) => p['unit'] == unit);
  return Directory('../../packs/little_learners/${unit.replaceAll('-', '_')}/v${entry['version']}');
}

bool hasPack(String unit) {
  final index = jsonDecode(File('../../packs/little_learners/index.json').readAsStringSync()) as Map<String, dynamic>;
  return (index['packs'] as List<dynamic>).cast<Map<String, dynamic>>().any((p) => p['unit'] == unit);
}

Map<String, dynamic> packManifest(String unit) => jsonDecode(File('${packDir(unit).path}/manifest.json').readAsStringSync()) as Map<String, dynamic>;

/// The lessons of a pack unit.
List<Lesson> packLessons(String unit) => [for (final l in packManifest(unit)['lessons'] as List<dynamic>) Lesson.fromJson(l as Map<String, dynamic>)];

/// Every file path the manifest lists.
Set<String> packFiles(String unit) => {for (final f in packManifest(unit)['files'] as List<dynamic>) (f as Map<String, dynamic>)['path'] as String};
