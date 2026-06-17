import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_provider.dart';
import '../theme.dart';
import 'map_screen.dart';
import 'feed_screen.dart';
import 'calendar_screen.dart';
import 'profile_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
  late final List<Widget> _screens;
  // Incoming pal-request count — badged on the Feed tab so it's visible from
  // anywhere in the app, not just while you're on Feed.
  late final Stream<List<Map<String, dynamic>>> _requestStream;

  @override
  void initState() {
    super.initState();
    final provider = context.read<AppProvider>();
    final uid = provider.currentUser!.uid;
    _requestStream = provider.palService.incomingRequests(uid);
    _screens = [
      const MapScreen(),
      const FeedScreen(),
      const CalendarScreen(),
      ProfileScreen(uid: uid),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.divider)),
        ),
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _requestStream,
          builder: (context, snap) {
            final requestCount = snap.data?.length ?? 0;
            return BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
              type: BottomNavigationBarType.fixed,
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.explore_outlined),
                  activeIcon: Icon(Icons.explore),
                  label: 'Explore',
                ),
                BottomNavigationBarItem(
                  icon: Badge.count(
                    count: requestCount,
                    isLabelVisible: requestCount > 0,
                    child: const Icon(Icons.people_outline),
                  ),
                  activeIcon: Badge.count(
                    count: requestCount,
                    isLabelVisible: requestCount > 0,
                    child: const Icon(Icons.people),
                  ),
                  label: 'Feed',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_month_outlined),
                  activeIcon: Icon(Icons.calendar_month),
                  label: 'Plan',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'Me',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
