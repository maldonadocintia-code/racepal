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
import '../theme.dart';
import 'race_detail_screen.dart';
import 'add_race_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

enum _MapFilter { both, parkruns, races }

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  _MapFilter _filter = _MapFilter.both;
  bool _parkrunsLoaded = false;
  bool _eventsLoaded = false;
  List<Map<String, dynamic>> _parkrunData = [];
  List<Map<String, dynamic>> _eventData = [];
  List<Race> _races = [];
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  // Date range filter — null means "upcoming / all"
  DateTime? _filterMonth; // first day of selected month

  // Selected item for bottom sheet
  Map<String, dynamic>? _selectedParkrun;
  Map<String, dynamic>? _selectedEvent;
  Race? _selectedRace;

  static const _ukCenter = LatLng(53.0, -1.8);

  @override
  void initState() {
    super.initState();
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
    final raw = await rootBundle.loadString('assets/findarace_uk.json');
    // Keep all events with a valid date — filtering is done in _rebuildMarkers
    _eventData = (jsonDecode(raw) as List)
        .cast<Map<String, dynamic>>()
        .where((e) => DateTime.tryParse(e['startDate'] ?? '') != null)
        .toList();
    _eventsLoaded = true;
    _rebuildMarkers();
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final initial = _filterMonth ?? DateTime(now.year, now.month);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month),
      lastDate: DateTime(now.year + 3, 12),
      helpText: 'Select month',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppTheme.primary,
            surface: AppTheme.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => _filterMonth = DateTime(picked.year, picked.month));
    _rebuildMarkers();
  }

  bool _inFilterMonth(DateTime date) {
    if (_filterMonth == null) return date.isAfter(DateTime.now());
    return date.year == _filterMonth!.year &&
        date.month == _filterMonth!.month;
  }

  void _rebuildMarkers() {
    final markers = <Marker>{};

    // Parkrun markers
    if (_filter != _MapFilter.races) {
      final filtered = _searchQuery.isEmpty
          ? _parkrunData
          : _parkrunData
              .where((p) =>
                  (p['name'] as String)
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase()) ||
                  (p['location'] as String)
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase()))
              .toList();

      for (final p in filtered) {
        if (p['lat'] == null || p['lng'] == null) continue;
        final id = p['id'] as String;
        markers.add(Marker(
          markerId: MarkerId('pr_$id'),
          position: LatLng(
            (p['lat'] as num).toDouble(),
            (p['lng'] as num).toDouble(),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          onTap: () => setState(() {
            _selectedParkrun = p;
            _selectedEvent = null;
            _selectedRace = null;
          }),
        ));
      }
    }

    // Findarace event markers
    if (_filter != _MapFilter.parkruns) {
      final filtered = _eventData.where((e) {
        final d = DateTime.tryParse(e['startDate'] ?? '');
        if (d == null || !_inFilterMonth(d)) return false;
        if (_searchQuery.isEmpty) return true;
        final q = _searchQuery.toLowerCase();
        return (e['name'] as String).toLowerCase().contains(q) ||
            ((e['city'] ?? '') as String).toLowerCase().contains(q);
      }).toList();

      for (var i = 0; i < filtered.length; i++) {
        final e = filtered[i];
        if (e['lat'] == null || e['lng'] == null) continue;
        markers.add(Marker(
          markerId: MarkerId('fa_${e['url']}'),
          position: LatLng(
            (e['lat'] as num).toDouble(),
            (e['lng'] as num).toDouble(),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueOrange),
          onTap: () => setState(() {
            _selectedEvent = e;
            _selectedParkrun = null;
            _selectedRace = null;
          }),
        ));
      }
    }

    // Race markers (Firestore)
    if (_filter != _MapFilter.parkruns) {
      final filtered = _races.where((r) {
        if (!_inFilterMonth(r.date)) return false;
        if (_searchQuery.isEmpty) return true;
        final q = _searchQuery.toLowerCase();
        return r.name.toLowerCase().contains(q) ||
            r.location.toLowerCase().contains(q);
      }).toList();

      for (final r in filtered) {
        if (r.lat == null || r.lng == null) continue;
        markers.add(Marker(
          markerId: MarkerId('race_${r.id}'),
          position: LatLng(r.lat!, r.lng!),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          onTap: () => setState(() {
            _selectedRace = r;
            _selectedParkrun = null;
            _selectedEvent = null;
          }),
        ));
      }
    }

    setState(() => _markers
      ..clear()
      ..addAll(markers));
  }

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
    // parkruns are every Saturday at 9am — use the next one
    final now = DateTime.now();
    var d = DateTime(now.year, now.month, now.day, 9);
    do {
      d = d.add(const Duration(days: 1));
    } while (d.weekday != DateTime.saturday);
    await _markGoing(Race(
      id: 'pr_${p['id']}_${DateFormat('yyyyMMdd').format(d)}',
      name: '${p['name']} parkrun',
      location: p['location'] ?? '',
      type: 'parkrun',
      category: RaceCategory.parkrun,
      date: d,
      lat: (p['lat'] as num?)?.toDouble(),
      lng: (p['lng'] as num?)?.toDouble(),
      createdBy: 'system',
    ));
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

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();

    return StreamBuilder<List<Race>>(
      stream: provider.raceService.upcomingRaces(),
      builder: (ctx, snap) {
        final newRaces = snap.data ?? [];
        if (newRaces.length != _races.length) {
          _races = newRaces;
          WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildMarkers());
        }

        return Scaffold(
          body: Stack(
            children: [
              // Full-screen map
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
              ),

              // Search + filter bar
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 12,
                right: 12,
                child: Column(
                  children: [
                    // Search bar
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) {
                          _searchQuery = v;
                          _rebuildMarkers();
                        },
                        decoration: InputDecoration(
                          hintText: 'Search races & parkruns...',
                          prefixIcon: const Icon(Icons.search,
                              color: AppTheme.textSecondary),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear,
                                      color: AppTheme.textSecondary),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    _searchQuery = '';
                                    _rebuildMarkers();
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Filter chips
                    Row(
                      children: [
                        _filterChip('Both', _MapFilter.both),
                        const SizedBox(width: 8),
                        _filterChip('Parkruns', _MapFilter.parkruns),
                        const SizedBox(width: 8),
                        _filterChip('Races', _MapFilter.races),
                        const SizedBox(width: 8),
                        _monthChip(),
                        const Spacer(),
                        // Add race button
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AddRaceScreen()),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                )
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add, size: 14, color: Colors.white),
                                SizedBox(width: 4),
                                Text('Add race',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Legend
              Positioned(
                bottom: _selectedParkrun != null ||
                        _selectedRace != null ||
                        _selectedEvent != null
                    ? 220
                    : 24,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _legendBadge(Colors.green, 'Parkrun'),
                    const SizedBox(height: 6),
                    _legendBadge(Colors.orange, 'Race'),
                  ],
                ),
              ),

              // Selected parkrun panel
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
                  ),
                ),

              // Selected findarace event panel
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

              // Selected race panel
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

  Widget _monthChip() {
    final label = _filterMonth == null
        ? 'Any date'
        : DateFormat('MMM yyyy').format(_filterMonth!);
    final active = _filterMonth != null;
    return GestureDetector(
      onTap: _pickMonth,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppTheme.accent.withValues(alpha: 0.15) : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppTheme.accent : AppTheme.divider.withValues(alpha: 0.8),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 4),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 12,
                color: active ? AppTheme.accent : AppTheme.textSecondary),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                  color: active ? AppTheme.accent : AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                )),
            if (active) ...[
              const SizedBox(width: 5),
              GestureDetector(
                onTap: () {
                  setState(() => _filterMonth = null);
                  _rebuildMarkers();
                },
                child: const Icon(Icons.close,
                    size: 13, color: AppTheme.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, _MapFilter value) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _filter = value);
        _rebuildMarkers();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 4,
            )
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppTheme.textPrimary,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _legendBadge(Color color, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.2), blurRadius: 4)
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
      );
}

// ── Parkrun detail panel ───────────────────────────────────────────────────

class _ParkrunPanel extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onClose;
  final VoidCallback onAttend;
  const _ParkrunPanel(
      {required this.data, required this.onClose, required this.onAttend});

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
                  border: Border.all(
                      color: Colors.green.withValues(alpha: 0.4)),
                ),
                child: const Text('parkrun',
                    style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              IconButton(
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onAttend,
              child: const Text("I'm doing this Saturday"),
            ),
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
                Text('£${(price as num).toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
              const Spacer(),
              IconButton(
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
                  const Text('⚡',
                      style: TextStyle(fontSize: 16)),
                const Spacer(),
                IconButton(
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
