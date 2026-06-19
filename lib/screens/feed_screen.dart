import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../services/app_provider.dart';
import '../models/review_model.dart';
import '../models/user_model.dart';
import '../widgets/shared_widgets.dart';
import '../theme.dart';
import 'race_detail_screen.dart';
import 'profile_screen.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final c = AppColors.of(context);
    final palUids = provider.palUids;
    final myUid = provider.currentUser!.uid;

    // Include self in feed
    final feedUids = [...palUids, myUid];

    return Scaffold(
      appBar: AppBar(
        actions: [
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: provider.palService.incomingRequests(myUid),
            builder: (context, snap) {
              final count = snap.data?.length ?? 0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    tooltip: 'Pal requests',
                    onPressed: () => _showRequests(context, myUid),
                  ),
                  if (count > 0)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        constraints:
                            const BoxConstraints(minWidth: 18, minHeight: 18),
                        decoration: BoxDecoration(
                          color: c.notifBg,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$count',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: c.notifText,
                              fontSize: AppType.xs,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: feedUids.isEmpty
          ? _emptyFeed(context)
          : StreamBuilder<List<ActivityItem>>(
              stream: provider.raceService.feedForUser(feedUids),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snap.data ?? [];
                if (items.isEmpty) return _emptyFeed(context);
                return _FeedTimeline(items: items);
              },
            ),
    );
  }

  Widget _emptyFeed(BuildContext context) {
    final c = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bolt, size: 56, color: c.primary),
            const SizedBox(height: 16),
            Text(
              'Your feed is empty',
              style: TextStyle(
                fontFamily: AppType.heading,
                color: c.textPrimary,
                fontSize: AppType.xl,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add pals to see their races, parkruns and reviews here.',
              style: TextStyle(color: c.textSecondary, fontSize: AppType.base),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showRequests(BuildContext context, String myUid) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.of(context).sheetBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      builder: (_) => _PalRequestsSheet(myUid: myUid),
    );
  }
}

// ── Feed timeline (Variant A) ───────────────────────────────────────────────

/// The activity feed as a vertical timeline: items are grouped under day
/// headers (Today / Yesterday / …), each hanging off a coloured type-node on a
/// connecting rail, with a relative timestamp and (for reviews) a quoted body.
class _FeedTimeline extends StatelessWidget {
  final List<ActivityItem> items;
  const _FeedTimeline({required this.items});

  // Day bucket for grouping. Items arrive newest-first, so buckets stay ordered.
  static String _bucket(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = today.difference(that).inDays;
    if (diff <= 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return 'Earlier this week';
    return DateFormat('d MMM yyyy').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    String? lastBucket;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final bucket = _bucket(item.createdAt);
      if (bucket != lastBucket) {
        children.add(_dayHeader(context, bucket));
        lastBucket = bucket;
      }
      final isLastInBucket =
          i == items.length - 1 || _bucket(items[i + 1].createdAt) != bucket;
      children.add(_TimelineRow(item: item, isLast: isLastInBucket));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: children,
    );
  }

  Widget _dayHeader(BuildContext context, String label) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: AppType.body,
            color: AppColors.of(context).feedSectionLabel,
            fontSize: AppType.xs,
            fontWeight: FontWeight.w500,
            letterSpacing: 2,
          ),
        ),
      );
}

class _TimelineRow extends StatelessWidget {
  final ActivityItem item;
  final bool isLast;
  const _TimelineRow({required this.item, required this.isLast});

  // (node colour, icon, verb) per activity type. Node colours are chosen to read
  // in both themes (going=cyan, attended=green, review=pink); volt is reserved
  // for the race-name link via feedLinkText.
  static (Color, IconData, String) _style(AppColors c, String type) {
    switch (type) {
      case 'going':
        return (c.secondary, Icons.place, 'is going to ');
      case 'attended':
        return (c.statusLive, Icons.check_circle, 'attended ');
      case 'review':
        return (c.achievement, Icons.bolt, 'reviewed ');
      default:
        return (c.pals, Icons.person_add, 'joined ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final (color, icon, verb) = _style(c, item.type);

    void openRace() => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RaceDetailScreen(raceId: item.raceId),
          ),
        );
    void openUser() => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProfileScreen(uid: item.userId)),
        );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Rail: coloured type node + connecting line down to the next item.
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: c.feedDotBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(icon, size: 15, color: color),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: c.feedLine),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Body
          Expanded(
            child: GestureDetector(
              onTap: openRace,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              style: TextStyle(
                                fontFamily: AppType.body,
                                color: c.feedNameText,
                                fontSize: AppType.base,
                                height: 1.35,
                              ),
                              children: [
                                TextSpan(
                                  text: item.userName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = openUser,
                                ),
                                TextSpan(text: ' $verb'),
                                TextSpan(
                                  text: item.raceName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: c.feedLinkText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeago.format(item.createdAt, locale: 'en_short'),
                          style: TextStyle(
                            color: c.feedTimeText,
                            fontSize: AppType.sm,
                          ),
                        ),
                      ],
                    ),
                    if (item.rating != null) ...[
                      const SizedBox(height: 4),
                      LightningRating(rating: item.rating!, size: 15),
                    ],
                    if (item.reviewBody != null &&
                        item.reviewBody!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                        decoration: BoxDecoration(
                          color: c.bgSurface,
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(8),
                            bottomRight: Radius.circular(8),
                          ),
                          border: Border(
                            left: BorderSide(color: c.achievement, width: 3),
                          ),
                        ),
                        child: Text(
                          item.reviewBody!,
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: AppType.sm,
                            height: 1.35,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pal requests sheet ──────────────────────────────────────────────────────

class _PalRequestsSheet extends StatelessWidget {
  final String myUid;
  const _PalRequestsSheet({required this.myUid});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final c = AppColors.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
            const SizedBox(height: 16),
            Text(
              'Pal requests',
              style: TextStyle(
                  fontFamily: AppType.heading,
                  color: c.textPrimary,
                  fontSize: AppType.xl,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: provider.palService.incomingRequests(myUid),
              builder: (context, snap) {
                final requests = snap.data ?? [];
                if (requests.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('No pal requests',
                          style: TextStyle(color: c.textSecondary)),
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: requests.length,
                  itemBuilder: (_, i) => _RequestTile(
                    requesterUid: requests[i]['fromUid'] as String,
                    targetUid: myUid,
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  final String requesterUid;
  final String targetUid;
  const _RequestTile({required this.requesterUid, required this.targetUid});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final c = AppColors.of(context);
    return FutureBuilder<AppUser?>(
      future: provider.authService.getUser(requesterUid),
      builder: (context, snap) {
        final user = snap.data;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              UserAvatar(
                photoUrl: user?.photoUrl,
                displayName: user?.displayName ?? '?',
                radius: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  user?.displayName ?? 'Runner',
                  style: TextStyle(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: AppType.base),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await provider.palService.acceptRequest(
                      requesterUid: requesterUid,
                      myUid: targetUid,
                    );
                    messenger.showSnackBar(SnackBar(
                        content: Text(
                            "You're now pals with ${user?.displayName ?? 'this runner'} 🎉")));
                  } catch (_) {
                    messenger.showSnackBar(const SnackBar(
                        content: Text('Could not accept. Try again.')));
                  }
                },
                style: TextButton.styleFrom(
                  backgroundColor: c.actionBg,
                  foregroundColor: c.actionText,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
                child: const Text('Accept',
                    style: TextStyle(
                        fontSize: AppType.sm, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Decline',
                icon: Icon(Icons.close, color: c.textTertiary),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await provider.palService.declineRequest(
                      requesterUid: requesterUid,
                      myUid: targetUid,
                    );
                  } catch (_) {
                    messenger.showSnackBar(const SnackBar(
                        content: Text('Could not decline. Try again.')));
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
