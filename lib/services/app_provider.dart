import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/race_model.dart';
import '../models/review_model.dart';
import '../services/auth_service.dart';
import '../services/race_service.dart';
import '../services/follow_service.dart';

class AppProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final RaceService _raceService = RaceService();
  final FollowService _followService = FollowService();

  AppUser? _currentUser;
  List<String> _followingUids = [];
  bool _loading = false;
  String? _error;

  StreamSubscription? _userSub;
  StreamSubscription? _followingSub;

  AppUser? get currentUser => _currentUser;
  List<String> get followingUids => _followingUids;
  bool get loading => _loading;
  String? get error => _error;
  bool get isLoggedIn => _currentUser != null;

  AuthService get authService => _authService;
  RaceService get raceService => _raceService;
  FollowService get followService => _followService;

  void init() {
    _authService.authStateChanges.listen((firebaseUser) {
      if (firebaseUser != null) {
        _listenToUser(firebaseUser.uid);
        _listenToFollowing(firebaseUser.uid);
        _autoCompletePastRaces(firebaseUser.uid);
      } else {
        _currentUser = null;
        _followingUids = [];
        _userSub?.cancel();
        _followingSub?.cancel();
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

  void _listenToFollowing(String uid) {
    _followingSub?.cancel();
    _followingSub = _followService.followingUids(uid).listen((uids) {
      _followingUids = uids;
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

  Future<void> updateProfile({
    String? displayName,
    String? bio,
    bool? isPublic,
    String? photoUrl,
  }) async {
    if (_currentUser == null) return;
    await _authService.updateProfile(
      uid: _currentUser!.uid,
      displayName: displayName,
      bio: bio,
      isPublic: isPublic,
      photoUrl: photoUrl,
    );
  }

  Future<FollowStatus> getFollowStatus(String targetUid) async {
    if (_currentUser == null) return FollowStatus.none;
    return _followService.getFollowStatus(
      fromUid: _currentUser!.uid,
      toUid: targetUid,
    );
  }

  Future<void> toggleFollow(AppUser target) async {
    if (_currentUser == null) return;
    final status = await getFollowStatus(target.uid);
    switch (status) {
      case FollowStatus.none:
        await _followService.follow(
          fromUid: _currentUser!.uid,
          toUid: target.uid,
          targetIsPublic: target.isPublic,
        );
        break;
      case FollowStatus.following:
        await _followService.unfollow(
          fromUid: _currentUser!.uid,
          toUid: target.uid,
        );
        break;
      case FollowStatus.requested:
        await _followService.cancelRequest(
          fromUid: _currentUser!.uid,
          toUid: target.uid,
        );
        break;
      case FollowStatus.self:
        break;
    }
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
    _followingSub?.cancel();
    super.dispose();
  }
}
