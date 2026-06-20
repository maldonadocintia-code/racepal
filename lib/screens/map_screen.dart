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
import '../utils/distance.dart';
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
  DistanceBucket? _dist; // null = Any
  String? _month; // 'yyyy-MM' or null = Any month
  bool _searchStarted = false; // false = show the "Find your next race" launcher
  bool _isListView = true; // list is the default — faster, no map-tile cost

  // Parkruns are all 5K. When true the distance filter treats them as 5K (so
  // choosing 10K/Half/etc. hides them); when false parkruns always show
  // regardless of the chosen distance. Single switch — flip if testers prefer.
  static const bool _distAppliesToParkruns = true;

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

    // Curated races and parkruns are drawn from the bundled assets, but their
    // ratings live on a Firestore "stats" doc under a deterministic id (created
    // the first time someone interacts with them). Index the loaded Firestore
    // races by id so we can show those ratings next to the asset rows.
    final raceById = {for (final r in _races) r.id: r};
    String? ratingFor(String id) {
      final r = raceById[id];
      if (r == null || r.reviewCount <= 0) return null;
      return '${r.averageRating.toStringAsFixed(1)} (${r.reviewCount})';
    }

    // Explore filters by location + radius only. Finding a race you already
    // know by name lives on the Plan tab (tap a date to add it).
    bool keep(double? dist) {
      if (_place != null) return dist != null && dist <= _radius;
      return true;
    }

    // Distance filter. Parkruns are 5K; whether the filter applies to them is
    // controlled by _distAppliesToParkruns.
    bool keepDist(Set<DistanceBucket> buckets, bool isParkrun) {
      if (_dist == null) return true;
      if (isParkrun && !_distAppliesToParkruns) return true;
      return buckets.contains(_dist);
    }

    // Month filter. Parkruns recur every Saturday, so they match any month and
    // skip this check entirely (only dated races are narrowed by month).
    bool keepMonth(DateTime d) =>
        _month == null || DateFormat('yyyy-MM').format(d) == _month;

    if (_seg != _Seg.races) {
      for (final p in _parkrunData) {
        final lat = (p['lat'] as num?)?.toDouble();
        final lng = (p['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        final dist = _distOf(lat, lng);
        final title = '${p['name']} parkrun';
        final address = (p['location'] ?? '') as String;
        const buckets = {DistanceBucket.fiveK};
        if (!keep(dist) || !keepDist(buckets, true)) continue;
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
          rating: ratingFor('pr_${p['id']}'),
          distLabel: '5K',
          buckets: buckets,
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
        final distRaw = e['distance'] as String?;
        final buckets = bucketsFor(distRaw);
        if (!keep(dist) || !keepDist(buckets, false) || !keepMonth(d)) continue;
        final url = e['url'] as String?;
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
          rating: url != null ? ratingFor('fa_${url.split('/').last}') : null,
          distLabel: distRaw,
          buckets: buckets,
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
        final buckets = bucketsFor(r.type);
        if (!keep(dist) || !keepDist(buckets, false) || !keepMonth(r.date)) {
          continue;
        }
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
          distLabel: r.type,
          buckets: buckets,
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
      final volt = AppColors.of(context).primary;
      circles.add(Circle(
        circleId: const CircleId('radius'),
        center: LatLng(_place!.lat, _place!.lng),
        radius: _radius * 1609.34,
        fillColor: volt.withValues(alpha: 0.10),
        strokeColor: volt.withValues(alpha: 0.6),
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
      backgroundColor: AppColors.of(context).sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
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

  // ── Launcher → results ─────────────────────────────────────────────────────

  // Upcoming months (this month + next 11) as ('yyyy-MM', 'MMM yyyy') pairs.
  List<MapEntry<String, String>> _monthOptions() {
    final now = DateTime.now();
    return List.generate(12, (i) {
      final d = DateTime(now.year, now.month + i);
      return MapEntry(
          DateFormat('yyyy-MM').format(d), DateFormat('MMM yyyy').format(d));
    });
  }

  // Enter the results list via one of the launcher cards, priming that lens.
  Future<void> _enter(String via) async {
    setState(() => _searchStarted = true);
    if (via == 'location') {
      await _openLocationPicker();
    } else if (via == 'month') {
      await _pickMonth();
    } else if (via == 'distance') {
      await _pickDistance();
    }
  }

  void _goHome() {
    setState(() {
      _searchStarted = false;
      _place = null;
      _seg = _Seg.all;
      _dist = null;
      _month = null;
      _selectedParkrun = null;
      _selectedEvent = null;
      _selectedRace = null;
    });
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
        // Only the marker set needs a full rebuild when the race *count* changes;
        // but always take the latest data so updated ratings/stats are reflected
        // even when the count is unchanged.
        if (newRaces.length != _races.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _rebuild());
        }
        _races = newRaces;
        final results = _buildResults();
        final panelOpen = _selectedParkrun != null ||
            _selectedEvent != null ||
            _selectedRace != null;

        final c = AppColors.of(context);
        // Launcher: "Find your next race or parkrun" with three ways in.
        if (!_searchStarted) {
          return Scaffold(
            body: SafeArea(child: _launcher()),
          );
        }
        return Scaffold(
          floatingActionButton: panelOpen
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddRaceScreen()),
                  ),
                  backgroundColor: c.fabBg,
                  foregroundColor: c.fabText,
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Add new event',
                      style: TextStyle(
                          fontFamily: AppType.body,
                          fontWeight: FontWeight.w500)),
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

  // ── Launcher ─────────────────────────────────────────────────────────────

  Widget _launcher() {
    final c = AppColors.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      children: [
        Text('Find your next\nrace or parkrun',
            style: TextStyle(
                fontFamily: AppType.heading,
                color: c.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: AppType.xxl,
                height: 1.15)),
        const SizedBox(height: 6),
        Text('Search whichever way suits you:',
            style: TextStyle(
                fontFamily: AppType.body,
                color: c.textSecondary,
                fontSize: AppType.base)),
        const SizedBox(height: 20),
        _launchCard(c, Icons.location_on_outlined, 'By location',
            'Races near a town, city or area', () => _enter('location')),
        _launchCard(c, Icons.calendar_month_outlined, 'By month',
            "See what's on in a given month", () => _enter('month')),
        _launchCard(c, Icons.directions_run, 'By distance',
            '5K, 10K, Half, Marathon, Ultra', () => _enter('distance')),
      ],
    );
  }

  Widget _launchCard(AppColors c, IconData icon, String title, String sub,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: c.bgSurface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.primary,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: c.textOnVolt, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontFamily: AppType.body,
                          color: c.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: AppType.lg)),
                  const SizedBox(height: 2),
                  Text(sub,
                      style: TextStyle(
                          fontFamily: AppType.body,
                          color: c.textSecondary,
                          fontSize: AppType.sm)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: c.textTertiary),
          ],
        ),
      ),
    );
  }

  // ── Results header (back + location + slider + filter pills) ─────────────────

  Widget _header() {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.divider)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _goHome,
                icon: Icon(Icons.arrow_back, color: c.textPrimary),
                tooltip: 'Back to search',
              ),
              Expanded(child: _locationPill(c)),
              const SizedBox(width: 4),
              _viewToggle(),
            ],
          ),
          if (_place != null) _radiusSlider(c),
          const SizedBox(height: 8),
          _pillsRow(c),
        ],
      ),
    );
  }

  Widget _locationPill(AppColors c) {
    return GestureDetector(
      onTap: _openLocationPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: c.searchBg,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: c.searchBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.location_on_outlined, color: c.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _place?.name ?? 'Search a place',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppType.body,
                  color: _place == null ? c.searchPlaceholder : c.searchText,
                  fontSize: AppType.md,
                  fontWeight:
                      _place == null ? FontWeight.normal : FontWeight.w600,
                ),
              ),
            ),
            if (_place != null)
              GestureDetector(
                onTap: _clearPlace,
                child: Icon(Icons.close, size: 18, color: c.searchIcon),
              )
            else
              Icon(Icons.search, color: c.searchIcon, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _radiusSlider(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, top: 4),
          child: Text('Within ${_radius.round()} miles of ${_place!.name}',
              style: TextStyle(color: c.textSecondary, fontSize: AppType.sm)),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            min: 1,
            max: 50,
            divisions: 49,
            value: _radius,
            label: '${_radius.round()} mi',
            activeColor: c.sliderFill,
            inactiveColor: c.sliderTrack,
            onChanged: (v) => setState(() => _radius = v),
            onChangeEnd: (v) {
              _rebuild();
              _moveCamera();
            },
          ),
        ),
      ],
    );
  }

  // Quiet filter pills — Month / Distance / Type. Outline at rest, fill volt
  // when active, so colour signals which filters are on. Distance is disabled
  // when Type = Parkruns (all parkruns are 5K).
  Widget _pillsRow(AppColors c) {
    final monthLabel = _month == null
        ? 'Any month'
        : DateFormat('MMM yyyy').format(DateFormat('yyyy-MM').parse(_month!));
    final parkOnly = _seg == _Seg.parkruns;
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _filterPill(c, monthLabel, _month != null, _pickMonth),
          const SizedBox(width: 8),
          _filterPill(
            c,
            parkOnly ? '5K only' : (_dist?.label ?? 'Any distance'),
            !parkOnly && _dist != null,
            parkOnly ? null : _pickDistance,
          ),
          const SizedBox(width: 8),
          _filterPill(c, _segLabel(), _seg != _Seg.all, _pickType),
        ],
      ),
    );
  }

  String _segLabel() => switch (_seg) {
        _Seg.all => 'All types',
        _Seg.parkruns => 'Parkruns',
        _Seg.races => 'Races',
      };

  Widget _filterPill(
      AppColors c, String label, bool active, VoidCallback? onTap) {
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: active ? c.filterActive : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border:
                Border.all(color: active ? Colors.transparent : c.filterBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: TextStyle(
                      fontFamily: AppType.body,
                      color: active ? c.filterActiveText : c.textSecondary,
                      fontSize: AppType.base,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
              const SizedBox(width: 4),
              Icon(Icons.expand_more,
                  size: 16,
                  color: active ? c.filterActiveText : c.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  // ── Filter pickers (one bottom sheet per pill) ───────────────────────────────

  Future<void> _pickMonth() async {
    final c = AppColors.of(context);
    await _openPicker('Month', (close) => [
          _pickChip(c, 'Any month', _month == null, () {
            setState(() => _month = null);
            _rebuild();
            close();
          }),
          for (final m in _monthOptions())
            _pickChip(c, m.value, _month == m.key, () {
              setState(() => _month = m.key);
              _rebuild();
              close();
            }),
        ]);
  }

  Future<void> _pickDistance() async {
    final c = AppColors.of(context);
    await _openPicker('Distance', (close) => [
          _pickChip(c, 'Any distance', _dist == null, () {
            setState(() => _dist = null);
            _rebuild();
            close();
          }),
          for (final b in kDistanceBuckets)
            _pickChip(c, b.label, _dist == b, () {
              setState(() => _dist = b);
              _rebuild();
              close();
            }),
        ]);
  }

  Future<void> _pickType() async {
    final c = AppColors.of(context);
    const labels = {
      _Seg.all: 'All types',
      _Seg.parkruns: 'Parkruns',
      _Seg.races: 'Races',
    };
    await _openPicker('Type', (close) => [
          for (final e in labels.entries)
            _pickChip(c, e.value, _seg == e.key, () {
              setState(() {
                _seg = e.key;
                if (e.key == _Seg.parkruns) {
                  _dist = null; // distance is meaningless for parkruns
                }
              });
              _rebuild();
              close();
            }),
        ]);
  }

  Future<void> _openPicker(
      String title, List<Widget> Function(VoidCallback close) chips) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.of(context).sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      builder: (sheetCtx) {
        final c = AppColors.of(context);
        return Padding(
          padding: EdgeInsets.fromLTRB(
              18, 14, 18, MediaQuery.of(sheetCtx).padding.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.sheetHandle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(title,
                  style: TextStyle(
                      fontFamily: AppType.heading,
                      color: c.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: AppType.xl)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: chips(() => Navigator.pop(sheetCtx)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pickChip(
      AppColors c, String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? c.filterActive : c.filterInactive,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
              color: selected ? Colors.transparent : c.filterBorder),
        ),
        child: Text(label,
            style: TextStyle(
              fontFamily: AppType.body,
              color: selected ? c.filterActiveText : c.filterInactiveText,
              fontSize: AppType.base,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            )),
      ),
    );
  }

  Widget _viewToggle() {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: () {
        setState(() => _isListView = !_isListView);
        if (!_isListView) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _moveCamera());
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: c.filterInactive,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: c.filterBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_isListView ? Icons.map_outlined : Icons.format_list_bulleted,
                size: 16, color: c.textPrimary),
            const SizedBox(width: 5),
            Text(_isListView ? 'Map' : 'List',
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: AppType.sm,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // ── List view ────────────────────────────────────────────────────────────

  Widget _listView(List<_Result> results) {
    final c = AppColors.of(context);
    if (results.isEmpty) {
      return Container(
        color: c.bgPrimary,
        alignment: Alignment.topCenter,
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
        child: Text(
          (_seg != _Seg.all || _dist != null || _month != null)
              ? 'Nothing matches.\nTry “Any month”, “Any distance”, or a wider radius.'
              : _place != null
                  ? 'Nothing within ${_radius.round()} miles of ${_place!.name}.\nTry a bigger radius.'
                  : 'No upcoming races or parkruns found.',
          textAlign: TextAlign.center,
          style: TextStyle(color: c.textSecondary),
        ),
      );
    }
    return Container(
      color: c.bgPrimary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: results.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _resultTile(results[i]),
      ),
    );
  }

  // Calm tile: race name is the hero; one muted meta line carries the rest
  // (distance-from-you OR date · race distance · place); muted rating.
  Widget _resultTile(_Result r) {
    final c = AppColors.of(context);
    final where = r.distanceMi != null
        ? '${r.distanceMi! < 10 ? r.distanceMi!.toStringAsFixed(1) : r.distanceMi!.toStringAsFixed(0)} mi'
        : (r.isParkrun ? 'Saturdays' : r.dateLabel);
    final meta = [
      where,
      if (r.distLabel != null && r.distLabel!.isNotEmpty) r.distLabel,
      if (r.address.isNotEmpty) r.address,
    ].join('  ·  ');
    return GestureDetector(
      onTap: r.onSelect,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.bgSurface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.title,
                      style: TextStyle(
                          fontFamily: AppType.body,
                          color: c.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: AppType.md),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(meta,
                      style: TextStyle(
                          fontFamily: AppType.body,
                          color: c.textSecondary,
                          fontSize: AppType.sm),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (r.rating != null) ...[
              const SizedBox(width: 10),
              Text('★ ${r.rating}',
                  style: TextStyle(
                      fontFamily: AppType.body,
                      color: c.textSecondary,
                      fontSize: AppType.sm,
                      fontWeight: FontWeight.w600)),
            ],
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
  final String? distLabel; // raw distance shown on the tile, e.g. "5K / 10K"
  final Set<DistanceBucket> buckets; // distances this event offers
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
    this.distLabel,
    this.buckets = const {},
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
    final c = AppColors.of(context);
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
                color: c.sheetHandle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text('Search a town, city or area',
              style: TextStyle(
                  fontFamily: AppType.heading,
                  color: c.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: AppType.xl)),
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
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text('Type a place to see matches',
                        style: TextStyle(color: c.textSecondary)),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _results.length,
                    itemBuilder: (_, i) {
                      final p = _results[i];
                      return ListTile(
                        leading: Icon(Icons.location_on_outlined,
                            color: c.primary),
                        title: Text(p.name,
                            style: TextStyle(color: c.textPrimary)),
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
    final c = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
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
              _tag(context, 'parkrun', AppPalette.goGreen),
              const Spacer(),
              IconButton(
                  tooltip: 'Close',
                  icon: Icon(Icons.close, color: c.textTertiary, size: 20),
                  onPressed: onClose),
            ],
          ),
          const SizedBox(height: 4),
          Text('${data['name']} parkrun',
              style: TextStyle(
                  fontFamily: AppType.heading,
                  color: c.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: AppType.xl)),
          const SizedBox(height: 4),
          _line(context, Icons.location_on_outlined,
              data['location'] as String? ?? ''),
          const SizedBox(height: 4),
          _line(context, Icons.calendar_today_outlined,
              'Every Saturday · 9:00am'),
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
                    foregroundColor: c.textPrimary,
                    side: BorderSide(color: c.border),
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
    final c = AppColors.of(context);
    final date = DateTime.tryParse(data['startDate'] ?? '');
    final price = data['price'];
    final address = (data['address'] ?? data['city'] ?? '') as String;

    return Container(
      decoration: BoxDecoration(
        color: c.sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
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
              _tag(context, 'Race', c.secondary),
              if (price != null) ...[
                const SizedBox(width: 8),
                Text(
                    price is num
                        ? '£${price.toStringAsFixed(0)}'
                        : price.toString(),
                    style: TextStyle(
                        color: c.textSecondary,
                        fontSize: AppType.sm,
                        fontWeight: FontWeight.w600)),
              ],
              const Spacer(),
              IconButton(
                  tooltip: 'Close',
                  icon: Icon(Icons.close, color: c.textTertiary, size: 20),
                  onPressed: onClose),
            ],
          ),
          const SizedBox(height: 4),
          Text(data['name'] ?? '',
              style: TextStyle(
                  fontFamily: AppType.heading,
                  color: c.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: AppType.xl),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          _line(context, Icons.location_on_outlined, address),
          if (date != null) ...[
            const SizedBox(height: 4),
            _line(context, Icons.calendar_today_outlined,
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
                    foregroundColor: c.textPrimary,
                    side: BorderSide(color: c.border),
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
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: c.sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
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
                _tag(context, race.type, c.secondary),
                const SizedBox(width: 8),
                if (race.lightningBolt)
                  const Text('⚡', style: TextStyle(fontSize: AppType.md)),
                const Spacer(),
                IconButton(
                    tooltip: 'Close',
                    icon: Icon(Icons.close, color: c.textTertiary, size: 20),
                    onPressed: onClose),
              ],
            ),
            const SizedBox(height: 4),
            Text(race.name,
                style: TextStyle(
                    fontFamily: AppType.heading,
                    color: c.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: AppType.xl)),
            const SizedBox(height: 4),
            _line(context, Icons.location_on_outlined, race.location),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 14, color: c.textSecondary),
                const SizedBox(width: 4),
                Text(DateFormat('EEE d MMM yyyy').format(race.date),
                    style: TextStyle(
                        color: c.textSecondary, fontSize: AppType.sm)),
                if (race.reviewCount > 0) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.star, size: 14, color: c.achievement),
                  const SizedBox(width: 2),
                  Text(
                    '${race.averageRating.toStringAsFixed(1)} (${race.reviewCount})',
                    style: TextStyle(
                        color: c.textSecondary, fontSize: AppType.sm),
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
                      foregroundColor: c.textPrimary,
                      side: BorderSide(color: c.border),
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

Widget _tag(BuildContext context, String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: AppType.sm, fontWeight: FontWeight.w600)),
    );

Widget _line(BuildContext context, IconData icon, String text) {
  final c = AppColors.of(context);
  return Row(
    children: [
      Icon(icon, size: 14, color: c.textSecondary),
      const SizedBox(width: 4),
      Expanded(
        child: Text(text,
            style: TextStyle(color: c.textSecondary, fontSize: AppType.sm),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ),
    ],
  );
}
