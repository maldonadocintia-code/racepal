/// Race distance buckets for the Explore distance filter (BACKLOG #3).
///
/// Runners think in standard distances. A single event can offer several
/// (curated data has values like "5K / 10K / Half"), so a race maps to a *set*
/// of buckets and matches the filter if the chosen bucket is in that set.
///
/// Tokens we don't recognise (e.g. "5 miles", "Trail", "Triathlon", "Other")
/// yield no bucket, so those events only show under "Any". Add a bucket here if
/// enough such races appear to warrant a chip.
enum DistanceBucket { fiveK, tenK, tenMile, half, marathon, ultra }

extension DistanceBucketLabel on DistanceBucket {
  String get label => switch (this) {
        DistanceBucket.fiveK => '5K',
        DistanceBucket.tenK => '10K',
        DistanceBucket.tenMile => '10 mile',
        DistanceBucket.half => 'Half',
        DistanceBucket.marathon => 'Marathon',
        DistanceBucket.ultra => 'Ultra',
      };
}

/// The chip order shown in the filter sheet.
const List<DistanceBucket> kDistanceBuckets = [
  DistanceBucket.fiveK,
  DistanceBucket.tenK,
  DistanceBucket.tenMile,
  DistanceBucket.half,
  DistanceBucket.marathon,
  DistanceBucket.ultra,
];

/// Parses a raw distance/type string into the standard buckets it offers.
/// Handles multi-distance strings split on "/", e.g. "5K / 10K / Half".
/// "Half Marathon" maps to [DistanceBucket.half] (not marathon).
Set<DistanceBucket> bucketsFor(String? raw) {
  final out = <DistanceBucket>{};
  if (raw == null || raw.isEmpty) return out;
  for (final part in raw.toLowerCase().split('/')) {
    final t = part.trim();
    if (t.contains('5k')) out.add(DistanceBucket.fiveK);
    if (t.contains('10k')) out.add(DistanceBucket.tenK);
    if (t.contains('10 mile')) out.add(DistanceBucket.tenMile);
    if (t.contains('ultra')) out.add(DistanceBucket.ultra);
    // "half" wins over "marathon" so "Half Marathon" is a Half, not a Marathon.
    if (t.contains('half')) {
      out.add(DistanceBucket.half);
    } else if (t.contains('marathon')) {
      out.add(DistanceBucket.marathon);
    }
  }
  return out;
}
