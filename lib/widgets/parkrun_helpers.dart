import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/race_model.dart';
import '../models/review_model.dart';
import '../services/app_provider.dart';
import '../theme.dart';

/// Lets the user choose which Saturday they're planning to run — not just the
/// next one. Returns null if dismissed. Shared by the Map screen and the
/// parkrun detail screen so the flow is identical in both places.
Future<DateTime?> pickParkrunSaturday(BuildContext context) {
  final now = DateTime.now();
  final saturdays = <DateTime>[];
  var cursor = DateTime(now.year, now.month, now.day, 9);
  while (saturdays.length < 16) {
    if (cursor.weekday == DateTime.saturday &&
        cursor.isAfter(now.subtract(const Duration(hours: 2)))) {
      saturdays.add(cursor);
    }
    cursor = cursor.add(const Duration(days: 1));
  }

  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Which Saturday are you running?',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: AppTheme.fsTitle)),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: saturdays.length,
              itemBuilder: (_, i) {
                final s = saturdays[i];
                return ListTile(
                  leading: const Icon(Icons.event_available_outlined,
                      color: AppTheme.primary),
                  title: Text(DateFormat('EEE d MMM yyyy').format(s)),
                  subtitle: Text(i == 0
                      ? 'This Saturday'
                      : i == 1
                          ? 'Next Saturday'
                          : 'In ${i + 1} weeks'),
                  onTap: () => Navigator.pop(ctx, s),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Asks which Saturday, then creates the per-date race doc and marks the user
/// as "going" so it lands on their calendar.
///
/// [venueId] is the stable parkrun id (e.g. `pr_pr_bushy`). The per-date doc
/// uses `venueId_yyyyMMdd`, which keeps each Saturday separate on the calendar
/// while reviews aggregate on the venue doc.
Future<void> planParkrunDate(
  BuildContext context, {
  required String venueId,
  required String name,
  required String location,
  double? lat,
  double? lng,
}) async {
  final date = await pickParkrunSaturday(context);
  if (date == null || !context.mounted) return;

  final provider = context.read<AppProvider>();
  final race = Race(
    id: '${venueId}_${DateFormat('yyyyMMdd').format(date)}',
    name: name,
    location: location,
    type: 'parkrun',
    category: RaceCategory.parkrun,
    date: date,
    lat: lat,
    lng: lng,
    createdBy: 'system',
  );
  await provider.raceService.ensureRace(race);
  await provider.setAttendance(
    raceId: race.id,
    raceName: race.name,
    status: AttendanceStatus.going,
  );
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$name added to your calendar 🎉')),
  );
}
