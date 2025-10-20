// timeline.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smart_finder/LANDLORD/CHAT2.dart';
import 'package:smart_finder/LANDLORD/DASHBOARD.dart';
import 'package:smart_finder/LANDLORD/LSETTINGS.dart';
import 'APARTMENT.dart';
import 'TENANTS.dart';
import 'TOTALROOM.dart';
import 'LOGIN.dart';
// import 'EDITROOM.dart'; // ← removed
import 'ROOMINFO.dart';
import 'ADDROOM.dart';

class Timeline extends StatefulWidget {
  const Timeline({super.key});

  @override
  State<Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<Timeline> {
  // ------------ Supabase ------------
  final supabase = Supabase.instance.client;
  String? get _userId => supabase.auth.currentUser?.id;

  // Realtime notifications
  RealtimeChannel? _notifChannel;
  final List<Map<String, dynamic>> _notifs = [];
  int _unread = 0;

  // ------------ Timeline data ------------
  String sortOption = 'Date Posted';
  List<Map<String, dynamic>> apartments = [];
  int currentPage = 0;
  final int cardsPerPage = 5;
  final ScrollController _scrollController = ScrollController();
  int _selectedIndex = 1; // Timeline tab
  bool _loading = true;

  // ============ NOTIFICATIONS ============

  Future<void> _loadNotifications() async {
    if (_userId == null) return;
    final data = await supabase
        .from('notifications')
        .select('id,title,body,type,is_read,created_at,room_id,user_id')
        .eq('user_id', _userId!)
        .order('created_at', ascending: false)
        .limit(30);

    _notifs
      ..clear()
      ..addAll((data as List).cast<Map<String, dynamic>>());
    _unread = _notifs.where((n) => (n['is_read'] as bool?) == false).length;
    if (mounted) setState(() {});
  }

  void _subscribeNotifications() {
    if (_userId == null) return;
    _notifChannel?.unsubscribe();

    _notifChannel = supabase.channel('notifs-timeline-${_userId!}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: _userId!,
        ),
        callback: (payload) {
          final rec = Map<String, dynamic>.from(payload.newRecord);
          if (rec['user_id'] != _userId) return;
          setState(() {
            _notifs.insert(0, rec);
            if (((rec['is_read'] as bool?) ?? false) == false) {
              _unread += 1;
            }
          });
        },
      )
      ..subscribe();
  }

  Future<void> _markAllRead() async {
    if (_userId == null) return;
    await supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', _userId!)
        .eq('is_read', false);

    for (var i = 0; i < _notifs.length; i++) {
      _notifs[i] = {..._notifs[i], 'is_read': true};
    }
    _unread = 0;
    if (mounted) setState(() {});
  }

  Future<void> _openNotification(Map<String, dynamic> n) async {
    if ((n['is_read'] as bool?) == false) {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', n['id']);
      final idx = _notifs.indexWhere((e) => e['id'] == n['id']);
      if (idx != -1) _notifs[idx] = {..._notifs[idx], 'is_read': true};
      if (_unread > 0) _unread -= 1;
      if (mounted) setState(() {});
    }

    final roomId = (n['room_id'] as String?)?.trim();
    if (roomId != null && roomId.isNotEmpty && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => Roominfo(roomId: roomId)),
      );
    }
  }

  void _openNotifications() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF003049),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          children: [
            ListTile(
              title: const Text(
                'Notifications',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              trailing: TextButton(
                onPressed: _markAllRead,
                child: const Text('Mark all read'),
              ),
            ),
            const Divider(height: 1, color: Colors.white24),
            Expanded(
              child: _notifs.isEmpty
                  ? const Center(
                      child: Text(
                        'No notifications',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : RefreshIndicator(
                      color: Colors.white,
                      backgroundColor: const Color(0xFF003049),
                      onRefresh: _loadNotifications,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _notifs.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: Colors.white12),
                        itemBuilder: (_, i) {
                          final n = _notifs[i];
                          final read = (n['is_read'] as bool?) ?? false;
                          final isRejected =
                              (n['type'] as String?) == 'room_rejected';
                          return ListTile(
                            onTap: () => _openNotification(n),
                            leading: Icon(
                              isRejected
                                  ? Icons.report_gmailerrorred_outlined
                                  : Icons.notifications_none,
                              color: read
                                  ? Colors.white54
                                  : (isRejected
                                        ? Colors.orangeAccent
                                        : Colors.lightBlueAccent),
                            ),
                            title: Text(
                              n['title'] ?? '',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: read
                                    ? FontWeight.w500
                                    : FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              n['body'] ?? '',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ============ TIMELINE (rooms) ============

  @override
  void initState() {
    super.initState();
    _refreshFromSupabase();
    _loadNotifications();
    _subscribeNotifications();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _notifChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _refreshFromSupabase() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);

    final List data = await supabase
        .from('rooms')
        .select(
          'id, apartment_name, location, monthly_payment, created_at, status, room_images(image_url, sort_order)',
        )
        .eq('landlord_id', user.id)
        .order('created_at', ascending: false);

    final List<Map<String, dynamic>> items = [];
    for (final r in data) {
      final images = (r['room_images'] as List?) ?? [];
      images.sort(
        (a, b) => (a['sort_order'] ?? 0).compareTo(b['sort_order'] ?? 0),
      );
      final firstUrl = images.isNotEmpty
          ? images.first['image_url'] as String?
          : null;

      items.add({
        'id': r['id'],
        'status': (r['status'] ?? 'pending').toString(),
        'title': (r['apartment_name'] ?? 'Room').toString(),
        'price': (r['monthly_payment'] ?? '').toString(),
        'location': (r['location'] ?? '').toString(),
        'imageUrl': firstUrl,
        'tags': const [],
      });
    }

    setState(() {
      apartments = items;
      _loading = false;
      currentPage = 0;
    });
  }

  void _onNavTap(int index) {
    if (_selectedIndex == index) return;

    setState(() => _selectedIndex = index);

    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const Dashboard()),
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
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ListChat()),
      );
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
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = (apartments.length / cardsPerPage).ceil();
    final startIndex = currentPage * cardsPerPage;
    final endIndex = (startIndex + cardsPerPage).clamp(0, apartments.length);

    return Scaffold(
      backgroundColor: const Color(0xFF003049),
      appBar: AppBar(
        backgroundColor: const Color(0xFF003049),
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          "MY TIMELINE",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 25,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              await _refreshFromSupabase();
              await _loadNotifications();
              if (!mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Refreshed')));
            },
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: _openNotifications,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none, color: Colors.white),
                if (_unread > 0)
                  Positioned(
                    right: -3,
                    top: -3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _unread > 99 ? '99+' : '$_unread',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
              children: [
                _buildTopControls(),
                Expanded(
                  child: apartments.isEmpty
                      ? const Center(
                          child: Text(
                            'No rooms yet. Tap Add to create one.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : ListView(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          children: [
                            ...List.generate(endIndex - startIndex, (index) {
                              final apartment = apartments[startIndex + index];
                              return Column(
                                children: [
                                  _buildApartmentCard(
                                    startIndex + index,
                                    apartment,
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              );
                            }),
                            _buildPagination(totalPages),
                          ],
                        ),
                ),
              ],
            ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ---------- UI helpers ----------

  Widget _buildTopControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              dropdownColor: Colors.white,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              value: sortOption,
              items: const [
                DropdownMenuItem(
                  value: 'Date Posted',
                  child: Text("Sort by Date Posted"),
                ),
                DropdownMenuItem(value: 'Price', child: Text("Sort by Price")),
              ],
              onChanged: (value) => setState(() => sortOption = value!),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                final result = await Navigator.push<Map<String, dynamic>>(
                  context,
                  MaterialPageRoute(builder: (context) => const Addroom()),
                );
                if (result == null) return;
                await _refreshFromSupabase();
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Room saved')));
              },
              icon: const Icon(Icons.add),
              label: const Text("Add Room"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApartmentCard(int index, Map<String, dynamic> apartment) {
    final String status = (apartment['status'] ?? 'pending').toString();

    Color statusColor;
    if (status == 'published') {
      statusColor = Colors.green;
    } else if (status == 'pending') {
      statusColor = Colors.orange;
    } else if (status == 'rejected') {
      statusColor = Colors.red;
    } else {
      statusColor = Colors.grey;
    }

    final String? imageUrl = apartment['imageUrl'] as String?;
    final Uint8List? imageBytes = apartment['imageBytes'] as Uint8List?;

    Widget imageWidget;
    if (imageBytes != null) {
      imageWidget = Image.memory(
        imageBytes,
        height: 160,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    } else if (imageUrl != null && imageUrl.isNotEmpty) {
      imageWidget = Image.network(
        imageUrl,
        height: 160,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    } else {
      imageWidget = Container(
        height: 160,
        width: double.infinity,
        color: Colors.black26,
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported, color: Colors.white70),
      );
    }

    final String title = (apartment['title'] ?? "Smart Finder Apartment")
        .toString();
    final String price = (apartment['price'] ?? "0").toString();
    final String location = (apartment['location'] ?? "Unknown location")
        .toString();

    String statusButtonText;
    if (status == 'published') {
      statusButtonText = "Published";
    } else if (status == 'pending') {
      statusButtonText = "Awaiting Approval";
    } else {
      statusButtonText = "Status: $status";
    }

    return GestureDetector(
      onTap: () {
        final roomId = apartment['id'];
        if (roomId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This item has no roomId')),
          );
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => Roominfo(roomId: roomId as String)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2D4C5D),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  child: imageWidget,
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "₱$price / Month",
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    location,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (status != 'rejected') ...[
                        ElevatedButton(
                          onPressed: null,
                          style: ElevatedButton.styleFrom(
                            disabledBackgroundColor: const Color(0xFF003049),
                            disabledForegroundColor: Colors.white,
                          ),
                          child: Text(statusButtonText),
                        ),
                        const SizedBox(width: 8),
                      ],
                      // EDIT button removed
                      ElevatedButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: Colors.white,
                              title: const Text("Confirm Delete"),
                              content: const Text(
                                "Are you sure you want to delete this apartment?",
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text("Cancel"),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    await supabase
                                        .from('rooms')
                                        .delete()
                                        .eq('id', apartment['id']);
                                    await _refreshFromSupabase();
                                    if (mounted) Navigator.of(context).pop();
                                  },
                                  child: const Text(
                                    "Delete",
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF003049),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Delete"),
                      ),
                      const Spacer(),
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

  Widget _buildPagination(int totalPages) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Wrap(
        alignment: WrapAlignment.center,
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
            color: Colors.white,
          ),
          ...List.generate(totalPages, (index) {
            final isSelected = index == currentPage;
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
            color: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
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
    );
  }
}
