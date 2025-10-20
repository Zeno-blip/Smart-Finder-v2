// TENANT/TCHAT2.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_finder/TENANT/CHAT.dart';

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

  String searchQuery = '';
  int _selectedIndex = 1;

  bool _loading = true;
  List<Map<String, dynamic>> _rows = [];

  RealtimeChannel? _channel;
  bool _navigating = false; // <— tap guard

  @override
  void initState() {
    super.initState();
    _load();
    _subscribe();
  }

  @override
  void dispose() {
    if (_channel != null) _sb.removeChannel(_channel!);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final me = _sb.auth.currentUser?.id;
    if (me == null) {
      setState(() {
        _rows = [];
        _loading = false;
      });
      return;
    }

    // mirror of landlord_inbox; rename if yours differs
    final data = await _sb
        .from('tenant_inbox')
        .select(
          'conversation_id, tenant_id, landlord_id, last_message, last_time, unread_for_tenant',
        )
        .eq('tenant_id', me)
        .order('last_time', ascending: false);

    setState(() {
      _rows = List<Map<String, dynamic>>.from(data);
      _loading = false;
    });
  }

  void _subscribe() {
    final ch = _sb.channel('inbox-tenant');

    ch.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (_) => _load(),
    );
    ch.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'messages',
      callback: (_) => _load(),
    );

    ch.subscribe();
    _channel = ch;
  }

  String _formatWhen(DateTime? utc) {
    if (utc == null) return '';
    final t = utc.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(t.year, t.month, t.day);

    if (date == today) return DateFormat('hh:mm a').format(t);
    if (date == today.subtract(const Duration(days: 1))) return 'Yesterday';
    if (now.difference(t).inDays < 7) return DateFormat('EEE').format(t);
    return DateFormat('MMM d').format(t);
  }

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

  @override
  Widget build(BuildContext context) {
    final filtered = _rows.where((row) {
      final s = searchQuery.toLowerCase();
      final msg = (row['last_message'] ?? '').toString().toLowerCase();
      final cid = (row['conversation_id'] ?? '').toString().toLowerCase();
      return msg.contains(s) || cid.contains(s);
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
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          if (!_loading)
            Expanded(
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 72, color: Colors.black),
                itemBuilder: (context, index) {
                  final row = filtered[index];
                  final last = (row['last_message'] ?? '').toString();
                  DateTime? t;
                  if (row['last_time'] != null) {
                    try {
                      t = DateTime.parse(row['last_time'].toString());
                    } catch (_) {}
                  }
                  final unread =
                      int.tryParse('${row['unread_for_tenant'] ?? 0}') ?? 0;

                  return ListTile(
                    tileColor: const Color(0xFFD9D9D9),
                    leading: const CircleAvatar(
                      radius: 24,
                      backgroundImage: AssetImage('assets/images/landlord.png'),
                    ),
                    title: Text(
                      'Landlord • ${_formatWhen(t)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      last,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: unread > 0 ? Colors.black : Colors.grey[600],
                        fontWeight: unread > 0
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: (unread > 0)
                        ? Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$unread',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          )
                        : null,
                    onTap: () async {
                      if (_navigating) return;
                      _navigating = true;
                      try {
                        final cid = (row['conversation_id'] ?? '').toString();
                        if (cid.isEmpty) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Missing conversation id'),
                            ),
                          );
                          return;
                        }
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreenTenant(
                              conversationId: cid,
                              peerName: 'Landlord',
                              peerImageAsset: 'assets/images/landlord.png',
                              landlordPhone:
                                  null, // fetched in chat if not provided
                            ),
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Open chat failed: $e')),
                        );
                      } finally {
                        _navigating = false;
                      }
                    },
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
