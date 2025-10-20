import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'APARTMENT.dart';
import 'Roominfo.dart';
import 'package:smart_finder/TOUR.dart';

// 👇 landlord chat screen
import 'package:smart_finder/LANDLORD/chatL.dart' show LandlordChatScreen;

class Gmap extends StatefulWidget {
  const Gmap({super.key, required this.roomId});
  final String roomId;

  @override
  State<Gmap> createState() => _GmapState();
}

class _GmapState extends State<Gmap> {
  final _sb = Supabase.instance.client;

  final List<String> _roomImages = const [
    'assets/images/roompano.png',
    'assets/images/roompano2.png',
    'assets/images/roompano3.png',
  ];

  int _hoveredIndex = -1;
  int _selectedIndex = 0;

  Future<void> _openChat() async {
    final me = _sb.auth.currentUser?.id;
    if (me == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please log in first.')));
      return;
    }

    try {
      // Pick the most recent conversation for this landlord.
      // You can change this logic if you want to target a specific tenant.
      final conv = await _sb
          .from('conversations')
          .select('id, tenant_id')
          .eq('landlord_id', me)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (conv == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No conversations yet. A tenant must message you first.',
            ),
          ),
        );
        return;
      }

      final conversationId = conv['id'] as String;
      final tenantId = conv['tenant_id'] as String?;

      // Try to fetch a display name for the peer
      String peerName = 'Tenant';
      if (tenantId != null) {
        final profile = await _sb
            .from('tenant_profile')
            .select('full_name')
            .eq('user_id', tenantId)
            .maybeSingle();
        final users = await _sb
            .from('users')
            .select('full_name')
            .eq('id', tenantId)
            .maybeSingle();
        final fromProfile = (profile?['full_name'] ?? '').toString().trim();
        final fromUsers = (users?['full_name'] ?? '').toString().trim();
        peerName = (fromProfile.isNotEmpty
            ? fromProfile
            : fromUsers.isNotEmpty
            ? fromUsers
            : 'Tenant');
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LandlordChatScreen(
            conversationId: conversationId,
            peerName: peerName,
            // use any placeholder/avatar you have for tenants
            peerImageAsset: 'assets/images/mykel.png',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open chat: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    const double imageHeight = 150;

    return Scaffold(
      backgroundColor: const Color(0xFF04395E),
      body: SafeArea(
        child: Column(
          children: [
            // Map + back
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    child: SizedBox.expand(
                      child: Image.asset(
                        'assets/images/map.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 20,
                    left: 12,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const Apartment()),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.black54, width: 1.5),
                        ),
                        padding: const EdgeInsets.all(6),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Thumbnails
            Container(
              color: const Color(0xFF5A7689),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                children: List.generate(_roomImages.length, (index) {
                  final img = _roomImages[index];
                  final isHovered = index == _hoveredIndex;
                  final isSelected = index == _selectedIndex;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0),
                      child: MouseRegion(
                        onEnter: (_) => setState(() => _hoveredIndex = index),
                        onExit: (_) => setState(() => _hoveredIndex = -1),
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedIndex = index);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => Tour(
                                  initialIndex: index,
                                  roomId: widget.roomId,
                                  titleHint: "Lopers Apartment",
                                  addressHint: "Brgy. Gravahan Alvaran St.",
                                ),
                              ),
                            );
                          },
                          child: Container(
                            height: imageHeight,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: (isHovered || isSelected)
                                    ? const Color.fromARGB(255, 27, 70, 120)
                                    : Colors.white24,
                                width: 3,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: Image.asset(img, fit: BoxFit.cover),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Info + actions
            Container(
              color: const Color(0xFF5A7689),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Lopers Apartment",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.white70, size: 16),
                      SizedBox(width: 4),
                      Text(
                        "Brgy. Gravahan Alvaran St.",
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      ...List.generate(
                        4,
                        (_) => const Icon(
                          Icons.star,
                          color: Colors.amber,
                          size: 18,
                        ),
                      ),
                      const Icon(
                        Icons.star_border,
                        color: Colors.amber,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "(4.8) ",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        "Previews",
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Room Details",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Cozy 3rd floor room at SmartFinder Apartment in Matina, Davao City. "
                    "Comes with a single bed, table, chair, and Wi-Fi.",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SizedBox(
                        width: 180,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF003049),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed:
                              _openChat, // 👈 open most recent conversation
                          child: const Text("Message Tenant"),
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF003049),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => Roominfo(roomId: widget.roomId),
                              ),
                            );
                          },
                          child: const Text("More Details"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
