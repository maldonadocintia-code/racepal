import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/race_model.dart';
import '../models/review_model.dart';
import '../theme.dart';

class RaceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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

  Future<Race?> getRace(String id) async {
    final doc = await _db.collection(AppConstants.racesCol).doc(id).get();
    return doc.exists ? Race.fromDoc(doc) : null;
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
    final batch = _db.batch();
    final reviewRef = _db.collection(AppConstants.reviewsCol).doc();
    batch.set(reviewRef, review.toMap());
    await batch.commit();
    await _recalcRaceStats(review.raceId);
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
  }

  Stream<List<Review>> raceReviews(String raceId, {bool publicOnly = false}) {
    Query q = _db
        .collection(AppConstants.reviewsCol)
        .where('raceId', isEqualTo: raceId)
        .orderBy('createdAt', descending: true);

    if (publicOnly) {
      q = q.where('isPublic', isEqualTo: true);
    }

    return q.snapshots().map(
      (s) => s.docs.map((d) => Review.fromDoc(d)).toList(),
    );
  }

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

  Stream<List<ActivityItem>> userActivity(String userId) => _db
      .collection(AppConstants.activitiesCol)
      .where('userId', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots()
      .map((s) => s.docs.map((d) => ActivityItem.fromDoc(d)).toList());
}
