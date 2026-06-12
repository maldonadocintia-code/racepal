import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/app_provider.dart';
import '../widgets/shared_widgets.dart';
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
  File? _pendingPhoto;
  bool _uploadingPhoto = false;

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

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (picked == null) return;
    setState(() => _pendingPhoto = File(picked.path));
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from library'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppProvider>().currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _saving || _uploadingPhoto ? null : _save,
            child: _saving || _uploadingPhoto
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
            // Avatar picker
            Center(
              child: Stack(
                children: [
                  _pendingPhoto != null
                      ? CircleAvatar(
                          radius: 48,
                          backgroundImage: FileImage(_pendingPhoto!),
                        )
                      : UserAvatar(
                          photoUrl: user.photoUrl,
                          displayName: user.displayName,
                          radius: 48,
                        ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: _showPhotoOptions,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.background, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                  if (_uploadingPhoto)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _showPhotoOptions,
                child: const Text('Change profile photo',
                    style: TextStyle(color: AppTheme.primary)),
              ),
            ),
            const SizedBox(height: 16),
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
    try {
      if (_pendingPhoto != null) {
        setState(() { _uploadingPhoto = true; _saving = false; });
        await context.read<AppProvider>().uploadProfilePhoto(_pendingPhoto!);
        setState(() => _uploadingPhoto = false);
      }
      await context.read<AppProvider>().updateProfile(
        displayName: _nameCtrl.text.trim(),
        bio: _bioCtrl.text.trim(),
        isPublic: _isPublic,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() { _saving = false; _uploadingPhoto = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }
}
