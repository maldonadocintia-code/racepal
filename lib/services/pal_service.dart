import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../theme.dart';

/// Pals are a single symmetric friendship: you send a pal request, they accept,
/// and you're pals — both ways, immediately. Stored as two mirrored docs
/// (`pals/{owner}_{other}`) so rules and "my pals" queries stay simple, mirroring
/// the old follows layout.
class PalService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Small in-memory cache for user search (refreshed every 30s).
  List<AppUser>? _userCache;
  DateTime? _userCacheAt;

  // ── Status ───────────────────────────────────────────────────────────────

  Future<PalStatus> getStatus({
    required String uid,
    required String otherUid,
  }) async {
    if (uid == otherUid) return PalStatus.self;

    final pal =
        await _db.collection(AppConstants.palsCol).doc('${uid}_$otherUid').get();
    if (pal.exists) return PalStatus.pals;

    final outgoing = await _db
        .collection(AppConstants.palRequestsCol)
        .doc('${uid}_$otherUid')
        .get();
    if (outgoing.exists) return PalStatus.requested;

    final incoming = await _db
        .collection(AppConstants.palRequestsCol)
        .doc('${otherUid}_$uid')
        .get();
    if (incoming.exists) return PalStatus.incoming;

    return PalStatus.none;
  }

  // ── Requests ───────────────────────────────────────────────────────────────

  Future<void> sendRequest({
    required String fromUid,
    required String toUid,
  }) async {
    await _db
        .collection(AppConstants.palRequestsCol)
        .doc('${fromUid}_$toUid')
        .set({
      'fromUid': fromUid,
      'toUid': toUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelRequest({
    required String fromUid,
    required String toUid,
  }) async {
    await _db
        .collection(AppConstants.palRequestsCol)
        .doc('${fromUid}_$toUid')
        .delete();
  }

  /// [requesterUid] sent the request; [myUid] accepts it. Creates both pal docs
  /// and removes the request, so they become pals instantly.
  Future<void> acceptRequest({
    required String requesterUid,
    required String myUid,
  }) async {
    final batch = _db.batch();
    batch.delete(_db
        .collection(AppConstants.palRequestsCol)
        .doc('${requesterUid}_$myUid'));
    _writePalPair(batch, myUid, requesterUid);
    await batch.commit();
  }

  Future<void> declineRequest({
    required String requesterUid,
    required String myUid,
  }) async {
    await _db
        .collection(AppConstants.palRequestsCol)
        .doc('${requesterUid}_$myUid')
        .delete();
  }

  // ── Pals ─────────────────────────────────────────────────────────────────

  Future<void> removePal({
    required String uid,
    required String otherUid,
  }) async {
    final batch = _db.batch();
    batch.delete(_db.collection(AppConstants.palsCol).doc('${uid}_$otherUid'));
    batch.delete(_db.collection(AppConstants.palsCol).doc('${otherUid}_$uid'));
    await batch.commit();
  }

  void _writePalPair(WriteBatch batch, String a, String b) {
    final now = FieldValue.serverTimestamp();
    batch.set(
      _db.collection(AppConstants.palsCol).doc('${a}_$b'),
      {'ownerUid': a, 'otherUid': b, 'createdAt': now},
    );
    batch.set(
      _db.collection(AppConstants.palsCol).doc('${b}_$a'),
      {'ownerUid': b, 'otherUid': a, 'createdAt': now},
    );
  }

  // ── Queries ────────────────────────────────────────────────────────────────

  Stream<List<String>> palUids(String uid) => _db
      .collection(AppConstants.palsCol)
      .where('ownerUid', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()['otherUid'] as String).toList());

  Stream<List<AppUser>> palsStream(String uid) =>
      palUids(uid).asyncMap(_fetchUsers);

  Future<List<AppUser>> getPals(String uid) async =>
      _fetchUsers(await palUids(uid).first);

  /// Incoming pal requests for [myUid] (newest first). No orderBy — that would
  /// need a composite index; sorted client-side instead.
  Stream<List<Map<String, dynamic>>> incomingRequests(String myUid) => _db
      .collection(AppConstants.palRequestsCol)
      .where('toUid', isEqualTo: myUid)
      .snapshots()
      .map((s) {
        final list = s.docs.map((d) => d.data()).toList();
        list.sort((a, b) {
          final ta = a['createdAt'];
          final tb = b['createdAt'];
          if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
          return 0;
        });
        return list;
      });

  Future<List<AppUser>> _fetchUsers(List<String> uids) async {
    if (uids.isEmpty) return [];
    final results = <AppUser>[];
    for (var i = 0; i < uids.length; i += 30) {
      final chunk = uids.sublist(i, (i + 30).clamp(0, uids.length));
      final snap = await _db
          .collection(AppConstants.usersCol)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      results.addAll(snap.docs.map((d) => AppUser.fromDoc(d)));
    }
    return results;
  }

  /// Case-insensitive name search over a cached user list (matches anywhere in
  /// the display name). Loads up to 500 users — fine for the beta; move to
  /// tokenised search before public launch (see BACKLOG SC1).
  Future<List<AppUser>> searchUsers(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final fresh = _userCacheAt != null &&
        DateTime.now().difference(_userCacheAt!) < const Duration(seconds: 30);
    if (_userCache == null || !fresh) {
      final snap =
          await _db.collection(AppConstants.usersCol).limit(500).get();
      _userCache = snap.docs.map((d) => AppUser.fromDoc(d)).toList();
      _userCacheAt = DateTime.now();
    }

    return _userCache!
        .where((u) => u.displayName.toLowerCase().contains(q))
        .take(20)
        .toList();
  }

  // ── One-off migration from the old follows model ───────────────────────────

  /// Converts a user's legacy follows into the Pals model, once. Mutual follows
  /// become pals (both docs written — so the pair is migrated even if the other
  /// person never opens the app); a one-directional follow becomes a pending
  /// pal request from the follower. Guarded by `palsMigrated` on the user doc.
  Future<void> migrateIfNeeded(String uid) async {
    final userRef = _db.collection(AppConstants.usersCol).doc(uid);
    final userDoc = await userRef.get();
    if ((userDoc.data()?['palsMigrated'] as bool?) == true) return;

    final followingSnap = await _db
        .collection(AppConstants.followsCol)
        .where('followerUid', isEqualTo: uid)
        .get();
    final followerSnap = await _db
        .collection(AppConstants.followsCol)
        .where('followingUid', isEqualTo: uid)
        .get();

    final following =
        followingSnap.docs.map((d) => d.data()['followingUid'] as String).toSet();
    final followers =
        followerSnap.docs.map((d) => d.data()['followerUid'] as String).toSet();
    final mutual = following.intersection(followers);

    final batch = _db.batch();
    for (final other in mutual) {
      _writePalPair(batch, uid, other);
    }
    // I follow them, they don't follow me back → pending request from me.
    for (final other in following.difference(followers)) {
      batch.set(
        _db.collection(AppConstants.palRequestsCol).doc('${uid}_$other'),
        {
          'fromUid': uid,
          'toUid': other,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
    }
    batch.update(userRef, {'palsMigrated': true});
    await batch.commit();
  }
}
