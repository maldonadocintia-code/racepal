import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/race_model.dart';
import '../models/review_model.dart';
import '../services/app_provider.dart';
import '../theme.dart';
import '../screens/add_race_screen.dart';

/// Opens the "add a race you already know" sheet for [date] (the day the user
/// tapped on the Plan calendar). Searches the bundled parkrun + race data by
/// name; tapping a result adds it to the user's calendar. If they can't find
/// it, an "add manually" fallback opens the full form with the date pre-filled.
///
/// Date handling: parkruns are added on the tapped [date] (you pick which
/// Saturday by tapping it). A known race keeps its own fixed date — tapping a
/// date is just how you start the search.
Future<void> showPlanAddSheet(BuildContext context, DateTime date) async {
  final message = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.of(context).sheetBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
    ),
    builder: (_) => _PlanAddSheet(date: date),
  );
  if (message != null && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _Kind {
  parkrun, // bundled parkrun (added on the tapped date)
  assetRace, // bundled race/event (keeps its fixed date)
  community, // a race another user created — already in Firestore
}

/// A searchable known race or parkrun.
class _Known {
  final _Kind kind;
  final String name;
  final String location;
  final Map<String, dynamic>? raw; // for bundled assets
  final Race? race; // for community races already in Firestore
  final DateTime? fixedDate; // races have a fixed date; parkruns don't
  _Known({
    required this.kind,
    required this.name,
    required this.location,
    this.raw,
    this.race,
    this.fixedDate,
  });

  bool get isParkrun => kind == _Kind.parkrun;
}

class _PlanAddSheet extends StatefulWidget {
  final DateTime date;
  const _PlanAddSheet({required this.date});

  @override
  State<_PlanAddSheet> createState() => _PlanAddSheetState();
}

class _PlanAddSheetState extends State<_PlanAddSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _loaded = false;
  bool _saving = false;
  List<_Known> _all = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final provider = context.read<AppProvider>();
    final parkrunRaw = await rootBundle.loadString('assets/parkruns_uk.json');
    final eventsRaw =
        await rootBundle.loadString('assets/manchester_races.json');

    final parkruns = (jsonDecode(parkrunRaw) as List)
        .cast<Map<String, dynamic>>()
        .map((p) => _Known(
              kind: _Kind.parkrun,
              name: '${p['name']} parkrun',
              location: (p['location'] ?? '') as String,
              raw: p,
            ));

    final eventsList =
        (jsonDecode(eventsRaw) as List).cast<Map<String, dynamic>>();
    final seen = <String>{};
    final events = <_Known>[];
    for (final e in eventsList) {
      final d = DateTime.tryParse(e['startDate'] ?? '');
      if (d == null) continue;
      final key = '${e['name']}_${e['startDate']}';
      if (!seen.add(key)) continue;
      events.add(_Known(
        kind: _Kind.assetRace,
        name: (e['name'] ?? '') as String,
        location: (e['address'] ?? e['city'] ?? '') as String,
        raw: e,
        fixedDate: d,
      ));
    }

    // Races other users have created live in Firestore (createdBy != 'system').
    // Pull them in so a race one runner adds is selectable by everyone.
    List<_Known> community = const [];
    try {
      final upcoming = await provider.raceService.upcomingRaces().first;
      community = upcoming
          .where((r) => r.createdBy != 'system')
          .map((r) => _Known(
                kind: _Kind.community,
                name: r.name,
                location: r.location,
                race: r,
                fixedDate: r.date,
              ))
          .toList();
    } catch (_) {
      // Network/permission hiccup — fall back to the bundled catalog only.
    }

    if (!mounted) return;
    setState(() {
      _all = [...community, ...parkruns, ...events];
      _loaded = true;
    });
  }

  List<_Known> get _results {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return _all
        .where((k) =>
            k.name.toLowerCase().contains(q) ||
            k.location.toLowerCase().contains(q))
        .take(30)
        .toList();
  }

  Future<void> _add(_Known k) async {
    if (_saving) return;
    setState(() => _saving = true);
    final provider = context.read<AppProvider>();

    late final Race race;
    switch (k.kind) {
      case _Kind.parkrun:
        // Added on the tapped date — tapping a day is how you pick the Saturday.
        final venueId = 'pr_${k.raw!['id']}';
        final id = '${venueId}_${DateFormat('yyyyMMdd').format(widget.date)}';
        race = Race(
          id: id,
          name: k.name,
          location: k.location,
          type: 'parkrun',
          category: RaceCategory.parkrun,
          date: widget.date,
          lat: (k.raw!['lat'] as num?)?.toDouble(),
          lng: (k.raw!['lng'] as num?)?.toDouble(),
          createdBy: 'system',
        );
        break;
      case _Kind.community:
        // Already exists in Firestore — just mark attendance, keep its date.
        race = k.race!;
        break;
      case _Kind.assetRace:
        // A bundled race keeps its own fixed date, regardless of the tapped day.
        final url = k.raw!['url'];
        final id = url is String
            ? 'fa_${url.split('/').last}'
            : 'evt_${k.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}_${DateFormat('yyyyMMdd').format(k.fixedDate!)}';
        race = Race(
          id: id,
          name: k.name,
          location: k.location,
          type: 'Race',
          category: RaceCategory.race,
          date: k.fixedDate!,
          website: url is String ? url : null,
          description: k.raw!['description'] as String?,
          lat: (k.raw!['lat'] as num?)?.toDouble(),
          lng: (k.raw!['lng'] as num?)?.toDouble(),
          createdBy: 'system',
        );
        break;
    }

    // ensureRace is idempotent — it no-ops for the community race that already exists.
    await provider.raceService.ensureRace(race);
    await provider.setAttendance(
      raceId: race.id,
      raceName: race.name,
      status: AttendanceStatus.going,
    );
    if (!mounted) return;
    final on = DateFormat('EEE d MMM').format(race.date);
    Navigator.pop(context, '${race.name} added on $on 🎉');
  }

  void _addManually() {
    final nav = Navigator.of(context);
    nav.pop(); // close the sheet
    nav.push(MaterialPageRoute(
      builder: (_) => AddRaceScreen(initialDate: widget.date),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final dateLabel = DateFormat('EEE d MMM yyyy').format(widget.date);
    final results = _results;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
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
          Text('Add a race',
              style: TextStyle(
                  fontFamily: AppType.heading,
                  color: c.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: AppType.xl)),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 13, color: c.textLink),
              const SizedBox(width: 4),
              Text(dateLabel,
                  style: TextStyle(
                      color: c.textLink,
                      fontSize: AppType.sm,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            autofocus: true,
            autocorrect: false,
            textInputAction: TextInputAction.search,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search a race or parkrun by name',
              prefixIcon: Icon(Icons.search, color: c.searchIcon),
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.42,
            ),
            child: _buildResults(results),
          ),
          Divider(height: 18, color: c.divider),
          Center(
            child: TextButton.icon(
              onPressed: _addManually,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text("Can't find it? Add it manually"),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  Widget _buildResults(List<_Known> results) {
    final c = AppColors.of(context);
    if (!_loaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_query.trim().isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text('Type a race or parkrun name to find it.',
            style: TextStyle(color: c.textSecondary)),
      );
    }
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text('No matches — try "add it manually" below.',
            style: TextStyle(color: c.textSecondary)),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      itemCount: results.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: c.divider),
      itemBuilder: (_, i) => _resultTile(results[i]),
    );
  }

  Widget _resultTile(_Known k) {
    final c = AppColors.of(context);
    // parkrun = green, race = cyan (matches the rest of the app, light-safe).
    final color = k.isParkrun ? AppPalette.goGreen : c.secondary;
    final sub = k.isParkrun
        ? 'Parkrun · ${k.location}'
        : '${DateFormat('EEE d MMM yyyy').format(k.fixedDate!)} · ${k.location}';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 2),
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: color.withValues(alpha: 0.18),
        child: Icon(
          k.isParkrun ? Icons.directions_run : Icons.flag_outlined,
          size: 17,
          color: color,
        ),
      ),
      title: Text(k.name,
          style: TextStyle(
              color: c.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: AppType.base),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      subtitle: Text(sub,
          style: TextStyle(color: c.textSecondary, fontSize: AppType.sm),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      trailing: _saving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(Icons.add_circle, color: c.primary),
      onTap: _saving ? null : () => _add(k),
    );
  }
}
