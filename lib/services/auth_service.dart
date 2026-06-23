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
    // Every collection holding this user's personal data, with the field that
    // ties a doc back to them. Legacy follows (both directions) are included
    // because if they survive, signing in again re-runs the one-off pals
    // migration on a fresh profile doc and resurrects the old connections —
    // clearing them keeps a re-signup truly empty.
    final queries = <Query>[
      // Reviews, attendances and activity entries I authored.
      _db.collection(AppConstants.reviewsCol).where('userId', isEqualTo: uid),
      _db.collection(AppConstants.attendancesCol).where('userId', isEqualTo: uid),
      _db.collection(AppConstants.activitiesCol).where('userId', isEqualTo: uid),
      // Pals — both mirrored docs of every friendship I'm in.
      _db.collection(AppConstants.palsCol).where('ownerUid', isEqualTo: uid),
      _db.collection(AppConstants.palsCol).where('otherUid', isEqualTo: uid),
      // Pal requests I sent or received.
      _db.collection(AppConstants.palRequestsCol).where('fromUid', isEqualTo: uid),
      _db.collection(AppConstants.palRequestsCol).where('toUid', isEqualTo: uid),
      // Legacy follows (both directions).
      _db.collection(AppConstants.followsCol).where('followerUid', isEqualTo: uid),
      _db.collection(AppConstants.followsCol).where('followingUid', isEqualTo: uid),
    ];

    // Run the queries together, then delete every matched doc concurrently.
    // Individual deletes (not a WriteBatch) sidestep the batch-delete-of-missing-
    // doc gotcha; gathering failures means one denied/missing doc can't abort the
    // rest, while the throw below keeps erasure loud — never silently partial.
    final snaps = await Future.wait(queries.map((q) => q.get()));
    final refs = [
      for (final snap in snaps) ...snap.docs.map((d) => d.reference),
    ];
    final failures = <Object>[];
    await Future.wait(refs.map((ref) async {
      try {
        await ref.delete();
      } catch (e) {
        failures.add(e);
      }
    }));

    // Profile photo (may not exist — a missing object is not a failure).
    try {
      await FirebaseStorage.instance
          .ref()
          .child('profile_photos/$uid.jpg')
          .delete();
    } catch (_) {}

    // If any data delete failed, stop before removing the profile doc / auth
    // account: the account stays recoverable and a retry can finish the job,
    // rather than leaving an orphaned auth account with stray personal data.
    if (failures.isNotEmpty) {
      throw Exception(
          'Account deletion incomplete: ${failures.length} item(s) could not be '
          'deleted (first error: ${failures.first}). Please try again.');
    }

    // Finally the profile doc itself.
    await _db.collection(AppConstants.usersCol).doc(uid).delete();
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
