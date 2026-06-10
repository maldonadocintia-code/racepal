import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../theme.dart';

class FollowService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Follow status ──────────────────────────────────────────────────────────

  Future<FollowStatus> getFollowStatus({
    required String fromUid,
    required String toUid,
  }) async {
    if (fromUid == toUid) return FollowStatus.self;

    final followDoc = await _db
        .collection(AppConstants.followsCol)
        .doc('${fromUid}_$toUid')
        .get();
    if (followDoc.exists) return FollowStatus.following;

    final requestDoc = await _db
        .collection(AppConstants.followRequestsCol)
        .doc('${fromUid}_$toUid')
        .get();
    if (requestDoc.exists) return FollowStatus.requested;

    return FollowStatus.none;
  }

  // ── Follow / unfollow ──────────────────────────────────────────────────────

  Future<void> follow({
    required String fromUid,
    required String toUid,
    required bool targetIsPublic,
  }) async {
    if (targetIsPublic) {
      // Direct follow
      final batch = _db.batch();

      batch.set(
        _db.collection(AppConstants.followsCol).doc('${fromUid}_$toUid'),
        {
          'followerUid': fromUid,
          'followingUid': toUid,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );

      batch.update(
        _db.collection(AppConstants.usersCol).doc(fromUid),
        {'followingCount': FieldValue.increment(1)},
      );
      batch.update(
        _db.collection(AppConstants.usersCol).doc(toUid),
        {'followersCount': FieldValue.increment(1)},
      );

      await batch.commit();
    } else {
      // Request to follow
      await _db
          .collection(AppConstants.followRequestsCol)
          .doc('${fromUid}_$toUid')
          .set({
        'requesterUid': fromUid,
        'targetUid': toUid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> unfollow({
    required String fromUid,
    required String toUid,
  }) async {
    final batch = _db.batch();

    batch.delete(
      _db.collection(AppConstants.followsCol).doc('${fromUid}_$toUid'),
    );
    batch.update(
      _db.collection(AppConstants.usersCol).doc(fromUid),
      {'followingCount': FieldValue.increment(-1)},
    );
    batch.update(
      _db.collection(AppConstants.usersCol).doc(toUid),
      {'followersCount': FieldValue.increment(-1)},
    );

    await batch.commit();
  }

  Future<void> cancelRequest({
    required String fromUid,
    required String toUid,
  }) async {
    await _db
        .collection(AppConstants.followRequestsCol)
        .doc('${fromUid}_$toUid')
        .delete();
  }

  // ── Accepting / rejecting follow requests ─────────────────────────────────

  Future<void> acceptRequest({
    required String requesterUid,
    required String targetUid,
  }) async {
    final batch = _db.batch();

    // Delete the request
    batch.delete(
      _db
          .collection(AppConstants.followRequestsCol)
          .doc('${requesterUid}_$targetUid'),
    );

    // Create follow
    batch.set(
      _db
          .collection(AppConstants.followsCol)
          .doc('${requesterUid}_$targetUid'),
      {
        'followerUid': requesterUid,
        'followingUid': targetUid,
        'createdAt': FieldValue.serverTimestamp(),
      },
    );

    // Update counts
    batch.update(
      _db.collection(AppConstants.usersCol).doc(requesterUid),
      {'followingCount': FieldValue.increment(1)},
    );
    batch.update(
      _db.collection(AppConstants.usersCol).doc(targetUid),
      {'followersCount': FieldValue.increment(1)},
    );

    await batch.commit();
  }

  Future<void> rejectRequest({
    required String requesterUid,
    required String targetUid,
  }) async {
    await _db
        .collection(AppConstants.followRequestsCol)
        .doc('${requesterUid}_$targetUid')
        .delete();
  }

  // ── Queries ────────────────────────────────────────────────────────────────

  Stream<List<String>> followingUids(String uid) => _db
      .collection(AppConstants.followsCol)
      .where('followerUid', isEqualTo: uid)
      .snapshots()
      .map(
        (s) => s.docs
            .map((d) => d.data()['followingUid'] as String)
            .toList(),
      );

  Stream<List<String>> followerUids(String uid) => _db
      .collection(AppConstants.followsCol)
      .where('followingUid', isEqualTo: uid)
      .snapshots()
      .map(
        (s) => s.docs
            .map((d) => d.data()['followerUid'] as String)
            .toList(),
      );

  Stream<List<Map<String, dynamic>>> pendingRequests(String targetUid) => _db
      .collection(AppConstants.followRequestsCol)
      .where('targetUid', isEqualTo: targetUid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList());

  Future<List<AppUser>> searchUsers(String query) async {
    if (query.isEmpty) return [];
    final snap = await _db
        .collection(AppConstants.usersCol)
        .orderBy('displayName')
        .startAt([query])
        .endAt(['$query\uf8ff'])
        .limit(15)
        .get();
    return snap.docs.map((d) => AppUser.fromDoc(d)).toList();
  }
}
