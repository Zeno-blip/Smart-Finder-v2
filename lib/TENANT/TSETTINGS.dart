// TENANT/TSETTINGS.dart
import 'package:flutter/material.dart';
import 'package:smart_finder/TENANT/TERMSCONDITION.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'TCHAT2.dart';
import 'TPROFILE.dart';
import 'TERMSCONDITION.dart';
import 'TAPARTMENT.dart';
import 'TLOGIN.dart';
import 'TMYROOM.dart';
import 'TPROFILEEDIT.dart';
import 'TRESETPASS.dart';

class TenantSettings extends StatefulWidget {
  const TenantSettings({super.key});

  @override
  State<TenantSettings> createState() => _TenantSettingsState();
}

class _TenantSettingsState extends State<TenantSettings> {
  bool _notificationEnabled = true;
  int _selectedNavIndex = 3;

  final _sb = Supabase.instance.client;
  Map<String, dynamic>? _userRow;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return;
    final row = await _sb
        .from('users')
        .select('id, full_name, avatar_url')
        .eq('id', uid)
        .maybeSingle();
    String? url = (row?['avatar_url'] as String?)?.trim();
    if (url == null || url.isEmpty) {
      url = _sb.storage.from('avatars').getPublicUrl('$uid.jpg');
    }
    setState(() {
      _userRow = row ?? {};
      _avatarUrl = url;
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = (_userRow?['full_name'] as String?) ?? 'Profile';

    return Scaffold(
      backgroundColor: const Color(0xFF0B3A5D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B3A5D),
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          'SETTINGS',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 25,
            color: Colors.white,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: ListView(
          children: [
            _tile(
              leading: CircleAvatar(
                backgroundColor: Colors.white,
                child: ClipOval(
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                        ? Image.network(
                            _avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) {
                              return const Icon(
                                Icons.person,
                                color: Colors.grey,
                              );
                            },
                          )
                        : const Icon(Icons.person, color: Colors.grey),
                  ),
                ),
              ),
              title: name,
              subtitle: 'Profile',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TenantProfile()),
              ),
              showArrow: true,
            ),
            const SizedBox(height: 12),
            _tile(
              leading: const Icon(Icons.notifications, color: Colors.black54),
              title: 'Notification',
              subtitle: 'Sound, Snooze',
              trailing: Switch(
                value: _notificationEnabled,
                onChanged: (val) => setState(() => _notificationEnabled = val),
              ),
            ),
            const SizedBox(height: 12),
            _tile(
              leading: const Icon(Icons.security, color: Colors.black54),
              title: 'Security',
              subtitle: 'Change password',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TenantResetPassword()),
              ),
              showArrow: true,
            ),
            const SizedBox(height: 12),
            _tile(
              leading: const Icon(Icons.phone, color: Colors.black54),
              title: 'Contact Us',
              subtitle: 'Reach our team',
              onTap: () {},
              showArrow: true,
            ),
            const SizedBox(height: 12),
            _tile(
              leading: const Icon(Icons.info, color: Colors.black54),
              title: 'About',
              subtitle: 'Terms and Condition',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TermsAndCondition()),
              ),
              showArrow: true,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
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
              MaterialPageRoute(builder: (_) => const TenantApartment()),
            );
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const TenantListChat()),
            );
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const TenantProfile()),
            );
          } else if (index == 3) {
            // stay
          } else if (index == 4) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MyRoom()),
            );
          } else if (index == 5) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginT()),
              (r) => false,
            );
          }
        },
        items: [
          _nav(Icons.apartment, "Apartment", 0),
          _nav(Icons.message, "Message", 1),
          _nav(Icons.person, "Profile", 2),
          _nav(Icons.settings, "Settings", 3),
          _nav(Icons.door_front_door, "My Room", 4),
          _nav(Icons.logout, "Logout", 5),
        ],
      ),
    );
  }

  BottomNavigationBarItem _nav(IconData icon, String label, int index) {
    final isSel = _selectedNavIndex == index;
    return BottomNavigationBarItem(
      icon: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 3,
            width: isSel ? 20 : 0,
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: isSel ? Colors.black : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Icon(icon),
        ],
      ),
      label: label,
    );
  }

  Widget _tile({
    required Widget leading,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    bool showArrow = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: leading,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing:
            trailing ??
            (showArrow ? const Icon(Icons.arrow_forward_ios, size: 16) : null),
        onTap: onTap,
      ),
    );
  }
}
