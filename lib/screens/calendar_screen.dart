import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/app_provider.dart';
import '../models/race_model.dart';
import '../models/review_model.dart';
import '../models/user_model.dart';
import '../theme.dart';
import '../widgets/plan_add_sheet.dart';
import 'race_detail_screen.dart';

/// Mine = purple (theme primary), Pals = teal.
const Color _palColor = Color(0xFF22D3EE);

/// A race on the calendar, with whether it's mine and which pals are going.
class _Entry {
  final Race race;
  final bool mine;
  final List<AppUser> pals;
  final AttendanceStatus? myStatus;
  _Entry({
    required this.race,
    required this.mine,
    required this.pals,
    this.myStatus,
  });
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  // Default to month view so the "tap a day to add a race" flow is visible.
  bool _monthView = true;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final uid = provider.currentUser!.uid;
    final palUids = provider.palUids;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan'),
        actions: [
          IconButton(
            icon: Icon(_monthView
                ? Icons.list_rounded
                : Icons.calendar_month_rounded),
            tooltip: _monthView ? 'List view' : 'Month view',
            onPressed: () => setState(() => _monthView = !_monthView),
          ),
        ],
      ),
      body: Column(
        children: [
          // Colour legend — replaces the old Me / Me+Pals tabs
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.divider)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _legendDot(AppTheme.primary),
                const SizedBox(width: 6),
                const Text('Mine',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: AppTheme.fsSecondary)),
                const SizedBox(width: 18),
                _legendDot(_palColor),
                const SizedBox(width: 6),
                const Text('Pals',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: AppTheme.fsSecondary)),
              ],
            ),
          ),
          Expanded(
            child: _monthView
                ? _MonthView(uid: uid, palUids: palUids)
                : _ListView(uid: uid, palUids: palUids),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color c) =>
      Container(width: 9, height: 9, decoration: BoxDecoration(color: c, shape: BoxShape.circle));
}

// ── Shared data loader ───────────────────────────────────────────────────────

Widget _entriesLoader(
  BuildContext context,
  String uid,
  List<String> palUids,
  Widget Function(List<_Entry>) builder,
) {
  final provider = context.read<AppProvider>();
  return StreamBuilder<List<AppUser>>(
    stream: provider.palService.palsStream(uid),
    builder: (ctx, usersSnap) {
      final userMap = {
        for (final u in (usersSnap.data ?? const <AppUser>[])) u.uid: u
      };
      return StreamBuilder<List<Attendance>>(
        stream: provider.raceService.userAttendances(uid),
        builder: (ctx, mySnap) {
          return StreamBuilder<List<Attendance>>(
            stream: palUids.isEmpty
                ? Stream.value(const <Attendance>[])
                : provider.raceService.attendancesForUsers(palUids),
            builder: (ctx, palSnap) {
              if (mySnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final myAtt = mySnap.data ?? const <Attendance>[];
              final palAtt = palSnap.data ?? const <Attendance>[];
              final myIds = myAtt.map((a) => a.raceId).toSet();
              final palByRace = <String, List<AppUser>>{};
              for (final a in palAtt) {
                final u = userMap[a.userId];
                if (u == null) continue;
                (palByRace[a.raceId] ??= []).add(u);
              }
              final allIds = {...myIds, ...palByRace.keys};

              return FutureBuilder<List<_Entry>>(
                future: Future.wait(allIds.map((id) async {
                  final race = await provider.raceService.getRace(id);
                  if (race == null) return null;
                  final mineAtt = myAtt.where((a) => a.raceId == id);
                  return _Entry(
                    race: race,
                    mine: myIds.contains(id),
                    pals: palByRace[id] ?? const [],
                    myStatus: mineAtt.isEmpty ? null : mineAtt.first.status,
                  );
                })).then((l) => l.whereType<_Entry>().toList()),
                builder: (ctx, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return builder(snap.data!);
                },
              );
            },
          );
        },
      );
    },
  );
}

// ── Pal avatars + shared row ─────────────────────────────────────────────────

Widget _palAvatar(AppUser u, {double r = 12}) {
  if (u.photoUrl != null && u.photoUrl!.isNotEmpty) {
    return CircleAvatar(radius: r, backgroundImage: NetworkImage(u.photoUrl!));
  }
  return CircleAvatar(
    radius: r,
    backgroundColor: _palColor,
    child: Text(
      u.displayName.isNotEmpty ? u.displayName[0].toUpperCase() : '?',
      style: TextStyle(
          color: Colors.white, fontSize: r * 0.85, fontWeight: FontWeight.bold),
    ),
  );
}

String _palLabel(List<AppUser> pals) {
  if (pals.isEmpty) return '';
  final first = pals.first.displayName.split(' ').first;
  if (pals.length == 1) return '$first going';
  return '$first +${pals.length - 1} going';
}

Widget _entryRow(BuildContext context, _Entry e) {
  final mine = e.mine;
  final borderColor = mine ? AppTheme.primary : _palColor;
  final hasReview = e.race.isPast && e.race.reviewCount > 0;

  return GestureDetector(
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RaceDetailScreen(raceId: e.race.id)),
    ),
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(color: borderColor, width: 4),
          top: BorderSide(color: AppTheme.divider),
          right: BorderSide(color: AppTheme.divider),
          bottom: BorderSide(color: AppTheme.divider),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Text(DateFormat('MMM').format(e.race.date).toUpperCase(),
                    style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
                Text(DateFormat('d').format(e.race.date),
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: AppTheme.fsDisplay,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.race.name,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: AppTheme.fsBody)),
                const SizedBox(height: 2),
                Text(e.race.location,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: AppTheme.fsCaption)),
                if (e.pals.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      ...e.pals.take(3).map((p) => Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: _palAvatar(p, r: 11),
                          )),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(_palLabel(e.pals),
                            style: const TextStyle(
                                color: _palColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (mine)
            hasReview
                ? Row(
                    children: [
                      const Icon(Icons.star, size: 13, color: AppTheme.accent),
                      const SizedBox(width: 2),
                      Text(e.race.averageRating.toStringAsFixed(1),
                          style: const TextStyle(
                              color: AppTheme.accent,
                              fontSize: AppTheme.fsSecondary,
                              fontWeight: FontWeight.w700)),
                    ],
                  )
                : _statusChip(e.myStatus)
          else
            _miniTag('Pal', _palColor),
        ],
      ),
    ),
  );
}

Widget _statusChip(AttendanceStatus? status) {
  final label = status == AttendanceStatus.attended
      ? 'Done'
      : status == AttendanceStatus.interested
          ? 'Interested'
          : 'Going';
  final color = status == AttendanceStatus.attended
      ? Colors.green
      : status == AttendanceStatus.interested
          ? AppTheme.textSecondary
          : AppTheme.primary;
  return _miniTag(label, color);
}

Widget _miniTag(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: AppTheme.fsCaption, fontWeight: FontWeight.w600)),
    );

// ── List view ────────────────────────────────────────────────────────────────

class _ListView extends StatelessWidget {
  final String uid;
  final List<String> palUids;
  const _ListView({required this.uid, required this.palUids});

  @override
  Widget build(BuildContext context) {
    return _entriesLoader(context, uid, palUids, (entries) {
      if (entries.isEmpty) {
        return Center(
          child: Text(
            palUids.isEmpty
                ? 'No races added yet.\nBrowse Explore, or switch to Month view and tap a day to add one.'
                : 'No races yet — yours or your pals\'.',
            style: const TextStyle(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        );
      }
      final upcoming = entries.where((e) => e.race.isUpcoming).toList()
        ..sort((a, b) => a.race.date.compareTo(b.race.date));
      final past = entries.where((e) => e.race.isPast).toList()
        ..sort((a, b) => b.race.date.compareTo(a.race.date));

      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          if (upcoming.isNotEmpty) ...[
            _sectionHeader('Upcoming'),
            ...upcoming.map((e) => _entryRow(context, e)),
          ],
          if (past.isNotEmpty) ...[
            _sectionHeader('Past'),
            ...past.map((e) => _entryRow(context, e)),
          ],
        ],
      );
    });
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 6),
        child: Text(title,
            style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: AppTheme.fsCaption,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8)),
      );
}

// ── Month view ───────────────────────────────────────────────────────────────

/// Loads the calendar entries once, then hands them to [_MonthCalendar].
/// Keeping the loader here (and selection state below) separate means tapping a
/// day or changing month only rebuilds the calendar — it does NOT re-run the
/// loader, so we don't re-read every race from Firestore on each tap. See
/// BACKLOG #9.
class _MonthView extends StatelessWidget {
  final String uid;
  final List<String> palUids;
  const _MonthView({required this.uid, required this.palUids});

  @override
  Widget build(BuildContext context) {
    return _entriesLoader(
        context, uid, palUids, (entries) => _MonthCalendar(entries: entries));
  }
}

class _MonthCalendar extends StatefulWidget {
  final List<_Entry> entries;
  const _MonthCalendar({required this.entries});

  @override
  State<_MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<_MonthCalendar> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    final events = <DateTime, List<_Entry>>{};
      for (final e in entries) {
        final day =
            DateTime(e.race.date.year, e.race.date.month, e.race.date.day);
        (events[day] ??= []).add(e);
      }
      final sel =
          DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
      final selectedEntries = events[sel] ?? [];

      return Column(
        children: [
          TableCalendar<_Entry>(
            firstDay: DateTime(2020),
            lastDay: DateTime(2030),
            focusedDay: _focusedDay,
            selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
            startingDayOfWeek: StartingDayOfWeek.monday,
            eventLoader: (day) =>
                events[DateTime(day.year, day.month, day.day)] ?? [],
            calendarBuilders: CalendarBuilders(
              markerBuilder: (ctx, day, dayEntries) {
                if (dayEntries.isEmpty) return null;
                final hasMine = dayEntries.any((e) => e.mine);
                final hasPals = dayEntries.any((e) => e.pals.isNotEmpty);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (hasMine) _dot(AppTheme.primary),
                    if (hasMine && hasPals) const SizedBox(width: 3),
                    if (hasPals) _dot(_palColor),
                  ],
                );
              },
            ),
            onDaySelected: (selected, focused) => setState(() {
              _selectedDay = selected;
              _focusedDay = focused;
            }),
            onPageChanged: (focused) => setState(() => _focusedDay = focused),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.4),
                  shape: BoxShape.circle),
              selectedDecoration: const BoxDecoration(
                  color: AppTheme.primary, shape: BoxShape.circle),
              defaultTextStyle: const TextStyle(color: AppTheme.textPrimary),
              weekendTextStyle: const TextStyle(color: AppTheme.textPrimary),
              outsideTextStyle: const TextStyle(color: AppTheme.textSecondary),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
              leftChevronIcon:
                  Icon(Icons.chevron_left, color: AppTheme.textPrimary),
              rightChevronIcon:
                  Icon(Icons.chevron_right, color: AppTheme.textPrimary),
            ),
          ),
          const Divider(height: 1, color: AppTheme.divider),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              children: [
                _addButton(context, _selectedDay),
                const SizedBox(height: 12),
                if (selectedEntries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Nothing planned on this day yet.',
                        style: TextStyle(color: AppTheme.textSecondary)),
                  )
                else
                  ...selectedEntries.map((e) => _entryRow(context, e)),
              ],
            ),
          ),
        ],
      );
  }

  Widget _addButton(BuildContext context, DateTime date) => GestureDetector(
        onTap: () => showPlanAddSheet(context, date),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primary),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add, size: 18, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text('Add a race on ${DateFormat('d MMM').format(date)}',
                  style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: AppTheme.fsBody)),
            ],
          ),
        ),
      );

  Widget _dot(Color color) => Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}
