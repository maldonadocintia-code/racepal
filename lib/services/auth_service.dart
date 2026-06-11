import 'package:firebase_auth/firebase_auth.dart';
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

  Future<AppUser?> getUser(String uid) async {
    final doc = await _db.collection(AppConstants.usersCol).doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromDoc(doc);
  }

  Future<void> updateProfile({
    required String uid,
    String? displayName,
    String? bio,
    bool? isPublic,
    String? photoUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (displayName != null) updates['displayName'] = displayName;
    if (bio != null) updates['bio'] = bio;
    if (isPublic != null) updates['isPublic'] = isPublic;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;

    await _db.collection(AppConstants.usersCol).doc(uid).update(updates);
  }

  Stream<AppUser?> userStream(String uid) => _db
      .collection(AppConstants.usersCol)
      .doc(uid)
      .snapshots()
      .map((s) => s.exists ? AppUser.fromDoc(s) : null);
}
