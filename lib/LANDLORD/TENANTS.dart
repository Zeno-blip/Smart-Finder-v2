import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ Ensure we import the right class that accepts `tenantData`
import 'tenantinfo.dart' show Tenantinfo;

import 'package:smart_finder/LANDLORD/DASHBOARD.dart';
import 'package:smart_finder/LANDLORD/APARTMENT.dart';
import 'package:smart_finder/LANDLORD/TOTALROOM.dart';
import 'package:smart_finder/LANDLORD/LSETTINGS.dart';
import 'package:smart_finder/LANDLORD/CHAT2.dart';
import 'package:smart_finder/LANDLORD/LOGIN.dart';
import 'package:smart_finder/LANDLORD/TIMELINE.dart';

class Tenants extends StatefulWidget {
  const Tenants({super.key});

  @override
  State<Tenants> createState() => _TenantsState();
}

class _TenantsState extends State<Tenants> {
  final _sb = Supabase.instance.client;

  String searchQuery = '';
  int? hoveredIndex;
  int _selectedIndex = 3; // Tenants tab selected

  /// Stream all, then filter by landlord_id + status in Dart.
  Stream<List<Map<String, dynamic>>> _streamTenantsSafe() {
    final me = _sb.auth.currentUser?.id;
    if (me == null) return const Stream.empty();

    return _sb.from('room_tenants').stream(primaryKey: ['id']).map((rows) {
      final list = List<Map<String, dynamic>>.from(rows);
      return list.where((t) {
        final status = (t['status'] ?? '').toString().toLowerCase();
        final ll = (t['landlord_id'] ?? '').toString();
        return status == 'active' && ll == me;
      }).toList();
    });
  }

  void _onNavTap(int index) {
    if (_selectedIndex == index) return;

    setState(() => _selectedIndex = index);

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
      // stay
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5E5E5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A3D62),
        automaticallyImplyLeading: false,
        title: const Text(
          'TENANTS',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 25,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),

      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Search
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade400, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                onChanged: (value) => setState(() => searchQuery = value),
                decoration: InputDecoration(
                  hintText: "Search Tenant",
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  prefixIcon: const Icon(Icons.search, color: Colors.black54),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Stream list
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _streamTenantsSafe(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Text('Error: ${snap.error}'));
                  }
                  final rows = snap.data ?? const [];
                  final filtered = rows.where((t) {
                    final s = searchQuery.toLowerCase();
                    final name = (t['full_name'] ?? '')
                        .toString()
                        .toLowerCase();
                    final email = (t['email'] ?? '').toString().toLowerCase();
                    return name.contains(s) || email.contains(s);
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(child: Text('No tenants found.'));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final t = filtered[index];
                      final name = (t['full_name'] ?? 'Unknown').toString();
                      final email = (t['email'] ?? '—').toString();

                      return MouseRegion(
                        onEnter: (_) => setState(() => hoveredIndex = index),
                        onExit: (_) => setState(() => hoveredIndex = null),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          curve: Curves.easeInOut,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: hoveredIndex == index
                                ? [
                                    BoxShadow(
                                      color: const Color.fromARGB(
                                        66,
                                        255,
                                        255,
                                        255,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Card(
                            color: hoveredIndex == index
                                ? Colors.blue.shade50
                                : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: hoveredIndex == index ? 6 : 3,
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => Tenantinfo(
                                      tenantData: Map<String, dynamic>.from(t),
                                    ),
                                  ),
                                );
                              },
                              leading: CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.grey[300],
                                child: Text(
                                  _initials(name),
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(email),
                              trailing: const Icon(Icons.more_horiz),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
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

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final s = parts.first;
      return (s.length >= 2 ? s.substring(0, 2) : s).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
