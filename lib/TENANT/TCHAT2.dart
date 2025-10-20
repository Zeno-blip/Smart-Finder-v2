// TENANT/TCHAT2.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 👇 tenant in-app chat screen (new class name)
import 'package:smart_finder/TENANT/CHAT.dart' show ChatScreenTenant;

// Tenant nav pages
import 'package:smart_finder/TENANT/TAPARTMENT.dart';
import 'package:smart_finder/TENANT/TPROFILE.dart';
import 'package:smart_finder/TENANT/TSETTINGS.dart';
import 'package:smart_finder/TENANT/TMYROOM.dart';
import 'package:smart_finder/TENANT/TLOGIN.dart';

class TenantListChat extends StatefulWidget {
  const TenantListChat({super.key});

  @override
  State<TenantListChat> createState() => _TenantListChatState();
}

class _TenantListChatState extends State<TenantListChat> {
  final _sb = Supabase.instance.client;

  final List<Map<String, dynamic>> chats = [
    {
      'name': 'Mr. Landlord',
      'message': 'Room is still available.',
      'time': DateTime.now().subtract(const Duration(minutes: 3)),
      'unreadCount': 1,
      'isOnline': true,
      'image': 'assets/images/landlord.png',
    },
    {
      'name': 'Agent Paula',
      'message': 'When can you visit?',
      'time': DateTime.now().subtract(const Duration(hours: 2)),
      'unreadCount': 0,
      'isOnline': false,
      'image': 'assets/images/agent.png',
    },
    {
      'name': 'Owner Mike',
      'message': 'Thanks for your interest.',
      'time': DateTime.now().subtract(const Duration(days: 1)),
      'unreadCount': 0,
      'isOnline': true,
      'image': 'assets/images/owner.png',
    },
  ];

  String searchQuery = '';
  int _selectedIndex = 1; // Message tab default for tenant bottom nav

  void _onNavTap(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);

    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TenantApartment()),
      );
    } else if (index == 1) {
      // stay
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TenantProfile()),
      );
    } else if (index == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TenantSettings()),
      );
    } else if (index == 4) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MyRoom()),
      );
    } else if (index == 5) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginT()),
        (route) => false,
      );
    }
  }

  Future<void> _openChatForTenant({
    required String fallbackPeerName,
    required String fallbackPeerImage,
  }) async {
    final me = _sb.auth.currentUser?.id;
    if (me == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please log in first.')));
      return;
    }

    try {
      // Get the most recent conversation for this tenant
      final conv = await _sb
          .from('conversations')
          .select('id, landlord_id')
          .eq('tenant_id', me)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (conv == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No conversations yet. Tap a room’s “Message Landlord” to start one.',
            ),
          ),
        );
        return;
      }

      final conversationId = conv['id'] as String;

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreenTenant(
            conversationId: conversationId,
            peerName: fallbackPeerName, // display name in the app bar
            peerImageAsset: fallbackPeerImage, // avatar asset
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
    final filteredChats = chats.where((chat) {
      final s = searchQuery.toLowerCase();
      return chat['name'].toLowerCase().contains(s) ||
          chat['message'].toLowerCase().contains(s);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFD9D9D9),
      appBar: AppBar(
        title: const Text(
          'CHAT',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 25),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF04395E),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search chats...',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => searchQuery = v),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: filteredChats.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 72, color: Colors.black),
              itemBuilder: (context, index) {
                final chat = filteredChats[index];
                final isUnread = chat['unreadCount'] > 0;

                return ListTile(
                  tileColor: const Color(0xFFD9D9D9),
                  leading: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.grey.shade300,
                        child: ClipOval(
                          child: Image.asset(
                            chat['image'],
                            fit: BoxFit.cover,
                            width: 48,
                            height: 48,
                          ),
                        ),
                      ),
                      if (chat['isOnline'])
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Text(
                    chat['name'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    chat['message'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isUnread ? Colors.black : Colors.grey[600],
                      fontWeight: isUnread
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: SizedBox(
                    height: 48,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('hh:mm a').format(chat['time']),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (isUnread)
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${chat['unreadCount']}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  onTap: () => _openChatForTenant(
                    fallbackPeerName: chat['name'],
                    fallbackPeerImage: chat['image'],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black54,
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        onTap: _onNavTap,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.apartment),
            label: "Apartment",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: "Message"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: "Settings",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.door_front_door),
            label: "My Room",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.logout), label: "Logout"),
        ],
      ),
    );
  }
}
