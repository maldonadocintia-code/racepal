import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/app_provider.dart';
import '../models/race_model.dart';
import '../models/review_model.dart';
import '../widgets/shared_widgets.dart';
import '../theme.dart';
import 'race_detail_screen.dart';

// Wraps a race with ownership info for the combined view
class _RaceEntry {
  final Race race;
  final bool mine;
  _RaceEntry(this.race, {required this.mine});
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  bool _showPals = false;
  bool _showCalendarView = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final uid = provider.currentUser!.uid;
    final followingUids = provider.followingUids;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            icon: Icon(_showCalendarView
                ? Icons.list_rounded
                : Icons.calendar_month_rounded),
            tooltip: _showCalendarView ? 'List view' : 'Month view',
            onPressed: () =>
                setState(() => _showCalendarView = !_showCalendarView),
          ),
        ],
      ),
      body: Column(
        children: [
          // Toggle bar
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.divider)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _toggleChip('Me', !_showPals, () => setState(() => _showPals = false)),
                const SizedBox(width: 8),
                _toggleChip('Me + Pals', _showPals, () => setState(() => _showPals = true)),
              ],
            ),
          ),
          Expanded(
            child: _showCalendarView
                ? _CalendarView(
                    uid: uid,
                    followingUids: _showPals ? followingUids : [],
                  )
                : _ListView(
                    uid: uid,
                    followingUids: _showPals ? followingUids : [],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _toggleChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppTheme.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ── Combined list view ─────────────────────────────────────────────────────

class _ListView extends StatelessWidget {
  final String uid;
  final List<String> followingUids;

  const _ListView({required this.uid, required this.followingUids});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();

    return StreamBuilder<List<Attendance>>(
      stream: provider.raceService.userAttendances(uid),
      builder: (ctx, mySnap) {
        return StreamBuilder<List<Attendance>>(
          stream: followingUids.isEmpty
              ? Stream.value([])
              : provider.raceService.attendancesForUsers(followingUids),
          builder: (ctx, palSnap) {
            if (mySnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final myAttendances = mySnap.data ?? [];
            final palAttendances = palSnap.data ?? [];

            // Collect all unique raceIds
            final myRaceIds = myAttendances.map((a) => a.raceId).toSet();
            final allAttendances = [
              ...myAttendances.map((a) => MapEntry(a.raceId, true)),
              ...palAttendances
                  .where((a) => !myRaceIds.contains(a.raceId))
                  .map((a) => MapEntry(a.raceId, false)),
            ];

            if (allAttendances.isEmpty) {
              return Center(
                child: Text(
                  followingUids.isEmpty
                      ? 'No races added yet.\nFind events on the Map!'
                      : 'No races yet — yours or your pals\'.',
                  style: const TextStyle(color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
              );
            }

            return FutureBuilder<List<_RaceEntry>>(
              future: Future.wait(
                allAttendances.map((e) async {
                  final race = await provider.raceService.getRace(e.key);
                  if (race == null) return null;
                  return _RaceEntry(race, mine: e.value);
                }),
              ).then((list) => list
                  .whereType<_RaceEntry>()
                  .toList()
                ..sort((a, b) => a.race.date.compareTo(b.race.date))),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final entries = snap.data!;
                final upcoming =
                    entries.where((e) => e.race.isUpcoming).toList();
                final past = entries
                    .where((e) => e.race.isPast)
                    .toList()
                  ..sort((a, b) => b.race.date.compareTo(a.race.date));

                if (entries.isEmpty) {
                  return const Center(
                    child: Text('No races yet.',
                        style: TextStyle(color: AppTheme.textSecondary)),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  children: [
                    if (upcoming.isNotEmpty) ...[
                      _sectionHeader('Upcoming'),
                      ...upcoming.map((e) => _raceRow(
                          ctx, e.race, myAttendances, e.mine)),
                    ],
                    if (past.isNotEmpty) ...[
                      _sectionHeader('Past'),
                      ...past.map((e) =>
                          _raceRow(ctx, e.race, myAttendances, e.mine)),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 6),
        child: Text(title,
            style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8)),
      );

  Widget _raceRow(BuildContext ctx, Race race,
      List<Attendance> myAttendances, bool mine) {
    final attendance = myAttendances.firstWhere(
      (a) => a.raceId == race.id,
      orElse: () => Attendance(
          id: '',
          raceId: race.id,
          userId: '',
          status: AttendanceStatus.going,
          createdAt: DateTime.now()),
    );
    final hasReview = race.isPast && race.reviewCount > 0;

    return GestureDetector(
      onTap: () => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => RaceDetailScreen(raceId: race.id)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: mine ? AppTheme.divider : AppTheme.primary.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            // Date column
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  Text(
                    DateFormat('MMM').format(race.date).toUpperCase(),
                    style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                  ),
                  Text(
                    DateFormat('d').format(race.date),
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const VerticalDivider(width: 1, color: AppTheme.divider),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(race.name,
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(race.location,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                  if (!mine) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.people,
                            size: 12,
                            color: AppTheme.primary.withValues(alpha: 0.8)),
                        const SizedBox(width: 4),
                        Text('Pal is going',
                            style: TextStyle(
                                color:
                                    AppTheme.primary.withValues(alpha: 0.8),
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Status / rating
            if (mine)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (hasReview)
                    Row(
                      children: [
                        const Icon(Icons.star,
                            size: 13, color: AppTheme.accent),
                        const SizedBox(width: 2),
                        Text(race.averageRating.toStringAsFixed(1),
                            style: const TextStyle(
                                color: AppTheme.accent,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ],
                    )
                  else
                    _statusChip(attendance.status),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(AttendanceStatus status) {
    final label = status == AttendanceStatus.going
        ? 'Going'
        : status == AttendanceStatus.attended
            ? 'Done'
            : 'Interested';
    final color = status == AttendanceStatus.going
        ? AppTheme.primary
        : status == AttendanceStatus.attended
            ? Colors.green
            : AppTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Calendar month view ────────────────────────────────────────────────────

class _CalendarView extends StatefulWidget {
  final String uid;
  final List<String> followingUids;
  const _CalendarView({required this.uid, required this.followingUids});

  @override
  State<_CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<_CalendarView> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();

    return StreamBuilder<List<Attendance>>(
      stream: provider.raceService.userAttendances(widget.uid),
      builder: (ctx, mySnap) {
        return StreamBuilder<List<Attendance>>(
          stream: widget.followingUids.isEmpty
              ? Stream.value([])
              : provider.raceService
                  .attendancesForUsers(widget.followingUids),
          builder: (ctx, palSnap) {
            final myAttendances = mySnap.data ?? [];
            final palAttendances = palSnap.data ?? [];
            final myRaceIds = myAttendances.map((a) => a.raceId).toSet();

            final allRaceIds = [
              ...myAttendances.map((a) => MapEntry(a.raceId, true)),
              ...palAttendances
                  .where((a) => !myRaceIds.contains(a.raceId))
                  .map((a) => MapEntry(a.raceId, false)),
            ];

            return FutureBuilder<List<_RaceEntry>>(
              future: Future.wait(
                allRaceIds.map((e) async {
                  final race = await provider.raceService.getRace(e.key);
                  if (race == null) return null;
                  return _RaceEntry(race, mine: e.value);
                }),
              ).then((list) => list.whereType<_RaceEntry>().toList()),
              builder: (ctx, snap) {
                final entries = snap.data ?? [];

                // Build event map keyed by day
                final Map<DateTime, List<_RaceEntry>> events = {};
                for (final e in entries) {
                  final day = DateTime(
                      e.race.date.year, e.race.date.month, e.race.date.day);
                  events[day] = [...(events[day] ?? []), e];
                }

                final selected = DateTime(
                    _selectedDay.year, _selectedDay.month, _selectedDay.day);
                final selectedEntries = events[selected] ?? [];

                return Column(
                  children: [
                    TableCalendar<_RaceEntry>(
                      firstDay: DateTime(2020),
                      lastDay: DateTime(2030),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (d) =>
                          isSameDay(d, _selectedDay),
                      startingDayOfWeek: StartingDayOfWeek.monday,
                      eventLoader: (day) {
                        final key =
                            DateTime(day.year, day.month, day.day);
                        return events[key] ?? [];
                      },
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (ctx, day, dayEntries) {
                          if (dayEntries.isEmpty) return null;
                          final hasMine =
                              dayEntries.any((e) => e.mine);
                          final hasPals =
                              dayEntries.any((e) => !e.mine);
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (hasMine)
                                _dot(AppTheme.accent),
                              if (hasMine && hasPals)
                                const SizedBox(width: 3),
                              if (hasPals)
                                _dot(AppTheme.primary
                                    .withValues(alpha: 0.6)),
                            ],
                          );
                        },
                      ),
                      onDaySelected: (selected, focused) =>
                          setState(() {
                        _selectedDay = selected;
                        _focusedDay = focused;
                      }),
                      onPageChanged: (focused) =>
                          setState(() => _focusedDay = focused),
                      calendarStyle: CalendarStyle(
                        todayDecoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: const BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        defaultTextStyle: const TextStyle(
                            color: AppTheme.textPrimary),
                        weekendTextStyle: const TextStyle(
                            color: AppTheme.textPrimary),
                        outsideTextStyle: const TextStyle(
                            color: AppTheme.textSecondary),
                      ),
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700),
                        leftChevronIcon: Icon(Icons.chevron_left,
                            color: AppTheme.textPrimary),
                        rightChevronIcon: Icon(Icons.chevron_right,
                            color: AppTheme.textPrimary),
                      ),
                    ),
                    // Dot legend (only in Me + Pals mode)
                    if (widget.followingUids.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        child: Row(
                          children: [
                            _dot(AppTheme.accent),
                            const SizedBox(width: 6),
                            const Text('Mine',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12)),
                            const SizedBox(width: 16),
                            _dot(AppTheme.primary.withValues(alpha: 0.6)),
                            const SizedBox(width: 6),
                            const Text('Pals',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                    const Divider(height: 1, color: AppTheme.divider),
                    if (selectedEntries.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No events on this day',
                            style: TextStyle(
                                color: AppTheme.textSecondary)),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: selectedEntries.length,
                          itemBuilder: (ctx, i) {
                            final entry = selectedEntries[i];
                            return Stack(
                              children: [
                                RaceCard(
                                  race: entry.race,
                                  onTap: () => Navigator.push(
                                    ctx,
                                    MaterialPageRoute(
                                      builder: (_) => RaceDetailScreen(
                                          raceId: entry.race.id),
                                    ),
                                  ),
                                ),
                                if (!entry.mine)
                                  Positioned(
                                    top: 10,
                                    right: 18,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary
                                            .withValues(alpha: 0.15),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                        border: Border.all(
                                            color: AppTheme.primary
                                                .withValues(alpha: 0.4)),
                                      ),
                                      child: const Text('Pal',
                                          style: TextStyle(
                                              color: AppTheme.primary,
                                              fontSize: 10,
                                              fontWeight:
                                                  FontWeight.w700)),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _dot(Color color) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
