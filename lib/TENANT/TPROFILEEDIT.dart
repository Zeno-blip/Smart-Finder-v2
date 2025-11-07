// TENANT/TPROFILEEDIT.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

class TenantEditProfile extends StatefulWidget {
  const TenantEditProfile({
    super.key,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    this.currentAvatarUrl,
  });

  final String name;
  final String email;
  final String phone;
  final String address;
  final String? currentAvatarUrl;

  @override
  State<TenantEditProfile> createState() => _TenantEditProfileState();
}

class _TenantEditProfileState extends State<TenantEditProfile> {
  final _sb = Supabase.instance.client;
  final _picker = ImagePicker();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController(); // read-only
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  File? _pickedImage;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.name;
    _emailCtrl.text = widget.email;
    _phoneCtrl.text = widget.phone;
    _addressCtrl.text = widget.address;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x != null) setState(() => _pickedImage = File(x.path));
  }

  Future<String?> _uploadAvatarIfNeeded(String uid) async {
    if (_pickedImage == null) return null;

    // Always store as <uid>.jpg (stable path, easy to protect with RLS)
    final storage = _sb.storage.from('avatars');
    final path = '$uid.jpg';

    await storage.upload(
      path,
      _pickedImage!,
      fileOptions: const FileOptions(
        upsert: true,
        contentType: 'image/jpeg',
        cacheControl: '1', // revalidate quickly
      ),
    );

    // Break CDN/browser cache after updates
    final base = storage.getPublicUrl(path);
    final v = DateTime.now().millisecondsSinceEpoch;
    return '$base?v=$v';
  }

  Future<void> _save() async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Not logged in.')));
      return;
    }

    setState(() => _saving = true);
    try {
      final avatarUrl = await _uploadAvatarIfNeeded(uid);

      final updates = <String, dynamic>{
        'full_name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      };

      await _sb.from('users').update(updates).eq('id', uid);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated.')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _pickedImage != null
        ? Image.file(_pickedImage!, fit: BoxFit.cover)
        : (widget.currentAvatarUrl != null &&
                  widget.currentAvatarUrl!.isNotEmpty
              ? Image.network(widget.currentAvatarUrl!, fit: BoxFit.cover)
              : const Icon(Icons.person, size: 64, color: Colors.grey));

    return Scaffold(
      backgroundColor: const Color(0xFF002D4C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF002D4C),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'EDIT PROFILE',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 25,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.white,
                  child: ClipOval(
                    child: SizedBox(
                      width: 110,
                      height: 110,
                      child: Center(child: avatar),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 10,
                  child: InkWell(
                    onTap: _pickImage,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blueAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            _field(Icons.person, 'Full name', controller: _nameCtrl),
            const SizedBox(height: 15),
            _field(
              Icons.email,
              'Email',
              controller: _emailCtrl,
              enabled: false,
            ),
            const SizedBox(height: 15),
            _field(Icons.phone, 'Phone', controller: _phoneCtrl),
            const SizedBox(height: 15),
            _field(Icons.location_on, 'Address', controller: _addressCtrl),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5A7689),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'SAVE',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    IconData icon,
    String hint, {
    required TextEditingController controller,
    bool enabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(enabled ? 0.95 : 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.black87),
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 18,
            horizontal: 12,
          ),
        ),
      ),
    );
  }
}
