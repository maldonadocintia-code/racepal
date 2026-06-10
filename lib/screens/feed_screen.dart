import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_provider.dart';
import '../models/review_model.dart';
import '../widgets/shared_widgets.dart';
import '../theme.dart';
import 'race_detail_screen.dart';
import 'profile_screen.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final followingUids = provider.followingUids;
    final myUid = provider.currentUser!.uid;

    // Include self in feed
    final feedUids = [...followingUids, myUid];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.bolt, color: AppTheme.accent, size: 26),
            const SizedBox(width: 8),
            Text(
              AppConstants.appName,
              style: Theme.of(context).appBarTheme.titleTextStyle,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => _showNotifications(context),
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
              'Follow other runners to see their races, parkruns and reviews here.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {},
              child: const Text('Find runners to follow'),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    // TODO: implement follow request notifications
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Notifications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No new notifications',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
