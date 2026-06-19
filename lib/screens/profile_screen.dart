import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_provider.dart';
import '../services/theme_controller.dart';
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
    final c = AppColors.of(context);

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
                    style: TextStyle(
                      fontFamily: AppType.heading,
                      color: c.textPrimary,
                      fontSize: AppType.xl,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (user.bio != null && user.bio!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      user.bio!,
                      style: TextStyle(color: c.textSecondary, fontSize: AppType.base),
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
  Widget _accountSection(BuildContext context, AppProvider provider) {
    final c = AppColors.of(context);
    return Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            const SizedBox(height: 12),
            _ThemeSelector(),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: Icon(Icons.privacy_tip_outlined,
                  size: 18, color: c.textSecondary),
              label: Text('Privacy policy',
                  style: TextStyle(color: c.textSecondary)),
              onPressed: () => launchUrl(
                Uri.parse(AppConstants.privacyPolicyUrl),
                mode: LaunchMode.externalApplication,
              ),
            ),
            TextButton.icon(
              icon: Icon(Icons.delete_forever_outlined,
                  size: 18, color: c.statusError),
              label: Text('Delete account',
                  style: TextStyle(color: c.statusError)),
              onPressed: () => _confirmDeleteAccount(context, provider),
            ),
          ],
        ),
      );
  }

  Future<void> _confirmDeleteAccount(
      BuildContext context, AppProvider provider) async {
    final c = AppColors.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.bgSurfaceHigh,
        title: const Text('Delete your account?'),
        content: Text(
          'This permanently deletes your profile, photo, reviews, race history, '
          'pals and activity. This cannot be undone.\n\n'
          'You\'ll be asked to sign in again to confirm it\'s you.',
          style: TextStyle(color: c.textSecondary, fontSize: AppType.base),
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

  Widget _stat(String label, String value) => Builder(
    builder: (context) {
      final c = AppColors.of(context);
      return Column(
        children: [
          Text(value,
              style: TextStyle(
                fontFamily: AppType.display,
                fontSize: AppType.xxl,
                fontWeight: FontWeight.w800,
                color: c.textPrimary,
              )),
          Text(label,
              style: TextStyle(
                fontSize: AppType.sm,
                color: c.textSecondary,
              )),
        ],
      );
    },
  );

  Widget _statDivider() => Builder(
    builder: (context) => Container(
      height: 30,
      width: 1,
      color: AppColors.of(context).divider,
    ),
  );

  Future<void> _confirmLogout(BuildContext context, AppProvider provider) async {
    final c = AppColors.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.bgSurfaceHigh,
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

/// Appearance picker (System / Light / Dark) backed by [ThemeController].
class _ThemeSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final controller = context.watch<ThemeController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Appearance',
            style: TextStyle(
                fontFamily: AppType.body,
                color: c.textSecondary,
                fontSize: AppType.sm,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8)),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('System'),
                  icon: Icon(Icons.brightness_auto_outlined, size: 18)),
              ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode_outlined, size: 18)),
              ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode_outlined, size: 18)),
            ],
            selected: {controller.mode},
            onSelectionChanged: (s) => controller.setMode(s.first),
          ),
        ),
      ],
    );
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
            return Center(
              child: Text('No races yet.',
                  style: TextStyle(color: AppColors.of(context).textSecondary)),
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

  Widget _header(String t) => Builder(
        builder: (context) => Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 6),
          child: Text(t.toUpperCase(),
              style: TextStyle(
                  color: AppColors.of(context).feedSectionLabel,
                  fontSize: AppType.xs,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2)),
        ),
      );

  Widget _raceRow(BuildContext context, Race race) {
    final c = AppColors.of(context);
    return GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => RaceDetailScreen(raceId: race.id)),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.bgSurface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(race.name,
                        style: TextStyle(
                            color: c.textPrimary,
                            fontWeight: FontWeight.w500,
                            fontSize: AppType.md)),
                    const SizedBox(height: 2),
                    Text(
                        '${DateFormat('EEE d MMM yyyy').format(race.date)} · ${race.location}',
                        style: TextStyle(
                            color: c.textSecondary, fontSize: AppType.sm),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (race.reviewCount > 0) ...[
                Icon(Icons.star, size: 13, color: c.achievement),
                const SizedBox(width: 2),
                Text(race.averageRating.toStringAsFixed(1),
                    style: TextStyle(
                        color: c.achievement,
                        fontSize: AppType.sm,
                        fontWeight: FontWeight.w700)),
              ],
            ],
          ),
        ),
      );
  }
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
          final c = AppColors.of(context);
          if (reviews.isEmpty) {
            return Center(
              child: Text('No reviews yet.',
                  style: TextStyle(color: c.textSecondary)),
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
                    color: c.bgSurface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: c.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder<Race?>(
                        future: provider.raceService.getRace(rv.raceId),
                        builder: (ctx, rs) => Text(
                          rs.data?.name ?? 'Race',
                          style: TextStyle(
                              color: c.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: AppType.md),
                        ),
                      ),
                      const SizedBox(height: 6),
                      LightningRating(rating: rv.rating, size: 16),
                      if (rv.body != null && rv.body!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(rv.body!,
                            style: TextStyle(
                                color: c.textSecondary, fontSize: AppType.sm)),
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
