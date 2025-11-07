import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smart_finder/LANDLORD/DASHBOARD.dart';
import 'package:smart_finder/LANDLORD/APARTMENT.dart';
import 'package:smart_finder/LANDLORD/TOTALROOM.dart';
import 'package:smart_finder/LANDLORD/LSETTINGS.dart';
import 'package:smart_finder/LANDLORD/LOGIN.dart';
import 'package:smart_finder/LANDLORD/TIMELINE.dart';
import 'package:smart_finder/LANDLORD/TENANTS.dart';

import 'package:smart_finder/services/chat_service.dart';
import 'package:smart_finder/LANDLORD/chatL.dart' show LandlordChatScreen;

class ListChat extends StatefulWidget {
  const ListChat({super.key});

  @override
  State<ListChat> createState() => _ListChatState();
}

class _ListChatState extends State<ListChat> {
  final _sb = Supabase.instance.client;
  final _chat = ChatService(Supabase.instance.client);

  String searchQuery = '';
  int _selectedIndex = 4;
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  RealtimeChannel? _channel;
  bool _navigating = false; // tap guard

  // cache: tenant_id -> {name, avatarUrl}
  final Map<String, Map<String, String>> _tenants = {};

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

    final data = await _sb
        .from('landlord_inbox')
        .select(
          'conversation_id, landlord_id, tenant_id, last_message, last_time, unread_for_landlord',
        )
        .eq('landlord_id', me)
        .order('last_time', ascending: false);

    final rows = List<Map<String, dynamic>>.from(data ?? const []);

    // Build tenant cache (name + avatar public URL from bucket)
    final ids = <String>{
      for (final r in rows)
        if ((r['tenant_id'] ?? '').toString().isNotEmpty)
          r['tenant_id'].toString(),
    }.toList();

    if (ids.isNotEmpty) {
      final users = await _sb
          .from('users')
          .select('id, full_name, first_name, last_name')
          .inFilter('id', ids);

      for (final u in (users as List? ?? const [])) {
        final id = (u['id'] ?? '').toString();
        final full =
            (u['full_name'] ??
                    '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}')
                .toString()
                .trim();

        final storage = _sb.storage.from('avatars');
        final jpg = storage.getPublicUrl('$id.jpg');
        final png = storage.getPublicUrl('$id.png');
        final avatarUrl = jpg.isNotEmpty ? jpg : png;

        _tenants[id] = {
          'name': full.isEmpty ? 'Tenant' : full,
          'avatarUrl': avatarUrl,
        };
      }
    }

    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  void _subscribe() {
    final ch = _sb.channel('inbox-landlord');
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
        MaterialPageRoute(builder: (_) => const Dashboard()),
      );
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const Timeline()),
      );
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const Apartment()),
      );
    } else if (index == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const Tenants()),
      );
    } else if (index == 4) {
      // stay
    } else if (index == 5) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TotalRoom()),
      );
    } else if (index == 6) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LandlordSettings()),
      );
    } else if (index == 7) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const Login()),
        (r) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _rows.where((row) {
      final s = searchQuery.toLowerCase();
      final msg = (row['last_message'] ?? '').toString().toLowerCase();
      final cid = (row['conversation_id'] ?? '').toString().toLowerCase();
      final tenantName =
          _tenants[(row['tenant_id'] ?? '').toString()]?['name'] ?? '';
      return msg.contains(s) ||
          cid.contains(s) ||
          tenantName.toLowerCase().contains(s);
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
                      int.tryParse('${row['unread_for_landlord'] ?? 0}') ?? 0;

                  final tenantId = (row['tenant_id'] ?? '').toString();
                  final info =
                      _tenants[tenantId] ??
                      const {'name': 'Tenant', 'avatarUrl': ''};
                  final titleName = info['name'] ?? 'Tenant';
                  final avatarUrl = info['avatarUrl'] ?? '';

                  final avatar = (avatarUrl.startsWith('http'))
                      ? NetworkImage(avatarUrl)
                      : const AssetImage('assets/images/mykel.png')
                            as ImageProvider;

                  return ListTile(
                    tileColor: const Color(0xFFD9D9D9),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundImage: avatar,
                      onBackgroundImageError: (_, __) {},
                    ),
                    title: Text(
                      '$titleName • ${_formatWhen(t)}',
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
                    trailing: unread > 0
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
                            builder: (_) => LandlordChatScreen(
                              conversationId: cid,
                              peerName: titleName,
                              // pass as URL so chat screen treats it as network image
                              peerAvatarUrl: avatarUrl,
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
                  break;
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
