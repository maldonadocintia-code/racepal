import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../services/app_provider.dart';
import '../models/race_model.dart';
import '../models/user_model.dart';
import '../widgets/shared_widgets.dart';
import '../theme.dart';
import 'race_detail_screen.dart';
import 'profile_screen.dart';
import 'add_race_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  String _selectedRaceType = 'All';
  String _selectedFindType = 'All';
  bool _showMap = false;
  List<_ParkrunPin> _parkrunPins = [];
  bool _parkrunsLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadParkruns() async {
    if (_parkrunsLoaded) return;
    final raw = await rootBundle.loadString('assets/parkruns_uk.json');
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    setState(() {
      _parkrunPins = list
          .where((e) => e['lat'] != null && e['lng'] != null)
          .map((e) => _ParkrunPin(
                id: e['id'] as String,
                name: e['name'] as String,
                location: e['location'] as String,
                lat: (e['lat'] as num).toDouble(),
                lng: (e['lng'] as num).toDouble(),
              ))
          .toList();
      _parkrunsLoaded = true;
    });
  }

  void _toggleMap() {
    setState(() => _showMap = !_showMap);
    if (_showMap) _loadParkruns();
  }

  String get _searchHint {
    if (_tabController.index == 0) return 'Search races & parkruns...';
    if (_tabController.index == 1) return 'Search events by name or city...';
    return 'Search runners...';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        bottom: _showMap
            ? null
            : TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Races & Parkruns'),
                  Tab(text: 'Find a Race'),
                  Tab(text: 'Runners'),
                ],
                indicatorColor: AppTheme.accent,
                labelColor: AppTheme.textPrimary,
                unselectedLabelColor: AppTheme.textSecondary,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
              ),
        actions: [
          IconButton(
            icon: Icon(_showMap ? Icons.list_rounded : Icons.map_rounded),
            tooltip: _showMap ? 'List view' : 'Map view',
            onPressed: _toggleMap,
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add race',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddRaceScreen()),
            ),
          ),
        ],
      ),
      body: _showMap
          ? _MapView(parkrunPins: _parkrunPins)
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: _searchHint,
                      prefixIcon: const Icon(Icons.search,
                          color: AppTheme.textSecondary),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  color: AppTheme.textSecondary),
                              onPressed: () => _searchCtrl.clear(),
                            )
                          : null,
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _RacesTab(
                        query: _query,
                        selectedType: _selectedRaceType,
                        onTypeChanged: (t) =>
                            setState(() => _selectedRaceType = t),
                      ),
                      _FindARaceTab(
                        query: _query,
                        selectedType: _selectedFindType,
                        onTypeChanged: (t) =>
                            setState(() => _selectedFindType = t),
                      ),
                      _RunnersTab(query: _query),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Map view ───────────────────────────────────────────────────────────────

class _ParkrunPin {
  final String id;
  final String name;
  final String location;
  final double lat;
  final double lng;
  const _ParkrunPin(
      {required this.id,
      required this.name,
      required this.location,
      required this.lat,
      required this.lng});
}

class _MapView extends StatefulWidget {
  final List<_ParkrunPin> parkrunPins;
  const _MapView({required this.parkrunPins});

  @override
  State<_MapView> createState() => _MapViewState();
}

class _MapViewState extends State<_MapView> {
  _ParkrunPin? _selectedParkrun;
  Race? _selectedRace;

  void _clearSelection() => setState(() {
        _selectedParkrun = null;
        _selectedRace = null;
      });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return StreamBuilder<List<Race>>(
      stream: provider.raceService.upcomingRaces(),
      builder: (context, snap) {
        final races =
            (snap.data ?? []).where((r) => r.lat != null && r.lng != null).toList();

        return Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: const LatLng(53.0, -1.8),
                initialZoom: 6.5,
                onTap: (_, __) => _clearSelection(),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.racepal.app',
                  tileBuilder: _darkTileBuilder,
                ),
                MarkerLayer(
                  markers: widget.parkrunPins.map((p) {
                    final selected = _selectedParkrun?.id == p.id;
                    return Marker(
                      point: LatLng(p.lat, p.lng),
                      width: selected ? 18 : 12,
                      height: selected ? 18 : 12,
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedParkrun = p;
                          _selectedRace = null;
                        }),
                        child: Container(
                          decoration: BoxDecoration(
                            color: selected
                                ? AppTheme.primary
                                : AppTheme.primary.withValues(alpha: 0.7),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.6),
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                MarkerLayer(
                  markers: races.map((r) {
                    final selected = _selectedRace?.id == r.id;
                    return Marker(
                      point: LatLng(r.lat!, r.lng!),
                      width: selected ? 28 : 22,
                      height: selected ? 28 : 22,
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedRace = r;
                          _selectedParkrun = null;
                        }),
                        child: Container(
                          decoration: BoxDecoration(
                            color: selected
                                ? AppTheme.accent
                                : AppTheme.accent.withValues(alpha: 0.85),
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.black26, width: 1.5),
                          ),
                          child: const Icon(Icons.flag,
                              size: 12, color: Colors.black),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),

            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _legendItem(AppTheme.primary, 'parkruns (${widget.parkrunPins.length})'),
                    const SizedBox(height: 4),
                    _legendItem(AppTheme.accent, 'races (${races.length})'),
                  ],
                ),
              ),
            ),

            if (_selectedParkrun != null)
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: _ParkrunCard(
                  pin: _selectedParkrun!,
                  onClose: _clearSelection,
                ),
              ),

            if (_selectedRace != null)
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: _RaceMapCard(
                  race: _selectedRace!,
                  onClose: _clearSelection,
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
        );
      },
    );
  }

  Widget _legendItem(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 11)),
        ],
      );

  Widget _darkTileBuilder(
      BuildContext context, Widget tileWidget, TileImage tile) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        -0.8, 0, 0, 0, 255,
        0, -0.8, 0, 0, 255,
        0, 0, -0.8, 0, 255,
        0, 0, 0, 1, 0,
      ]),
      child: tileWidget,
    );
  }
}

class _ParkrunCard extends StatelessWidget {
  final _ParkrunPin pin;
  final VoidCallback onClose;
  const _ParkrunCard({required this.pin, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bolt, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${pin.name} parkrun',
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                Text(pin.location,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
              icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 18),
              onPressed: onClose),
        ],
      ),
    );
  }
}

class _RaceMapCard extends StatelessWidget {
  final Race race;
  final VoidCallback onClose;
  final VoidCallback onTap;
  const _RaceMapCard(
      {required this.race, required this.onClose, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.flag, color: AppTheme.accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(race.name,
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                  Text(race.location,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            IconButton(
                icon: const Icon(Icons.close,
                    color: AppTheme.textSecondary, size: 18),
                onPressed: onClose),
          ],
        ),
      ),
    );
  }
}

// ── Races list tab ─────────────────────────────────────────────────────────

class _RacesTab extends StatelessWidget {
  final String query;
  final String selectedType;
  final ValueChanged<String> onTypeChanged;

  const _RacesTab({
    required this.query,
    required this.selectedType,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final types = ['All', ...AppConstants.raceTypes];

    return Column(
      children: [
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: types.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final t = types[i];
              final selected = t == selectedType;
              return GestureDetector(
                onTap: () => onTypeChanged(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.primary
                        : AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    t,
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: selected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<List<Race>>(
            stream: provider.raceService.upcomingRaces(
              type: selectedType == 'All' ? null : selectedType,
            ),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              var races = snap.data ?? [];
              if (query.isNotEmpty) {
                races = races
                    .where((r) =>
                        r.name
                            .toLowerCase()
                            .contains(query.toLowerCase()) ||
                        r.location
                            .toLowerCase()
                            .contains(query.toLowerCase()))
                    .toList();
              }
              if (races.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.flag,
                          size: 48, color: AppTheme.textSecondary),
                      const SizedBox(height: 12),
                      const Text('No races found',
                          style:
                              TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AddRaceScreen()),
                        ),
                        child: const Text('Add a race'),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: races.length,
                itemBuilder: (ctx, i) => RaceCard(
                  race: races[i],
                  onTap: () => Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) =>
                          RaceDetailScreen(raceId: races[i].id),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Find a Race tab ────────────────────────────────────────────────────────

class _FindRaceItem {
  final String name;
  final String url;
  final DateTime date;
  final String city;
  final String address;
  final String? description;
  final double? lat;
  final double? lng;
  final String? price;
  final String type;

  const _FindRaceItem({
    required this.name,
    required this.url,
    required this.date,
    required this.city,
    required this.address,
    this.description,
    this.lat,
    this.lng,
    this.price,
    required this.type,
  });
}

String _inferRaceType(String name) {
  final n = name.toLowerCase();
  if (n.contains('ultra')) return 'Ultra';
  if ((n.contains('half') && n.contains('marathon')) ||
      n.contains('half-marathon') ||
      n.contains('21k') ||
      n.contains('21km')) return 'Half Marathon';
  if (n.contains('marathon')) return 'Marathon';
  if (n.contains('10k') || n.contains('10km') || n.contains('10 km') || n.contains('10-k')) return '10K';
  if (n.contains('5k') || n.contains('5km') || n.contains('5 km') || n.contains('5-k')) return '5K';
  if (n.contains('trail') || n.contains('fell') || n.contains('off road') || n.contains('cross country')) return 'Trail';
  if (n.contains('mile') || n.contains('1 mile')) return 'Mile';
  return 'Other';
}

class _FindARaceTab extends StatefulWidget {
  final String query;
  final String selectedType;
  final ValueChanged<String> onTypeChanged;

  const _FindARaceTab({
    required this.query,
    required this.selectedType,
    required this.onTypeChanged,
  });

  @override
  State<_FindARaceTab> createState() => _FindARaceTabState();
}

class _FindARaceTabState extends State<_FindARaceTab>
    with AutomaticKeepAliveClientMixin {
  List<_FindRaceItem> _allRaces = [];
  bool _loaded = false;
  final Set<String> _addingUrls = {};
  final Set<String> _addedUrls = {};

  static const _types = [
    'All', '5K', '10K', 'Half Marathon', 'Marathon', 'Ultra', 'Trail', 'Mile', 'Other',
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = await rootBundle.loadString('assets/findarace_uk.json');
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    setState(() {
      _allRaces = list.map((e) {
        final dateStr = e['startDate'] as String? ?? '';
        DateTime date;
        try {
          date = DateTime.parse(dateStr);
        } catch (_) {
          date = DateTime.now();
        }
        return _FindRaceItem(
          name: e['name'] as String? ?? '',
          url: e['url'] as String? ?? '',
          date: date,
          city: e['city'] as String? ?? '',
          address: e['address'] as String? ?? '',
          description: e['description'] as String?,
          lat: (e['lat'] as num?)?.toDouble(),
          lng: (e['lng'] as num?)?.toDouble(),
          price: e['price'] as String?,
          type: _inferRaceType(e['name'] as String? ?? ''),
        );
      }).toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      _loaded = true;
    });
  }

  List<_FindRaceItem> get _filtered {
    var races = _allRaces;
    if (widget.selectedType != 'All') {
      races = races.where((r) => r.type == widget.selectedType).toList();
    }
    if (widget.query.isNotEmpty) {
      final q = widget.query.toLowerCase();
      races = races
          .where((r) =>
              r.name.toLowerCase().contains(q) ||
              r.city.toLowerCase().contains(q))
          .toList();
    }
    return races;
  }

  Future<void> _addToRacePal(BuildContext context, _FindRaceItem item) async {
    final provider = context.read<AppProvider>();
    final uid = provider.currentUser?.uid;
    if (uid == null) return;

    setState(() => _addingUrls.add(item.url));
    try {
      final race = Race(
        id: '',
        name: item.name,
        location: item.city.isNotEmpty ? item.city : item.address,
        type: item.type,
        category: RaceCategory.race,
        date: item.date,
        website: item.url,
        description: item.description,
        lat: item.lat,
        lng: item.lng,
        createdBy: uid,
      );
      await provider.raceService.addRace(race);
      setState(() => _addedUrls.add(item.url));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.name} added to RacePal'),
            backgroundColor: AppTheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() => _addingUrls.remove(item.url));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final races = _filtered;

    return Column(
      children: [
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _types.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final t = _types[i];
              final selected = t == widget.selectedType;
              return GestureDetector(
                onTap: () => widget.onTypeChanged(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.primary : AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    t,
                    style: TextStyle(
                      color: selected ? Colors.white : AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${races.length} events',
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: races.isEmpty
              ? const Center(
                  child: Text('No events found',
                      style: TextStyle(color: AppTheme.textSecondary)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: races.length,
                  itemBuilder: (ctx, i) => _FindARaceCard(
                    item: races[i],
                    isAdding: _addingUrls.contains(races[i].url),
                    isAdded: _addedUrls.contains(races[i].url),
                    onAdd: () => _addToRacePal(ctx, races[i]),
                    onOpen: () async {
                      final uri = Uri.tryParse(races[i].url);
                      if (uri != null) await launchUrl(uri);
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _FindARaceCard extends StatelessWidget {
  final _FindRaceItem item;
  final bool isAdding;
  final bool isAdded;
  final VoidCallback onAdd;
  final VoidCallback onOpen;

  const _FindARaceCard({
    required this.item,
    required this.isAdding,
    required this.isAdded,
    required this.onAdd,
    required this.onOpen,
  });

  static Color _typeColor(String type) {
    switch (type) {
      case '5K': return const Color(0xFF4CAF50);
      case '10K': return const Color(0xFF2196F3);
      case 'Half Marathon': return const Color(0xFF9C27B0);
      case 'Marathon': return const Color(0xFFE91E63);
      case 'Ultra': return const Color(0xFFFF5722);
      case 'Trail': return const Color(0xFF795548);
      case 'Mile': return const Color(0xFF00BCD4);
      default: return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE d MMM yyyy').format(item.date.toLocal());
    final color = _typeColor(item.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Text(item.type,
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(dateStr,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ),
              if (item.price != null && item.price!.isNotEmpty)
                Text(item.price!,
                    style: const TextStyle(
                        color: AppTheme.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.name,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 15),
          ),
          if (item.city.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 13, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(item.city,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new, size: 14),
                label: const Text('Details', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  side: const BorderSide(color: AppTheme.divider),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              if (isAdded)
                const Row(
                  children: [
                    Icon(Icons.check_circle, color: AppTheme.primary, size: 18),
                    SizedBox(width: 4),
                    Text('Added',
                        style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                )
              else
                FilledButton.icon(
                  onPressed: isAdding ? null : onAdd,
                  icon: isAdding
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.add, size: 16),
                  label: const Text('Add to RacePal',
                      style: TextStyle(fontSize: 13)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Runners tab ────────────────────────────────────────────────────────────

class _RunnersTab extends StatefulWidget {
  final String query;
  const _RunnersTab({required this.query});

  @override
  State<_RunnersTab> createState() => _RunnersTabState();
}

class _RunnersTabState extends State<_RunnersTab> {
  List<AppUser> _results = [];
  bool _searching = false;

  @override
  void didUpdateWidget(_RunnersTab old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query) _search(widget.query);
  }

  Future<void> _search(String q) async {
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    final provider = context.read<AppProvider>();
    final res = await provider.followService.searchUsers(q);
    if (mounted) setState(() { _results = res; _searching = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (widget.query.isEmpty) {
      return const Center(
        child: Text('Search for runners by name',
            style: TextStyle(color: AppTheme.textSecondary)),
      );
    }
    if (_results.isEmpty) {
      return const Center(
        child: Text('No runners found',
            style: TextStyle(color: AppTheme.textSecondary)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _results.length,
      itemBuilder: (ctx, i) {
        final user = _results[i];
        return ListTile(
          leading: UserAvatar(
            photoUrl: user.photoUrl,
            displayName: user.displayName,
            radius: 22,
          ),
          title: Text(user.displayName),
          subtitle: Text(
            '${user.racesCount} races · ${user.followersCount} followers',
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12),
          ),
          trailing: Icon(
            user.isPublic ? Icons.person : Icons.lock,
            size: 16,
            color: AppTheme.textSecondary,
          ),
          onTap: () => Navigator.push(
            ctx,
            MaterialPageRoute(builder: (_) => ProfileScreen(uid: user.uid)),
          ),
        );
      },
    );
  }
}
