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

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showCalendarView = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final uid = provider.currentUser!.uid;
    final followingUids = provider.followingUids;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        bottom: _showCalendarView
            ? null
            : TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Mine'),
                  Tab(text: 'Pals'),
                ],
                indicatorColor: AppTheme.accent,
                labelColor: AppTheme.textPrimary,
                unselectedLabelColor: AppTheme.textSecondary,
              ),
        actions: [
          IconButton(
            icon: Icon(_showCalendarView
                ? Icons.list_rounded
                : Icons.calendar_month_rounded),
            onPressed: () =>
                setState(() => _showCalendarView = !_showCalendarView),
          ),
        ],
      ),
      body: _showCalendarView
          ? _CalendarView(uid: uid, followingUids: followingUids)
          : TabBarView(
              controller: _tabController,
              children: [
                _RaceList(
                  stream: provider.raceService.userAttendances(uid),
                  label: 'No races added yet.\nFind events on the Map!',
                ),
                _PalsRaceList(
                  followingUids: followingUids,
                  provider: provider,
                ),
              ],
            ),
    );
  }
}

// ── List view — my races ───────────────────────────────────────────────────

class _RaceList extends StatelessWidget {
  final Stream<List<Attendance>> stream;
  final String label;

  const _RaceList({required this.stream, required this.label});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();

    return StreamBuilder<List<Attendance>>(
      stream: stream,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final attendances = snap.data ?? [];
        if (attendances.isEmpty) {
          return Center(
            child: Text(label,
                style: const TextStyle(color: AppTheme.textSecondary),
                textAlign: TextAlign.center),
          );
        }
        return FutureBuilder<List<Race>>(
          future: Future.wait(
            attendances.map((a) => provider.raceService.getRace(a.raceId)),
          ).then((list) => list
              .whereType<Race>()
              .toList()
            ..sort((a, b) => a.date.compareTo(b.date))),
          builder: (ctx, raceSnap) {
            if (!raceSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final races = raceSnap.data!;
            final upcoming = races.where((r) => r.isUpcoming).toList();
            final past = races.where((r) => r.isPast).toList()
              ..sort((a, b) => b.date.compareTo(a.date));

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                if (upcoming.isNotEmpty) ...[
                  _sectionHeader('Upcoming'),
                  ...upcoming.map((r) => _raceRow(ctx, r, attendances)),
                ],
                if (past.isNotEmpty) ...[
                  _sectionHeader('Past'),
                  ...past.map((r) => _raceRow(ctx, r, attendances)),
                ],
              ],
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

  Widget _raceRow(BuildContext ctx, Race race, List<Attendance> attendances) {
    final attendance = attendances.firstWhere(
      (a) => a.raceId == race.id,
      orElse: () => Attendance(
          id: '', raceId: race.id, userId: '', status: AttendanceStatus.going, createdAt: DateTime.now()),
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
          border: Border.all(color: AppTheme.divider),
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
                ],
              ),
            ),
            // Status / rating
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (hasReview) ...[
                  Row(
                    children: [
                      const Icon(Icons.star, size: 13, color: AppTheme.accent),
                      const SizedBox(width: 2),
                      Text(race.averageRating.toStringAsFixed(1),
                          style: const TextStyle(
                              color: AppTheme.accent,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ] else ...[
                  _statusChip(attendance.status),
                ],
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
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Pals races ─────────────────────────────────────────────────────────────

class _PalsRaceList extends StatelessWidget {
  final List<String> followingUids;
  final AppProvider provider;

  const _PalsRaceList(
      {required this.followingUids, required this.provider});

  @override
  Widget build(BuildContext context) {
    if (followingUids.isEmpty) {
      return const Center(
        child: Text('Follow some runners to see their plans here.',
            style: TextStyle(color: AppTheme.textSecondary),
            textAlign: TextAlign.center),
      );
    }

    return StreamBuilder<List<Attendance>>(
      stream: provider.raceService.attendancesForUsers(followingUids),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final attendances = snap.data ?? [];
        if (attendances.isEmpty) {
          return const Center(
            child: Text('Your pals haven\'t signed up for anything yet.',
                style: TextStyle(color: AppTheme.textSecondary),
                textAlign: TextAlign.center),
          );
        }
        return FutureBuilder<List<Race>>(
          future: Future.wait(
            attendances.map((a) => provider.raceService.getRace(a.raceId)),
          ).then((list) => list
              .whereType<Race>()
              .where((r) => r.isUpcoming)
              .toList()
            ..sort((a, b) => a.date.compareTo(b.date))),
          builder: (ctx, raceSnap) {
            if (!raceSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final races = raceSnap.data!;
            if (races.isEmpty) {
              return const Center(
                child: Text('No upcoming events from your pals.',
                    style: TextStyle(color: AppTheme.textSecondary)),
              );
            }
            return ListView.builder(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: races.length,
              itemBuilder: (ctx, i) => RaceCard(
                race: races[i],
                onTap: () => Navigator.push(
                  ctx,
                  MaterialPageRoute(
                      builder: (_) =>
                          RaceDetailScreen(raceId: races[i].id)),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Calendar view ──────────────────────────────────────────────────────────

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
      builder: (ctx, snap) {
        final attendances = snap.data ?? [];

        return FutureBuilder<List<Race>>(
          future: Future.wait(
            attendances.map((a) => provider.raceService.getRace(a.raceId)),
          ).then((list) => list.whereType<Race>().toList()),
          builder: (ctx, raceSnap) {
            final races = raceSnap.data ?? [];

            Map<DateTime, List<Race>> events = {};
            for (final r in races) {
              final day =
                  DateTime(r.date.year, r.date.month, r.date.day);
              events[day] = [...(events[day] ?? []), r];
            }

            final selectedEvents = events[DateTime(
                  _selectedDay.year,
                  _selectedDay.month,
                  _selectedDay.day,
                )] ??
                [];

            return Column(
              children: [
                TableCalendar<Race>(
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
                  onDaySelected: (selected, focused) => setState(() {
                    _selectedDay = selected;
                    _focusedDay = focused;
                  }),
                  onPageChanged: (focused) =>
                      setState(() => _focusedDay = focused),
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color:
                          AppTheme.primary.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    markerDecoration: const BoxDecoration(
                      color: AppTheme.accent,
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
                const Divider(height: 1, color: AppTheme.divider),
                if (selectedEvents.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No events on this day',
                        style:
                            TextStyle(color: AppTheme.textSecondary)),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: selectedEvents.length,
                      itemBuilder: (ctx, i) => RaceCard(
                        race: selectedEvents[i],
                        onTap: () => Navigator.push(
                          ctx,
                          MaterialPageRoute(
                            builder: (_) => RaceDetailScreen(
                                raceId: selectedEvents[i].id),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
