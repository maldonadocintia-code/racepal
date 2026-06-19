import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/race_model.dart';
import '../models/review_model.dart';
import '../models/user_model.dart';
import '../theme.dart';

// ── ⚡ Lightning Bolt Rating ───────────────────────────────────────────────

class LightningRating extends StatelessWidget {
  final double rating;
  final double size;
  final bool interactive;
  final ValueChanged<double>? onRatingChanged;

  const LightningRating({
    super.key,
    required this.rating,
    this.size = 20,
    this.interactive = false,
    this.onRatingChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (interactive) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          final filled = i < rating;
          return Semantics(
            label: '${i + 1} bolt${i == 0 ? '' : 's'}',
            button: true,
            child: GestureDetector(
              onTap: () => onRatingChanged?.call(i + 1.0),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Icon(
                  Icons.bolt,
                  size: size,
                  color: filled ? c.achievement : c.border,
                ),
              ),
            ),
          );
        }),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rating.round();
        return Icon(
          Icons.bolt,
          size: size,
          color: filled ? c.achievement : c.border,
        );
      }),
    );
  }
}

// ── User Avatar ───────────────────────────────────────────────────────────

class UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String displayName;
  final double radius;

  const UserAvatar({
    super.key,
    this.photoUrl,
    required this.displayName,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: CachedNetworkImageProvider(photoUrl!),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: c.avatarBg,
      child: Text(
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
        style: TextStyle(
          fontFamily: AppType.display,
          color: c.avatarText,
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.9,
        ),
      ),
    );
  }
}

// ── Race Card ─────────────────────────────────────────────────────────────

class RaceCard extends StatelessWidget {
  final Race race;
  final VoidCallback? onTap;
  final bool compact;

  const RaceCard({
    super.key,
    required this.race,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: c.bgSurface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: c.border),
        ),
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _typeBadge(c),
                  const Spacer(),
                  Text(
                    DateFormat('EEE d MMM').format(race.date),
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: AppType.sm,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                race.name,
                style: TextStyle(
                  fontFamily: AppType.heading,
                  color: c.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? AppType.md : AppType.lg,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: c.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      race.location,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: AppType.sm,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (!compact && race.reviewCount > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    LightningRating(rating: race.averageRating, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      '${race.averageRating.toStringAsFixed(1)} (${race.reviewCount})',
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: AppType.sm,
                      ),
                    ),
                    const Spacer(),
                    if (race.attendeeCount > 0)
                      Row(
                        children: [
                          Icon(Icons.people, size: 14, color: c.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            '${race.attendeeCount} going',
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: AppType.sm,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeBadge(AppColors c) {
    final isParkrun = race.isParkrun;
    // parkrun = green (brand convention), race = cyan (light-safe in both modes).
    final color = isParkrun ? AppPalette.goGreen : c.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isParkrun ? Icons.bolt : Icons.flag,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            race.type,
            style: TextStyle(
              color: color,
              fontSize: AppType.sm,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Review Tile ───────────────────────────────────────────────────────────

class ReviewTile extends StatelessWidget {
  final Review review;
  final String? currentUserId;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ReviewTile({
    super.key,
    required this.review,
    this.currentUserId,
    this.onEdit,
    this.onDelete,
  });

  bool get _isOwner => currentUserId != null && currentUserId == review.userId;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.bgSurfaceHigh,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(
                photoUrl: review.userPhotoUrl,
                displayName: review.userName,
                radius: 16,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.userName,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: AppType.base,
                      ),
                    ),
                    if (review.finishTime != null)
                      Text(
                        '⏱ ${review.finishTime}',
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: AppType.sm,
                        ),
                      ),
                  ],
                ),
              ),
              LightningRating(rating: review.rating, size: 16),
              if (!review.isPublic)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(Icons.lock, size: 14, color: c.textTertiary),
                ),
              if (_isOwner)
                PopupMenuButton<_ReviewAction>(
                  tooltip: 'Review options',
                  icon: Icon(Icons.more_vert, size: 20, color: c.textTertiary),
                  color: c.bgSurfaceHigh,
                  onSelected: (action) {
                    if (action == _ReviewAction.edit) onEdit?.call();
                    if (action == _ReviewAction.delete) _confirmDelete(context);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: _ReviewAction.edit,
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined,
                              size: 16, color: c.textPrimary),
                          const SizedBox(width: 10),
                          const Text('Edit review'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: _ReviewAction.delete,
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 16, color: Colors.red),
                          SizedBox(width: 10),
                          Text('Delete review',
                              style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (review.body != null && review.body!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.body!,
              style: TextStyle(color: c.textPrimary, fontSize: AppType.base),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final c = AppColors.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.bgSurfaceHigh,
        title: const Text('Delete review?'),
        content: Text(
          'This will permanently remove your review.',
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
    if (confirm == true) onDelete?.call();
  }
}

enum _ReviewAction { edit, delete }

// ── Pal button ─────────────────────────────────────────────────────────────

class PalButton extends StatelessWidget {
  final PalStatus status;
  final VoidCallback onPressed;

  const PalButton({
    super.key,
    required this.status,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    OutlinedButton outlined(String label, {Color? fg}) => OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: fg ?? c.textPrimary,
            side: BorderSide(color: fg ?? c.border),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.full)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          ),
          child: Text(label),
        );
    ElevatedButton filled(String label, {Color? bg, Color? fg}) =>
        ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: bg ?? c.actionBg,
            foregroundColor: fg ?? c.actionText,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.full)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          ),
          child: Text(label),
        );

    switch (status) {
      case PalStatus.pals:
        return outlined('Pals ✓', fg: c.pals);
      case PalStatus.requested:
        return outlined('Requested', fg: c.textSecondary);
      case PalStatus.incoming:
        return filled('Accept pal');
      case PalStatus.none:
        return filled('Add pal');
      case PalStatus.self:
        return const SizedBox.shrink();
    }
  }
}
