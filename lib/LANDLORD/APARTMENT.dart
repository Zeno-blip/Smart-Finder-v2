import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smart_finder/LANDLORD/ROOMINFO.dart' show Roominfo;
import 'package:smart_finder/TENANT/TGMAP.dart'; // if you need tenant map elsewhere
import 'GMAP.dart'; // landlord map
import 'TIMELINE.dart';
import 'TENANTS.dart';
import 'TOTALROOM.dart';
import 'LOGIN.dart';
import 'DASHBOARD.dart';
import 'CHAT2.dart';
import 'LSETTINGS.dart';

class Apartment extends StatefulWidget {
  const Apartment({super.key});

  @override
  State<Apartment> createState() => _ApartmentState();
}

class _ApartmentState extends State<Apartment> {
  // ---------- Supabase ----------
  final supabase = Supabase.instance.client;
  RealtimeChannel? _notifChannel;
  List<Map<String, dynamic>> _notifs = [];
  int _unread = 0;
  String? get _userId => supabase.auth.currentUser?.id;

  // ---------- Data: ALL ROOMS ----------
  List<_RoomCard> _rooms = [];
  bool _loadingRooms = true;
  String? _roomError;

  // ---------- Paging / UI state ----------
  int currentPage = 0;
  final int cardsPerPage = 10;
  final ScrollController _scrollController = ScrollController();
  int _selectedIndex = 2; // Apartment tab selected by default

  // using sets for favorite/bookmark keyed by roomId
  final Set<String> _fav = {};
  final Set<String> _bm = {};

  // ---------- Filters (kept) ----------
  Map<String, String> preferences = {
    "Pet-Friendly": "Yes",
    "Open to all": "Yes",
    "Common CR": "Yes",
    "Occupation": "Student Only",
    "Smoking": "Non-Smoker Only",
    "Location": "Near UM",
    "WiFi": "Yes",
  };

  final Map<String, IconData> icons = {
    "Pet-Friendly": Icons.pets,
    "Open to all": Icons.people,
    "Common CR": Icons.bathroom,
    "Occupation": Icons.work,
    "Smoking": Icons.smoking_rooms,
    "Location": Icons.location_on,
    "WiFi": Icons.wifi,
  };

  final Map<String, List<String>> dropdownOptions = {
    "Pet-Friendly": ["Yes", "No"],
    "Open to all": ["Yes", "No"],
    "Common CR": ["Yes", "No"],
    "Occupation": ["Student Only", "Professional Only", "Others"],
    "Smoking": ["Non-Smoker Only", "Smoker Allowed"],
    "Location": ["Near UM", "Near SM Eco", "Near Mapua", "Near DDC"],
    "WiFi": ["Yes", "No"],
  };

  // ---------- Notifications ----------
  Future<void> _loadNotifications() async {
    if (_userId == null) return;

    final data = await supabase
        .from('notifications')
        .select('id,title,body,type,is_read,created_at,room_id,user_id')
        .eq('user_id', _userId!)
        .order('created_at', ascending: false)
        .limit(20);

    setState(() {
      _notifs = (data as List).cast<Map<String, dynamic>>();
      _unread = _notifs.where((n) => (n['is_read'] as bool?) == false).length;
    });
  }

  void _subscribeNotifications() {
    if (_userId == null) return;

    _notifChannel?.unsubscribe();
    _notifChannel = supabase.channel('notifs-${_userId!}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'notifications',
        callback: (payload) {
          final rec = payload.newRecord as Map<String, dynamic>;
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

    setState(() {
      _unread = 0;
      _notifs = _notifs.map((n) => {...n, 'is_read': true}).toList();
    });
  }

  Future<void> _openNotification(Map<String, dynamic> n) async {
    if ((n['is_read'] as bool?) == false) {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', n['id']);
      setState(() {
        final idx = _notifs.indexWhere((e) => e['id'] == n['id']);
        if (idx != -1) _notifs[idx] = {..._notifs[idx], 'is_read': true};
        if (_unread > 0) _unread -= 1;
      });
    }
    final roomId = (n['room_id'] as String?)?.trim();
    if (roomId != null && roomId.isNotEmpty && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => Gmap(roomId: roomId)),
      );
    }
  }

  void _openNotifications() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF00324E),
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
                      backgroundColor: const Color(0xFF00324E),
                      onRefresh: _loadNotifications,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _notifs.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: Colors.white10),
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
                                  : Icons.notifications_active_outlined,
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

  Future<void> _refreshPage() async {
    await Future.wait([_loadNotifications(), _loadAllRooms()]);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Refreshed')));
  }

  // ---------- Load ALL rooms (all landlords) ----------
  Future<void> _loadAllRooms() async {
    setState(() {
      _loadingRooms = true;
      _roomError = null;
    });

    try {
      // 1) base rooms (adjust selected columns to your schema)
      final rows = await supabase
          .from('rooms')
          .select(
            'id, apartment_name, location, monthly_payment, advance_deposit, landlord_id, created_at',
          )
          .order('created_at', ascending: false);

      final rooms = List<Map<String, dynamic>>.from(rows as List);

      if (rooms.isEmpty) {
        setState(() {
          _rooms = [];
          _loadingRooms = false;
        });
        return;
      }

      // 2) fetch first photo per room
      final ids = rooms.map((r) => r['id'].toString()).toList();
      final imgs = await supabase
          .from('room_images')
          .select('room_id, image_url, sort_order, storage_path')
          .inFilter('room_id', ids)
          .order('sort_order', ascending: true);

      final List<Map<String, dynamic>> imgRows =
          List<Map<String, dynamic>>.from(imgs as List);

      // pick first image per room (by lowest sort_order)
      final Map<String, String> thumbByRoom = {};
      for (final r in imgRows) {
        final rid = (r['room_id'] ?? '').toString();
        if (rid.isEmpty) continue;
        if (thumbByRoom.containsKey(rid)) continue; // already have the first
        final url = (r['image_url'] as String?)?.trim();
        if (url != null && url.isNotEmpty) {
          thumbByRoom[rid] = url;
        } else if (r['storage_path'] != null) {
          final u = supabase.storage
              .from('room-images')
              .getPublicUrl(r['storage_path'] as String);
          if (u.isNotEmpty) thumbByRoom[rid] = u;
        }
      }

      // 3) map to card models
      final list = <_RoomCard>[];
      for (final r in rooms) {
        final id = (r['id'] ?? '').toString();
        if (id.isEmpty) continue;

        final title = (r['apartment_name'] ?? 'Apartment').toString();
        final address = (r['location'] ?? '—').toString();
        final monthly = r['monthly_payment'];
        final priceText = (monthly is num)
            ? '₱ ${monthly.toStringAsFixed(2)} / Month'
            : '₱ —';

        list.add(
          _RoomCard(
            roomId: id,
            title: title,
            address: address,
            price: priceText,
            imageUrl: thumbByRoom[id],
          ),
        );
      }

      setState(() {
        _rooms = list;
        // keep currentPage in range when dataset changes
        final totalPages = (_rooms.length / cardsPerPage).ceil().clamp(
          1,
          1 << 30,
        );
        if (currentPage > totalPages - 1)
          currentPage = (totalPages - 1).clamp(0, totalPages - 1);
        _loadingRooms = false;
      });
    } catch (e) {
      setState(() {
        _roomError = '$e';
        _loadingRooms = false;
      });
    }
  }

  // ---------- Nav ----------
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
        (r) => false,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _subscribeNotifications();
    _loadAllRooms();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _notifChannel?.unsubscribe();
    super.dispose();
  }

  // ---------- Filter UI ----------
  void _openFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF00324E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          minChildSize: 0.5,
          initialChildSize: 0.9,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    "FILTER APARTMENTS",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...preferences.entries.map((entry) {
                    final key = entry.key;
                    final value = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: const Color(0xFF00324E),
                            child: Icon(icons[key], color: Colors.white),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Text(
                              key,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: SizedBox(
                              width: 140,
                              child: DropdownButton<String>(
                                value: value,
                                isExpanded: true,
                                underline: const SizedBox(),
                                borderRadius: BorderRadius.circular(8),
                                dropdownColor: Colors.white,
                                items: dropdownOptions[key]!
                                    .map<DropdownMenuItem<String>>(
                                      (String option) =>
                                          DropdownMenuItem<String>(
                                            value: option,
                                            child: Text(
                                              option,
                                              style: const TextStyle(
                                                fontSize: 14,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                    )
                                    .toList(),
                                onChanged: (String? newValue) {
                                  setState(() => preferences[key] = newValue!);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        // TODO: apply real filters to _rooms if you store flags on rooms
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Filters applied successfully!"),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: const Text(
                        'APPLY FILTERS',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _rooms.length;
    final totalPages = (total / cardsPerPage).ceil().clamp(1, 1 << 30);
    final startIndex = (currentPage * cardsPerPage).clamp(0, total);
    final endIndex = (startIndex + cardsPerPage).clamp(0, total);

    return Scaffold(
      backgroundColor: const Color(0xFF04354B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF04354B),
        automaticallyImplyLeading: false,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'APARTMENTS',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 25,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refreshPage,
            icon: const Icon(Icons.refresh, color: Colors.white),
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
                    right: -2,
                    top: -2,
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
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Search + Filter
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              hintText: "Search Apartment or Address",
                              border: InputBorder.none,
                            ),
                            onChanged: (q) {
                              // simple local filter (title or address contains)
                              q = q.trim().toLowerCase();
                              if (q.isEmpty) {
                                _loadAllRooms();
                                return;
                              }
                              final filtered = _rooms.where((r) {
                                return r.title.toLowerCase().contains(q) ||
                                    r.address.toLowerCase().contains(q);
                              }).toList();
                              setState(() {
                                _rooms = filtered;
                                currentPage = 0;
                              });
                            },
                          ),
                        ),
                        const Icon(Icons.search, color: Colors.black54),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _openFilterDialog,
                  child: Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.filter_list, color: Colors.black87),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Cards with pagination / loading / error
            Expanded(
              child: _loadingRooms
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : (_roomError != null
                        ? Center(
                            child: Text(
                              'Failed to load rooms:\n$_roomError',
                              style: const TextStyle(color: Colors.white70),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : (total == 0
                              ? const Center(
                                  child: Text(
                                    'No rooms found.',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                )
                              : ListView.builder(
                                  controller: _scrollController,
                                  itemCount: (endIndex - startIndex) + 1,
                                  itemBuilder: (context, index) {
                                    if (index < endIndex - startIndex) {
                                      final card = _rooms[startIndex + index];
                                      final isFav = _fav.contains(card.roomId);
                                      final isBm = _bm.contains(card.roomId);

                                      return ApartmentCard(
                                        data: card,
                                        isFavorited: isFav,
                                        isBookmarked: isBm,
                                        onFavoriteToggle: () {
                                          setState(() {
                                            if (isFav) {
                                              _fav.remove(card.roomId);
                                            } else {
                                              _fav.add(card.roomId);
                                            }
                                          });
                                        },
                                        onBookmarkPressed: () {
                                          setState(() {
                                            if (isBm) {
                                              _bm.remove(card.roomId);
                                            } else {
                                              _bm.add(card.roomId);
                                            }
                                          });
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                isBm
                                                    ? 'Bookmark removed.'
                                                    : 'Apartment bookmarked!',
                                              ),
                                              duration: const Duration(
                                                seconds: 2,
                                              ),
                                            ),
                                          );
                                        },
                                        onOpenMap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  Gmap(roomId: card.roomId),
                                            ),
                                          );
                                        },
                                        onOpenInfo: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  Roominfo(roomId: card.roomId),
                                            ),
                                          );
                                        },
                                      );
                                    } else {
                                      // pager row
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 20.0,
                                        ),
                                        child: Center(
                                          child: Wrap(
                                            alignment: WrapAlignment.center,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            spacing: 12,
                                            runSpacing: 10,
                                            children: [
                                              IconButton(
                                                onPressed: currentPage > 0
                                                    ? () {
                                                        setState(() {
                                                          currentPage--;
                                                          _scrollController
                                                              .jumpTo(0);
                                                        });
                                                      }
                                                    : null,
                                                icon: const Icon(
                                                  Icons.chevron_left,
                                                ),
                                                iconSize: 30,
                                                color: Colors.white,
                                              ),
                                              ...List.generate(totalPages, (
                                                index,
                                              ) {
                                                final isSelected =
                                                    index == currentPage;
                                                return GestureDetector(
                                                  onTap: () {
                                                    setState(() {
                                                      currentPage = index;
                                                      _scrollController.jumpTo(
                                                        0,
                                                      );
                                                    });
                                                  },
                                                  child: AnimatedContainer(
                                                    duration: const Duration(
                                                      milliseconds: 300,
                                                    ),
                                                    width: 40,
                                                    height: 40,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                      color: isSelected
                                                          ? const Color.fromARGB(
                                                              255,
                                                              214,
                                                              214,
                                                              214,
                                                            )
                                                          : Colors.white10,
                                                      border: isSelected
                                                          ? Border.all(
                                                              color:
                                                                  Colors.white,
                                                              width: 2,
                                                            )
                                                          : null,
                                                      boxShadow: isSelected
                                                          ? [
                                                              const BoxShadow(
                                                                color: Colors
                                                                    .black26,
                                                                blurRadius: 6,
                                                                offset: Offset(
                                                                  0,
                                                                  2,
                                                                ),
                                                              ),
                                                            ]
                                                          : [],
                                                    ),
                                                    alignment: Alignment.center,
                                                    child: Text(
                                                      "${index + 1}",
                                                      style: TextStyle(
                                                        color: isSelected
                                                            ? Colors.black
                                                            : Colors.white70,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }),
                                              IconButton(
                                                onPressed:
                                                    currentPage < totalPages - 1
                                                    ? () {
                                                        setState(() {
                                                          currentPage++;
                                                          _scrollController
                                                              .jumpTo(0);
                                                        });
                                                      }
                                                    : null,
                                                icon: const Icon(
                                                  Icons.chevron_right,
                                                ),
                                                iconSize: 30,
                                                color: Colors.white,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ))),
            ),
          ],
        ),
      ),

      // Bottom Navigation Bar
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
}

/* --------------------------- MODELS + CARD --------------------------- */

class _RoomCard {
  final String roomId;
  final String title;
  final String address;
  final String price;
  final String? imageUrl;

  _RoomCard({
    required this.roomId,
    required this.title,
    required this.address,
    required this.price,
    this.imageUrl,
  });
}

class ApartmentCard extends StatelessWidget {
  final _RoomCard data;
  final bool isFavorited;
  final bool isBookmarked;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onBookmarkPressed;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenInfo;

  const ApartmentCard({
    super.key,
    required this.data,
    required this.isFavorited,
    required this.isBookmarked,
    required this.onFavoriteToggle,
    required this.onBookmarkPressed,
    required this.onOpenMap,
    required this.onOpenInfo,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpenInfo,
      child: Card(
        margin: const EdgeInsets.only(bottom: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Stack(
              children: [
                (data.imageUrl != null && data.imageUrl!.isNotEmpty)
                    ? Image.network(
                        data.imageUrl!,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/images/roompano.png',
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Image.asset(
                        'assets/images/roompano.png',
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: onFavoriteToggle,
                    child: Icon(
                      isFavorited ? Icons.favorite : Icons.favorite_border,
                      color: isFavorited ? Colors.red : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(10),
              color: const Color(0xFF5A7689),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    data.price,
                    style: const TextStyle(color: Colors.orange),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 14,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          data.address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "#WiFi #CCTV #NearTransport",
                    style: TextStyle(
                      color: Colors.lightBlueAccent,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: const Color(0xFF5A7689),
              padding: const EdgeInsets.only(right: 10, left: 10, bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Open Map
                  TextButton.icon(
                    onPressed: onOpenMap,
                    icon: const Icon(Icons.map, color: Colors.white, size: 18),
                    label: const Text(
                      'Map',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  // Bookmark
                  GestureDetector(
                    onTap: onBookmarkPressed,
                    child: Icon(
                      Icons.bookmark,
                      color: isBookmarked
                          ? const Color.fromARGB(255, 1, 210, 109)
                          : Colors.white,
                    ),
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
