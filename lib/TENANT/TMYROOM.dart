import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'TAPARTMENT.dart';
import 'TCHAT2.dart';
import 'TPROFILE.dart';
import 'TSETTINGS.dart';
import 'TLOGIN.dart';

class MyRoom extends StatefulWidget {
  const MyRoom({super.key});

  @override
  State<MyRoom> createState() => _MyRoomState();
}

class _MyRoomState extends State<MyRoom> {
  int _selectedIndex = 4; // For bottom navigation
  int _currentPage = 0; // For carousel indicator
  final PageController _pageController = PageController();
  Timer? _timer;

  final List<String> images = [
    "assets/images/roompano.png",
    "assets/images/roompano2.png",
    "assets/images/roompano3.png",
  ];

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
      if (_pageController.hasClients) {
        int nextPage = (_currentPage + 1) % images.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE6E6E6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF003049),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          "MY ROOM",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 25,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _imageCarousel(context),
            const SizedBox(height: 20),
            _box1(),
            _box2(),
            _box3(),
            _box4(),
            _box5(),
            const SizedBox(height: 20),
            _roomDetailsBox(),
          ],
        ),
      ),

      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black54,
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == _selectedIndex) return; // Prevent reload
          setState(() {
            _selectedIndex = index;
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
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const TenantSettings()),
            );
          } else if (index == 4) {
            // Already here
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

  // Custom Nav Item with Indicator
  BottomNavigationBarItem _buildNavItem(
    IconData icon,
    String label,
    int index,
  ) {
    bool isSelected = _selectedIndex == index;
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

  /// BIG IMAGE CAROUSEL
  Widget _imageCarousel(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 300,
          width: double.infinity,
          child: GestureDetector(
            onPanDown: (_) => _timer?.cancel(),
            onPanEnd: (_) => _startAutoScroll(),
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index; // Only update carousel indicator
                });
              },
              itemCount: images.length,
              itemBuilder: (context, index) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    images[index],
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(images.length, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 10,
              width: _currentPage == index ? 24 : 10,
              decoration: BoxDecoration(
                color: _currentPage == index
                    ? const Color(0xFF003049)
                    : Colors.grey,
                borderRadius: BorderRadius.circular(12),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _box1() {
    return _infoTile(
      Icons.apartment,
      "3rd Floor",
      Icons.price_change,
      "₱3,700",
      iconSize: 28.0,
    );
  }

  Widget _box2() {
    return _infoTile(
      FontAwesomeIcons.doorClosed,
      "L204",
      Icons.attach_money,
      "₱3,700",
      iconSize: 28.0,
    );
  }

  Widget _box3() {
    return _infoTile(
      Icons.location_on,
      "Davao City, Matina Crossing \nGravahan",
      Icons.flash_on,
      "16/watts",
      iconSize: 28.0,
    );
  }

  Widget _box4() {
    return _infoTile(
      Icons.chair,
      "Single Bed, Table, Chair, WiFi",
      Icons.person,
      "N/A",
      iconSize: 28.0,
    );
  }

  Widget _box5() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: _infoBox(Icons.apartment, "SmartFinder Apartment", 28.0),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Opacity(
              opacity: 0,
              child: _infoBox(Icons.ac_unit, "", 28.0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roomDetailsBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Room Details",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            "Cozy 3rd floor room at SmartFinder Apartment in Matina, Davao City. Comes with a single bed, table, chair, and Wi-Fi. All for ₱3,700/month. Ideal for students and professionals!",
            style: TextStyle(fontSize: 14),
          ),
          SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              Chip(
                label: Text("#NearUM", style: TextStyle(color: Colors.blue)),
              ),
              Chip(
                label: Text("#SingleBed", style: TextStyle(color: Colors.blue)),
              ),
              Chip(
                label: Text("#OwnCR", style: TextStyle(color: Colors.blue)),
              ),
              Chip(
                label: Text("#WithWiFi", style: TextStyle(color: Colors.blue)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoTile(
    IconData leftIcon,
    String leftText,
    IconData? rightIcon,
    String rightText, {
    double iconSize = 24.0,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: _infoBox(leftIcon, leftText, iconSize)),
          const SizedBox(width: 10),
          Expanded(
            child: rightIcon != null && rightText.isNotEmpty
                ? _infoBox(rightIcon, rightText, iconSize)
                : Opacity(
                    opacity: 0,
                    child: _infoBox(Icons.ac_unit, "", iconSize),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _infoBox(IconData icon, String text, double iconSize) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.black54, size: iconSize),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
