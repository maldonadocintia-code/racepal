import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/app_provider.dart';
import '../widgets/shared_widgets.dart';
import '../theme.dart';
import 'profile_screen.dart';

class PalsScreen extends StatefulWidget {
  final String uid;
  final int initialTab; // 0 = Pals, 1 = Following, 2 = Followers

  const PalsScreen({super.key, required this.uid, this.initialTab = 0});

  @override
  State<PalsScreen> createState() => _PalsScreenState();
}

class _PalsScreenState extends State<PalsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final followService = context.read<AppProvider>().followService;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_search),
            tooltip: 'Find pals',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FindPalsScreen()),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pals'),
            Tab(text: 'Following'),
            Tab(text: 'Followers'),
          ],
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.textPrimary,
          unselectedLabelColor: AppTheme.textSecondary,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Pals — mutual follows (reactive, updates after follow-backs)
          StreamBuilder<List<AppUser>>(
            stream: followService.palsStream(widget.uid),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              return _UserList(
                users: snap.data ?? [],
                emptyMessage: 'No pals yet.\nWhen someone follows you back, they\'ll appear here.',
              );
            },
          ),

          // Following
          StreamBuilder<List<AppUser>>(
            stream: followService.followingUsers(widget.uid),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              return _UserList(
                users: snap.data ?? [],
                emptyMessage: 'Not following anyone yet.\nFind runners in Discover!',
              );
            },
          ),

          // Followers
          StreamBuilder<List<AppUser>>(
            stream: followService.followerUsers(widget.uid),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              return _UserList(
                users: snap.data ?? [],
                emptyMessage: 'No followers yet.',
                showFollowButton: true,
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Find pals — search all users by name ───────────────────────────────────

class FindPalsScreen extends StatefulWidget {
  const FindPalsScreen({super.key});

  @override
  State<FindPalsScreen> createState() => _FindPalsScreenState();
}

class _FindPalsScreenState extends State<FindPalsScreen> {
  final TextEditingController _ctrl = TextEditingController();
  List<AppUser> _results = [];
  bool _searching = false;
  bool _searched = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _searched = false;
      });
      return;
    }
    setState(() => _searching = true);
    final provider = context.read<AppProvider>();
    final myUid = provider.currentUser!.uid;
    final users = await provider.followService.searchUsers(q);
    if (!mounted) return;
    setState(() {
      _results = users.where((u) => u.uid != myUid).toList();
      _searching = false;
      _searched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find pals')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: _search,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Search by name...',
                prefixIcon:
                    const Icon(Icons.search, color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Text(
              'Tip: names are matched from the start — try the first few letters.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ),
          Expanded(
            child: _searching
                ? const Center(child: CircularProgressIndicator())
                : !_searched
                    ? const Center(
                        child: Text('Search for runners by name',
                            style:
                                TextStyle(color: AppTheme.textSecondary)),
                      )
                    : _results.isEmpty
                        ? const Center(
                            child: Text('No runners found with that name',
                                style: TextStyle(
                                    color: AppTheme.textSecondary)),
                          )
                        : ListView.separated(
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _results.length,
                            separatorBuilder: (_, __) => const Divider(
                                height: 1,
                                color: AppTheme.divider,
                                indent: 72),
                            itemBuilder: (ctx, i) =>
                                _FoundUserTile(user: _results[i]),
                          ),
          ),
        ],
      ),
    );
  }
}

class _FoundUserTile extends StatefulWidget {
  final AppUser user;
  const _FoundUserTile({required this.user});

  @override
  State<_FoundUserTile> createState() => _FoundUserTileState();
}

class _FoundUserTileState extends State<_FoundUserTile> {
  FollowStatus? _status;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final status =
          await context.read<AppProvider>().getFollowStatus(widget.user.uid);
      if (mounted) setState(() => _status = status);
    } catch (_) {
      // If the status check fails for any reason, still show a usable
      // Follow button rather than an endless spinner.
      if (mounted) setState(() => _status = FollowStatus.none);
    }
  }

  Future<void> _toggle() async {
    final previous = _status;
    setState(() => _status = null);
    try {
      await context.read<AppProvider>().toggleFollow(widget.user);
    } catch (_) {
      if (mounted) {
        setState(() => _status = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update. Try again.')),
        );
        return;
      }
    }
    await _loadStatus();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: UserAvatar(
        photoUrl: user.photoUrl,
        displayName: user.displayName,
        radius: 24,
      ),
      title: Text(user.displayName,
          style:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: user.bio != null && user.bio!.isNotEmpty
          ? Text(user.bio!,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis)
          : null,
      trailing: _status == null
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2))
          : TextButton(
              onPressed: _toggle,
              style: TextButton.styleFrom(
                backgroundColor: _status == FollowStatus.none
                    ? AppTheme.primary
                    : AppTheme.surface,
                foregroundColor: _status == FollowStatus.none
                    ? Colors.white
                    : AppTheme.textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: _status == FollowStatus.none
                      ? BorderSide.none
                      : const BorderSide(color: AppTheme.divider),
                ),
              ),
              child: Text(
                _status == FollowStatus.none
                    ? 'Follow'
                    : _status == FollowStatus.following
                        ? 'Following'
                        : 'Requested',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProfileScreen(uid: user.uid)),
      ),
    );
  }
}

class _UserList extends StatelessWidget {
  final List<AppUser> users;
  final String emptyMessage;
  // When true, each row shows a Follow / Following button (used on the
  // Followers tab so you can follow back and become pals).
  final bool showFollowButton;

  const _UserList({
    required this.users,
    required this.emptyMessage,
    this.showFollowButton = false,
  });

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_outline,
                size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            Text(
              emptyMessage,
              style: const TextStyle(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: users.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AppTheme.divider, indent: 72),
      itemBuilder: (ctx, i) => showFollowButton
          ? _FoundUserTile(user: users[i])
          : _PalTile(user: users[i]),
    );
  }
}

class _PalTile extends StatelessWidget {
  final AppUser user;
  const _PalTile({required this.user});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: UserAvatar(
        photoUrl: user.photoUrl,
        displayName: user.displayName,
        radius: 24,
      ),
      title: Text(
        user.displayName,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: user.bio != null && user.bio!.isNotEmpty
          ? Text(
              user.bio!,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : Text(
              '${user.racesCount} race${user.racesCount == 1 ? '' : 's'}',
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13),
            ),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProfileScreen(uid: user.uid)),
      ),
    );
  }
}
