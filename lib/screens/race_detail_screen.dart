import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_provider.dart';
import '../models/race_model.dart';
import '../models/review_model.dart';
import '../widgets/shared_widgets.dart';
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
            // Header banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: race.isParkrun
                      ? [AppTheme.primary, AppTheme.primary.withBlue(255)]
                      : [const Color(0xFF1A1A2E), AppTheme.surface],
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
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(race.location,
                          style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('EEEE, d MMMM yyyy').format(race.date),
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
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
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
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

            if (race.description != null) ...[
              _section('About', Padding(
                padding: const EdgeInsets.all(16),
                child: Text(race.description!,
                    style: const TextStyle(color: AppTheme.textSecondary)),
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
                    foregroundColor: AppTheme.accent,
                    side: const BorderSide(color: AppTheme.accent),
                  ),
                ),
              ),

            // Attendees
            _section(
              'Who\'s going (${race.attendeeCount})',
              _AttendeesList(raceId: race.id),
            ),

            // Reviews
            _section(
              'Reviews',
              _ReviewSection(race: race, uid: uid),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      child,
    ],
  );

  Widget _typeBadge(Race race) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      race.type,
      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );

  Future<void> _confirmDelete(BuildContext context, AppProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete race?'),
        content: const Text(
          'This will permanently delete the race.',
          style: TextStyle(color: AppTheme.textSecondary),
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? AppTheme.primary
                : accent
                    ? AppTheme.accent.withOpacity(0.15)
                    : danger
                        ? Colors.red.withValues(alpha: 0.1)
                        : AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: accent && !active
                ? Border.all(color: AppTheme.accent.withOpacity(0.5))
                : danger
                    ? Border.all(color: Colors.red.withValues(alpha: 0.4))
                    : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: active
                      ? Colors.white
                      : accent
                          ? AppTheme.accent
                          : danger
                              ? Colors.red
                              : AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: active
                      ? Colors.white
                      : accent
                          ? AppTheme.accent
                          : danger
                              ? Colors.red
                              : AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
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
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ReviewSheet(race: widget.race),
    );
  }
}

class _AttendeesList extends StatelessWidget {
  final String raceId;
  const _AttendeesList({required this.raceId});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    return StreamBuilder<List<Attendance>>(
      stream: provider.raceService.raceAttendees(raceId),
      builder: (ctx, snap) {
        final attendees = snap.data ?? [];
        if (attendees.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('No attendees yet. Be the first!',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          );
        }
        return SizedBox(
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
        );
      },
    );
  }
}

class _ReviewSection extends StatelessWidget {
  final Race race;
  final String uid;
  const _ReviewSection({required this.race, required this.uid});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    return StreamBuilder<List<Review>>(
      stream: provider.raceService.raceReviews(race.id, publicOnly: true),
      builder: (ctx, snap) {
        final reviews = snap.data ?? [];
        if (reviews.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('No reviews yet.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: reviews.length,
          itemBuilder: (_, i) => ReviewTile(
            review: reviews[i],
            currentUserId: uid,
            onEdit: () => showModalBottomSheet(
              context: ctx,
              isScrollControlled: true,
              backgroundColor: AppTheme.surface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (_) => ReviewSheet(
                race: race,
                existingReview: reviews[i],
              ),
            ),
            onDelete: () async {
              await provider.raceService.deleteReview(reviews[i]);
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
        );
      },
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
  late bool _isPublic;
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
    _isPublic = e?.isPublic ?? true;
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
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
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
          Text(
            _isEditing ? 'Edit review' : 'Review: ${widget.race.name}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
          ),
          const SizedBox(height: 16),
          const Text('Your rating', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
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
          const Text('Would you recommend this event?',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              _recommendBtn(true, '⚡ Yes'),
              const SizedBox(width: 10),
              _recommendBtn(false, 'No'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Visible to:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => setState(() => _isPublic = true),
                child: Row(
                  children: [
                    Radio<bool>(value: true, groupValue: _isPublic, onChanged: (v) => setState(() => _isPublic = v!)),
                    const Text('Everyone', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _isPublic = false),
                child: Row(
                  children: [
                    Radio<bool>(value: false, groupValue: _isPublic, onChanged: (v) => setState(() => _isPublic = v!)),
                    const Text('Followers', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
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
    );
  }

  Widget _recommendBtn(bool value, String label) {
    final selected = _recommend == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _recommend = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? (value ? AppTheme.primary : AppTheme.surfaceLight)
                : AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? (value ? AppTheme.primary : AppTheme.textSecondary)
                  : AppTheme.divider,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
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
        isPublic: _isPublic,
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
        isPublic: _isPublic,
        recommend: _recommend,
      );
    }
    if (mounted) Navigator.pop(context);
  }
}
