import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;
  final String? bio;
  final bool isPublic;
  final int followersCount;
  final int followingCount;
  final int racesCount;
  final DateTime createdAt;

  AppUser({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
    this.bio,
    this.isPublic = true,
    this.followersCount = 0,
    this.followingCount = 0,
    this.racesCount = 0,
    required this.createdAt,
  });

  factory AppUser.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      displayName: data['displayName'] ?? '',
      email: data['email'] ?? '',
      photoUrl: data['photoUrl'],
      bio: data['bio'],
      isPublic: data['isPublic'] ?? true,
      followersCount: data['followersCount'] ?? 0,
      followingCount: data['followingCount'] ?? 0,
      racesCount: data['racesCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'displayName': displayName,
    'email': email,
    'photoUrl': photoUrl,
    'bio': bio,
    'isPublic': isPublic,
    'followersCount': followersCount,
    'followingCount': followingCount,
    'racesCount': racesCount,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  AppUser copyWith({
    String? displayName,
    String? photoUrl,
    String? bio,
    bool? isPublic,
    int? followersCount,
    int? followingCount,
    int? racesCount,
  }) => AppUser(
    uid: uid,
    displayName: displayName ?? this.displayName,
    email: email,
    photoUrl: photoUrl ?? this.photoUrl,
    bio: bio ?? this.bio,
    isPublic: isPublic ?? this.isPublic,
    followersCount: followersCount ?? this.followersCount,
    followingCount: followingCount ?? this.followingCount,
    racesCount: racesCount ?? this.racesCount,
    createdAt: createdAt,
  );
}

/// Relationship between the current user and another, in the Pals model.
///  - none: no connection
///  - requested: you've sent them a pal request (awaiting their accept)
///  - incoming: they've sent you a pal request (you can accept / decline)
///  - pals: mutual — you're pals
///  - self: it's you
enum PalStatus { none, requested, incoming, pals, self }
