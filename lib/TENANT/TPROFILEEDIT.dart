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
  final _emailCtrl = TextEditingController(); // shown but disabled
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
    if (x != null) {
      setState(() => _pickedImage = File(x.path));
    }
  }

  Future<String?> _uploadAvatarIfNeeded(String uid) async {
    if (_pickedImage == null) return null;

    final ext = p.extension(_pickedImage!.path).toLowerCase();
    final object = 'avatars/$uid${ext.isNotEmpty ? ext : '.jpg'}';

    final storage = _sb.storage.from('avatars');
    await storage.upload(
      object.replaceFirst('avatars/', ''), // bucket-scoped path
      _pickedImage!,
      fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
    );

    // Get a public URL you can display
    final publicUrl = storage.getPublicUrl(object.replaceFirst('avatars/', ''));
    return publicUrl;
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
      // 1) Upload avatar if the user picked one
      final avatarUrl = await _uploadAvatarIfNeeded(uid);

      // 2) Update the public.users row (keeps with your schema)
      final toUpdate = <String, dynamic>{
        'full_name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        // If you add an "avatar_url" column later, uncomment:
        // if (avatarUrl != null) 'avatar_url': avatarUrl,
      };

      await _sb.from('users').update(toUpdate).eq('id', uid);

      // 3) (Optional) keep tenant_profile in sync if you use it in other places
      try {
        await _sb
            .from('tenant_profile')
            .update({
              'full_name': _nameCtrl.text.trim(),
              'phone': _phoneCtrl.text.trim(),
            })
            .eq('user_id', uid);
      } catch (_) {
        // ignore if tenant_profile missing or you don't need it
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated.')));
      Navigator.pop(context, true); // tell caller to refresh
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
        : (widget.currentAvatarUrl != null
              ? Image.network(widget.currentAvatarUrl!, fit: BoxFit.cover)
              : Image.asset('assets/images/josil.png', fit: BoxFit.cover));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "EDIT PROFILE",
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF00324E),
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF00324E), Color(0xFF005B96)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),

                // Avatar
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.1),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: avatar,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Upload Photo",
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                _input(Icons.person, 'Full name', controller: _nameCtrl),
                const SizedBox(height: 15),
                _input(
                  Icons.email,
                  'Email',
                  controller: _emailCtrl,
                  enabled: false,
                ),
                const SizedBox(height: 15),
                _input(
                  Icons.phone,
                  'Phone',
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 15),
                _input(Icons.location_on, 'Address', controller: _addressCtrl),

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF04354B),
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
                            "SAVE",
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _input(
    IconData icon,
    String hint, {
    required TextEditingController controller,
    bool enabled = true,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(enabled ? 0.95 : 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.black87),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black54),
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
