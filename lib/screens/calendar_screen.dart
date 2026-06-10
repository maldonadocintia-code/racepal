import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
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
    final provider = context.watch<AppProvider>();
    final uid = provider.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Calendar'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Past'),
          ],
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.textPrimary,
          unselectedLabelColor: AppTheme.textSecondary,
        ),
      ),
      body: StreamBuilder<List<Attendance>>(
        stream: provider.raceService.userAttendances(uid),
        builder: (context, attendSnap) {
          final attendances = attendSnap.data ?? [];
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

          return TabBarView(
            controller: _tabController,
            children: [
              _RaceIdList(raceIds: upcomingIds, emptyMessage: 'No upcoming races.\nTap Discover to find races!'),
              _RaceIdList(raceIds: pastIds, emptyMessage: 'No past races yet.\nMark races as attended to see them here.'),
            ],
          );
        },
      ),
    );
  }
}

class _RaceIdList extends StatelessWidget {
  final Set<String> raceIds;
  final String emptyMessage;

  const _RaceIdList({
    required this.raceIds,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (raceIds.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.calendar_today, size: 48, color: AppTheme.textSecondary),
              const SizedBox(height: 12),
              Text(
                emptyMessage,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: raceIds.length,
      itemBuilder: (ctx, i) {
        final raceId = raceIds.elementAt(i);
        return _RaceIdCard(raceId: raceId);
      },
    );
  }
}

class _RaceIdCard extends StatelessWidget {
  final String raceId;
  const _RaceIdCard({required this.raceId});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    return FutureBuilder<Race?>(
      future: provider.raceService.getRace(raceId),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
          );
        }
        final race = snap.data;
        if (race == null) return const SizedBox.shrink();
        return RaceCard(
          race: race,
          onTap: () => Navigator.push(
            ctx,
            MaterialPageRoute(
              builder: (_) => RaceDetailScreen(raceId: raceId),
            ),
          ),
        );
      },
    );
  }
}
