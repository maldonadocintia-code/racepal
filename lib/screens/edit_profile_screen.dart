import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_provider.dart';
import '../theme.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _bioCtrl;
  late bool _isPublic;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AppProvider>().currentUser!;
    _nameCtrl = TextEditingController(text: user.displayName);
    _bioCtrl = TextEditingController(text: user.bio ?? '');
    _isPublic = user.isPublic;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save', style: TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Display name',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bioCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Bio',
                hintText: 'Tell people a bit about your running...',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.info_outline),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Account privacy',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Private accounts require approval for followers. Your reviews and activity will only be visible to approved followers.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _privacyOption(
                          icon: Icons.public,
                          label: 'Public',
                          desc: 'Anyone can follow',
                          selected: _isPublic,
                          onTap: () => setState(() => _isPublic = true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _privacyOption(
                          icon: Icons.lock_outline,
                          label: 'Private',
                          desc: 'Approve followers',
                          selected: !_isPublic,
                          onTap: () => setState(() => _isPublic = false),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _privacyOption({
    required IconData icon,
    required String label,
    required String desc,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary.withOpacity(0.15) : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected ? AppTheme.primary : AppTheme.textSecondary,
                size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                  color: selected ? AppTheme.primary : AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                )),
            Text(desc,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await context.read<AppProvider>().updateProfile(
      displayName: _nameCtrl.text.trim(),
      bio: _bioCtrl.text.trim(),
      isPublic: _isPublic,
    );
    if (mounted) Navigator.pop(context);
  }
}
