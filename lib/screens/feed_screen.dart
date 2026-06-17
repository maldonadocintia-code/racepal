import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$count',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
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

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final item = items[i];
                    return ActivityCard(
                      item: item,
                      onRaceTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RaceDetailScreen(raceId: item.raceId),
                        ),
                      ),
                      onUserTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfileScreen(uid: item.userId),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _emptyFeed(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bolt, size: 56, color: AppTheme.accent),
            const SizedBox(height: 16),
            const Text(
              'Your feed is empty',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add pals to see their races, parkruns and reviews here.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
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
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PalRequestsSheet(myUid: myUid),
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
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Pal requests',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: provider.palService.incomingRequests(myUid),
              builder: (context, snap) {
                final requests = snap.data ?? [];
                if (requests.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('No pal requests',
                          style: TextStyle(color: AppTheme.textSecondary)),
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
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
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
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Accept',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Decline',
                icon: const Icon(Icons.close, color: AppTheme.textSecondary),
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
