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
    final c = AppColors.of(context);
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
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: c.divider)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _legendDot(c.calDotMine),
                const SizedBox(width: 6),
                Text('Mine',
                    style: TextStyle(
                        color: c.textSecondary, fontSize: AppType.sm)),
                const SizedBox(width: 18),
                _legendDot(c.calDotPals),
                const SizedBox(width: 6),
                Text('Pals',
                    style: TextStyle(
                        color: c.textSecondary, fontSize: AppType.sm)),
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

  Widget _legendDot(Color c) => Container(
      width: 9, height: 9, decoration: BoxDecoration(color: c, shape: BoxShape.circle));
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

Widget _palAvatar(BuildContext context, AppUser u, {double r = 12}) {
  final c = AppColors.of(context);
  if (u.photoUrl != null && u.photoUrl!.isNotEmpty) {
    return CircleAvatar(radius: r, backgroundImage: NetworkImage(u.photoUrl!));
  }
  return CircleAvatar(
    radius: r,
    backgroundColor: c.pals,
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
  final c = AppColors.of(context);
  final mine = e.mine;
  final borderColor = mine ? c.planBarMine : c.planBarPals;
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
        color: c.bgSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border(
          left: BorderSide(color: borderColor, width: 4),
          top: BorderSide(color: c.border),
          right: BorderSide(color: c.border),
          bottom: BorderSide(color: c.border),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Text(DateFormat('MMM').format(e.race.date).toUpperCase(),
                    style: TextStyle(
                        color: c.textTertiary,
                        fontSize: AppType.xs,
                        fontWeight: FontWeight.w600)),
                Text(DateFormat('d').format(e.race.date),
                    style: TextStyle(
                        fontFamily: AppType.display,
                        color: c.textPrimary,
                        fontSize: AppType.xxl,
                        height: 1.1,
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
                    style: TextStyle(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w500,
                        fontSize: AppType.md)),
                const SizedBox(height: 2),
                Text(e.race.location,
                    style: TextStyle(
                        color: c.textSecondary, fontSize: AppType.sm)),
                if (e.pals.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      ...e.pals.take(3).map((p) => Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: _palAvatar(context, p, r: 11),
                          )),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(_palLabel(e.pals),
                            style: TextStyle(
                                color: c.pals,
                                fontSize: AppType.sm,
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
                      Icon(Icons.star, size: 13, color: c.achievement),
                      const SizedBox(width: 2),
                      Text(e.race.averageRating.toStringAsFixed(1),
                          style: TextStyle(
                              color: c.achievement,
                              fontSize: AppType.sm,
                              fontWeight: FontWeight.w700)),
                    ],
                  )
                : _statusChip(context, e.myStatus)
          else
            _miniTag('Pal', c.pals),
        ],
      ),
    ),
  );
}

Widget _statusChip(BuildContext context, AttendanceStatus? status) {
  final c = AppColors.of(context);
  // "Going" uses the dedicated going-badge tokens (light-safe); other states
  // fall back to a single readable colour.
  if (status == null || status == AttendanceStatus.going) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.goingBg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: c.goingBorder),
      ),
      child: Text('Going',
          style: TextStyle(
              color: c.goingText,
              fontSize: AppType.sm,
              fontWeight: FontWeight.w600)),
    );
  }
  final label =
      status == AttendanceStatus.attended ? 'Done' : 'Interested';
  final color =
      status == AttendanceStatus.attended ? c.statusLive : c.textSecondary;
  return _miniTag(label, color);
}

Widget _miniTag(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: AppType.sm, fontWeight: FontWeight.w600)),
    );

// ── List view ────────────────────────────────────────────────────────────────

class _ListView extends StatelessWidget {
  final String uid;
  final List<String> palUids;
  const _ListView({required this.uid, required this.palUids});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return _entriesLoader(context, uid, palUids, (entries) {
      if (entries.isEmpty) {
        return Center(
          child: Text(
            palUids.isEmpty
                ? 'No races added yet.\nBrowse Explore, or switch to Month view and tap a day to add one.'
                : 'No races yet — yours or your pals\'.',
            style: TextStyle(color: c.textSecondary),
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
            _sectionHeader(context, 'Upcoming'),
            ...upcoming.map((e) => _entryRow(context, e)),
          ],
          if (past.isNotEmpty) ...[
            _sectionHeader(context, 'Past'),
            ...past.map((e) => _entryRow(context, e)),
          ],
        ],
      );
    });
  }

  Widget _sectionHeader(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 6),
        child: Text(title.toUpperCase(),
            style: TextStyle(
                color: AppColors.of(context).feedSectionLabel,
                fontSize: AppType.xs,
                fontWeight: FontWeight.w500,
                letterSpacing: 2)),
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
    final c = AppColors.of(context);
    final entries = widget.entries;
    final events = <DateTime, List<_Entry>>{};
    for (final e in entries) {
      final day =
          DateTime(e.race.date.year, e.race.date.month, e.race.date.day);
      (events[day] ??= []).add(e);
    }
    final sel = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    final selectedEntries = events[sel] ?? [];

    return Column(
      children: [
        TableCalendar<_Entry>(
          firstDay: DateTime(2020),
          lastDay: DateTime(2030),
          focusedDay: _focusedDay,
          selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
          startingDayOfWeek: StartingDayOfWeek.monday,
          // Default is 16px, which clips the weekday labels (Mon/Tue/…) with the
          // taller bundled fonts — give the header row room to show in full.
          daysOfWeekHeight: 24,
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
                  if (hasMine) _dot(c.calDotMine),
                  if (hasMine && hasPals) const SizedBox(width: 3),
                  if (hasPals) _dot(c.calDotPals),
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
            todayDecoration:
                BoxDecoration(color: c.calSelected, shape: BoxShape.circle),
            todayTextStyle: TextStyle(color: c.calSelectedText),
            selectedDecoration:
                BoxDecoration(color: c.calToday, shape: BoxShape.circle),
            selectedTextStyle: TextStyle(
                color: c.calTodayText, fontWeight: FontWeight.w600),
            defaultTextStyle: TextStyle(color: c.textPrimary),
            weekendTextStyle: TextStyle(color: c.textPrimary),
            outsideTextStyle: TextStyle(color: c.textTertiary),
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: TextStyle(
                fontFamily: AppType.heading,
                color: c.textPrimary,
                fontWeight: FontWeight.w700),
            leftChevronIcon: Icon(Icons.chevron_left, color: c.textPrimary),
            rightChevronIcon: Icon(Icons.chevron_right, color: c.textPrimary),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: TextStyle(color: c.textSecondary),
            weekendStyle: TextStyle(color: c.textSecondary),
          ),
        ),
        Divider(height: 1, color: c.divider),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            children: [
              _addButton(context, _selectedDay),
              const SizedBox(height: 12),
              if (selectedEntries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('Nothing planned on this day yet.',
                      style: TextStyle(color: c.textSecondary)),
                )
              else
                ...selectedEntries.map((e) => _DayRaceCard(entry: e)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _addButton(BuildContext context, DateTime date) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: () => showPlanAddSheet(context, date),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: c.textLink, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 18, color: c.textLink),
            const SizedBox(width: 6),
            Text('Add a race on ${DateFormat('d MMM').format(date)}',
                style: TextStyle(
                    color: c.textLink,
                    fontWeight: FontWeight.w600,
                    fontSize: AppType.base)),
          ],
        ),
      ),
    );
  }

  Widget _dot(Color color) => Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

// ── Day panel card ───────────────────────────────────────────────────────────

/// A race card for the selected-day panel. Unlike the compact list-view row, it
/// drops the redundant date column (the day is already selected) and lists
/// *every* person going — you and each pal, by avatar + name — rather than
/// capping at a few avatars. A long list collapses behind an "and N more"
/// toggle so a busy day doesn't force endless scrolling. See BACKLOG #11.
class _DayRaceCard extends StatefulWidget {
  final _Entry entry;
  const _DayRaceCard({required this.entry});

  @override
  State<_DayRaceCard> createState() => _DayRaceCardState();
}

class _DayRaceCardState extends State<_DayRaceCard> {
  // How many attendees to show before collapsing the rest behind a toggle.
  static const int _collapsedCount = 6;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final e = widget.entry;
    final me = e.mine ? context.read<AppProvider>().currentUser : null;
    final borderColor = e.mine ? c.planBarMine : c.planBarPals;
    final hasReview = e.race.isPast && e.race.reviewCount > 0;

    // Everyone we know is going: you first (if you're going), then each pal.
    final attendees = <Widget>[
      if (me != null) _attendeeChip(context, _meAvatar(context, me), 'You'),
      ...e.pals.map((p) => _attendeeChip(
            context,
            _palAvatar(context, p, r: 12),
            p.displayName.split(' ').first,
          )),
    ];
    final total = attendees.length;
    final shown =
        _expanded ? attendees : attendees.take(_collapsedCount).toList();
    final hidden = total - shown.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: c.bgSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border(
          left: BorderSide(color: borderColor, width: 4),
          top: BorderSide(color: c.border),
          right: BorderSide(color: c.border),
          bottom: BorderSide(color: c.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — tap anywhere to open the race.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => RaceDetailScreen(raceId: e.race.id)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.race.name,
                            style: TextStyle(
                                color: c.textPrimary,
                                fontWeight: FontWeight.w500,
                                fontSize: AppType.md)),
                        const SizedBox(height: 2),
                        Text(e.race.location,
                            style: TextStyle(
                                color: c.textSecondary, fontSize: AppType.sm)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (e.mine)
                    hasReview
                        ? Row(
                            children: [
                              Icon(Icons.star, size: 13, color: c.achievement),
                              const SizedBox(width: 2),
                              Text(e.race.averageRating.toStringAsFixed(1),
                                  style: TextStyle(
                                      color: c.achievement,
                                      fontSize: AppType.sm,
                                      fontWeight: FontWeight.w700)),
                            ],
                          )
                        : _statusChip(context, e.myStatus)
                  else
                    _miniTag('Pal', c.pals),
                ],
              ),
            ),
          ),
          if (total > 0) ...[
            Divider(height: 1, color: c.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$total GOING',
                      style: TextStyle(
                          color: c.textTertiary,
                          fontSize: AppType.xs,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 10, runSpacing: 8, children: shown),
                  if (total > _collapsedCount) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Text(_expanded ? 'Show less' : 'and $hidden more',
                          style: TextStyle(
                              color: c.textLink,
                              fontSize: AppType.sm,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Widget _attendeeChip(BuildContext context, Widget avatar, String name) {
  final c = AppColors.of(context);
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      avatar,
      const SizedBox(width: 5),
      Text(name, style: TextStyle(color: c.textPrimary, fontSize: AppType.sm)),
    ],
  );
}

/// "You" avatar for the attendee list — your photo, or your initial on the
/// "mine" calendar colour so it reads as you, not a pal.
Widget _meAvatar(BuildContext context, AppUser u, {double r = 12}) {
  final c = AppColors.of(context);
  if (u.photoUrl != null && u.photoUrl!.isNotEmpty) {
    return CircleAvatar(radius: r, backgroundImage: NetworkImage(u.photoUrl!));
  }
  return CircleAvatar(
    radius: r,
    backgroundColor: c.calDotMine,
    child: Text(
      u.displayName.isNotEmpty ? u.displayName[0].toUpperCase() : '?',
      style: TextStyle(
          color: Colors.white, fontSize: r * 0.85, fontWeight: FontWeight.bold),
    ),
  );
}
