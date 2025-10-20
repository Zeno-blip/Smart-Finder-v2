import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_finder/services/chat_service.dart';

import 'CHAT.dart' show ChatScreenTenant; // <-- your tenant chat screen
import 'TROOMINFO.dart';
import 'TAPARTMENT.dart';

class TenantGmap extends StatefulWidget {
  final String roomId;
  final String? titleHint;
  final String? addressHint;
  final double? monthlyHint;

  const TenantGmap({
    super.key,
    required this.roomId,
    this.titleHint,
    this.addressHint,
    this.monthlyHint,
  });

  @override
  State<TenantGmap> createState() => _TenantGmapState();
}

class _TenantGmapState extends State<TenantGmap> {
  final List<String> _roomImages = const [
    'assets/images/roompano.png',
    'assets/images/roompano2.png',
    'assets/images/roompano3.png',
  ];

  int _hoveredIndex = -1;
  int _selectedIndex = 0;
  bool _startingChat = false;

  Future<void> _messageLandlord() async {
    if (_startingChat) return;
    setState(() => _startingChat = true);

    try {
      final sb = Supabase.instance.client;
      final me = sb.auth.currentUser?.id;

      if (me == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please log in first.')));
        return;
      }

      final chat = ChatService(sb);
      final result = await chat.startChatFromRoom(
        roomId: widget.roomId,
        tenantId: me,
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreenTenant(
            conversationId: result['conversationId']!,
            peerName: result['landlordName'] ?? 'Landlord',
            peerImageAsset: 'assets/images/landlord.png',
            landlordPhone: result['landlordPhone'], // <-- REMOVE this line (not in constructor)
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not start chat: $e')));
      }
    } finally {
      if (mounted) setState(() => _startingChat = false);
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
            // Map banner
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  SizedBox.expand(
                    child: Image.asset(
                      'assets/images/map.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 20,
                    left: 12,
                    child: GestureDetector(
                      onTap: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TenantApartment(),
                        ),
                      ),
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
                          onTap: () => setState(() => _selectedIndex = index),
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
                  Text(
                    widget.titleHint ?? "Smart-Finder Apartment",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.addressHint ?? "Address not provided",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
                          onPressed: _startingChat ? null : _messageLandlord,
                          child: Text(
                            _startingChat ? 'Starting…' : 'Message Landlord',
                          ),
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
                                builder: (_) => TenantRoomInfo(
                                  roomId: widget.roomId,
                                  titleHint: widget.titleHint,
                                  addressHint: widget.addressHint,
                                  monthlyHint: widget.monthlyHint,
                                ),
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
