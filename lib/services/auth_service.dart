import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../theme.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _google = GoogleSignIn();

  GoogleSignIn get googleSignIn => _google;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<AppUser?> signInWithGoogle() async {
    try {
      final googleUser = await _google.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await _auth.signInWithCredential(credential);
      final user = userCred.user!;

      // Check if profile exists
      final doc = await _db
          .collection(AppConstants.usersCol)
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        // Create new profile
        final appUser = AppUser(
          uid: user.uid,
          displayName: user.displayName ?? 'Runner',
          email: user.email ?? '',
          photoUrl: user.photoURL,
          isPublic: true,
          createdAt: DateTime.now(),
        );
        await _db
            .collection(AppConstants.usersCol)
            .doc(user.uid)
            .set(appUser.toMap());
        return appUser;
      }

      return AppUser.fromDoc(doc);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _google.signOut();
    await _auth.signOut();
  }

  // ── Account deletion (GDPR right to erasure) ───────────────────────────────

  /// Re-authenticates the current user with a fresh Google credential. Firebase
  /// requires a recent login before sensitive actions like account deletion;
  /// doing it unconditionally also gives a clear "are you sure" moment.
  Future<void> reauthenticateWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not signed in');
    final googleUser = await _google.signIn();
    if (googleUser == null) throw Exception('cancelled');
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    await user.reauthenticateWithCredential(credential);
  }

  /// Permanently erases all of [uid]'s personal data, then deletes the auth
  /// account itself. Call [reauthenticateWithGoogle] first. Data is removed
  /// while still authenticated; the auth account goes last so the writes are
  /// permitted. Races themselves are left intact (they're shared, not personal).
  Future<void> deleteAccount(String uid) async {
    await _deleteUserData(uid);
    await _auth.currentUser?.delete();
    await _google.signOut();
  }

  Future<void> _deleteUserData(String uid) async {
    // Reviews, attendances and activity entries I authored.
    await _deleteByQuery(
        _db.collection(AppConstants.reviewsCol).where('userId', isEqualTo: uid));
    await _deleteByQuery(_db
        .collection(AppConstants.attendancesCol)
        .where('userId', isEqualTo: uid));
    await _deleteByQuery(_db
        .collection(AppConstants.activitiesCol)
        .where('userId', isEqualTo: uid));
    // Pals — both mirrored docs of every friendship I'm in.
    await _deleteByQuery(
        _db.collection(AppConstants.palsCol).where('ownerUid', isEqualTo: uid));
    await _deleteByQuery(
        _db.collection(AppConstants.palsCol).where('otherUid', isEqualTo: uid));
    // Pal requests I sent or received.
    await _deleteByQuery(_db
        .collection(AppConstants.palRequestsCol)
        .where('fromUid', isEqualTo: uid));
    await _deleteByQuery(_db
        .collection(AppConstants.palRequestsCol)
        .where('toUid', isEqualTo: uid));
    // Profile photo (may not exist — ignore a missing-object error).
    try {
      await FirebaseStorage.instance
          .ref()
          .child('profile_photos/$uid.jpg')
          .delete();
    } catch (_) {}
    // Finally the profile doc itself.
    await _db.collection(AppConstants.usersCol).doc(uid).delete();
  }

  /// Deletes every doc a query matches, one at a time. Individual deletes (not a
  /// batch) keep this robust: a single denied/missing doc can't fail the rest —
  /// see the batch-delete-of-missing-doc gotcha.
  Future<void> _deleteByQuery(Query query) async {
    final snap = await query.get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  Future<AppUser?> getUser(String uid) async {
    final doc = await _db.collection(AppConstants.usersCol).doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromDoc(doc);
  }

  Future<void> updateProfile({
    required String uid,
    String? displayName,
    String? bio,
    String? photoUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (displayName != null) updates['displayName'] = displayName;
    if (bio != null) updates['bio'] = bio;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;

    await _db.collection(AppConstants.usersCol).doc(uid).update(updates);
  }

  Stream<AppUser?> userStream(String uid) => _db
      .collection(AppConstants.usersCol)
      .doc(uid)
      .snapshots()
      .map((s) => s.exists ? AppUser.fromDoc(s) : null);
}
