import 'dart:convert';
import 'package:flutter/services.dart';

/// A UK town/city with coordinates, used to turn a typed place into a map
/// point for radius search. Bundled offline (assets/uk_places.json) — free,
/// no geocoding API.
class UkPlace {
  final String name;
  final double lat;
  final double lng;
  const UkPlace(this.name, this.lat, this.lng);
}

class PlacesService {
  static List<UkPlace>? _cache;

  static Future<List<UkPlace>> _load() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/uk_places.json');
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    _cache = list
        .map((p) => UkPlace(
              p['name'] as String,
              (p['lat'] as num).toDouble(),
              (p['lng'] as num).toDouble(),
            ))
        .toList();
    return _cache!;
  }

  /// Type-ahead search: places whose name contains [query].
  /// Prefix matches are ranked first, then alphabetical.
  static Future<List<UkPlace>> search(String query, {int limit = 8}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final places = await _load();
    final matches =
        places.where((p) => p.name.toLowerCase().contains(q)).toList();
    matches.sort((a, b) {
      final ap = a.name.toLowerCase().startsWith(q) ? 0 : 1;
      final bp = b.name.toLowerCase().startsWith(q) ? 0 : 1;
      if (ap != bp) return ap - bp;
      return a.name.compareTo(b.name);
    });
    return matches.take(limit).toList();
  }
}
