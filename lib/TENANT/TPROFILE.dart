import 'dart:io';
import 'package:flutter/material.dart';
import 'package:smart_finder/TENANT/TCHAT2.dart';

import 'TAPARTMENT.dart';
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
  int _selectedNavIndex = 2; // Default to Profile tab

  // ------- Local profile state (initial sample values) -------
  String? _avatarPath; // file path from editor (if user picked)
  String _name = 'Mykel Josh Nombrads';
  String _email = '@mykeljoshnombrads.gmail.com';
  String _birthday = 'May 11, 2003';
  String _gender = 'Male';
  String _address = 'Davao City, Brgy Maa, Grava...';
  String _phone = '09612783021';
  String _guardianPhone = '09612783021';

  // Non-editable (still shown)
  String _moveIn = '2025-08-17';
  String _monthlyRent = '₱3,750';
  String _roomNo = 'L204';
  String _floorNo = '3RD Floor';

  Future<void> _openEdit() async {
    // Push the editor with current values; wait for result
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => TenantEditProfile(
          name: _name,
          email: _email,
          birthday: _birthday,
          gender: _gender,
          address: _address,
          contactNumber: _phone,
          guardianContact: _guardianPhone,
          moveIn: _moveIn,
          monthlyRent: _monthlyRent,
          roomNo: _roomNo,
          floorNo: _floorNo,
          avatarPath: _avatarPath,
        ),
      ),
    );

    if (!mounted || result == null) return;

    // Update local state with any returned values
    setState(() {
      _name = result['name'] ?? _name;
      _email = result['email'] ?? _email;
      _birthday = result['birthday'] ?? _birthday;
      _gender = result['gender'] ?? _gender;
      _address = result['address'] ?? _address;
      _phone = result['contactNumber'] ?? _phone;
      _guardianPhone = result['guardianContact'] ?? _guardianPhone;

      _moveIn = result['moveIn'] ?? _moveIn;
      _monthlyRent = result['monthlyRent'] ?? _monthlyRent;
      _roomNo = result['roomNo'] ?? _roomNo;
      _floorNo = result['floorNo'] ?? _floorNo;

      _avatarPath = result['avatarPath'] ?? _avatarPath;
    });
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _avatarPath != null && _avatarPath!.isNotEmpty
        ? ClipOval(
            child: Image.file(
              File(_avatarPath!),
              fit: BoxFit.cover,
              width: 95,
              height: 95,
            ),
          )
        : ClipOval(
            child: Image.asset(
              'assets/images/josil.png',
              fit: BoxFit.cover,
              width: 95,
              height: 95,
            ),
          );

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
      ),
      body: Padding(
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
                          child: avatar,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: InkWell(
                            onTap:
                                _openEdit, // go straight to edit to change photo
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
                                Icons.camera_alt,
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
                          _name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _email,
                          style: const TextStyle(color: Colors.white70),
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
                                  backgroundColor: const Color(0xFF5A7689),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
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
                            const SizedBox(width: 10),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 50),
              Row(
                children: [
                  Expanded(child: buildInfoField('Birthday', _birthday)),
                  const SizedBox(width: 12),
                  Expanded(child: buildInfoField('Gender', _gender)),
                ],
              ),
              buildInfoField('Address', _address),
              buildInfoField('Phone Number', _phone),
              buildInfoField('Parent Contacts', _guardianPhone),
              Row(
                children: [
                  Expanded(child: buildInfoField('Move-In', _moveIn)),
                  const SizedBox(width: 12),
                  Expanded(child: buildInfoField('Monthly Rent', _monthlyRent)),
                ],
              ),
              Row(
                children: [
                  Expanded(child: buildInfoField('Room No.', _roomNo)),
                  const SizedBox(width: 12),
                  Expanded(child: buildInfoField('Floor No.', _floorNo)),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black54,
        currentIndex: _selectedNavIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == _selectedNavIndex) return; // Prevent reload
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
            // Already here
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
                value,
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
