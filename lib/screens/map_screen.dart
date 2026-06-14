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
import '../widgets/parkrun_helpers.dart';
import '../theme.dart';
import 'race_detail_screen.dart';
import 'add_race_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

/// Two simple tabs — that's the whole top-level filter now.
enum _Tab { parkruns, races }

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};

  _Tab _tab = _Tab.parkruns;
  bool _isListView = true; // list is the default — faster, no map-tile cost

  bool _parkrunsLoaded = false;
  bool _eventsLoaded = false;
  List<Map<String, dynamic>> _parkrunData = [];
  List<Map<String, dynamic>> _eventData = [];
  List<Race> _races = [];

  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  // Month filter — only used on the Races tab. null = upcoming (any month).
  DateTime? _filterMonth;

  // Community races stream, created once (not on every rebuild).
  late final Stream<List<Race>> _racesStream;

  // Selected item for the bottom panel
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
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadParkruns() async {
    if (_parkrunsLoaded) return;
    final raw = await rootBundle.loadString('assets/parkruns_uk.json');
    _parkrunData = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    _parkrunsLoaded = true;
    _rebuildMarkers();
  }

  Future<void> _loadEvents() async {
    if (_eventsLoaded) return;
    final rawFindarace = await rootBundle.loadString('assets/findarace_uk.json');
    final rawMajor = await rootBundle.loadString('assets/major_races_uk.json');
    final findaraceList =
        (jsonDecode(rawFindarace) as List).cast<Map<String, dynamic>>();
    final majorList =
        (jsonDecode(rawMajor) as List).cast<Map<String, dynamic>>();
    // Deduplicate by (name, startDate) then keep only valid dates
    final seen = <String>{};
    _eventData = [...findaraceList, ...majorList].where((e) {
      final key = '${e['name']}_${e['startDate']}';
      if (!seen.add(key)) return false;
      return DateTime.tryParse(e['startDate'] ?? '') != null;
    }).toList();
    _eventsLoaded = true;
    _rebuildMarkers();
  }

  // ── Filtering ──────────────────────────────────────────────────────────────

  bool _inMonth(DateTime date) {
    if (_filterMonth == null) return date.isAfter(DateTime.now());
    return date.year == _filterMonth!.year && date.month == _filterMonth!.month;
  }

  List<Map<String, dynamic>> _filteredParkruns() {
    final q = _searchQuery.toLowerCase();
    return _parkrunData.where((p) {
      if (p['lat'] == null || p['lng'] == null) return false;
      if (q.isEmpty) return true;
      return (p['name'] as String).toLowerCase().contains(q) ||
          (p['location'] as String).toLowerCase().contains(q);
    }).toList();
  }

  List<Map<String, dynamic>> _filteredEvents() {
    final q = _searchQuery.toLowerCase();
    return _eventData.where((e) {
      if (e['lat'] == null || e['lng'] == null) return false;
      final d = DateTime.tryParse(e['startDate'] ?? '');
      if (d == null || !_inMonth(d)) return false;
      if (q.isEmpty) return true;
      return (e['name'] as String).toLowerCase().contains(q) ||
          ((e['city'] ?? '') as String).toLowerCase().contains(q);
    }).toList();
  }

  List<Race> _filteredRaces() {
    final q = _searchQuery.toLowerCase();
    return _races.where((r) {
      if (r.isParkrun) return false; // parkrun venue docs never show on Races
      if (r.lat == null || r.lng == null) return false;
      if (!_inMonth(r.date)) return false;
      if (q.isEmpty) return true;
      return r.name.toLowerCase().contains(q) ||
          r.location.toLowerCase().contains(q);
    }).toList();
  }

  // ── Markers ─────────────────────────────────────────────────────────────────

  void _rebuildMarkers() {
    final markers = <Marker>{};

    if (_tab == _Tab.parkruns) {
      for (final p in _filteredParkruns()) {
        markers.add(Marker(
          markerId: MarkerId('pr_${p['id']}'),
          position: LatLng(
            (p['lat'] as num).toDouble(),
            (p['lng'] as num).toDouble(),
          ),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          onTap: () => setState(() {
            _selectedParkrun = p;
            _selectedEvent = null;
            _selectedRace = null;
          }),
        ));
      }
    } else {
      for (final e in _filteredEvents()) {
        markers.add(Marker(
          markerId: MarkerId('fa_${e['url']}'),
          position: LatLng(
            (e['lat'] as num).toDouble(),
            (e['lng'] as num).toDouble(),
          ),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          onTap: () => setState(() {
            _selectedEvent = e;
            _selectedParkrun = null;
            _selectedRace = null;
          }),
        ));
      }
      for (final r in _filteredRaces()) {
        markers.add(Marker(
          markerId: MarkerId('race_${r.id}'),
          position: LatLng(r.lat!, r.lng!),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          onTap: () => setState(() {
            _selectedRace = r;
            _selectedParkrun = null;
            _selectedEvent = null;
          }),
        ));
      }
    }

    if (!mounted) return;
    setState(() => _markers
      ..clear()
      ..addAll(markers));
  }

  void _switchTab(_Tab tab) {
    if (_tab == tab) return;
    setState(() {
      _tab = tab;
      _selectedParkrun = null;
      _selectedEvent = null;
      _selectedRace = null;
    });
    _rebuildMarkers();
  }

  // ── Month filter (Races tab only) ────────────────────────────────────────────

  String get _monthLabel =>
      _filterMonth == null ? 'Any month' : DateFormat('MMM yyyy').format(_filterMonth!);

  void _showMonthFilter() {
    final now = DateTime.now();
    final months = List.generate(13, (i) => DateTime(now.year, now.month + i));

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filter races by month',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _monthOption('Any month', _filterMonth == null, () {
                  setState(() => _filterMonth = null);
                  _rebuildMarkers();
                  Navigator.pop(ctx);
                }),
                ...months.map((m) {
                  final selected = _filterMonth != null &&
                      _filterMonth!.year == m.year &&
                      _filterMonth!.month == m.month;
                  return _monthOption(
                      DateFormat('MMM yyyy').format(m), selected, () {
                    setState(() => _filterMonth = m);
                    _rebuildMarkers();
                    Navigator.pop(ctx);
                  });
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthOption(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : AppTheme.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.divider),
        ),
        child: Text(label,
            style: TextStyle(
              color: selected ? Colors.white : AppTheme.textPrimary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
              fontSize: 13,
            )),
      ),
    );
  }

  // ── Attendance actions ───────────────────────────────────────────────────────

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

  /// Ensures the stable venue doc exists, then opens its detail/reviews screen.
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

  static DateTime _nextSaturday() {
    final now = DateTime.now();
    var d = DateTime(now.year, now.month, now.day, 9);
    while (d.weekday != DateTime.saturday) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isParkrunTab = _tab == _Tab.parkruns;
    final panelOpen = _selectedParkrun != null ||
        _selectedEvent != null ||
        _selectedRace != null;

    return StreamBuilder<List<Race>>(
      stream: _racesStream,
      builder: (ctx, snap) {
        final newRaces = snap.data ?? [];
        if (newRaces.length != _races.length) {
          _races = newRaces;
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _rebuildMarkers());
        }

        return Scaffold(
          body: Stack(
            children: [
              // Map (hidden in list view so no tiles load)
              if (!_isListView)
                GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: _ukCenter,
                    zoom: 6.0,
                  ),
                  onMapCreated: (c) => _mapController = c,
                  markers: _markers,
                  myLocationButtonEnabled: true,
                  myLocationEnabled: true,
                  mapToolbarEnabled: false,
                  zoomControlsEnabled: false,
                  onTap: (_) => setState(() {
                    _selectedParkrun = null;
                    _selectedEvent = null;
                    _selectedRace = null;
                  }),
                )
              else
                Positioned.fill(child: _buildListView()),

              // Top bar: tabs + search (+ month chip on Races)
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 12,
                right: 12,
                child: Column(
                  children: [
                    _tabBar(),
                    const SizedBox(height: 8),
                    _searchBar(isParkrunTab),
                    if (!isParkrunTab) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _monthChip(),
                      ),
                    ],
                  ],
                ),
              ),

              // Floating actions (bottom-right)
              if (!panelOpen)
                Positioned(
                  right: 14,
                  bottom: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _viewToggleFab(),
                      const SizedBox(height: 12),
                      _addRaceFab(),
                    ],
                  ),
                ),

              // Bottom panels
              if (_selectedParkrun != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _ParkrunPanel(
                    data: _selectedParkrun!,
                    onClose: () => setState(() => _selectedParkrun = null),
                    onAttend: () => _attendParkrun(_selectedParkrun!),
                    onViewDetails: () => _openParkrunDetails(_selectedParkrun!),
                  ),
                ),
              if (_selectedEvent != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _EventPanel(
                    data: _selectedEvent!,
                    onClose: () => setState(() => _selectedEvent = null),
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
                    onClose: () => setState(() => _selectedRace = null),
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
        );
      },
    );
  }

  // ── Top-bar widgets ──────────────────────────────────────────────────────────

  Widget _tabBar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 6),
        ],
      ),
      child: Row(
        children: [
          _tabButton('Parkruns', _Tab.parkruns),
          _tabButton('Races', _Tab.races),
        ],
      ),
    );
  }

  Widget _tabButton(String label, _Tab tab) {
    final selected = _tab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchTab(tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchBar(bool isParkrunTab) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) {
          _searchQuery = v;
          _rebuildMarkers();
        },
        decoration: InputDecoration(
          hintText:
              isParkrunTab ? 'Search parkruns...' : 'Search races...',
          prefixIcon:
              const Icon(Icons.search, color: AppTheme.textSecondary),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: AppTheme.textSecondary),
                  onPressed: () {
                    _searchCtrl.clear();
                    _searchQuery = '';
                    _rebuildMarkers();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _monthChip() {
    final active = _filterMonth != null;
    return GestureDetector(
      onTap: _showMonthFilter,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.accent.withValues(alpha: 0.15)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? AppTheme.accent
                : AppTheme.divider.withValues(alpha: 0.8),
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.25), blurRadius: 4),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 13,
                color: active ? AppTheme.accent : AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(_monthLabel,
                style: TextStyle(
                  color: active ? AppTheme.accent : AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                )),
            if (active) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  setState(() => _filterMonth = null);
                  _rebuildMarkers();
                },
                child: const Icon(Icons.close,
                    size: 15, color: AppTheme.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _viewToggleFab() {
    return GestureDetector(
      onTap: () => setState(() => _isListView = !_isListView),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.4), blurRadius: 8),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_isListView ? Icons.map_outlined : Icons.format_list_bulleted,
                size: 18, color: AppTheme.primary),
            const SizedBox(width: 6),
            Text(_isListView ? 'Map' : 'List',
                style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _addRaceFab() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddRaceScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.4), blurRadius: 8),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_location_alt_outlined, size: 18, color: Colors.white),
            SizedBox(width: 6),
            Text('Add race',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  // ── List view ────────────────────────────────────────────────────────────────

  Widget _buildListView() {
    final entries = <_ListEntry>[];

    if (_tab == _Tab.parkruns) {
      for (final p in _filteredParkruns()) {
        entries.add(_ListEntry(
          date: _nextSaturday(),
          title: '${p['name']} parkrun',
          subtitle: (p['location'] ?? '') as String,
          dateLabel: 'Saturdays · 9:00am',
          color: Colors.green,
          onTap: () => setState(() {
            _selectedParkrun = p;
            _selectedEvent = null;
            _selectedRace = null;
          }),
        ));
      }
      // Parkruns: alphabetical (they're all "every Saturday")
      entries.sort((a, b) => a.title.compareTo(b.title));
    } else {
      for (final e in _filteredEvents()) {
        final d = DateTime.parse(e['startDate']);
        entries.add(_ListEntry(
          date: d,
          title: (e['name'] ?? '') as String,
          subtitle: (e['city'] ?? '') as String,
          dateLabel: DateFormat('EEE d MMM yyyy').format(d),
          color: Colors.orange,
          onTap: () => setState(() {
            _selectedEvent = e;
            _selectedParkrun = null;
            _selectedRace = null;
          }),
        ));
      }
      for (final r in _filteredRaces()) {
        entries.add(_ListEntry(
          date: r.date,
          title: r.name,
          subtitle: r.location,
          dateLabel: DateFormat('EEE d MMM yyyy').format(r.date),
          color: Colors.orange,
          onTap: () => setState(() {
            _selectedRace = r;
            _selectedParkrun = null;
            _selectedEvent = null;
          }),
        ));
      }
      entries.sort((a, b) => a.date.compareTo(b.date));
    }

    // Leaves room for the tab bar + search (+ month chip on Races).
    final topPad = MediaQuery.of(context).padding.top +
        (_tab == _Tab.races ? 168 : 120);

    if (entries.isEmpty) {
      return Container(
        color: AppTheme.background,
        padding: EdgeInsets.fromLTRB(24, topPad, 24, 24),
        alignment: Alignment.topCenter,
        child: Text(
          _tab == _Tab.parkruns
              ? 'No parkruns match your search.'
              : 'No races match your search or month.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return Container(
      color: AppTheme.background,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(12, topPad, 12, 100),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _listTile(entries[i]),
      ),
    );
  }

  Widget _listTile(_ListEntry e) {
    return GestureDetector(
      onTap: e.onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: e.color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('${e.dateLabel}  ·  ${e.subtitle}',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// One row in the list view.
class _ListEntry {
  final DateTime date;
  final String title;
  final String subtitle;
  final String dateLabel;
  final Color color;
  final VoidCallback onTap;

  _ListEntry({
    required this.date,
    required this.title,
    required this.subtitle,
    required this.dateLabel,
    required this.color,
    required this.onTap,
  });
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.green.withValues(alpha: 0.4)),
                ),
                child: const Text('parkrun',
                    style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close,
                      color: AppTheme.textSecondary, size: 20),
                  onPressed: onClose),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${data['name']} parkrun',
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 20),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text(data['location'] as String,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 4),
          const Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 14, color: AppTheme.textSecondary),
              SizedBox(width: 4),
              Text('Every Saturday · 9:00am',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13)),
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                ),
                child: const Text('Event',
                    style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
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
          Text(
            data['name'] ?? '',
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 20),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text((data['city'] ?? '') as String,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          if (date != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(DateFormat('EEE d MMM yyyy').format(date),
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
              ],
            ),
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
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppTheme.accent.withValues(alpha: 0.4)),
                  ),
                  child: Text(race.type,
                      style: const TextStyle(
                          color: AppTheme.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
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
            Text(
              race.name,
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 20),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(race.location,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13)),
                ),
              ],
            ),
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
