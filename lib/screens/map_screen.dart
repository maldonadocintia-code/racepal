import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/race_model.dart';
import '../models/review_model.dart';
import '../services/app_provider.dart';
import '../services/places_service.dart';
import '../utils/geo.dart';
import '../widgets/parkrun_helpers.dart';
import '../theme.dart';
import 'race_detail_screen.dart';
import 'add_race_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

enum _Seg { all, parkruns, races }

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};

  // Search centre (typed place) + radius in miles. Null place = no location
  // filter yet (show everything upcoming).
  UkPlace? _place;
  double _radius = 10;

  _Seg _seg = _Seg.all;
  bool _isListView = true; // list is the default — faster, no map-tile cost

  bool _parkrunsLoaded = false;
  bool _eventsLoaded = false;
  List<Map<String, dynamic>> _parkrunData = [];
  List<Map<String, dynamic>> _eventData = [];
  List<Race> _races = [];
  late final Stream<List<Race>> _racesStream;

  Map<String, dynamic>? _selectedParkrun;
  Map<String, dynamic>? _selectedEvent;
  Race? _selectedRace;

  static const _ukCenter = LatLng(53.0, -1.8);

  @override
  void initState() {
    super.initState();
    _racesStream = context.read<AppProvider>().raceService.upcomingRaces();
    _loadParkruns();
    _loadEvents();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadParkruns() async {
    if (_parkrunsLoaded) return;
    final raw = await rootBundle.loadString('assets/parkruns_uk.json');
    _parkrunData = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    _parkrunsLoaded = true;
    _rebuild();
  }

  Future<void> _loadEvents() async {
    if (_eventsLoaded) return;
    // Curated, verified Manchester-area race set (replaces the unreliable
    // bundled findarace/major data — see assets/manchester_races.json).
    final raw = await rootBundle.loadString('assets/manchester_races.json');
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    final seen = <String>{};
    _eventData = list.where((e) {
      final key = '${e['name']}_${e['startDate']}';
      if (!seen.add(key)) return false;
      return DateTime.tryParse(e['startDate'] ?? '') != null;
    }).toList();
    _eventsLoaded = true;
    _rebuild();
  }

  // ── Geo helpers ──────────────────────────────────────────────────────────

  double? _distOf(double? lat, double? lng) {
    if (_place == null || lat == null || lng == null) return null;
    return milesBetween(_place!.lat, _place!.lng, lat, lng);
  }

  static DateTime _nextSaturday() {
    final now = DateTime.now();
    var d = DateTime(now.year, now.month, now.day, 9);
    while (d.weekday != DateTime.saturday) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }

  double _zoomForRadius(double r) {
    if (r <= 3) return 11.5;
    if (r <= 6) return 11;
    if (r <= 12) return 10;
    if (r <= 25) return 9;
    return 8;
  }

  void _moveCamera() {
    if (_mapController != null && _place != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(
          LatLng(_place!.lat, _place!.lng), _zoomForRadius(_radius)));
    }
  }

  // ── Build the filtered, sorted result set ─────────────────────────────────

  List<_Result> _buildResults() {
    final res = <_Result>[];
    final now = DateTime.now();
    final nextSat = _nextSaturday();

    // Explore filters by location + radius only. Finding a race you already
    // know by name lives on the Plan tab (tap a date to add it).
    bool keep(double? dist) {
      if (_place != null) return dist != null && dist <= _radius;
      return true;
    }

    if (_seg != _Seg.races) {
      for (final p in _parkrunData) {
        final lat = (p['lat'] as num?)?.toDouble();
        final lng = (p['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        final dist = _distOf(lat, lng);
        final title = '${p['name']} parkrun';
        final address = (p['location'] ?? '') as String;
        if (!keep(dist)) continue;
        res.add(_Result(
          markerKey: 'pr_${p['id']}',
          lat: lat,
          lng: lng,
          isParkrun: true,
          distanceMi: dist,
          sortDate: nextSat,
          title: title,
          address: address,
          dateLabel: 'Saturdays · 9:00am',
          rating: null,
          onSelect: () => setState(() {
            _selectedParkrun = p;
            _selectedEvent = null;
            _selectedRace = null;
          }),
        ));
      }
    }

    if (_seg != _Seg.parkruns) {
      for (final e in _eventData) {
        final lat = (e['lat'] as num?)?.toDouble();
        final lng = (e['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        final d = DateTime.tryParse(e['startDate'] ?? '');
        if (d == null || d.isBefore(now)) continue;
        final dist = _distOf(lat, lng);
        final title = (e['name'] ?? '') as String;
        final address = (e['address'] ?? e['city'] ?? '') as String;
        if (!keep(dist)) continue;
        res.add(_Result(
          markerKey: 'fa_${e['url']}',
          lat: lat,
          lng: lng,
          isParkrun: false,
          distanceMi: dist,
          sortDate: d,
          title: title,
          address: address,
          dateLabel: DateFormat('EEE d MMM yyyy').format(d),
          rating: null,
          onSelect: () => setState(() {
            _selectedEvent = e;
            _selectedParkrun = null;
            _selectedRace = null;
          }),
        ));
      }
      for (final r in _races) {
        // Skip system-created Firestore copies of bundled races — the asset
        // catalogue is the single source for those, so they'd otherwise show
        // twice. Only genuinely user-created races come from Firestore here.
        if (r.isParkrun ||
            r.createdBy == 'system' ||
            r.lat == null ||
            r.lng == null ||
            !r.isUpcoming) {
          continue;
        }
        final dist = _distOf(r.lat, r.lng);
        if (!keep(dist)) continue;
        res.add(_Result(
          markerKey: 'race_${r.id}',
          lat: r.lat!,
          lng: r.lng!,
          isParkrun: false,
          distanceMi: dist,
          sortDate: r.date,
          title: r.name,
          address: r.location,
          dateLabel: DateFormat('EEE d MMM yyyy').format(r.date),
          rating: r.reviewCount > 0
              ? '${r.averageRating.toStringAsFixed(1)} (${r.reviewCount})'
              : null,
          onSelect: () => setState(() {
            _selectedRace = r;
            _selectedParkrun = null;
            _selectedEvent = null;
          }),
        ));
      }
    }

    if (_place != null) {
      res.sort((a, b) =>
          (a.distanceMi ?? 1e9).compareTo(b.distanceMi ?? 1e9));
    } else {
      res.sort((a, b) => a.sortDate.compareTo(b.sortDate));
    }
    return res;
  }

  void _rebuild() {
    final results = _buildResults();
    final markers = <Marker>{};
    for (final r in results) {
      markers.add(Marker(
        markerId: MarkerId(r.markerKey),
        position: LatLng(r.lat, r.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(
            r.isParkrun ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueOrange),
        onTap: r.onSelect,
      ));
    }
    final circles = <Circle>{};
    if (_place != null) {
      circles.add(Circle(
        circleId: const CircleId('radius'),
        center: LatLng(_place!.lat, _place!.lng),
        radius: _radius * 1609.34,
        fillColor: AppTheme.primary.withValues(alpha: 0.10),
        strokeColor: AppTheme.primary.withValues(alpha: 0.6),
        strokeWidth: 2,
      ));
    }
    if (!mounted) return;
    setState(() {
      _markers
        ..clear()
        ..addAll(markers);
      _circles
        ..clear()
        ..addAll(circles);
    });
  }

  Future<void> _openLocationPicker() async {
    final picked = await showModalBottomSheet<UkPlace>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _LocationPickerSheet(),
    );
    if (picked == null) return;
    setState(() {
      _place = picked;
      _selectedParkrun = null;
      _selectedEvent = null;
      _selectedRace = null;
    });
    _rebuild();
    _moveCamera();
  }

  void _clearPlace() {
    setState(() => _place = null);
    _rebuild();
  }

  // ── Attendance actions ─────────────────────────────────────────────────────

  Future<void> _markGoing(Race race) async {
    final provider = context.read<AppProvider>();
    await provider.raceService.ensureRace(race);
    await provider.setAttendance(
      raceId: race.id,
      raceName: race.name,
      status: AttendanceStatus.going,
    );
    if (!mounted) return;
    setState(() {
      _selectedParkrun = null;
      _selectedEvent = null;
      _selectedRace = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${race.name} added to your calendar 🎉')),
    );
  }

  Future<void> _attendParkrun(Map<String, dynamic> p) async {
    await planParkrunDate(
      context,
      venueId: 'pr_${p['id']}',
      name: '${p['name']} parkrun',
      location: p['location'] ?? '',
      lat: (p['lat'] as num?)?.toDouble(),
      lng: (p['lng'] as num?)?.toDouble(),
    );
    if (mounted) setState(() => _selectedParkrun = null);
  }

  Future<void> _openParkrunDetails(Map<String, dynamic> p) async {
    final venueId = 'pr_${p['id']}';
    final venue = Race(
      id: venueId,
      name: '${p['name']} parkrun',
      location: p['location'] ?? '',
      type: 'parkrun',
      category: RaceCategory.parkrun,
      date: _nextSaturday(),
      lat: (p['lat'] as num?)?.toDouble(),
      lng: (p['lng'] as num?)?.toDouble(),
      createdBy: 'system',
    );
    await context.read<AppProvider>().raceService.ensureRace(venue);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RaceDetailScreen(raceId: venueId)),
    );
  }

  Future<void> _attendEvent(Map<String, dynamic> e) async {
    final slug = (e['url'] as String).split('/').last;
    await _markGoing(Race(
      id: 'fa_$slug',
      name: e['name'] ?? '',
      location: e['city'] ?? '',
      type: 'Race',
      category: RaceCategory.race,
      date: DateTime.parse(e['startDate']),
      website: e['url'],
      description: e['description'],
      lat: (e['lat'] as num?)?.toDouble(),
      lng: (e['lng'] as num?)?.toDouble(),
      createdBy: 'system',
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Race>>(
      stream: _racesStream,
      builder: (ctx, snap) {
        final newRaces = snap.data ?? [];
        if (newRaces.length != _races.length) {
          _races = newRaces;
          WidgetsBinding.instance.addPostFrameCallback((_) => _rebuild());
        }
        final results = _buildResults();
        final panelOpen = _selectedParkrun != null ||
            _selectedEvent != null ||
            _selectedRace != null;

        return Scaffold(
          floatingActionButton: panelOpen
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddRaceScreen()),
                  ),
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Add new event'),
                ),
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _header(),
                Expanded(
                  child: Stack(
                    children: [
                      if (_isListView)
                        _listView(results)
                      else
                        _mapView(),
                      if (_selectedParkrun != null)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: _ParkrunPanel(
                            data: _selectedParkrun!,
                            onClose: () =>
                                setState(() => _selectedParkrun = null),
                            onAttend: () => _attendParkrun(_selectedParkrun!),
                            onViewDetails: () =>
                                _openParkrunDetails(_selectedParkrun!),
                          ),
                        ),
                      if (_selectedEvent != null)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: _EventPanel(
                            data: _selectedEvent!,
                            onClose: () =>
                                setState(() => _selectedEvent = null),
                            onAttend: () => _attendEvent(_selectedEvent!),
                          ),
                        ),
                      if (_selectedRace != null)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: _RacePanel(
                            race: _selectedRace!,
                            onClose: () =>
                                setState(() => _selectedRace = null),
                            onAttend: () => _markGoing(_selectedRace!),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    RaceDetailScreen(raceId: _selectedRace!.id),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Header (location + radius + segment + toggle) ────────────────────────────

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.divider)),
      ),
      child: Column(
        children: [
          // Location search bar
          GestureDetector(
            onTap: _openLocationPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      color: AppTheme.accent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _place?.name ?? 'Search a town, city or area',
                      style: TextStyle(
                        color: _place == null
                            ? AppTheme.textSecondary
                            : AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight:
                            _place == null ? FontWeight.normal : FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_place != null)
                    GestureDetector(
                      onTap: _clearPlace,
                      child: const Icon(Icons.close,
                          size: 18, color: AppTheme.textSecondary),
                    )
                  else
                    const Icon(Icons.search, color: AppTheme.textSecondary),
                ],
              ),
            ),
          ),
          // Radius slider — only relevant once a place is chosen
          if (_place != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Text('Within ${_radius.round()} miles',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 16),
              ),
              child: Slider(
                min: 1,
                max: 50,
                divisions: 49,
                value: _radius,
                label: '${_radius.round()} mi',
                activeColor: AppTheme.primary,
                inactiveColor: AppTheme.divider,
                onChanged: (v) => setState(() => _radius = v),
                onChangeEnd: (v) {
                  _rebuild();
                  _moveCamera();
                },
              ),
            ),
          ] else
            const SizedBox(height: 8),
          // Segment + view toggle
          Row(
            children: [
              _segChip('All', _Seg.all),
              const SizedBox(width: 8),
              _segChip('Parkruns', _Seg.parkruns),
              const SizedBox(width: 8),
              _segChip('Races', _Seg.races),
              const Spacer(),
              _viewToggle(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _segChip(String label, _Seg value) {
    final selected = _seg == value;
    return GestureDetector(
      onTap: () {
        setState(() => _seg = value);
        _rebuild();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.divider),
        ),
        child: Text(label,
            style: TextStyle(
              color: selected ? Colors.white : AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
            )),
      ),
    );
  }

  Widget _viewToggle() {
    return GestureDetector(
      onTap: () {
        setState(() => _isListView = !_isListView);
        if (!_isListView) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _moveCamera());
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_isListView ? Icons.map_outlined : Icons.format_list_bulleted,
                size: 16, color: AppTheme.primary),
            const SizedBox(width: 5),
            Text(_isListView ? 'Map' : 'List',
                style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  // ── List view ────────────────────────────────────────────────────────────

  Widget _listView(List<_Result> results) {
    if (results.isEmpty) {
      return Container(
        color: AppTheme.background,
        alignment: Alignment.topCenter,
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
        child: Text(
          _place != null
              ? 'Nothing within ${_radius.round()} miles of ${_place!.name}.\nTry a bigger radius.'
              : 'No upcoming races or parkruns found.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }
    return Container(
      color: AppTheme.background,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
        itemCount: results.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _resultTile(results[i]),
      ),
    );
  }

  Widget _resultTile(_Result r) {
    return GestureDetector(
      onTap: r.onSelect,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            if (r.distanceMi != null)
              SizedBox(
                width: 50,
                child: Column(
                  children: [
                    Text(
                      r.distanceMi! < 10
                          ? r.distanceMi!.toStringAsFixed(1)
                          : r.distanceMi!.toStringAsFixed(0),
                      style: const TextStyle(
                          color: AppTheme.accent,
                          fontSize: 17,
                          fontWeight: FontWeight.w800),
                    ),
                    const Text('miles',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 10)),
                  ],
                ),
              )
            else
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                    color: r.isParkrun ? Colors.green : Colors.orange,
                    shape: BoxShape.circle),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(r.dateLabel,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12.5)),
                  Text('📍 ${r.address}',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (r.rating != null) ...[
              const SizedBox(width: 8),
              Text('★ ${r.rating}',
                  style: const TextStyle(
                      color: AppTheme.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ],
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _mapView() {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _place != null ? LatLng(_place!.lat, _place!.lng) : _ukCenter,
        zoom: _place != null ? _zoomForRadius(_radius) : 6.0,
      ),
      onMapCreated: (c) {
        _mapController = c;
        _moveCamera();
      },
      markers: _markers,
      circles: _circles,
      myLocationButtonEnabled: true,
      myLocationEnabled: true,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
      onTap: (_) => setState(() {
        _selectedParkrun = null;
        _selectedEvent = null;
        _selectedRace = null;
      }),
    );
  }
}

/// A single discovery result (parkrun / event / community race) with its
/// computed distance and a callback that opens its bottom panel.
class _Result {
  final String markerKey;
  final double lat;
  final double lng;
  final bool isParkrun;
  final double? distanceMi;
  final DateTime sortDate;
  final String title;
  final String address;
  final String dateLabel;
  final String? rating;
  final VoidCallback onSelect;

  _Result({
    required this.markerKey,
    required this.lat,
    required this.lng,
    required this.isParkrun,
    required this.distanceMi,
    required this.sortDate,
    required this.title,
    required this.address,
    required this.dateLabel,
    required this.rating,
    required this.onSelect,
  });
}

// ── Location picker sheet (type-ahead over the UK places gazetteer) ──────────

class _LocationPickerSheet extends StatefulWidget {
  const _LocationPickerSheet();

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  final TextEditingController _ctrl = TextEditingController();
  List<UkPlace> _results = const [];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onChanged(String q) async {
    final r = await PlacesService.search(q);
    if (mounted) setState(() => _results = r);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 18,
        right: 18,
        top: 14,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Search a town, city or area',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            autocorrect: false,
            textInputAction: TextInputAction.search,
            onChanged: _onChanged,
            decoration: const InputDecoration(
              hintText: 'Start typing… e.g. Manchester',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: _results.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('Type a place to see matches',
                        style: TextStyle(color: AppTheme.textSecondary)),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _results.length,
                    itemBuilder: (_, i) {
                      final p = _results[i];
                      return ListTile(
                        leading: const Icon(Icons.location_on_outlined,
                            color: AppTheme.accent),
                        title: Text(p.name),
                        onTap: () => Navigator.pop(context, p),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ── Parkrun detail panel ───────────────────────────────────────────────────

class _ParkrunPanel extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onClose;
  final VoidCallback onAttend;
  final VoidCallback onViewDetails;
  const _ParkrunPanel({
    required this.data,
    required this.onClose,
    required this.onAttend,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 16)
        ],
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _tag('parkrun', Colors.green),
              const Spacer(),
              IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close,
                      color: AppTheme.textSecondary, size: 20),
                  onPressed: onClose),
            ],
          ),
          const SizedBox(height: 4),
          Text('${data['name']} parkrun',
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 20)),
          const SizedBox(height: 4),
          _line(Icons.location_on_outlined, data['location'] as String? ?? ''),
          const SizedBox(height: 4),
          _line(Icons.calendar_today_outlined, 'Every Saturday · 9:00am'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onAttend,
                  child: const Text("I'm doing this"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: onViewDetails,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: const BorderSide(color: AppTheme.divider),
                  ),
                  child: const Text('Reviews'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Findarace event panel ──────────────────────────────────────────────────

class _EventPanel extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onClose;
  final VoidCallback onAttend;
  const _EventPanel(
      {required this.data, required this.onClose, required this.onAttend});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(data['startDate'] ?? '');
    final price = data['price'];
    final address = (data['address'] ?? data['city'] ?? '') as String;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 16)
        ],
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _tag('Race', Colors.orange),
              if (price != null) ...[
                const SizedBox(width: 8),
                Text(
                    price is num
                        ? '£${price.toStringAsFixed(0)}'
                        : price.toString(),
                    style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
              const Spacer(),
              IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close,
                      color: AppTheme.textSecondary, size: 20),
                  onPressed: onClose),
            ],
          ),
          const SizedBox(height: 4),
          Text(data['name'] ?? '',
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 20),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          _line(Icons.location_on_outlined, address),
          if (date != null) ...[
            const SizedBox(height: 4),
            _line(Icons.calendar_today_outlined,
                DateFormat('EEE d MMM yyyy').format(date)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onAttend,
                  child: const Text("I'm doing this"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    final url = data['url'] as String?;
                    if (url != null) {
                      launchUrl(Uri.parse(url),
                          mode: LaunchMode.externalApplication);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: const BorderSide(color: AppTheme.divider),
                  ),
                  child: const Text('Website'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Race detail panel ──────────────────────────────────────────────────────

class _RacePanel extends StatelessWidget {
  final Race race;
  final VoidCallback onClose;
  final VoidCallback onTap;
  final VoidCallback onAttend;
  const _RacePanel(
      {required this.race,
      required this.onClose,
      required this.onTap,
      required this.onAttend});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.4), blurRadius: 16)
          ],
        ),
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _tag(race.type, AppTheme.accent),
                const SizedBox(width: 8),
                if (race.lightningBolt)
                  const Text('⚡', style: TextStyle(fontSize: 16)),
                const Spacer(),
                IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close,
                        color: AppTheme.textSecondary, size: 20),
                    onPressed: onClose),
              ],
            ),
            const SizedBox(height: 4),
            Text(race.name,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 20)),
            const SizedBox(height: 4),
            _line(Icons.location_on_outlined, race.location),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(DateFormat('EEE d MMM yyyy').format(race.date),
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
                if (race.reviewCount > 0) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.star, size: 14, color: AppTheme.accent),
                  const SizedBox(width: 2),
                  Text(
                    '${race.averageRating.toStringAsFixed(1)} (${race.reviewCount})',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAttend,
                    child: const Text("I'm doing this"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onTap,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textPrimary,
                      side: const BorderSide(color: AppTheme.divider),
                    ),
                    child: const Text('View details'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared small widgets for the panels ─────────────────────────────────────

Widget _tag(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );

Widget _line(IconData icon, String text) => Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Expanded(
          child: Text(text,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
