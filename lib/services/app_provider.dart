import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user_model.dart';
import '../models/race_model.dart';
import '../models/review_model.dart';
import '../services/auth_service.dart';
import '../services/race_service.dart';
import '../services/pal_service.dart';

class AppProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final RaceService _raceService = RaceService();
  final PalService _palService = PalService();

  AppUser? _currentUser;
  List<String> _palUids = [];
  bool _loading = false;
  String? _error;

  StreamSubscription? _userSub;
  StreamSubscription? _palsSub;

  AppUser? get currentUser => _currentUser;
  List<String> get palUids => _palUids;
  bool get loading => _loading;
  String? get error => _error;
  bool get isLoggedIn => _currentUser != null;

  AuthService get authService => _authService;
  RaceService get raceService => _raceService;
  PalService get palService => _palService;

  void init() {
    _authService.authStateChanges.listen((firebaseUser) {
      if (firebaseUser != null) {
        _palService
            .migrateIfNeeded(firebaseUser.uid)
            .catchError((_) {}); // one-off follows -> pals, guarded internally
        _listenToUser(firebaseUser.uid);
        _listenToPals(firebaseUser.uid);
        _autoCompletePastRaces(firebaseUser.uid);
      } else {
        _currentUser = null;
        _palUids = [];
        _userSub?.cancel();
        _palsSub?.cancel();
        notifyListeners();
      }
    });
  }

  /// Flips 'going' to 'attended' for races whose date has passed.
  Future<void> _autoCompletePastRaces(String uid) async {
    try {
      final atts = await _raceService.userAttendances(uid).first;
      for (final a in atts.where((a) => a.status == AttendanceStatus.going)) {
        final race = await _raceService.getRace(a.raceId);
        if (race != null && race.isPast) {
          await _raceService.setAttendance(
            raceId: a.raceId,
            userId: uid,
            status: AttendanceStatus.attended,
          );
        }
      }
    } catch (_) {
      // Non-critical; retried on next sign-in
    }
  }

  void _listenToUser(String uid) {
    _userSub?.cancel();
    _userSub = _authService.userStream(uid).listen((user) {
      _currentUser = user;
      notifyListeners();
    });
  }

  void _listenToPals(String uid) {
    _palsSub?.cancel();
    _palsSub = _palService.palUids(uid).listen((uids) {
      _palUids = uids;
      notifyListeners();
    });
  }

  Future<void> signInWithGoogle() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _authService.signInWithGoogle();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }

  /// GDPR right to erasure. Re-authenticates (a fresh Google sign-in), then
  /// permanently deletes all the user's data and their auth account. The
  /// auth-state listener then fires null and the app returns to the login
  /// screen. Throws if the user cancels the re-auth prompt.
  Future<void> deleteAccount() async {
    final uid = _currentUser?.uid;
    if (uid == null) return;
    await _authService.reauthenticateWithGoogle();
    await _authService.deleteAccount(uid);
  }

  Future<void> updateProfile({
    String? displayName,
    String? bio,
    String? photoUrl,
  }) async {
    if (_currentUser == null) return;
    await _authService.updateProfile(
      uid: _currentUser!.uid,
      displayName: displayName,
      bio: bio,
      photoUrl: photoUrl,
    );
  }

  Future<String> uploadProfilePhoto(File file) async {
    if (_currentUser == null) throw Exception('Not signed in');
    final ref = FirebaseStorage.instance
        .ref()
        .child('profile_photos/${_currentUser!.uid}.jpg');
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();
    await _authService.updateProfile(uid: _currentUser!.uid, photoUrl: url);
    return url;
  }

  Future<PalStatus> getPalStatus(String otherUid) async {
    if (_currentUser == null) return PalStatus.none;
    return _palService.getStatus(
      uid: _currentUser!.uid,
      otherUid: otherUid,
    );
  }

  /// Drives the pal button: the action depends on the current status.
  Future<void> togglePal(AppUser target) async {
    if (_currentUser == null) return;
    final me = _currentUser!.uid;
    final status = await getPalStatus(target.uid);
    switch (status) {
      case PalStatus.none:
        await _palService.sendRequest(fromUid: me, toUid: target.uid);
        break;
      case PalStatus.requested:
        await _palService.cancelRequest(fromUid: me, toUid: target.uid);
        break;
      case PalStatus.incoming:
        await _palService.acceptRequest(requesterUid: target.uid, myUid: me);
        break;
      case PalStatus.pals:
        await _palService.removePal(uid: me, otherUid: target.uid);
        break;
      case PalStatus.self:
        break;
    }
  }

  Future<void> acceptPalRequest(String requesterUid) async {
    if (_currentUser == null) return;
    await _palService.acceptRequest(
        requesterUid: requesterUid, myUid: _currentUser!.uid);
  }

  Future<void> declinePalRequest(String requesterUid) async {
    if (_currentUser == null) return;
    await _palService.declineRequest(
        requesterUid: requesterUid, myUid: _currentUser!.uid);
  }

  Future<void> addRace(Race race) async {
    await _raceService.addRace(race);
  }

  Future<void> setAttendance({
    required String raceId,
    required String raceName,
    required AttendanceStatus status,
  }) async {
    if (_currentUser == null) return;
    await _raceService.setAttendance(
      raceId: raceId,
      userId: _currentUser!.uid,
      status: status,
    );
    // Post to activity feed
    await _raceService.postActivity(ActivityItem(
      id: '',
      userId: _currentUser!.uid,
      userName: _currentUser!.displayName,
      userPhotoUrl: _currentUser!.photoUrl,
      type: status == AttendanceStatus.attended ? 'attended' : 'going',
      raceId: raceId,
      raceName: raceName,
      createdAt: DateTime.now(),
    ));
  }

  Future<void> submitReview({
    required String raceId,
    required String raceName,
    required double rating,
    String? body,
    String? finishTime,
    bool isPublic = true,
    bool recommend = true,
  }) async {
    if (_currentUser == null) return;
    final review = Review(
      id: '',
      raceId: raceId,
      userId: _currentUser!.uid,
      userName: _currentUser!.displayName,
      userPhotoUrl: _currentUser!.photoUrl,
      rating: rating,
      body: body,
      finishTime: finishTime,
      isPublic: isPublic,
      recommend: recommend,
      createdAt: DateTime.now(),
    );
    await _raceService.addReview(review);
    await _raceService.postActivity(ActivityItem(
      id: '',
      userId: _currentUser!.uid,
      userName: _currentUser!.displayName,
      userPhotoUrl: _currentUser!.photoUrl,
      type: 'review',
      raceId: raceId,
      raceName: raceName,
      rating: rating,
      reviewBody: body,
      createdAt: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _palsSub?.cancel();
    super.dispose();
  }
}
