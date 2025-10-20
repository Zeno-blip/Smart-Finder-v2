import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_finder/TENANT/TGMAP.dart'; // <-- already present (keep it)
import 'package:smart_finder/LANDLORD/CHAT2.dart';
import 'package:smart_finder/LANDLORD/DASHBOARD.dart';
import 'package:smart_finder/LANDLORD/LSETTINGS.dart';
import 'GMAP.dart';
import 'TIMELINE.dart';
import 'TENANTS.dart';
import 'TOTALROOM.dart';
import 'LOGIN.dart';

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

  // ---------- Paging / UI state ----------
  int currentPage = 0;
  final int cardsPerPage = 10;
  final ScrollController _scrollController = ScrollController();
  int _selectedIndex = 2; // Apartment tab selected by default

  List<bool> favoriteStatus = List.generate(30, (_) => false);
  List<bool> bookmarkStatus = List.generate(30, (_) => false);

  // ---------- Filters ----------
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
          // client-side filter so we only react to my notifications
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
    // mark this one as read if needed
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
    // navigate if it has a room_id
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
    await _loadNotifications();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Refreshed')));
  }

  // ---------- Nav ----------
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
  void initState() {
    super.initState();
    _loadNotifications();
    _subscribeNotifications();
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
                    String key = entry.key;
                    String value = entry.value;

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
    int totalPages = (favoriteStatus.length / cardsPerPage).ceil();
    int startIndex = currentPage * cardsPerPage;
    int endIndex = (startIndex + cardsPerPage).clamp(0, favoriteStatus.length);

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
          // Refresh
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refreshPage,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
          // Notifications
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
                    child: const Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: "Search Tenant",
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        Icon(Icons.search, color: Colors.black54),
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

            // Cards with pagination
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: (endIndex - startIndex) + 1,
                itemBuilder: (context, index) {
                  if (index < endIndex - startIndex) {
                    final cardIndex = startIndex + index;
                    final demoRoomId =
                        'demo-room-${cardIndex + 1}'; // sample id

                    return ApartmentCard(
                      roomId: demoRoomId,
                      isFavorited: favoriteStatus[cardIndex],
                      isBookmarked: bookmarkStatus[cardIndex],
                      onFavoriteToggle: () {
                        setState(
                          () => favoriteStatus[cardIndex] =
                              !favoriteStatus[cardIndex],
                        );
                      },
                      onBookmarkPressed: () {
                        setState(
                          () => bookmarkStatus[cardIndex] =
                              !bookmarkStatus[cardIndex],
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              bookmarkStatus[cardIndex]
                                  ? 'Apartment bookmarked!'
                                  : 'Bookmark removed.',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    );
                  } else {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: Center(
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
                                        ? const Color.fromARGB(
                                            255,
                                            214,
                                            214,
                                            214,
                                          )
                                        : Colors.white10,
                                    border: isSelected
                                        ? Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          )
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
                                      color: isSelected
                                          ? Colors.black
                                          : Colors.white70,
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
                      ),
                    );
                  }
                },
              ),
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
}

class ApartmentCard extends StatelessWidget {
  final String roomId;
  final bool isFavorited;
  final bool isBookmarked;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onBookmarkPressed;

  const ApartmentCard({
    super.key,
    required this.roomId,
    required this.isFavorited,
    required this.isBookmarked,
    required this.onFavoriteToggle,
    required this.onBookmarkPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Pass the required roomId to Gmap
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => Gmap(roomId: roomId)),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Stack(
              children: [
                Image.asset(
                  'assets/images/roompano.png',
                  height: 100,
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
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Smart Finder Apartment",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "₱ 3750 / Month",
                    style: TextStyle(color: Colors.orange),
                  ),
                  SizedBox(height: 5),
                  Text(
                    "Davao City, Matina Crossing, Grazuhan Alvaran st.",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "#NearJTI #OwnCR #SingleBed #WiFi #CCTV",
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
              padding: const EdgeInsets.only(right: 10, bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
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
