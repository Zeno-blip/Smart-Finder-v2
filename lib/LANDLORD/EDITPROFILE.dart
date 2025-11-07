// lib/LANDLORD/editprofile.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

class LandlordEditProfile extends StatefulWidget {
  final String name;
  final String email;
  final String phone;
  final String address;
  final String? currentAvatarUrl;

  const LandlordEditProfile({
    super.key,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    this.currentAvatarUrl,
  });

  @override
  State<LandlordEditProfile> createState() => _LandlordEditProfileState();
}

class _LandlordEditProfileState extends State<LandlordEditProfile> {
  final _sb = Supabase.instance.client;
  final _picker = ImagePicker();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
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

    final storage = _sb.storage.from('avatars');
    final ext = p.extension(_pickedImage!.path).toLowerCase();
    final useExt = (ext == '.png' || ext == '.jpg' || ext == '.jpeg')
        ? ext
        : '.jpg';
    final contentType = (useExt == '.png') ? 'image/png' : 'image/jpeg';
    final objectName = '$uid$useExt';

    await storage.upload(
      objectName,
      _pickedImage!,
      fileOptions: FileOptions(upsert: true, contentType: contentType),
    );
    return storage.getPublicUrl(objectName);
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

      final toUpdate = <String, dynamic>{
        'full_name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      };

      await _sb.from('users').update(toUpdate).eq('id', uid);

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
        : (widget.currentAvatarUrl != null
              ? Image.network(widget.currentAvatarUrl!, fit: BoxFit.cover)
              : Image.asset('assets/images/landlord.png', fit: BoxFit.cover));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'EDIT PROFILE',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF00324E),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 120,
                height: 120,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white),
                ),
                child: avatar,
              ),
            ),
            const SizedBox(height: 18),
            _input(Icons.person, 'Full name', controller: _nameCtrl),
            const SizedBox(height: 12),
            _input(
              Icons.email,
              'Email',
              controller: _emailCtrl,
              enabled: false,
            ),
            const SizedBox(height: 12),
            _input(
              Icons.phone,
              'Phone',
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            _input(Icons.location_on, 'Address', controller: _addressCtrl),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF04354B),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'SAVE',
                        style: TextStyle(
                          color: Colors.white,
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

  Widget _input(
    IconData icon,
    String hint, {
    required TextEditingController controller,
    bool enabled = true,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.shade200,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
