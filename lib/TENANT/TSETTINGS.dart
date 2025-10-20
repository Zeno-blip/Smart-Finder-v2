import 'package:flutter/material.dart';
import 'package:smart_finder/TENANT/TCHAT2.dart';
import 'package:smart_finder/TENANT/TPROFILE.dart';
import 'package:smart_finder/TERMSCONDITION.dart';
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
  int _selectedNavIndex = 3; // Default to Settings tab

  @override
  Widget build(BuildContext context) {
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
            // Profile Tile
            _buildTile(
              leading: const CircleAvatar(
                backgroundImage: AssetImage('assets/images/josil.png'),
              ),
              title: 'Myke Batawski',
              subtitle: 'Profile',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TenantProfile(),
                  ),
                );
              },
              showTrailingArrow: true,
            ),
            const SizedBox(height: 12),

            
            // Notification Tile
            _buildTile(
              leading: const Icon(Icons.notifications, color: Colors.black54),
              title: 'Notification',
              subtitle: 'Sound, Snooze',
              trailing: Switch(
                value: _notificationEnabled,
                onChanged: (val) {
                  setState(() {
                    _notificationEnabled = val;
                  });
                },
              ),
            ),
            const SizedBox(height: 12),

            // Security Tile
            _buildTile(
              leading: const Icon(Icons.security, color: Colors.black54),
              title: 'Security',
              subtitle: 'Change password',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TenantResetPassword(),
                  ),
                );
              },
              showTrailingArrow: true,
            ),
            const SizedBox(height: 12),

            // Contact Us Tile
            _buildTile(
              leading: const Icon(Icons.phone, color: Colors.black54),
              title: 'Contact Us',
              subtitle: 'Reach our team',
              onTap: () {},
              showTrailingArrow: true,
            ),
            const SizedBox(height: 12),

            // About / Terms Tile
            _buildTile(
              leading: const Icon(Icons.info, color: Colors.black54),
              title: 'About',
              subtitle: 'Terms and Condition',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TermsAndCondition(),
                  ),
                );
              },
              showTrailingArrow: true,
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
          setState(() {
            _selectedNavIndex = index;
          });

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
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const TenantProfile()),
            );
          } else if (index == 3) {
            // Already here
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
    bool isSelected = _selectedNavIndex == index;
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

  Widget _buildTile({
    required Widget leading,
    required String title,
    required String subtitle,
    void Function()? onTap,
    Widget? trailing,
    bool showTrailingArrow = false,
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
        trailing: trailing ??
            (showTrailingArrow
                ? const Icon(Icons.arrow_forward_ios, size: 16)
                : null),
        onTap: onTap,
      ),
    );
  }
}
