import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_provider.dart';
import '../models/user_model.dart';
import '../models/race_model.dart';
import '../models/review_model.dart';
import '../widgets/shared_widgets.dart';
import '../theme.dart';
import 'pals_screen.dart';
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
                  if (user.bio != null && user.bio!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      user.bio!,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Stats row — all three tappable
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Races = events completed (attended), derived from attendances
                      StreamBuilder<List<Attendance>>(
                        stream:
                            provider.raceService.userAttendances(user.uid),
                        builder: (ctx, snap) {
                          final done = (snap.data ?? [])
                              .where((a) =>
                                  a.status == AttendanceStatus.attended)
                              .length;
                          return GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    _UserRacesScreen(uid: user.uid, isMe: isMe),
                              ),
                            ),
                            child: _stat(
                                'Races', snap.hasData ? done.toString() : '—'),
                          );
                        },
                      ),
                      _statDivider(),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PalsScreen(uid: user.uid),
                          ),
                        ),
                        child: StreamBuilder<List<AppUser>>(
                          stream: context
                              .read<AppProvider>()
                              .palService
                              .palsStream(user.uid),
                          builder: (ctx, snap) => _stat(
                            'Pals',
                            snap.hasData ? snap.data!.length.toString() : '—',
                          ),
                        ),
                      ),
                      _statDivider(),
                      StreamBuilder<List<Review>>(
                        stream: provider.raceService.userReviews(user.uid),
                        builder: (ctx, snap) => GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  _UserReviewsScreen(uid: user.uid, isMe: isMe),
                            ),
                          ),
                          child: _stat('Reviews',
                              snap.hasData ? snap.data!.length.toString() : '—'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (!isMe)
                    _PalButtonWidget(user: user),
                ],
              ),
            ),
            if (isMe) _accountSection(context, provider),
          ],
        ),
      ),
    );
  }

  // Privacy policy link + account deletion (GDPR + Play Store requirement).
  Widget _accountSection(BuildContext context, AppProvider provider) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          children: [
            const Divider(),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.privacy_tip_outlined,
                  size: 18, color: AppTheme.textSecondary),
              label: const Text('Privacy policy',
                  style: TextStyle(color: AppTheme.textSecondary)),
              onPressed: () => launchUrl(
                Uri.parse(AppConstants.privacyPolicyUrl),
                mode: LaunchMode.externalApplication,
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.delete_forever_outlined,
                  size: 18, color: Colors.redAccent),
              label: const Text('Delete account',
                  style: TextStyle(color: Colors.redAccent)),
              onPressed: () => _confirmDeleteAccount(context, provider),
            ),
          ],
        ),
      );

  Future<void> _confirmDeleteAccount(
      BuildContext context, AppProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete your account?'),
        content: const Text(
          'This permanently deletes your profile, photo, reviews, race history, '
          'pals and activity. This cannot be undone.\n\n'
          'You\'ll be asked to sign in again to confirm it\'s you.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    // Block the UI while we re-auth + wipe data.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await provider.deleteAccount();
      // Auth-state listener returns the app to the login screen on its own.
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // dismiss the progress spinner
        final cancelled = e.toString().contains('cancelled');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(cancelled
                ? 'Account deletion cancelled.'
                : 'Could not delete account. Please try again.'),
          ),
        );
      }
    }
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

class _PalButtonWidget extends StatefulWidget {
  final AppUser user;
  const _PalButtonWidget({required this.user});

  @override
  State<_PalButtonWidget> createState() => _PalButtonWidgetState();
}

class _PalButtonWidgetState extends State<_PalButtonWidget> {
  PalStatus _status = PalStatus.none;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await context.read<AppProvider>().getPalStatus(widget.user.uid);
    if (mounted) setState(() { _status = s; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(height: 40);
    return PalButton(
      status: _status,
      onPressed: () async {
        await context.read<AppProvider>().togglePal(widget.user);
        _load();
      },
    );
  }
}

// ── A user's races (Upcoming + Completed) ──────────────────────────────────

class _RaceWithStatus {
  final Race race;
  final AttendanceStatus status;
  _RaceWithStatus(this.race, this.status);
}

class _UserRacesScreen extends StatelessWidget {
  final String uid;
  final bool isMe;
  const _UserRacesScreen({required this.uid, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(isMe ? 'My races' : 'Races')),
      body: StreamBuilder<List<Attendance>>(
        stream: provider.raceService.userAttendances(uid),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final atts = snap.data ?? [];
          if (atts.isEmpty) {
            return const Center(
              child: Text('No races yet.',
                  style: TextStyle(color: AppTheme.textSecondary)),
            );
          }
          return FutureBuilder<List<_RaceWithStatus>>(
            future: Future.wait(atts.map((a) async {
              final r = await provider.raceService.getRace(a.raceId);
              return r == null ? null : _RaceWithStatus(r, a.status);
            })).then((l) => l.whereType<_RaceWithStatus>().toList()),
            builder: (ctx, snap2) {
              if (!snap2.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snap2.data!;
              final upcoming = items.where((x) => x.race.isUpcoming).toList()
                ..sort((a, b) => a.race.date.compareTo(b.race.date));
              final past = items.where((x) => x.race.isPast).toList()
                ..sort((a, b) => b.race.date.compareTo(a.race.date));
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (upcoming.isNotEmpty) ...[
                    _header('Upcoming'),
                    ...upcoming.map((x) => _raceRow(context, x.race)),
                  ],
                  if (past.isNotEmpty) ...[
                    _header('Completed'),
                    ...past.map((x) => _raceRow(context, x.race)),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _header(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 6),
        child: Text(t,
            style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8)),
      );

  Widget _raceRow(BuildContext context, Race race) => GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => RaceDetailScreen(raceId: race.id)),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(race.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                        '${DateFormat('EEE d MMM yyyy').format(race.date)} · ${race.location}',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (race.reviewCount > 0) ...[
                const Icon(Icons.star, size: 13, color: AppTheme.accent),
                const SizedBox(width: 2),
                Text(race.averageRating.toStringAsFixed(1),
                    style: const TextStyle(
                        color: AppTheme.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ],
            ],
          ),
        ),
      );
}

// ── A user's reviews ───────────────────────────────────────────────────────

class _UserReviewsScreen extends StatelessWidget {
  final String uid;
  final bool isMe;
  const _UserReviewsScreen({required this.uid, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(isMe ? 'My reviews' : 'Reviews')),
      body: StreamBuilder<List<Review>>(
        stream: provider.raceService.userReviews(uid),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final reviews = snap.data ?? [];
          if (reviews.isEmpty) {
            return const Center(
              child: Text('No reviews yet.',
                  style: TextStyle(color: AppTheme.textSecondary)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reviews.length,
            itemBuilder: (ctx, i) {
              final rv = reviews[i];
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => RaceDetailScreen(raceId: rv.raceId)),
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder<Race?>(
                        future: provider.raceService.getRace(rv.raceId),
                        builder: (ctx, rs) => Text(
                          rs.data?.name ?? 'Race',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ),
                      const SizedBox(height: 6),
                      LightningRating(rating: rv.rating, size: 16),
                      if (rv.body != null && rv.body!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(rv.body!,
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 13)),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
