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
                  color: filled ? AppTheme.accent : AppTheme.surfaceLight,
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
          color: filled ? AppTheme.accent : AppTheme.surfaceLight,
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
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: CachedNetworkImageProvider(photoUrl!),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.primary,
      child: Text(
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _typeBadge(),
                  const Spacer(),
                  Text(
                    DateFormat('EEE d MMM').format(race.date),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: AppTheme.fsCaption,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                race.name,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 15 : 17,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      race.location,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: AppTheme.fsSecondary,
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
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: AppTheme.fsCaption,
                      ),
                    ),
                    const Spacer(),
                    if (race.attendeeCount > 0)
                      Row(
                        children: [
                          const Icon(Icons.people, size: 14, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            '${race.attendeeCount} going',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: AppTheme.fsCaption,
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

  Widget _typeBadge() {
    final isParkrun = race.isParkrun;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isParkrun
            ? AppTheme.primary.withOpacity(0.2)
            : AppTheme.accent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isParkrun ? AppTheme.primary : AppTheme.accent,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isParkrun ? Icons.bolt : Icons.flag,
            size: 12,
            color: isParkrun ? AppTheme.primary : AppTheme.accent,
          ),
          const SizedBox(width: 4),
          Text(
            race.type,
            style: TextStyle(
              color: isParkrun ? AppTheme.primary : AppTheme.accent,
              fontSize: AppTheme.fsCaption,
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(14),
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
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: AppTheme.fsBody,
                      ),
                    ),
                    if (review.finishTime != null)
                      Text(
                        '⏱ ${review.finishTime}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: AppTheme.fsCaption,
                        ),
                      ),
                  ],
                ),
              ),
              LightningRating(rating: review.rating, size: 16),
              if (!review.isPublic)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(Icons.lock, size: 14, color: AppTheme.textSecondary),
                ),
              if (_isOwner)
                PopupMenuButton<_ReviewAction>(
                  tooltip: 'Review options',
                  icon: const Icon(Icons.more_vert,
                      size: 20, color: AppTheme.textSecondary),
                  color: AppTheme.surface,
                  onSelected: (action) {
                    if (action == _ReviewAction.edit) onEdit?.call();
                    if (action == _ReviewAction.delete) _confirmDelete(context);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: _ReviewAction.edit,
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 16, color: AppTheme.textPrimary),
                          SizedBox(width: 10),
                          Text('Edit review'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
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
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: AppTheme.fsBody),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete review?'),
        content: const Text(
          'This will permanently remove your review.',
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
    if (confirm == true) onDelete?.call();
  }
}

enum _ReviewAction { edit, delete }

// ── Follow button ─────────────────────────────────────────────────────────

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
    OutlinedButton outlined(String label, {Color? fg}) => OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: fg ?? AppTheme.textPrimary,
            side: const BorderSide(color: AppTheme.divider),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          ),
          child: Text(label),
        );
    ElevatedButton filled(String label, {Color? bg, Color? fg}) =>
        ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: bg ?? AppTheme.primary,
            foregroundColor: fg ?? Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          ),
          child: Text(label),
        );

    switch (status) {
      case PalStatus.pals:
        return outlined('Pals ✓');
      case PalStatus.requested:
        return outlined('Requested', fg: AppTheme.textSecondary);
      case PalStatus.incoming:
        return filled('Accept pal',
            bg: AppTheme.accent, fg: AppTheme.background);
      case PalStatus.none:
        return filled('Add pal');
      case PalStatus.self:
        return const SizedBox.shrink();
    }
  }
}
