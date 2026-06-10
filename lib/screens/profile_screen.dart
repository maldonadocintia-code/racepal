import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_provider.dart';
import '../models/user_model.dart';
import '../models/review_model.dart';
import '../widgets/shared_widgets.dart';
import '../theme.dart';
import 'edit_profile_screen.dart';
import 'race_detail_screen.dart';

class ProfileScreen extends StatelessWidget {
  final String uid;
  const ProfileScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isMe = provider.currentUser?.uid == uid;

    return StreamBuilder<AppUser?>(
      stream: provider.authService.userStream(uid),
      builder: (ctx, snap) {
        final user = snap.data;
        if (user == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return _ProfileBody(user: user, isMe: isMe);
      },
    );
  }
}

class _ProfileBody extends StatelessWidget {
  final AppUser user;
  final bool isMe;

  const _ProfileBody({required this.user, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(user.displayName),
        actions: [
          if (isMe) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => _confirmLogout(context, provider),
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  UserAvatar(
                    photoUrl: user.photoUrl,
                    displayName: user.displayName,
                    radius: 40,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.displayName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (!user.isPublic) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.lock, size: 13, color: AppTheme.textSecondary),
                        SizedBox(width: 4),
                        Text(
                          'Private account',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                  if (user.bio != null && user.bio!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      user.bio!,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _stat('Races', user.racesCount.toString()),
                      _statDivider(),
                      _stat('Followers', user.followersCount.toString()),
                      _statDivider(),
                      _stat('Following', user.followingCount.toString()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (!isMe)
                    _FollowButtonWidget(user: user),
                ],
              ),
            ),

            const Divider(height: 1, color: AppTheme.divider),

            // Activity
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: const [
                  Text(
                    'Recent activity',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                  ),
                ],
              ),
            ),
            _ActivityList(uid: user.uid, isPublic: user.isPublic, isMe: isMe),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) => Column(
    children: [
      Text(value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          )),
      Text(label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          )),
    ],
  );

  Widget _statDivider() => Container(
    height: 30,
    width: 1,
    color: AppTheme.divider,
  );

  Future<void> _confirmLogout(BuildContext context, AppProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) await provider.signOut();
  }
}

class _FollowButtonWidget extends StatefulWidget {
  final AppUser user;
  const _FollowButtonWidget({required this.user});

  @override
  State<_FollowButtonWidget> createState() => _FollowButtonWidgetState();
}

class _FollowButtonWidgetState extends State<_FollowButtonWidget> {
  FollowStatus _status = FollowStatus.none;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await context.read<AppProvider>().getFollowStatus(widget.user.uid);
    if (mounted) setState(() { _status = s; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(height: 40);
    return FollowButton(
      status: _status,
      onPressed: () async {
        await context.read<AppProvider>().toggleFollow(widget.user);
        _load();
      },
    );
  }
}

class _ActivityList extends StatelessWidget {
  final String uid;
  final bool isPublic;
  final bool isMe;

  const _ActivityList({
    required this.uid,
    required this.isPublic,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    // If private and not me, don't show activity
    if (!isPublic && !isMe) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.lock, size: 36, color: AppTheme.textSecondary),
              SizedBox(height: 8),
              Text(
                'This account is private.\nFollow to see their activity.',
                style: TextStyle(color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<List<ActivityItem>>(
      stream: provider.raceService.userActivity(uid),
      builder: (ctx, snap) {
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text('No activity yet',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: items.length,
          itemBuilder: (ctx, i) => ActivityCard(
            item: items[i],
            onRaceTap: () => Navigator.push(
              ctx,
              MaterialPageRoute(
                builder: (_) => RaceDetailScreen(raceId: items[i].raceId),
              ),
            ),
          ),
        );
      },
    );
  }
}
