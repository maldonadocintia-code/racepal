import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String id;
  final String raceId;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final double rating; // 1–5 (displayed as ⚡)
  final String? body;
  final DateTime createdAt;
  final String? finishTime; // e.g. "24:32"
  final bool recommend;

  Review({
    required this.id,
    required this.raceId,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    required this.rating,
    this.body,
    required this.createdAt,
    this.finishTime,
    this.recommend = true,
  });

  factory Review.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Review(
      id: doc.id,
      raceId: d['raceId'] ?? '',
      userId: d['userId'] ?? '',
      userName: d['userName'] ?? '',
      userPhotoUrl: d['userPhotoUrl'],
      rating: (d['rating'] as num?)?.toDouble() ?? 3.0,
      body: d['body'],
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      finishTime: d['finishTime'],
      recommend: d['recommend'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'raceId': raceId,
    'userId': userId,
    'userName': userName,
    'userPhotoUrl': userPhotoUrl,
    'rating': rating,
    'body': body,
    'createdAt': Timestamp.fromDate(createdAt),
    'finishTime': finishTime,
    'recommend': recommend,
  };
}

enum AttendanceStatus { going, attended, interested }

class Attendance {
  final String id;
  final String raceId;
  final String userId;
  final AttendanceStatus status;
  final DateTime createdAt;

  Attendance({
    required this.id,
    required this.raceId,
    required this.userId,
    required this.status,
    required this.createdAt,
  });

  factory Attendance.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Attendance(
      id: doc.id,
      raceId: d['raceId'] ?? '',
      userId: d['userId'] ?? '',
      status: AttendanceStatus.values.firstWhere(
        (e) => e.name == d['status'],
        orElse: () => AttendanceStatus.going,
      ),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'raceId': raceId,
    'userId': userId,
    'status': status.name,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}

class ActivityItem {
  final String id;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final String type; // 'review' | 'going' | 'attended'
  final String raceId;
  final String raceName;
  final double? rating;
  final String? reviewBody;
  final DateTime createdAt;

  ActivityItem({
    required this.id,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    required this.type,
    required this.raceId,
    required this.raceName,
    this.rating,
    this.reviewBody,
    required this.createdAt,
  });

  factory ActivityItem.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ActivityItem(
      id: doc.id,
      userId: d['userId'] ?? '',
      userName: d['userName'] ?? '',
      userPhotoUrl: d['userPhotoUrl'],
      type: d['type'] ?? '',
      raceId: d['raceId'] ?? '',
      raceName: d['raceName'] ?? '',
      rating: (d['rating'] as num?)?.toDouble(),
      reviewBody: d['reviewBody'],
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'userName': userName,
    'userPhotoUrl': userPhotoUrl,
    'type': type,
    'raceId': raceId,
    'raceName': raceName,
    'rating': rating,
    'reviewBody': reviewBody,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}
