// lib/LANDLORD/totalroom.dart
import 'package:flutter/material.dart';
import 'package:smart_finder/LANDLORD/CHAT2.dart';
import 'package:smart_finder/LANDLORD/DASHBOARD.dart';
import 'package:smart_finder/LANDLORD/APARTMENT.dart';
import 'package:smart_finder/LANDLORD/LSETTINGS.dart';
import 'package:smart_finder/LANDLORD/LOGIN.dart';
import 'package:smart_finder/LANDLORD/TIMELINE.dart';
import 'package:smart_finder/LANDLORD/TENANTS.dart';

// services
import '../services/room_service.dart';

// imports for both room states
import 'package:smart_finder/LANDLORD/roomavail.dart' as avail;
import 'package:smart_finder/LANDLORD/roomnotavail.dart' as notavail;

class TotalRoom extends StatefulWidget {
  const TotalRoom({super.key});

  @override
  State<TotalRoom> createState() => _TotalRoomState();
}

class _TotalRoomState extends State<TotalRoom> {
  final RoomService _service = RoomService();
  late final Stream<List<Map<String, dynamic>>> _stream;
  int _selectedIndex = 5; // Rooms tab

  @override
  void initState() {
    super.initState();
    _stream = _service.streamMyRooms();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  // ---------- NAV BAR ----------
  void _onNavTap(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);

    Widget? destination;
    switch (index) {
      case 0:
        destination = const Dashboard();
        break;
      case 1:
        destination = const Timeline();
        break;
      case 2:
        destination = const Apartment();
        break;
      case 3:
        destination = const Tenants();
        break;
      case 4:
        destination = const ListChat();
        break;
      case 6:
        destination = const LandlordSettings();
        break;
      case 7:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const Login()),
          (r) => false,
        );
        return;
    }

    if (destination != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => destination!),
      );
    }
  }

  // ---------- UTILITIES ----------
  String _availability(Map<String, dynamic> r) {
    final a = (r['availability_status'] ?? '').toString().toLowerCase();
    if (a == 'available' || a == 'not_available') return a;
    final s = (r['status'] ?? '').toString().toLowerCase();
    return s == 'available' ? 'available' : 'not_available';
  }

  void _openRoom(Map<String, dynamic> r) {
    final bool isAvail = _availability(r) == 'available';

    // Force a Map<String, dynamic> (in case r has dynamic keys/values)
    final Map<String, dynamic> room = Map<String, dynamic>.from(r);

    // Make the ternary produce a Widget
    final Widget page = isAvail
        ? avail.RoomAvailable(roomData: room)
        : notavail.RoomNotAvailable(roomData: room);

    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }


  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE6E6E6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF003B5C),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        title: const Text(
          'MY ROOMS',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _stream,
        initialData: const [],
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load rooms:\n${snap.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final rooms = snap.data ?? const [];
          if (rooms.isEmpty) return const _EmptyListState();

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rooms.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final r = rooms[i];
              final title = (r['apartment_name'] ?? 'SmartFinder Apartment')
                  .toString();
              final location = (r['location'] ?? '').toString();
              final monthly = r['monthly_payment'];
              final isAvail = _availability(r) == 'available';

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black, width: 1),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      // ---------- TITLE + STATUS ----------
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isAvail
                                  ? Colors.green.shade100
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Text(
                              isAvail ? 'available' : 'not_available',
                              style: TextStyle(
                                color: isAvail
                                    ? Colors.green.shade800
                                    : Colors.grey.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // ---------- LOCATION + MONTHLY ----------
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 18,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              location,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (monthly != null)
                            Row(
                              children: [
                                const Icon(
                                  Icons.price_change,
                                  size: 18,
                                  color: Colors.black54,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '₱$monthly',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // ---------- BUTTON ----------
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Colors.black,
                                  width: 1,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              onPressed: () => _openRoom(r),
                              child: const Text(
                                'More Info',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),

      // ---------- BOTTOM NAV ----------
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
                  label = 'Dashboard';
                  break;
                case 1:
                  icon = Icons.view_timeline_outlined;
                  label = 'Timeline';
                  break;
                case 2:
                  icon = Icons.apartment;
                  label = 'Apartment';
                  break;
                case 3:
                  icon = Icons.group;
                  label = 'Tenants';
                  break;
                case 4:
                  icon = Icons.message;
                  label = 'Message';
                  break;
                case 5:
                  icon = Icons.door_front_door;
                  label = 'Rooms';
                  break;
                case 6:
                  icon = Icons.settings;
                  label = 'Settings';
                  break;
                case 7:
                  icon = Icons.logout;
                  label = 'Logout';
                  break;
                default:
                  icon = Icons.circle;
                  label = '';
              }

              final isSelected = _selectedIndex == index;
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
}

// ---------- EMPTY STATE ----------
class _EmptyListState extends StatelessWidget {
  const _EmptyListState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'No rooms yet.\nCreate a room in AddRoom to see it here.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}
