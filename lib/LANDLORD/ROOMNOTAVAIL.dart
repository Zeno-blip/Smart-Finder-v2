// roomnotavail.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../TOUR.dart';
import 'EditRoom.dart';

class RoomNotAvailable extends StatefulWidget {
  const RoomNotAvailable({super.key, required this.roomData});
  final Map<String, dynamic> roomData;

  @override
  State<RoomNotAvailable> createState() => _RoomNotAvailableState();
}

class _RoomNotAvailableState extends State<RoomNotAvailable> {
  final SupabaseClient _sb = Supabase.instance.client;

  Map<String, dynamic>? _room;
  bool _loading = true;

  List<String> _imageUrls = const [];

  RealtimeChannel? _roomChannel;
  RealtimeChannel? _imagesChannel;

  int _hoveredIndex = -1;
  int _selectedIndex = 0;

  String? _resolveRoomId() {
    final dynamic raw = _room != null ? _room!['id'] : widget.roomData['id'];
    if (raw == null) return null;
    final id = raw.toString().trim();
    return id.isEmpty ? null : id;
  }

  @override
  void initState() {
    super.initState();
    _fetchAll();
    _listenRealtime();
  }

  @override
  void dispose() {
    _roomChannel?.unsubscribe();
    _imagesChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    try {
      final String? idOpt = _resolveRoomId();
      if (idOpt == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final String id = idOpt;

      final data = await _sb.from('rooms').select().eq('id', id).maybeSingle();
      final imgs = await _sb
          .from('room_images')
          .select('image_url, storage_path, sort_order')
          .eq('room_id', id)
          .order('sort_order', ascending: true);

      final urls = <String>[];
      for (final row in (imgs as List? ?? const [])) {
        final String? direct = (row['image_url'] as String?);
        final String? storagePath = (row['storage_path'] as String?);
        if (direct != null && direct.trim().isNotEmpty) {
          urls.add(direct);
        } else if (storagePath != null && storagePath.trim().isNotEmpty) {
          final pub = _sb.storage.from('room-images').getPublicUrl(storagePath);
          urls.add(pub);
        }
      }

      if (!mounted) return;
      setState(() {
        _room = (data as Map<String, dynamic>?) ?? widget.roomData;
        _imageUrls = urls.isEmpty
            ? [
                'assets/images/roompano.png',
                'assets/images/roompano2.png',
                'assets/images/roompano3.png',
              ]
            : urls;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _listenRealtime() {
    final String? idOpt = _resolveRoomId();
    if (idOpt == null) return;
    final String id = idOpt;

    _roomChannel?.unsubscribe();
    _roomChannel = _sb.channel('rooms_changes_$id')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'rooms',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: id,
        ),
        callback: (_) async => _fetchAll(),
      )
      ..subscribe();

    _imagesChannel?.unsubscribe();
    _imagesChannel = _sb.channel('room_images_changes_$id')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'room_images',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'room_id',
          value: id,
        ),
        callback: (_) async => _fetchAll(),
      )
      ..subscribe();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFE6E6E6),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final room = _room ?? widget.roomData;

    return Scaffold(
      backgroundColor: const Color(0xFFE6E6E6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF003049),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "ROOM INFO",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 25,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _imageCarousel(room),
            const SizedBox(height: 20),
            _infoBoxes(room),
            const SizedBox(height: 20),
            _roomDetailsBox(room),
            const SizedBox(height: 20),
            _actionButtons(room),
          ],
        ),
      ),
    );
  }

  Widget _imageCarousel(Map<String, dynamic> room) {
    return SizedBox(
      height: 120,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(_imageUrls.length, (index) {
          final isHovered = index == _hoveredIndex;
          final isSelected = index == _selectedIndex;
          final url = _imageUrls[index];

          final isAsset = url.startsWith('assets/');
          final imageWidget = isAsset
              ? Image.asset(url, width: 150, height: 150, fit: BoxFit.cover)
              : Image.network(url, width: 150, height: 150, fit: BoxFit.cover);

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedIndex = index;
                    _hoveredIndex = index;
                  });

                  final String? roomId = _resolveRoomId();
                  if (roomId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Missing room id.')),
                    );
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Tour(
                        initialIndex: index,
                        roomId: roomId,
                        titleHint: (room['apartment_name'] as String?),
                        addressHint: (room['location'] as String?),
                        monthlyHint: (room['monthly_payment'] as num?)
                            ?.toDouble(),
                      ),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isHovered || isSelected
                          ? const Color(0xFF1B4678)
                          : const Color(0xFF767676),
                      width: 3,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: imageWidget,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _infoBoxes(Map<String, dynamic> room) {
    return Column(
      children: [
        _infoTile(
          Icons.apartment,
          "${room['floor_number'] ?? '—'}",
          Icons.price_change,
          "₱${room['monthly_payment'] ?? '—'}",
          iconSize: 28.0,
        ),
        _infoTile(
          FontAwesomeIcons.doorClosed,
          room['id']?.toString() ?? "—",
          Icons.attach_money,
          "₱${room['advance_deposit'] ?? '—'}",
          iconSize: 28.0,
        ),
        _infoTile(
          Icons.location_on,
          room['location'] ?? "—",
          Icons.square_foot,
          "${room['room_size'] ?? '—'}",
          iconSize: 28.0,
        ),
        _infoTile(
          Icons.chair,
          room['furnishing'] ?? "Single Bed, Table, Chair, WiFi",
          Icons.person,
          "Occupied",
          iconSize: 28.0,
        ),
      ],
    );
  }

  Widget _roomDetailsBox(Map<String, dynamic> room) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Room Details",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            (room['description'] as String?) ??
                "Currently unavailable. Cozy room with bed, table, chair, and Wi-Fi.",
          ),
        ],
      ),
    );
  }

  Widget _actionButtons(Map<String, dynamic> room) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003049),
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditRoom()),
              );
            },
            child: const Text(
              "Edit Room",
              style: TextStyle(fontSize: 20, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003049),
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              final landlordId = _sb.auth.currentUser?.id;
              if (landlordId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No logged-in landlord found.')),
                );
                return;
              }

              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (_) =>
                    _TenantPicker(supabase: _sb, landlordId: landlordId),
              );
            },
            child: const Text(
              "Add Tenant",
              style: TextStyle(fontSize: 20, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoTile(
    IconData leftIcon,
    String leftText,
    IconData? rightIcon,
    String rightText, {
    double iconSize = 24.0,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: _InfoBox(icon: leftIcon, text: leftText, iconSize: iconSize),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: (rightIcon != null && rightText.isNotEmpty)
                ? _InfoBox(icon: rightIcon, text: rightText, iconSize: iconSize)
                : const Opacity(opacity: 0, child: SizedBox(height: 80)),
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.icon,
    required this.text,
    required this.iconSize,
  });

  final IconData icon;
  final String text;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.black54, size: iconSize),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// Same tenant picker logic as in roomavail.dart
class _TenantPicker extends StatefulWidget {
  final SupabaseClient supabase;
  final String landlordId;

  const _TenantPicker({required this.supabase, required this.landlordId});

  @override
  State<_TenantPicker> createState() => _TenantPickerState();
}

class _TenantPickerState extends State<_TenantPicker> {
  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = true;
  List<Map<String, String>> _allPeople = [];
  String _q = '';
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _loadPeople();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPeople() async {
    try {
      final meId = widget.landlordId; // auth.users.id

      // 1) landlord_profiles.id for this user (if any)
      String? landlordProfileId;
      try {
        final lpRow = await widget.supabase
            .from('landlord_profiles')
            .select('id')
            .eq('user_id', meId)
            .maybeSingle();

        if (lpRow != null && lpRow['id'] != null) {
          landlordProfileId = lpRow['id'].toString();
        }
      } catch (_) {
        // ignore
      }

      final landlordIds = <String>{};
      if (meId.isNotEmpty) landlordIds.add(meId);
      if (landlordProfileId != null && landlordProfileId.isNotEmpty) {
        landlordIds.add(landlordProfileId);
      }

      if (landlordIds.isEmpty) {
        if (!mounted) return;
        setState(() {
          _allPeople = [];
          _loading = false;
        });
        return;
      }

      // 2) conversations where landlord_id is any of those
      final convs = await widget.supabase
          .from('conversations')
          .select('tenant_id, landlord_id')
          .inFilter('landlord_id', landlordIds.toList());

      final tenantIds = <String>{};
      for (final row in (convs as List? ?? const [])) {
        final tid = row['tenant_id']?.toString();
        if (tid != null && tid.isNotEmpty) tenantIds.add(tid);
      }

      if (tenantIds.isEmpty) {
        if (!mounted) return;
        setState(() {
          _allPeople = [];
          _loading = false;
        });
        return;
      }

      // 3) tenant_profile.user_id matches conversations.tenant_id
      final profiles = await widget.supabase
          .from('tenant_profile')
          .select('user_id, full_name')
          .inFilter('user_id', tenantIds.toList());

      final people = <Map<String, String>>[];
      for (final row in (profiles as List? ?? const [])) {
        final id = row['user_id']?.toString();
        final nameRaw = row['full_name']?.toString() ?? '';
        final name = nameRaw.trim().isEmpty ? 'Unknown tenant' : nameRaw.trim();

        if (id != null && id.isNotEmpty) {
          people.add({'id': id, 'name': name});
        }
      }

      if (!mounted) return;
      setState(() {
        _allPeople = people;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load tenants: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _allPeople
        .where((p) => p["name"]!.toLowerCase().contains(_q.toLowerCase()))
        .toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black26, width: 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.black54),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Search tenant',
                        border: InputBorder.none,
                      ),
                      onChanged: (v) => setState(() => _q = v),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              )
            else if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No tenants found.\n(Only tenants who have conversations with you will show here.)',
                  textAlign: TextAlign.center,
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final p = filtered[i];
                    final isChecked = _selectedId == p["id"];

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black87, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        onTap: () => setState(() {
                          _selectedId = isChecked ? null : p["id"];
                        }),
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFECECEC),
                          radius: 22,
                          child: Icon(Icons.person, color: Colors.black54),
                        ),
                        title: Text(
                          p["name"] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        trailing: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => setState(() {
                            _selectedId = isChecked ? null : p["id"];
                          }),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.black87,
                                width: 2,
                              ),
                              color: isChecked
                                  ? Colors.black87
                                  : Colors.transparent,
                            ),
                            alignment: Alignment.center,
                            child: isChecked
                                ? const Icon(
                                    Icons.check,
                                    size: 18,
                                    color: Colors.white,
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.black87, width: 1.5),
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () async {
                      final sel = _allPeople.firstWhere(
                        (p) => p["id"] == _selectedId,
                        orElse: () => const {"id": "", "name": ""},
                      );

                      final pickedName = sel["name"]!;
                      if (pickedName.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No tenant selected.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        return;
                      }

                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Confirm selection'),
                          content: Text(
                            'Are you sure this is the right tenant?\n\n$pickedName',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('No'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Yes, add'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        // TODO: insert into room_tenants here if needed

                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Selected: $pickedName'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    child: const Text('Add'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
