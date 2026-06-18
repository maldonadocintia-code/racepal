import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/app_provider.dart';
import '../widgets/shared_widgets.dart';
import '../theme.dart';
import 'profile_screen.dart';

/// A person's pals — mutual friendships. Tapping a pal opens their profile
/// (where you can remove them). The + opens search to add new pals.
class PalsScreen extends StatelessWidget {
  final String uid;
  const PalsScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final isMe = provider.currentUser?.uid == uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pals'),
        actions: [
          if (isMe)
            IconButton(
              icon: const Icon(Icons.person_add_alt_1),
              tooltip: 'Find pals',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FindPalsScreen()),
              ),
            ),
        ],
      ),
      body: StreamBuilder<List<AppUser>>(
        stream: provider.palService.palsStream(uid),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final pals = snap.data ?? [];
          if (pals.isEmpty) return _empty(context, isMe);
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: pals.length,
            separatorBuilder: (_, __) => const Divider(
                height: 1, color: AppTheme.divider, indent: 72),
            itemBuilder: (_, i) => _PalTile(user: pals[i]),
          );
        },
      ),
    );
  }

  Widget _empty(BuildContext context, bool isMe) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.people_outline,
                  size: 48, color: AppTheme.textSecondary),
              const SizedBox(height: 12),
              Text(
                isMe ? 'No pals yet.' : 'No pals yet.',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              if (isMe) ...[
                const SizedBox(height: 4),
                const Text(
                  'Find runners and send a pal request.\nWhen they accept, they appear here.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: AppTheme.fsSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FindPalsScreen()),
                  ),
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: const Text('Find pals'),
                ),
              ],
            ],
          ),
        ),
      );
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
      title: Text(user.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: AppTheme.fsBody)),
      subtitle: user.bio != null && user.bio!.isNotEmpty
          ? Text(user.bio!,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: AppTheme.fsSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis)
          : Text('${user.racesCount} race${user.racesCount == 1 ? '' : 's'}',
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: AppTheme.fsSecondary)),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProfileScreen(uid: user.uid)),
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
    final users = await provider.palService.searchUsers(q);
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
              style: TextStyle(color: AppTheme.textSecondary, fontSize: AppTheme.fsCaption),
            ),
          ),
          Expanded(
            child: _searching
                ? const Center(child: CircularProgressIndicator())
                : !_searched
                    ? const Center(
                        child: Text('Search for runners by name',
                            style: TextStyle(color: AppTheme.textSecondary)),
                      )
                    : _results.isEmpty
                        ? const Center(
                            child: Text('No runners found with that name',
                                style:
                                    TextStyle(color: AppTheme.textSecondary)),
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

/// A search result with a pal button reflecting the current relationship.
class _FoundUserTile extends StatefulWidget {
  final AppUser user;
  const _FoundUserTile({required this.user});

  @override
  State<_FoundUserTile> createState() => _FoundUserTileState();
}

class _FoundUserTileState extends State<_FoundUserTile> {
  PalStatus? _status;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final status =
          await context.read<AppProvider>().getPalStatus(widget.user.uid);
      if (mounted) setState(() => _status = status);
    } catch (_) {
      if (mounted) setState(() => _status = PalStatus.none);
    }
  }

  Future<void> _toggle() async {
    final previous = _status;
    setState(() => _status = null);
    try {
      await context.read<AppProvider>().togglePal(widget.user);
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
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: UserAvatar(
        photoUrl: widget.user.photoUrl,
        displayName: widget.user.displayName,
        radius: 24,
      ),
      title: Text(widget.user.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: AppTheme.fsBody)),
      subtitle: widget.user.bio != null && widget.user.bio!.isNotEmpty
          ? Text(widget.user.bio!,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: AppTheme.fsSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis)
          : null,
      trailing: _status == null
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2))
          : PalButton(status: _status!, onPressed: _toggle),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProfileScreen(uid: widget.user.uid)),
      ),
    );
  }
}
