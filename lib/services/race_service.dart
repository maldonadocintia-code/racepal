import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/race_model.dart';
import '../models/review_model.dart';
import '../theme.dart';

class RaceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Short-lived cache of race docs. The calendar (and profile lists) call
  // getRace() for the same races repeatedly — on every redraw, day tap and
  // month change — which previously re-read every race from Firestore each
  // time and burned the free-tier read quota. The cache serves repeat lookups
  // locally; a short TTL keeps it fresh, and writes that change a race bust its
  // entry (see _invalidateRace). See BACKLOG #9.
  final Map<String, _CachedRace> _raceCache = {};
  static const Duration _raceCacheTtl = Duration(minutes: 2);

  void _invalidateRace(String id) => _raceCache.remove(id);

  // ── Races ──────────────────────────────────────────────────────────────────

  Stream<List<Race>> upcomingRaces({String? type, int limit = 30}) {
    Query q = _db
        .collection(AppConstants.racesCol)
        .where('date', isGreaterThan: Timestamp.fromDate(DateTime.now()))
        .orderBy('date')
        .limit(limit);

    if (type != null && type != 'All') {
      q = q.where('type', isEqualTo: type);
    }

    return q.snapshots().map(
      (s) => s.docs.map((d) => Race.fromDoc(d)).toList(),
    );
  }

  Stream<List<Race>> parkruns({int limit = 50}) => _db
      .collection(AppConstants.racesCol)
      .where('category', isEqualTo: 'parkrun')
      .where('date', isGreaterThan: Timestamp.fromDate(DateTime.now()))
      .orderBy('date')
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map((d) => Race.fromDoc(d)).toList());

  /// Fetches a race, serving a recent cached copy when possible to avoid
  /// re-reading the same doc on every UI rebuild. Pass [forceRefresh] when you
  /// need guaranteed-fresh data.
  Future<Race?> getRace(String id, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _raceCache[id];
      if (cached != null &&
          DateTime.now().difference(cached.at) < _raceCacheTtl) {
        return cached.race;
      }
    }
    final doc = await _db.collection(AppConstants.racesCol).doc(id).get();
    if (!doc.exists) return null;
    final race = Race.fromDoc(doc);
    _raceCache[id] = _CachedRace(race, DateTime.now());
    return race;
  }

  Future<String> addRace(Race race) async {
    final ref = await _db
        .collection(AppConstants.racesCol)
        .add(race.toMap());
    return ref.id;
  }

  /// Creates the race doc with a deterministic id if it doesn't exist yet.
  /// Used when attending a parkrun or findarace event that lives in assets.
  Future<String> ensureRace(Race race) async {
    final ref = _db.collection(AppConstants.racesCol).doc(race.id);
    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set(race.toMap());
    }
    return race.id;
  }

  Future<void> deleteRace(String raceId) async {
    await _db.collection(AppConstants.racesCol).doc(raceId).delete();
    _invalidateRace(raceId);
  }

  // ── Parkrun venues ───────────────────────────────────────────────────────────
  // User-created parkruns that aren't in the bundled assets/parkruns_uk.json.
  // They're stored as venues (no date) so every user's parkrun picker can show
  // them; picking one runs the normal pick-a-Saturday → ensureRace flow, the
  // same as a bundled parkrun.

  /// Creates a user parkrun venue and returns the `venueId` (`prv_<docId>`) used
  /// to build per-date race ids. [name] is the bare name (no "parkrun" suffix).
  Future<String> addParkrunVenue({
    required String name,
    required String location,
    required String createdBy,
    double? lat,
    double? lng,
    String? website,
  }) async {
    final ref = await _db.collection(AppConstants.parkrunVenuesCol).add({
      'name': name,
      'location': location,
      'lat': lat,
      'lng': lng,
      'website': website,
      'createdBy': createdBy,
      'createdAt': Timestamp.now(),
    });
    return 'prv_${ref.id}';
  }

  /// User-created parkrun venues, shaped to match the bundled asset entries
  /// (`name`, `location`, `lat`, `lng`) plus a stable `venueId` so the pickers
  /// can merge them with the bundled list and render them identically.
  Future<List<Map<String, dynamic>>> parkrunVenues() async {
    final snap = await _db.collection(AppConstants.parkrunVenuesCol).get();
    return snap.docs.map((d) {
      final data = d.data();
      return <String, dynamic>{
        'id': d.id,
        'venueId': 'prv_${d.id}',
        'name': data['name'] ?? '',
        'location': data['location'] ?? '',
        'lat': (data['lat'] as num?)?.toDouble(),
        'lng': (data['lng'] as num?)?.toDouble(),
        'website': data['website'],
      };
    }).toList();
  }

  Stream<List<Race>> searchRaces(String query) {
    final lower = query.toLowerCase();
    return _db
        .collection(AppConstants.racesCol)
        .orderBy('name')
        .startAt([lower])
        .endAt(['$lower\uf8ff'])
        .limit(20)
        .snapshots()
        .map((s) => s.docs.map((d) => Race.fromDoc(d)).toList());
  }

  // ── Attendance ─────────────────────────────────────────────────────────────

  Future<void> setAttendance({
    required String raceId,
    required String userId,
    required AttendanceStatus status,
  }) async {
    final docId = '${userId}_$raceId';
    await _db.collection(AppConstants.attendancesCol).doc(docId).set(
      Attendance(
        id: docId,
        raceId: raceId,
        userId: userId,
        status: status,
        createdAt: DateTime.now(),
      ).toMap(),
    );
  }

  Future<void> removeAttendance({
    required String raceId,
    required String userId,
  }) async {
    await _db
        .collection(AppConstants.attendancesCol)
        .doc('${userId}_$raceId')
        .delete();
  }

  Future<Attendance?> getAttendance({
    required String raceId,
    required String userId,
  }) async {
    final doc = await _db
        .collection(AppConstants.attendancesCol)
        .doc('${userId}_$raceId')
        .get();
    return doc.exists ? Attendance.fromDoc(doc) : null;
  }

  Stream<List<Attendance>> userAttendances(String userId) => _db
      .collection(AppConstants.attendancesCol)
      .where('userId', isEqualTo: userId)
      .snapshots()
      .map((s) => s.docs.map((d) => Attendance.fromDoc(d)).toList());

  Stream<List<Attendance>> attendancesForUsers(List<String> userIds) {
    if (userIds.isEmpty) return Stream.value([]);
    // Firestore whereIn limit is 30
    final ids = userIds.take(30).toList();
    return _db
        .collection(AppConstants.attendancesCol)
        .where('userId', whereIn: ids)
        .where('status', isEqualTo: 'going')
        .snapshots()
        .map((s) => s.docs.map((d) => Attendance.fromDoc(d)).toList());
  }

  Stream<List<Attendance>> raceAttendees(String raceId) => _db
      .collection(AppConstants.attendancesCol)
      .where('raceId', isEqualTo: raceId)
      .snapshots()
      .map((s) => s.docs.map((d) => Attendance.fromDoc(d)).toList());

  // ── Reviews ────────────────────────────────────────────────────────────────

  Future<void> addReview(Review review) async {
    final reviewRef = _db.collection(AppConstants.reviewsCol).doc();
    await reviewRef.set(review.toMap());
    // The review is saved — that's all the user is waiting on. Recalculating the
    // race's aggregate rating re-reads every review, so run it in the background
    // rather than blocking the "Post review" tap. The reviews list updates live
    // via its stream; the average refreshes a moment later.
    unawaited(_recalcRaceStats(review.raceId));
  }

  Future<void> _recalcRaceStats(String raceId) async {
    final snap = await _db
        .collection(AppConstants.reviewsCol)
        .where('raceId', isEqualTo: raceId)
        .get();
    if (snap.docs.isEmpty) return;
    final reviews = snap.docs.map((d) => Review.fromDoc(d)).toList();
    final count = reviews.length;
    final avg = reviews.map((r) => r.rating).reduce((a, b) => a + b) / count;
    final recommended = reviews.where((r) => r.recommend).length;
    final recommendPercent = recommended / count;
    final bolt = count >= 10 && recommendPercent >= 0.8;
    await _db.collection(AppConstants.racesCol).doc(raceId).update({
      'reviewCount': count,
      'averageRating': avg,
      'recommendPercent': recommendPercent,
      'lightningBolt': bolt,
    });
    // The race doc's stats just changed — drop any cached copy so the next read
    // (e.g. the detail header) reflects the new rating/review count.
    _invalidateRace(raceId);
  }

  /// All reviews for a race, newest first. Reviews are public to any signed-in
  /// user (the everyone/pals-only split was dropped), so a single equality
  /// query is enough — we sort client-side to avoid needing a composite index,
  /// and per-race review counts are small.
  Stream<List<Review>> raceReviews(String raceId) => _db
      .collection(AppConstants.reviewsCol)
      .where('raceId', isEqualTo: raceId)
      .snapshots()
      .map((s) {
        final list = s.docs.map((d) => Review.fromDoc(d)).toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });

  Stream<List<Review>> userReviews(String userId) => _db
      .collection(AppConstants.reviewsCol)
      .where('userId', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => Review.fromDoc(d)).toList());

  Future<Review?> getUserRaceReview({
    required String userId,
    required String raceId,
  }) async {
    final snap = await _db
        .collection(AppConstants.reviewsCol)
        .where('userId', isEqualTo: userId)
        .where('raceId', isEqualTo: raceId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return Review.fromDoc(snap.docs.first);
  }

  Future<void> updateReview(Review review) async {
    await _db.collection(AppConstants.reviewsCol).doc(review.id).update({
      'rating': review.rating,
      'body': review.body,
      'finishTime': review.finishTime,
      'isPublic': review.isPublic,
    });
  }

  Future<void> deleteReview(Review review) async {
    final batch = _db.batch();
    batch.delete(_db.collection(AppConstants.reviewsCol).doc(review.id));
    batch.update(
      _db.collection(AppConstants.racesCol).doc(review.raceId),
      {'reviewCount': FieldValue.increment(-1)},
    );
    await batch.commit();
    _invalidateRace(review.raceId);
  }

  // ── Activity feed ──────────────────────────────────────────────────────────

  Future<void> postActivity(ActivityItem item) async {
    await _db.collection(AppConstants.activitiesCol).add(item.toMap());
  }

  Stream<List<ActivityItem>> feedForUser(List<String> followingUids) {
    if (followingUids.isEmpty) {
      return Stream.value([]);
    }
    // Firestore 'whereIn' limit is 30
    final uids = followingUids.take(30).toList();
    return _db
        .collection(AppConstants.activitiesCol)
        .where('userId', whereIn: uids)
        .orderBy('createdAt', descending: true)
        .limit(40)
        .snapshots()
        .map((s) => s.docs.map((d) => ActivityItem.fromDoc(d)).toList());
  }
}

/// A race doc cached with the time it was fetched (for TTL expiry).
class _CachedRace {
  final Race race;
  final DateTime at;
  _CachedRace(this.race, this.at);
}
