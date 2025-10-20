import 'package:flutter/material.dart';
import 'package:smart_finder/LANDLORD/CHAT2.dart';
import 'package:smart_finder/LANDLORD/ROOMAVAIL.dart'; // For vacant rooms
import 'package:smart_finder/LANDLORD/ROOMNOTAVAIL.dart'; // For occupied rooms

import 'package:smart_finder/LANDLORD/DASHBOARD.dart';
import 'package:smart_finder/LANDLORD/APARTMENT.dart';

import 'package:smart_finder/LANDLORD/LSETTINGS.dart';
import 'package:smart_finder/LANDLORD/LOGIN.dart';
import 'package:smart_finder/LANDLORD/TIMELINE.dart';
import 'package:smart_finder/LANDLORD/TENANTS.dart';

class TotalRoom extends StatefulWidget {
  const TotalRoom({super.key});

  @override
  State<TotalRoom> createState() => _TotalRoomState();
}

class _TotalRoomState extends State<TotalRoom> {
  int _selectedIndex = 5; // ✅ Rooms tab selected by default

  // Example room data
  final List<Map<String, dynamic>> rooms = [
    {"room": "L206", "status": "VACANT"},
    {"room": "L207", "status": "OCCUPIED", "date": "December 25, 2025"},
    {"room": "L208", "status": "VACANT"},
    {"room": "L209", "status": "OCCUPIED", "date": "December 25, 2025"},
    {"room": "L210", "status": "VACANT"},
    {"room": "L211", "status": "VACANT"},
    {"room": "L212", "status": "OCCUPIED", "date": "January 5, 2026"},
    {"room": "L213", "status": "VACANT"},
    {"room": "L214", "status": "OCCUPIED", "date": "January 15, 2026"},
  ];

  int currentPage = 0;
  final int cardsPerPage = 8; // 👈 8 rooms per page
  final ScrollController _scrollController = ScrollController();

  // ✅ Navigation handler (copied from ListChat)
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
      // Current page → Rooms
    } else if (index == 6) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LandlordSettings()),
      );
    } else if (index == 7) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const Login()),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int totalPages = (rooms.length / cardsPerPage).ceil();
    int startIndex = currentPage * cardsPerPage;
    int endIndex = (startIndex + cardsPerPage).clamp(0, rooms.length);

    return Scaffold(
      backgroundColor: const Color(0xFF003B5C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF003B5C),
        elevation: 0,
        automaticallyImplyLeading: false, // ✅ remove back button
        centerTitle: true,
        title: const Text(
          "TOTAL ROOMS",
          style: TextStyle(
            color: Colors.white,
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        controller: _scrollController,
        children: [
          // 👇 Grid of cards
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(10.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 20,
            ),
            itemCount: endIndex - startIndex,
            itemBuilder: (context, index) {
              final room = rooms[startIndex + index];
              final isVacant = room['status'] == "VACANT";
              final hasDate = room.containsKey("date");

              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF7B8D93),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(2, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          // Status dot
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: isVacant
                                    ? const Color.fromARGB(255, 62, 255, 69)
                                    : Colors.red,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 3,
                                    offset: const Offset(1, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Date occupied
                          if (hasDate)
                            Positioned(
                              top: 8,
                              left: 0,
                              right: 0,
                              child: Text(
                                "Occupied: ${room['date']}",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),

                          // Main icon + text
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.home_rounded,
                                  size: 70,
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  room['room'],
                                  style: const TextStyle(
                                    fontSize: 26,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isVacant ? "VACANT" : "OCCUPIED",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                    color: isVacant
                                        ? Colors.greenAccent
                                        : Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // More info bar
                    Container(
                      height: 38,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: InkWell(
                        onTap: () {
                          if (isVacant) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RoomAvailable(roomData: room),
                              ),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    RoomNotAvailable(roomData: room),
                              ),
                            );
                          }
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.info_outline,
                              size: 18,
                              color: Colors.blue,
                            ),
                            SizedBox(width: 6),
                            Text(
                              "More Info",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // 👇 Pagination will now scroll with the grid and appear after last card
          _buildPagination(totalPages),
        ],
      ),

      // ✅ Replaced BottomNavigationBar with custom scrollable nav from ListChat
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

  Widget _buildPagination(int totalPages) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          IconButton(
            onPressed: currentPage > 0
                ? () {
                    setState(() {
                      currentPage--;
                      _scrollController.jumpTo(0);
                    });
                  }
                : null,
            icon: const Icon(Icons.chevron_left),
            iconSize: 30,
            color: Colors.white,
          ),
          ...List.generate(totalPages, (index) {
            bool isSelected = index == currentPage;
            return GestureDetector(
              onTap: () {
                setState(() {
                  currentPage = index;
                  _scrollController.jumpTo(0);
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isSelected
                      ? const Color.fromARGB(255, 214, 214, 214)
                      : Colors.white10,
                  border: isSelected
                      ? Border.all(color: Colors.white, width: 2)
                      : null,
                  boxShadow: isSelected
                      ? [
                          const BoxShadow(
                            color: Colors.black26,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  "${index + 1}",
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }),
          IconButton(
            onPressed: currentPage < totalPages - 1
                ? () {
                    setState(() {
                      currentPage++;
                      _scrollController.jumpTo(0);
                    });
                  }
                : null,
            icon: const Icon(Icons.chevron_right),
            iconSize: 30,
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}
