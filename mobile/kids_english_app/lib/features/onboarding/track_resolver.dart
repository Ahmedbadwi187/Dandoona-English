/// The track a child belongs to, from their age. Only Little Learners (ages 3-5) has content so far; the older tracks are
/// named so that a six-year-old is told the truth and still gets something useful.
class TrackChoice {
  const TrackChoice({required this.trackId, required this.ageYears, required this.available, required this.resolvedTrackId});

  /// The track that fits the age: `little-learners` (up to 5), `explorers` (6-8) or `champions` (9 and up).
  final String trackId;
  final int ageYears;

  /// False when that track has no lessons yet; the child then uses [resolvedTrackId].
  final bool available;

  /// The track the child will really use.
  final String resolvedTrackId;
}

/// Exact age in whole years (with the month when it is known) and the track that fits it.
TrackChoice resolveTrack({
  required int birthYear,
  int? birthMonth,
  required DateTime now,
  Set<String> available = const {'little-learners'},
}) {
  var age = now.year - birthYear;
  if (birthMonth != null && now.month < birthMonth) age--;
  final fits = age <= 5 ? 'little-learners' : (age <= 8 ? 'explorers' : 'champions');
  final ok = available.contains(fits);
  return TrackChoice(trackId: fits, ageYears: age < 0 ? 0 : age, available: ok, resolvedTrackId: ok ? fits : 'little-learners');
}
