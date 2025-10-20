import 'package:flutter/material.dart';
import 'package:smart_finder/LANDLORD/CHAT2.dart';
import 'package:smart_finder/LANDLORD/DASHBOARD.dart';
import 'package:smart_finder/LANDLORD/EDITPROFILE.dart';
import 'package:smart_finder/LANDLORD/PROFILE.dart';
import 'package:smart_finder/LANDLORD/RESETPASS.dart';
import 'package:smart_finder/LANDLORD/TIMELINE.dart';
import 'package:smart_finder/LANDLORD/APARTMENT.dart';
import 'package:smart_finder/LANDLORD/TENANTS.dart';
import 'package:smart_finder/LANDLORD/TOTALROOM.dart';
import 'package:smart_finder/LANDLORD/LOGIN.dart';
import 'package:smart_finder/TERMSCONDITION.dart';

class LandlordSettings extends StatefulWidget {
  const LandlordSettings({super.key});

  @override
  State<LandlordSettings> createState() => _LandlordSettingsState();
}

class _LandlordSettingsState extends State<LandlordSettings> {
  bool _notificationEnabled = true;
  int _selectedIndex = 6;

  void _onNavTap(int index) {
    if (_selectedIndex == index) return;

    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Dashboard()),
      );
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Timeline()),
      );
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Apartment()),
      );
    } else if (index == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Tenants()),
      );
    } else if (index == 4) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ListChat()),
      );
    } else if (index == 5) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const TotalRoom()),
      );
    } else if (index == 6) {
      // Already on Settings
    } else if (index == 7) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const Login()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B3A5D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B3A5D),
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
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
            _buildTile(
              leading: const CircleAvatar(
                backgroundImage: AssetImage('assets/images/landlord.png'),
              ),
              title: 'John Doe',
              subtitle: 'Profile',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const Adminprofile()),
                );
              },
              showTrailingArrow: true,
            ),
            const SizedBox(height: 12),
            _buildTile(
              leading: const Icon(Icons.person, color: Colors.black54),
              title: 'Account',
              subtitle: 'Edit Profile',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EditProfile()),
                );
              },
              showTrailingArrow: true,
            ),
            const SizedBox(height: 12),
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
            _buildTile(
              leading: const Icon(Icons.security, color: Colors.black54),
              title: 'Security',
              subtitle: 'Change Password',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ResetPassword(),
                  ),
                );
              },
              showTrailingArrow: true,
            ),
            const SizedBox(height: 12),
            _buildTile(
              leading: const Icon(Icons.phone, color: Colors.black54),
              title: 'Contact Us',
              subtitle: 'Contact us',
              onTap: () {},
              showTrailingArrow: true,
            ),
            const SizedBox(height: 12),
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
      bottomNavigationBar: Container(
        color: Colors.white,
        height: 60,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(8, (index) {
              IconData icon;
              String label;
              switch (index) {
                case 0:
                  icon = Icons.dashboard;
                  label = "Dashboard";
                  break;
                case 1:
                  icon = Icons.view_timeline_outlined;
                  label = "Timeline";
                  break;
                case 2:
                  icon = Icons.apartment;
                  label = "Apartment";
                  break;
                case 3:
                  icon = Icons.group;
                  label = "Tenants";
                  break;
                case 4:
                  icon = Icons.message;
                  label = "Message";
                  break;
                case 5:
                  icon = Icons.door_front_door;
                  label = "Rooms";
                  break;
                case 6:
                  icon = Icons.settings;
                  label = "Settings";
                  break;
                case 7:
                  icon = Icons.logout;
                  label = "Logout";
                  break;
                default:
                  icon = Icons.circle;
                  label = "";
              }

              bool isSelected = _selectedIndex == index;

              return GestureDetector(
                onTap: () => _onNavTap(index),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
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
                      Icon(
                        icon,
                        color: isSelected ? Colors.black : Colors.black54,
                      ),
                      Text(
                        label,
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
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
        trailing:
            trailing ??
            (showTrailingArrow
                ? const Icon(Icons.arrow_forward_ios, size: 16)
                : null),
        onTap: onTap,
      ),
    );
  }
}
