import 'package:cloud_firestore/cloud_firestore.dart';

enum RaceCategory { parkrun, race }

class Race {
  final String id;
  final String name;
  final String location;
  final String type; // parkrun / 5K / 10K etc
  final RaceCategory category;
  final DateTime date;
  final String? website;
  final String? description;
  final double? lat;
  final double? lng;
  final String createdBy; // uid or 'system'
  final int attendeeCount;
  final double averageRating;
  final int reviewCount;

  Race({
    required this.id,
    required this.name,
    required this.location,
    required this.type,
    required this.category,
    required this.date,
    this.website,
    this.description,
    this.lat,
    this.lng,
    required this.createdBy,
    this.attendeeCount = 0,
    this.averageRating = 0.0,
    this.reviewCount = 0,
  });

  factory Race.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Race(
      id: doc.id,
      name: d['name'] ?? '',
      location: d['location'] ?? '',
      type: d['type'] ?? 'Other',
      category: d['category'] == 'parkrun'
          ? RaceCategory.parkrun
          : RaceCategory.race,
      date: (d['date'] as Timestamp).toDate(),
      website: d['website'],
      description: d['description'],
      lat: (d['lat'] as num?)?.toDouble(),
      lng: (d['lng'] as num?)?.toDouble(),
      createdBy: d['createdBy'] ?? '',
      attendeeCount: d['attendeeCount'] ?? 0,
      averageRating: (d['averageRating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: d['reviewCount'] ?? 0,
    );
  }

  factory Race.fromParkrunJson(Map<String, dynamic> j, DateTime date) => Race(
    id: j['id'],
    name: '${j['name']} parkrun',
    location: j['location'],
    type: 'parkrun',
    category: RaceCategory.parkrun,
    date: date,
    lat: (j['lat'] as num?)?.toDouble(),
    lng: (j['lng'] as num?)?.toDouble(),
    createdBy: 'system',
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'location': location,
    'type': type,
    'category': category.name,
    'date': Timestamp.fromDate(date),
    'website': website,
    'description': description,
    'lat': lat,
    'lng': lng,
    'createdBy': createdBy,
    'attendeeCount': attendeeCount,
    'averageRating': averageRating,
    'reviewCount': reviewCount,
  };

  bool get isParkrun => category == RaceCategory.parkrun;
  bool get isUpcoming => date.isAfter(DateTime.now());
  bool get isPast => date.isBefore(DateTime.now());
}
