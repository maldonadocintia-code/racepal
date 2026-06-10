import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_provider.dart';
import '../models/race_model.dart';
import '../models/user_model.dart';
import '../widgets/shared_widgets.dart';
import '../theme.dart';
import 'race_detail_screen.dart';
import 'profile_screen.dart';
import 'add_race_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  String _selectedType = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Races & Parkruns'),
            Tab(text: 'Runners'),
          ],
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.textPrimary,
          unselectedLabelColor: AppTheme.textSecondary,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add race',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddRaceScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: _tabController.index == 0
                    ? 'Search races...'
                    : 'Search runners...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppTheme.textSecondary),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _RacesTab(query: _query, selectedType: _selectedType,
                    onTypeChanged: (t) => setState(() => _selectedType = t)),
                _RunnersTab(query: _query),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RacesTab extends StatelessWidget {
  final String query;
  final String selectedType;
  final ValueChanged<String> onTypeChanged;

  const _RacesTab({
    required this.query,
    required this.selectedType,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final types = ['All', ...AppConstants.raceTypes];

    return Column(
      children: [
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: types.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final t = types[i];
              final selected = t == selectedType;
              return GestureDetector(
                onTap: () => onTypeChanged(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.primary : AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    t,
                    style: TextStyle(
                      color: selected ? Colors.white : AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<List<Race>>(
            stream: provider.raceService.upcomingRaces(
              type: selectedType == 'All' ? null : selectedType,
            ),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              var races = snap.data ?? [];
              if (query.isNotEmpty) {
                races = races
                    .where((r) =>
                        r.name.toLowerCase().contains(query.toLowerCase()) ||
                        r.location.toLowerCase().contains(query.toLowerCase()))
                    .toList();
              }
              if (races.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.flag, size: 48, color: AppTheme.textSecondary),
                      const SizedBox(height: 12),
                      const Text('No races found',
                          style: TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AddRaceScreen()),
                        ),
                        child: const Text('Add a race'),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: races.length,
                itemBuilder: (ctx, i) => RaceCard(
                  race: races[i],
                  onTap: () => Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => RaceDetailScreen(raceId: races[i].id),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RunnersTab extends StatefulWidget {
  final String query;
  const _RunnersTab({required this.query});

  @override
  State<_RunnersTab> createState() => _RunnersTabState();
}

class _RunnersTabState extends State<_RunnersTab> {
  List<AppUser> _results = [];
  bool _searching = false;

  @override
  void didUpdateWidget(_RunnersTab old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query) _search(widget.query);
  }

  Future<void> _search(String q) async {
    if (q.isEmpty) {
      setState(() { _results = []; _searching = false; });
      return;
    }
    setState(() => _searching = true);
    final provider = context.read<AppProvider>();
    final res = await provider.followService.searchUsers(q);
    if (mounted) setState(() { _results = res; _searching = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (widget.query.isEmpty) {
      return const Center(
        child: Text(
          'Search for runners by name',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }
    if (_results.isEmpty) {
      return const Center(
        child: Text('No runners found',
            style: TextStyle(color: AppTheme.textSecondary)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _results.length,
      itemBuilder: (ctx, i) {
        final user = _results[i];
        return ListTile(
          leading: UserAvatar(
            photoUrl: user.photoUrl,
            displayName: user.displayName,
            radius: 22,
          ),
          title: Text(user.displayName),
          subtitle: Text(
            '${user.racesCount} races · ${user.followersCount} followers',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          trailing: Icon(
            user.isPublic ? Icons.person : Icons.lock,
            size: 16,
            color: AppTheme.textSecondary,
          ),
          onTap: () => Navigator.push(
            ctx,
            MaterialPageRoute(builder: (_) => ProfileScreen(uid: user.uid)),
          ),
        );
      },
    );
  }
}
