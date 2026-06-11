import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/app_provider.dart';
import '../services/google_calendar_service.dart';
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
  bool _showCalendar = false;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  final Map<String, Race> _raceCache = {};
  final Set<String> _loadingIds = {};

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

  void _cacheRaces(Set<String> ids, AppProvider provider) {
    for (final id in ids) {
      if (_raceCache.containsKey(id) || _loadingIds.contains(id)) continue;
      _loadingIds.add(id);
      provider.raceService.getRace(id).then((race) {
        _loadingIds.remove(id);
        if (race != null && mounted) setState(() => _raceCache[id] = race);
      });
    }
  }

  List<Race> _eventsForDay(DateTime day) => _raceCache.values
      .where((r) =>
          r.date.year == day.year &&
          r.date.month == day.month &&
          r.date.day == day.day)
      .toList();

  Future<void> _addToCalendar(Race race) async {
    final provider = context.read<AppProvider>();
    final svc = GoogleCalendarService(provider.authService.googleSignIn);
    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(const SnackBar(
      content: Text('Adding to Google Calendar…'),
      duration: Duration(seconds: 1),
    ));

    try {
      await svc.addRace(race);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('${race.name} added!'),
        backgroundColor: AppTheme.success,
      ));
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('denied')
          ? 'Calendar permission denied'
          : 'Failed to add to Google Calendar';
      messenger.showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final uid = provider.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Calendar'),
        actions: [
          IconButton(
            icon: Icon(_showCalendar
                ? Icons.list_rounded
                : Icons.calendar_month_rounded),
            tooltip: _showCalendar ? 'List view' : 'Calendar view',
            onPressed: () => setState(() => _showCalendar = !_showCalendar),
          ),
        ],
        bottom: _showCalendar
            ? null
            : TabBar(
                controller: _tabController,
                tabs: const [Tab(text: 'Upcoming'), Tab(text: 'Past')],
                indicatorColor: AppTheme.accent,
                labelColor: AppTheme.textPrimary,
                unselectedLabelColor: AppTheme.textSecondary,
              ),
      ),
      body: StreamBuilder<List<Attendance>>(
        stream: provider.raceService.userAttendances(uid),
        builder: (context, snap) {
          final attendances = snap.data ?? [];

          final upcomingIds = attendances
              .where((a) =>
                  a.status == AttendanceStatus.going ||
                  a.status == AttendanceStatus.interested)
              .map((a) => a.raceId)
              .toSet();
          final pastIds = attendances
              .where((a) => a.status == AttendanceStatus.attended)
              .map((a) => a.raceId)
              .toSet();

          _cacheRaces({...upcomingIds, ...pastIds}, provider);

          final upcomingRaces = upcomingIds
              .where(_raceCache.containsKey)
              .map((id) => _raceCache[id]!)
              .where((r) => r.isUpcoming)
              .toList()
            ..sort((a, b) => a.date.compareTo(b.date));

          final pastRaces = pastIds
              .where(_raceCache.containsKey)
              .map((id) => _raceCache[id]!)
              .where((r) => r.isPast)
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));

          if (_showCalendar) {
            final dayEvents = _eventsForDay(_selectedDay);
            final listToShow =
                dayEvents.isNotEmpty ? dayEvents : upcomingRaces;
            final label = dayEvents.isNotEmpty
                ? _formatDay(_selectedDay)
                : 'Upcoming';

            return Column(
              children: [
                _CalendarWidget(
                  focusedDay: _focusedDay,
                  selectedDay: _selectedDay,
                  eventsForDay: _eventsForDay,
                  onDaySelected: (sel, foc) => setState(() {
                    _selectedDay = sel;
                    _focusedDay = foc;
                  }),
                  onPageChanged: (foc) =>
                      setState(() => _focusedDay = foc),
                ),
                const Divider(height: 1, color: AppTheme.divider),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _RaceList(
                    races: listToShow,
                    emptyMessage: 'No races on this day.',
                    showCalendarButton: true,
                    onAddToCalendar: _addToCalendar,
                  ),
                ),
              ],
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _RaceList(
                races: upcomingRaces,
                emptyMessage:
                    'No upcoming races.\nTap Discover to find races!',
                showCalendarButton: true,
                onAddToCalendar: _addToCalendar,
              ),
              _RaceList(
                races: pastRaces,
                emptyMessage:
                    'No past races yet.\nMark races as attended to see them here.',
                showCalendarButton: false,
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDay(DateTime d) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[d.weekday]} ${d.day} ${months[d.month]}';
  }
}

// ── Calendar widget ────────────────────────────────────────────────────────

class _CalendarWidget extends StatelessWidget {
  final DateTime focusedDay;
  final DateTime selectedDay;
  final List<Race> Function(DateTime) eventsForDay;
  final void Function(DateTime, DateTime) onDaySelected;
  final void Function(DateTime) onPageChanged;

  const _CalendarWidget({
    required this.focusedDay,
    required this.selectedDay,
    required this.eventsForDay,
    required this.onDaySelected,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TableCalendar<Race>(
      firstDay: DateTime.utc(2024, 1, 1),
      lastDay: DateTime.utc(2028, 12, 31),
      focusedDay: focusedDay,
      selectedDayPredicate: (day) => isSameDay(selectedDay, day),
      startingDayOfWeek: StartingDayOfWeek.monday,
      eventLoader: eventsForDay,
      calendarFormat: CalendarFormat.month,
      availableCalendarFormats: const {CalendarFormat.month: 'Month'},
      onDaySelected: onDaySelected,
      onPageChanged: onPageChanged,
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        todayDecoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        todayTextStyle: const TextStyle(color: AppTheme.textPrimary),
        selectedDecoration: const BoxDecoration(
          color: AppTheme.accent,
          shape: BoxShape.circle,
        ),
        selectedTextStyle: const TextStyle(
            color: Colors.black, fontWeight: FontWeight.bold),
        markerDecoration: const BoxDecoration(
          color: AppTheme.accent,
          shape: BoxShape.circle,
        ),
        markerSize: 5,
        markersMaxCount: 3,
        defaultTextStyle: const TextStyle(color: AppTheme.textPrimary),
        weekendTextStyle: const TextStyle(color: AppTheme.textSecondary),
        disabledTextStyle: const TextStyle(color: AppTheme.divider),
      ),
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
        leftChevronIcon:
            Icon(Icons.chevron_left, color: AppTheme.textPrimary),
        rightChevronIcon:
            Icon(Icons.chevron_right, color: AppTheme.textPrimary),
        headerPadding: EdgeInsets.symmetric(vertical: 6),
      ),
      daysOfWeekStyle: const DaysOfWeekStyle(
        weekdayStyle: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600),
        weekendStyle: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Race list ──────────────────────────────────────────────────────────────

class _RaceList extends StatelessWidget {
  final List<Race> races;
  final String emptyMessage;
  final bool showCalendarButton;
  final Future<void> Function(Race)? onAddToCalendar;

  const _RaceList({
    required this.races,
    required this.emptyMessage,
    this.showCalendarButton = false,
    this.onAddToCalendar,
  });

  @override
  Widget build(BuildContext context) {
    if (races.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.calendar_today,
                  size: 48, color: AppTheme.textSecondary),
              const SizedBox(height: 12),
              Text(emptyMessage,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 14),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: races.length,
      itemBuilder: (ctx, i) => _RaceRow(
        race: races[i],
        showCalendarButton: showCalendarButton,
        onAddToCalendar: onAddToCalendar,
      ),
    );
  }
}

// ── Race row with optional calendar-add button ─────────────────────────────

class _RaceRow extends StatelessWidget {
  final Race race;
  final bool showCalendarButton;
  final Future<void> Function(Race)? onAddToCalendar;

  const _RaceRow({
    required this.race,
    required this.showCalendarButton,
    this.onAddToCalendar,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RaceCard(
          race: race,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => RaceDetailScreen(raceId: race.id)),
          ),
        ),
        if (showCalendarButton && onAddToCalendar != null)
          Positioned(
            top: 10,
            right: 10,
            child: GestureDetector(
              onTap: () => onAddToCalendar!(race),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: const Icon(Icons.calendar_month,
                    size: 16, color: AppTheme.accent),
              ),
            ),
          ),
      ],
    );
  }
}
