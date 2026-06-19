import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_provider.dart';
import '../models/race_model.dart';
import '../models/review_model.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/parkrun_helpers.dart';
import '../theme.dart';

class RaceDetailScreen extends StatelessWidget {
  final String raceId;
  const RaceDetailScreen({super.key, required this.raceId});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();

    return FutureBuilder<Race?>(
      future: provider.raceService.getRace(raceId),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final race = snap.data;
        if (race == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Race not found')),
          );
        }
        return _RaceDetailBody(race: race);
      },
    );
  }
}

class _RaceDetailBody extends StatelessWidget {
  final Race race;
  const _RaceDetailBody({required this.race});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final c = AppColors.of(context);
    final uid = provider.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(race.name),
        actions: [
          if (provider.currentUser?.uid == race.createdBy)
            IconButton(
              tooltip: 'Delete race',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, provider),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header banner — a dark "hero" in both themes so the white text and
            // volt accents always read. Parkrun gets a green-tinted edge, races
            // a cyan-tinted one.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.alphaBlend(
                        (race.isParkrun ? AppPalette.goGreen : AppPalette.cyan)
                            .withValues(alpha: 0.18),
                        AppPalette.surfaceHigh),
                    AppPalette.midnight,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _typeBadge(race),
                  const SizedBox(height: 12),
                  Text(
                    race.name,
                    style: const TextStyle(
                      fontFamily: AppType.heading,
                      fontSize: AppType.xxl,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(race.location,
                          style: const TextStyle(color: Colors.white70, fontSize: AppType.base)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        race.isParkrun
                            ? 'Every Saturday · 9:00am'
                            : DateFormat('EEEE, d MMMM yyyy').format(race.date),
                        style: const TextStyle(color: Colors.white70, fontSize: AppType.base),
                      ),
                    ],
                  ),
                  if (race.averageRating > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        LightningRating(rating: race.averageRating, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '${race.averageRating.toStringAsFixed(1)} · ${race.reviewCount} reviews',
                          style: const TextStyle(color: Colors.white70, fontSize: AppType.sm),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Attendance row
            Padding(
              padding: const EdgeInsets.all(16),
              child: _AttendanceRow(race: race, uid: uid),
            ),

            // Pals going / attended (per-date; not shown for parkrun venue doc)
            if (!race.isParkrun) _PalsSection(raceId: race.id, uid: uid),

            if (race.description != null) ...[
              _section('About', Padding(
                padding: const EdgeInsets.all(16),
                child: Text(race.description!,
                    style: TextStyle(color: c.textSecondary)),
              )),
            ],

            if (race.website != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: OutlinedButton.icon(
                  onPressed: () => launchUrl(Uri.parse(race.website!)),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Race website'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.textLink,
                    side: BorderSide(color: c.textLink),
                  ),
                ),
              ),

            // Attendees (per-date; not shown for parkrun venue doc). The count
            // and the avatar list are both driven off the same live stream, so
            // the header stays in sync as people join/leave.
            if (!race.isParkrun) _AttendeesSection(raceId: race.id),

            // Reviews
            _ReviewSection(race: race, uid: uid),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, Widget child) => Builder(
    builder: (context) {
      final c = AppColors.of(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: TextStyle(
                fontFamily: AppType.heading,
                fontWeight: FontWeight.w700,
                fontSize: AppType.lg,
                color: c.textPrimary,
              ),
            ),
          ),
          child,
        ],
      );
    },
  );

  Widget _typeBadge(Race race) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(AppRadius.full),
    ),
    child: Text(
      race.type,
      style: const TextStyle(color: Colors.white, fontSize: AppType.sm, fontWeight: FontWeight.w600),
    ),
  );

  Future<void> _confirmDelete(BuildContext context, AppProvider provider) async {
    final c = AppColors.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.bgSurfaceHigh,
        title: const Text('Delete race?'),
        content: Text(
          'This will permanently delete the race.',
          style: TextStyle(color: c.textSecondary),
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
    if (confirm == true && context.mounted) {
      await provider.raceService.deleteRace(race.id);
      Navigator.pop(context);
    }
  }
}

class _AttendanceRow extends StatefulWidget {
  final Race race;
  final String uid;
  const _AttendanceRow({required this.race, required this.uid});

  @override
  State<_AttendanceRow> createState() => _AttendanceRowState();
}

class _AttendanceRowState extends State<_AttendanceRow> {
  Attendance? _attendance;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = await context
        .read<AppProvider>()
        .raceService
        .getAttendance(raceId: widget.race.id, userId: widget.uid);
    if (mounted) setState(() => _attendance = a);
  }

  Future<void> _set(AttendanceStatus status) async {
    if (_loading) return;
    setState(() => _loading = true);
    final provider = context.read<AppProvider>();
    if (_attendance?.status == status) {
      await provider.raceService.removeAttendance(
          raceId: widget.race.id, userId: widget.uid);
      setState(() { _attendance = null; _loading = false; });
    } else {
      await provider.setAttendance(
          raceId: widget.race.id,
          raceName: widget.race.name,
          status: status);
      await _load();
      setState(() => _loading = false);
    }
  }

  Future<void> _remove() async {
    if (_loading) return;
    setState(() => _loading = true);
    await context
        .read<AppProvider>()
        .raceService
        .removeAttendance(raceId: widget.race.id, userId: widget.uid);
    setState(() { _attendance = null; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    // Parkruns plan a specific Saturday (per-date) rather than a one-off
    // Going/Attended on the venue doc — keeps the calendar accurate.
    if (widget.race.isParkrun) {
      // If the user already planned this specific Saturday (a per-date doc they
      // marked "going"), let them back out — "can't make it / changed my mind".
      // The generic venue doc instead offers "Plan a date".
      final planned = _attendance?.status == AttendanceStatus.going;
      return Row(
        children: [
          if (planned)
            _btn(
              label: 'Not going',
              icon: Icons.cancel_outlined,
              active: false,
              onTap: _remove,
              danger: true,
            )
          else
            _btn(
              label: 'Plan a date',
              icon: Icons.event_available_outlined,
              active: false,
              onTap: () => planParkrunDate(
                context,
                venueId: widget.race.id,
                name: widget.race.name,
                location: widget.race.location,
                lat: widget.race.lat,
                lng: widget.race.lng,
              ),
            ),
          const SizedBox(width: 10),
          _btn(
            label: 'Review',
            icon: Icons.bolt,
            active: false,
            onTap: () => _showReviewSheet(context),
            accent: true,
          ),
        ],
      );
    }

    final status = _attendance?.status;

    // Row adapts to current status:
    // - Not attending  → [Going] [Attended] [Review]
    // - Going          → [Not going] [Attended] [Review]
    // - Attended       → [Going] [✓ Attended] [Review]
    return Row(
      children: [
        if (status == AttendanceStatus.going)
          _btn(
            label: 'Not going',
            icon: Icons.cancel_outlined,
            active: false,
            onTap: _remove,
            danger: true,
          )
        else
          _btn(
            label: 'Going',
            icon: Icons.check_circle_outline,
            active: status == AttendanceStatus.going,
            onTap: () => _set(AttendanceStatus.going),
          ),
        const SizedBox(width: 10),
        _btn(
          label: 'Attended',
          icon: Icons.emoji_events_outlined,
          active: status == AttendanceStatus.attended,
          onTap: () => _set(AttendanceStatus.attended),
        ),
        const SizedBox(width: 10),
        _btn(
          label: 'Review',
          icon: Icons.bolt,
          active: false,
          onTap: () => _showReviewSheet(context),
          accent: true,
        ),
      ],
    );
  }

  Widget _btn({
    required String label,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
    bool accent = false,
    bool danger = false,
  }) {
    final c = AppColors.of(context);
    final Color bg = active
        ? c.actionBg
        : accent
            ? c.primaryMuted
            : danger
                ? Colors.red.withValues(alpha: 0.1)
                : c.bgSurfaceHigh;
    final Color fg = active
        ? c.actionText
        : accent
            ? c.textLink
            : danger
                ? Colors.red
                : c.textSecondary;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: accent && !active
                ? Border.all(color: c.textLink.withValues(alpha: 0.5))
                : danger
                    ? Border.all(color: Colors.red.withValues(alpha: 0.4))
                    : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w600,
                  fontSize: AppType.sm,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReviewSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.of(context).sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      builder: (_) => ReviewSheet(race: widget.race),
    );
  }
}

class _PalsSection extends StatefulWidget {
  final String raceId;
  final String uid;
  const _PalsSection({required this.raceId, required this.uid});

  @override
  State<_PalsSection> createState() => _PalsSectionState();
}

class _PalsSectionState extends State<_PalsSection> {
  Set<String> _palUids = {};

  @override
  void initState() {
    super.initState();
    _loadPals();
  }

  Future<void> _loadPals() async {
    final provider = context.read<AppProvider>();
    final pals = await provider.palService.getPals(widget.uid);
    if (mounted) setState(() => _palUids = pals.map((p) => p.uid).toSet());
  }

  @override
  Widget build(BuildContext context) {
    if (_palUids.isEmpty) return const SizedBox.shrink();

    final provider = context.read<AppProvider>();
    final c = AppColors.of(context);
    return StreamBuilder<List<Attendance>>(
      stream: provider.raceService.raceAttendees(widget.raceId),
      builder: (ctx, snap) {
        final palAttendances = (snap.data ?? [])
            .where((a) => _palUids.contains(a.userId))
            .toList();

        if (palAttendances.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Pals',
                    style: TextStyle(
                      fontFamily: AppType.heading,
                      fontWeight: FontWeight.w700,
                      fontSize: AppType.lg,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: c.palBadgeBg,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      '${palAttendances.length}',
                      style: TextStyle(
                        color: c.palBadgeText,
                        fontSize: AppType.sm,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: palAttendances.length,
                itemBuilder: (_, i) {
                  final a = palAttendances[i];
                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: FutureBuilder(
                      future: provider.authService.getUser(a.userId),
                      builder: (_, userSnap) {
                        final u = userSnap.data;
                        return Column(
                          children: [
                            UserAvatar(
                              photoUrl: u?.photoUrl,
                              displayName: u?.displayName ?? '?',
                              radius: 22,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              u?.displayName.split(' ').first ?? '...',
                              style: TextStyle(
                                fontSize: AppType.xs,
                                color: c.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              a.status == AttendanceStatus.going
                                  ? 'Going'
                                  : 'Been here',
                              style: TextStyle(
                                fontSize: AppType.xs,
                                color: a.status == AttendanceStatus.going
                                    ? c.secondary
                                    : c.statusLive,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Section header matching the look of `_RaceDetailBody._section`, used by the
/// sections that render their own (live-counted) header.
Widget _sectionHeader(BuildContext context, String title) {
  final c = AppColors.of(context);
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Text(
      title,
      style: TextStyle(
        fontFamily: AppType.heading,
        fontWeight: FontWeight.w700,
        fontSize: AppType.lg,
        color: c.textPrimary,
      ),
    ),
  );
}

class _AttendeesSection extends StatelessWidget {
  final String raceId;
  const _AttendeesSection({required this.raceId});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final c = AppColors.of(context);
    return StreamBuilder<List<Attendance>>(
      stream: provider.raceService.raceAttendees(raceId),
      builder: (ctx, snap) {
        final attendees = snap.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(context, 'Who\'s going (${attendees.length})'),
            if (attendees.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('No attendees yet. Be the first!',
                    style: TextStyle(color: c.textSecondary, fontSize: AppType.sm)),
              )
            else
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: attendees.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FutureBuilder(
                      future: provider.authService.getUser(attendees[i].userId),
                      builder: (_, userSnap) {
                        final u = userSnap.data;
                        return UserAvatar(
                          photoUrl: u?.photoUrl,
                          displayName: u?.displayName ?? '?',
                          radius: 22,
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ReviewSection extends StatefulWidget {
  final Race race;
  final String uid;
  const _ReviewSection({required this.race, required this.uid});

  @override
  State<_ReviewSection> createState() => _ReviewSectionState();
}

class _ReviewSectionState extends State<_ReviewSection> {
  bool _palsOnly = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final c = AppColors.of(context);
    final palUids = provider.palUids.toSet();

    return StreamBuilder<List<Review>>(
      stream: provider.raceService.raceReviews(widget.race.id),
      builder: (ctx, snap) {
        final all = snap.data ?? [];
        final palReviews =
            all.where((r) => palUids.contains(r.userId)).toList();

        // "All" surfaces your own review first, then pals' (social proof),
        // then everyone else's. "Pals" narrows to just your pals' reviews.
        final List<Review> visible;
        if (_palsOnly) {
          visible = palReviews;
        } else {
          final mine = <Review>[];
          final pals = <Review>[];
          final others = <Review>[];
          for (final r in all) {
            if (r.userId == widget.uid) {
              mine.add(r);
            } else if (palUids.contains(r.userId)) {
              pals.add(r);
            } else {
              others.add(r);
            }
          }
          visible = [...mine, ...pals, ...others];
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(context, 'Reviews (${all.length})'),
            // Only offer the Pals filter once a pal has actually reviewed —
            // otherwise it's a dead toggle.
            if (palReviews.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    _filterChip(context, 'All', !_palsOnly,
                        () => setState(() => _palsOnly = false)),
                    const SizedBox(width: 8),
                    _filterChip(context, 'Pals (${palReviews.length})',
                        _palsOnly, () => setState(() => _palsOnly = true)),
                  ],
                ),
              ),
            if (all.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('No reviews yet.',
                    style: TextStyle(color: c.textSecondary, fontSize: AppType.sm)),
              )
            else if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('None of your pals have reviewed this yet.',
                    style: TextStyle(color: c.textSecondary, fontSize: AppType.sm)),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: visible.length,
                itemBuilder: (_, i) => ReviewTile(
                  review: visible[i],
                  currentUserId: widget.uid,
                  isPal: palUids.contains(visible[i].userId),
                  onEdit: () => showModalBottomSheet(
                    context: ctx,
                    isScrollControlled: true,
                    backgroundColor: c.sheetBg,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
                    ),
                    builder: (_) => ReviewSheet(
                      race: widget.race,
                      existingReview: visible[i],
                    ),
                  ),
                  onDelete: () async {
                    await provider.raceService.deleteReview(visible[i]);
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Review deleted'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _filterChip(
      BuildContext context, String label, bool selected, VoidCallback onTap) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.actionBg : c.bgSurfaceHigh,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: selected ? c.actionBg : c.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? c.actionText : c.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: AppType.sm,
          ),
        ),
      ),
    );
  }
}

// ── Review bottom sheet ────────────────────────────────────────────────────

class ReviewSheet extends StatefulWidget {
  final Race race;
  final Review? existingReview;
  const ReviewSheet({super.key, required this.race, this.existingReview});

  @override
  State<ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<ReviewSheet> {
  late double _rating;
  late final TextEditingController _bodyCtrl;
  late final TextEditingController _timeCtrl;
  late bool _recommend;
  bool _saving = false;

  bool get _isEditing => widget.existingReview != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existingReview;
    _rating = e?.rating ?? 3;
    _bodyCtrl = TextEditingController(text: e?.body ?? '');
    _timeCtrl = TextEditingController(text: e?.finishTime ?? '');
    _recommend = e?.recommend ?? true;
  }

  @override
  void dispose() {
    _bodyCtrl.dispose();
    _timeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      // Pad by the keyboard height so the sheet lifts above it, and make the
      // content scrollable so the "Post review" button is always reachable
      // (previously it could sit hidden behind the keyboard).
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
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
            _isEditing ? 'Edit review' : 'Review: ${widget.race.name}',
            style: TextStyle(
                fontFamily: AppType.heading,
                color: c.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: AppType.lg),
          ),
          const SizedBox(height: 16),
          Text('Your rating',
              style: TextStyle(color: c.textSecondary, fontSize: AppType.sm)),
          const SizedBox(height: 8),
          LightningRating(
            rating: _rating,
            size: 36,
            interactive: true,
            onRatingChanged: (r) => setState(() => _rating = r),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _timeCtrl,
            decoration: const InputDecoration(
              labelText: 'Finish time (optional)',
              hintText: 'e.g. 24:32',
              prefixIcon: Icon(Icons.timer_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Write a review (optional)',
              hintText: 'What was it like?',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          Text('Would you recommend this event?',
              style: TextStyle(color: c.textSecondary, fontSize: AppType.sm)),
          const SizedBox(height: 8),
          Row(
            children: [
              _recommendBtn(true, '⚡ Yes'),
              const SizedBox(width: 10),
              _recommendBtn(false, 'No'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_isEditing ? 'Update review' : 'Post review'),
            ),
          ),
          const SizedBox(height: 20),
        ],
        ),
      ),
    );
  }

  Widget _recommendBtn(bool value, String label) {
    final c = AppColors.of(context);
    final selected = _recommend == value;
    final Color bg = selected && value ? c.actionBg : c.bgSurfaceHigh;
    final Color fg = selected && value
        ? c.actionText
        : selected
            ? c.textPrimary
            : c.textSecondary;
    final Color border = selected
        ? (value ? c.actionBg : c.textSecondary)
        : c.divider;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _recommend = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: border),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w600,
                fontSize: AppType.base,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final provider = context.read<AppProvider>();
    if (_isEditing) {
      final e = widget.existingReview!;
      await provider.raceService.updateReview(Review(
        id: e.id,
        raceId: e.raceId,
        userId: e.userId,
        userName: e.userName,
        userPhotoUrl: e.userPhotoUrl,
        rating: _rating,
        body: _bodyCtrl.text.trim().isNotEmpty ? _bodyCtrl.text.trim() : null,
        finishTime: _timeCtrl.text.trim().isNotEmpty ? _timeCtrl.text.trim() : null,
        isPublic: true,
        recommend: _recommend,
        createdAt: e.createdAt,
      ));
    } else {
      await provider.submitReview(
        raceId: widget.race.id,
        raceName: widget.race.name,
        rating: _rating,
        body: _bodyCtrl.text.trim().isNotEmpty ? _bodyCtrl.text.trim() : null,
        finishTime: _timeCtrl.text.trim().isNotEmpty ? _timeCtrl.text.trim() : null,
        isPublic: true,
        recommend: _recommend,
      );
    }
    if (mounted) Navigator.pop(context);
  }
}
