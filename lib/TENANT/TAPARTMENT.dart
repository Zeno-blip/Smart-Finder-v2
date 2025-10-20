// TENANT/TAPARTMENT.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ===== IMPORTANT: import your map page with an alias =====
// Use the one that matches your real file name/case:
//import 'package:smart_finder/TENANT/tgmap.dart'
 //   as tenant_map; // <-- if file is tgmap.dart
 //import 'package:smart_finder/TENANT/TGMAP.dart' as tenant_map; // <-- use this instead if file is TGMAP.dart
import 'package:smart_finder/TENANT/TGMAP.dart' as tenant_map;

import 'package:smart_finder/TENANT/TLOGIN.dart';
import 'package:smart_finder/TENANT/TMYROOM.dart';
import 'package:smart_finder/TENANT/TPROFILE.dart';
import 'TCHAT2.dart';
import 'TSETTINGS.dart';

class TenantApartment extends StatefulWidget {
  /// If provided, page shows only this landlord’s rooms.
  final String? landlordId;

  /// Optional cosmetic name for the AppBar when filtering.
  final String? landlordName;

  const TenantApartment({super.key, this.landlordId, this.landlordName});

  @override
  State<TenantApartment> createState() => _TenantApartmentState();
}

class _TenantApartmentState extends State<TenantApartment> {
  final _sb = Supabase.instance.client;

  // Realtime
  RealtimeChannel? _roomsChannel;

  List<_RoomItem> _rooms = [];
  bool _loading = true;
  String? _error;

  int currentPage = 0;
  final int cardsPerPage = 10;
  final ScrollController _scrollController = ScrollController();

  final TextEditingController _searchCtrl = TextEditingController();

  final Map<String, bool> _favorite = {};
  final Map<String, bool> _bookmark = {};

  int _selectedNavIndex = 0;

  // (Demo) filter panel options
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

  @override
  void initState() {
    super.initState();
    _fetchRooms();
    _subscribeApprovedRooms();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchCtrl.dispose();
    _roomsChannel?.unsubscribe();
    super.dispose();
  }

  // ---------- Helpers ----------

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  bool _isApprovedStatus(dynamic v) {
    final s = (v ?? '').toString().toLowerCase();
    return s == 'published' || s == 'approved' || s == 'active';
  }

  bool _passesLandlordFilter(Map<String, dynamic> r) {
    if (widget.landlordId == null || widget.landlordId!.isEmpty) return true;
    return (r['landlord_id']?.toString() == widget.landlordId);
  }

  // ---------- Data load (approved only) ----------

  Future<void> _fetchRooms() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final selectCols = '''
        id,
        landlord_id,
        apartment_name,
        location,
        monthly_payment,
        created_at,
        status,
        room_images ( image_url, sort_order )
      ''';

      // NOTE: avoid .or() to keep older SDKs happy
      final List<dynamic> data = await _sb
          .from('rooms')
          .select(selectCols)
          .order('created_at', ascending: false)
          .limit(200);

      final rooms = <_RoomItem>[];
      for (final r in data) {
        // keep only approved + (optionally) specific landlord
        if (!_isApprovedStatus(r['status']) || !_passesLandlordFilter(r)) {
          continue;
        }

        final String id = r['id'].toString();
        final String title = (r['apartment_name'] ?? 'Apartment').toString();
        final String address = (r['location'] ?? '—').toString();
        final double monthly = _toDouble(r['monthly_payment']);

        String? thumb;
        final imgs = (r['room_images'] as List?) ?? [];
        if (imgs.isNotEmpty) {
          imgs.sort(
            (a, b) => ((a['sort_order'] ?? 0) as int).compareTo(
              (b['sort_order'] ?? 0) as int,
            ),
          );
          thumb = imgs.first['image_url'] as String?;
        }

        rooms.add(
          _RoomItem(
            id: id,
            title: title,
            address: address,
            monthly: monthly,
            imageUrl: thumb,
          ),
        );
      }

      setState(() {
        _rooms = rooms;
        _loading = false;
        _error = rooms.isEmpty
            ? (widget.landlordId == null
                  ? 'No approved rooms yet.'
                  : 'This landlord has no approved rooms yet.')
            : null;
        currentPage = 0;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to load rooms: $e';
      });
    }
  }

  // ---------- Realtime: pick up newly approved rooms ----------

  void _subscribeApprovedRooms() {
    _roomsChannel?.unsubscribe();

    _roomsChannel = _sb.channel('tenant-approved-rooms')
      // New rows
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'rooms',
        callback: (payload) {
          final rec = Map<String, dynamic>.from(payload.newRecord);
          if (_isApprovedStatus(rec['status']) && _passesLandlordFilter(rec)) {
            _fetchRooms();
          }
        },
      )
      // Updates
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'rooms',
        callback: (payload) {
          final newRec = Map<String, dynamic>.from(payload.newRecord);
          final oldRec = Map<String, dynamic>.from(payload.oldRecord ?? {});
          final becameApproved =
              _isApprovedStatus(newRec['status']) &&
              !_isApprovedStatus(oldRec['status']);

          if (becameApproved && _passesLandlordFilter(newRec)) {
            _fetchRooms();
          } else if (_isApprovedStatus(oldRec['status']) &&
              !_isApprovedStatus(newRec['status'])) {
            _fetchRooms();
          }
        },
      )
      ..subscribe();
  }

  // ---------- Search / Filter ----------

  List<_RoomItem> get _filteredRooms {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _rooms;
    return _rooms.where((r) {
      return r.title.toLowerCase().contains(q) ||
          r.address.toLowerCase().contains(q);
    }).toList();
  }

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
                                items: (dropdownOptions[key] ?? [])
                                    .map<DropdownMenuItem<String>>((opt) {
                                      return DropdownMenuItem<String>(
                                        value: opt,
                                        child: Text(
                                          opt,
                                          style: const TextStyle(fontSize: 14),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    })
                                    .toList(),
                                onChanged: (newValue) {
                                  setState(() {
                                    preferences[key] = newValue ?? value;
                                  });
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
                            content: Text("Filters applied (demo)"),
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

  // ---------- Utility functions ----------

  Future<void> refreshRooms() async => _fetchRooms();

  void clearSearch() {
    _searchCtrl.clear();
    setState(() {});
  }

  String formatPrice(num? v) {
    final n = (v ?? 0).toInt();
    return '₱ $n / Month';
  }

  void scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  void goToPage(int index, int totalPages) {
    final safe = index.clamp(0, totalPages - 1);
    setState(() {
      currentPage = safe;
    });
    scrollToTop();
  }

  void nextPage(int totalPages) {
    if (currentPage < totalPages - 1) {
      goToPage(currentPage + 1, totalPages);
    }
  }

  void prevPage() {
    if (currentPage > 0) {
      goToPage(currentPage - 1, currentPage + 1);
    }
  }

  void toggleFavorite(String roomId) {
    setState(() {
      _favorite[roomId] = !(_favorite[roomId] ?? false);
    });
  }

  void toggleBookmark(BuildContext context, String roomId) {
    final newVal = !(_bookmark[roomId] ?? false);
    setState(() => _bookmark[roomId] = newVal);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(newVal ? 'Apartment bookmarked!' : 'Bookmark removed.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Navigate to the **map-like detail page** that shows the address
  void openRoomInfo(_RoomItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => tenant_map.TenantGmap(
          // <-- use alias here
          roomId: item.id,
          titleHint: item.title,
          addressHint: item.address, // landlord's specific location
          monthlyHint: item.monthly,
        ),
      ),
    );
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final rooms = _filteredRooms;
    final totalPages = rooms.isEmpty ? 1 : (rooms.length / cardsPerPage).ceil();
    currentPage = currentPage.clamp(0, totalPages - 1);
    final startIndex = currentPage * cardsPerPage;
    final endIndex = (startIndex + cardsPerPage).clamp(0, rooms.length);

    final titleText = widget.landlordId == null
        ? 'TENANT APARTMENTS'
        : 'ROOMS BY ${widget.landlordName ?? 'LANDLORD'}';

    return Scaffold(
      backgroundColor: const Color(0xFF04354B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF04354B),
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          titleText,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 25,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchRooms,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : (_error != null
                  ? Center(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : Column(
                      children: [
                        // Search + Filter
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 40,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _searchCtrl,
                                        decoration: const InputDecoration(
                                          hintText: "Search Apartment",
                                          border: InputBorder.none,
                                        ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.search,
                                      color: Colors.black54,
                                    ),
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
                                child: const Icon(
                                  Icons.filter_list,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Cards + pagination
                        Expanded(
                          child: ListView.builder(
                            controller: _scrollController,
                            itemCount: (endIndex - startIndex) + 1,
                            itemBuilder: (context, index) {
                              if (index < endIndex - startIndex) {
                                final item = rooms[startIndex + index];
                                final fav = _favorite[item.id] ?? false;
                                final bm = _bookmark[item.id] ?? false;

                                return TenantApartmentCard(
                                  title: item.title,
                                  address: item.address,
                                  priceText:
                                      "₱ ${item.monthly.toStringAsFixed(0)} / Month",
                                  imageUrl: item.imageUrl,
                                  isFavorited: fav,
                                  isBookmarked: bm,
                                  onFavoriteToggle: () =>
                                      toggleFavorite(item.id),
                                  onBookmarkPressed: () =>
                                      toggleBookmark(context, item.id),
                                  onOpen: () => openRoomInfo(item),
                                );
                              } else {
                                return _buildPagination(totalPages);
                              }
                            },
                          ),
                        ),
                      ],
                    )),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black54,
        currentIndex: _selectedNavIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == _selectedNavIndex) return;
          setState(() => _selectedNavIndex = index);

          if (index == 0) {
            // stay here
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const TenantListChat()),
            );
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const TenantProfile()),
            );
          } else if (index == 3) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const TenantSettings()),
            );
          } else if (index == 4) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MyRoom()),
            );
          } else if (index == 5) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginT()),
              (route) => false,
            );
          }
        },
        items: [
          _buildNavItem(Icons.apartment, "Apartment", 0),
          _buildNavItem(Icons.message, "Message", 1),
          _buildNavItem(Icons.person, "Profile", 2),
          _buildNavItem(Icons.settings, "Settings", 3),
          _buildNavItem(Icons.door_front_door, "My Room", 4),
          _buildNavItem(Icons.logout, "Logout", 5),
        ],
      ),
    );
  }

  Widget _buildPagination(int totalPages) {
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
              onPressed: currentPage > 0 ? () => prevPage() : null,
              icon: const Icon(Icons.chevron_left),
              iconSize: 30,
              color: Colors.white,
            ),
            ...List.generate(totalPages, (index) {
              final isSelected = index == currentPage;
              return GestureDetector(
                onTap: () => goToPage(index, totalPages),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: isSelected
                        ? const Color.fromARGB(255, 214, 214, 214)
                        : Colors.white10,
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 2)
                        : null,
                    boxShadow: isSelected
                        ? const [
                            BoxShadow(
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
                      color: isSelected ? Colors.black : Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }),
            IconButton(
              onPressed: currentPage < totalPages - 1
                  ? () => nextPage(totalPages)
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

  BottomNavigationBarItem _buildNavItem(
    IconData icon,
    String label,
    int index,
  ) {
    final isSelected = _selectedNavIndex == index;
    return BottomNavigationBarItem(
      icon: Column(
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
          Icon(icon),
        ],
      ),
      label: label,
    );
  }
}

class TenantApartmentCard extends StatelessWidget {
  final String title;
  final String address;
  final String priceText;
  final String? imageUrl;

  final bool isFavorited;
  final bool isBookmarked;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onBookmarkPressed;
  final VoidCallback onOpen;

  const TenantApartmentCard({
    super.key,
    required this.title,
    required this.address,
    required this.priceText,
    required this.imageUrl,
    required this.isFavorited,
    required this.isBookmarked,
    required this.onFavoriteToggle,
    required this.onBookmarkPressed,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      child: Card(
        margin: const EdgeInsets.only(bottom: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: (imageUrl != null && imageUrl!.isNotEmpty)
                      ? Image.network(imageUrl!, fit: BoxFit.cover)
                      : Image.asset(
                          'assets/images/roompano.png',
                          fit: BoxFit.cover,
                        ),
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
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(priceText, style: const TextStyle(color: Colors.orange)),
                  const SizedBox(height: 5),
                  Text(
                    address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Row(
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomItem {
  final String id;
  final String title;
  final String address;
  final double monthly;
  final String? imageUrl;

  _RoomItem({
    required this.id,
    required this.title,
    required this.address,
    required this.monthly,
    required this.imageUrl,
  });
}
