// TENANT/TPROFILE.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'TAPARTMENT.dart';
import 'TCHAT2.dart';
import 'TSETTINGS.dart';
import 'TLOGIN.dart';
import 'TMYROOM.dart';
import 'TPROFILEEDIT.dart';

class TenantProfile extends StatefulWidget {
  const TenantProfile({super.key});

  @override
  State<TenantProfile> createState() => _TenantProfileState();
}

class _TenantProfileState extends State<TenantProfile> {
  final _sb = Supabase.instance.client;
  int _selectedNavIndex = 2;

  Map<String, dynamic>? _userRow; // from public.users
  String? _avatarUrl; // storage public URL
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = _sb.auth.currentUser?.id;
      if (uid == null) {
        setState(() {
          _loading = false;
          _error = 'Not logged in.';
        });
        return;
      }

      // Pull from your public.users table (per your schema image)
      final row = await _sb
          .from('users')
          .select('id, full_name, email, phone, address, first_name, last_name')
          .eq('id', uid)
          .maybeSingle();

      // Build avatar URL from storage (avatars/<uid>.jpg or .png – jpg default)
      final storage = _sb.storage.from('avatars');
      // Try jpg then png
      String? url;
      final jpg = storage.getPublicUrl('$uid.jpg');
      final png = storage.getPublicUrl('$uid.png');
      // We can't probe existence without a request; pick jpg first
      url = jpg;
      // If you know your uploads are png, swap the order.

      setState(() {
        _userRow = row ?? {};
        _avatarUrl = url;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load profile: $e';
        _loading = false;
      });
    }
  }

  Future<void> _openEdit() async {
    if (_userRow == null) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TenantEditProfile(
          // Pass current values (fallbacks to keep UI populated)
          name:
              (_userRow!['full_name'] ??
                      '${_userRow!['first_name'] ?? ''} ${_userRow!['last_name'] ?? ''}')
                  .toString()
                  .trim(),
          email: (_userRow!['email'] ?? '').toString(),
          phone: (_userRow!['phone'] ?? '').toString(),
          address: (_userRow!['address'] ?? '').toString(),
          currentAvatarUrl: _avatarUrl,
        ),
      ),
    );

    // If edit screen says something changed, reload
    if (saved == true && mounted) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = _userRow ?? {};
    final displayName =
        (row['full_name'] ??
                '${row['first_name'] ?? ''} ${row['last_name'] ?? ''}')
            .toString()
            .trim();
    final email = (row['email'] ?? '').toString();

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
          'TENANT INFORMATION',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 25,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : (_error != null
                ? Center(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 50,
                                      backgroundColor: Colors.white,
                                      child: ClipOval(
                                        child: _avatarUrl == null
                                            ? Image.asset(
                                                'assets/images/josil.png',
                                                fit: BoxFit.cover,
                                                width: 95,
                                                height: 95,
                                              )
                                            : Image.network(
                                                _avatarUrl!,
                                                fit: BoxFit.cover,
                                                width: 95,
                                                height: 95,
                                                errorBuilder: (_, __, ___) =>
                                                    Image.asset(
                                                      'assets/images/josil.png',
                                                      fit: BoxFit.cover,
                                                      width: 95,
                                                      height: 95,
                                                    ),
                                              ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: InkWell(
                                        onTap: _openEdit,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.blueAccent,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                          padding: const EdgeInsets.all(5),
                                          child: const Icon(
                                            Icons.edit,
                                            size: 18,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName.isEmpty
                                          ? 'Your name'
                                          : displayName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      email.isEmpty ? '—' : email,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 220,
                                          height: 40,
                                          child: ElevatedButton(
                                            onPressed: _openEdit,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFF5A7689,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: const Text(
                                              'Edit Profile',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 20,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 50),

                          // DB-driven fields
                          Row(
                            children: [
                              Expanded(
                                child: buildInfoField(
                                  'Full name',
                                  displayName.isEmpty ? '—' : displayName,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: buildInfoField(
                                  'Phone',
                                  (row['phone'] ?? '—').toString(),
                                ),
                              ),
                            ],
                          ),
                          buildInfoField(
                            'Address',
                            (row['address'] ?? '—').toString(),
                          ),

                          // Static demo fields (you can wire these later)
                          buildInfoField('Parent Contacts', '—'),
                          Row(
                            children: [
                              Expanded(child: buildInfoField('Move-In', '—')),
                              const SizedBox(width: 12),
                              Expanded(
                                child: buildInfoField('Monthly Rent', '—'),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(child: buildInfoField('Room No.', '—')),
                              const SizedBox(width: 12),
                              Expanded(child: buildInfoField('Floor No.', '—')),
                            ],
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  )),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black54,
        currentIndex: _selectedNavIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == _selectedNavIndex) return;
          setState(() => _selectedNavIndex = index);

          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const TenantApartment()),
            );
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const TenantListChat()),
            );
          } else if (index == 2) {
            // already here
          } else if (index == 3) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const TenantSettings()),
            );
          } else if (index == 4) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MyRoom()),
            );
          } else if (index == 5) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginT()),
              (route) => false,
            );
          }
        },
        items: [
          _buildNavItem(Icons.apartment, "Apartment", 0),
          _buildNavItem(Icons.message, "Message", 1),
          _buildNavItem(Icons.person, "Profile", 2),
          _buildNavItem(Icons.settings, "Settings", 3),
          _buildNavItem(Icons.door_front_door, "My Room", 4),
          _buildNavItem(Icons.logout, "Logout", 5),
        ],
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(
    IconData icon,
    String label,
    int index,
  ) {
    final isSelected = _selectedNavIndex == index;
    return BottomNavigationBarItem(
      icon: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 3,
            width: isSelected ? 20 : 0,
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: isSelected ? Colors.black : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Icon(icon),
        ],
      ),
      label: label,
    );
  }

  Widget buildInfoField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 48,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                value.isEmpty ? '—' : value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
