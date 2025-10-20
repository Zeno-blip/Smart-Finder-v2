// TENANT/TROOMINFO.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../TOUR.dart'; // adjust path if different

class TenantRoomInfo extends StatefulWidget {
  final String roomId;

  /// Optional hints so the header isn't blank before fetch completes.
  final String? titleHint;
  final String? addressHint;
  final double? monthlyHint;

  const TenantRoomInfo({
    super.key,
    required this.roomId,
    this.titleHint,
    this.addressHint,
    this.monthlyHint,
  });

  @override
  State<TenantRoomInfo> createState() => _TenantRoomInfoState();
}

class _TenantRoomInfoState extends State<TenantRoomInfo> {
  final _sb = Supabase.instance.client;

  // Loading state
  bool _loading = true;
  String? _error;

  // Core room fields
  String _apartmentName = '';
  String _location = '';
  int? _floorNumber;
  double? _monthlyPayment;
  double? _advanceDeposit;
  String _description = '';

  // Images (ordered by sort_order)
  final List<_Img> _images = [];

  // Tags
  List<String> _inclusions = [];
  List<String> _preferences = [];

  // UI state for the small thumbnail row
  int _hoveredIndex = -1;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();

    // optional hints for instant UI
    _apartmentName = widget.titleHint ?? _apartmentName;
    _location = widget.addressHint ?? _location;
    _monthlyPayment = widget.monthlyHint ?? _monthlyPayment;

    _loadRoom();
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  Future<void> _loadRoom() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      /// Pull everything we need in one query with nested selects.
      final data = await _sb
          .from('rooms')
          .select('''
            id,
            apartment_name,
            location,
            floor_number,
            monthly_payment,
            advance_deposit,
            description,
            room_images ( id, image_url, sort_order ),
            room_inclusions ( inclusion_options ( name ) ),
            room_preferences ( preference_options ( name ) )
          ''')
          .eq('id', widget.roomId)
          .maybeSingle();

      if (data == null) {
        setState(() {
          _loading = false;
          _error = 'Room not found.';
        });
        return;
      }

      // Scalars
      _apartmentName = (data['apartment_name'] ?? '') as String;
      _location = (data['location'] ?? '') as String;
      _floorNumber = data['floor_number'] as int?;
      _monthlyPayment = _toDouble(data['monthly_payment']);
      _advanceDeposit = _toDouble(data['advance_deposit']);
      _description = (data['description'] ?? '') as String;

      // Images
      _images
        ..clear()
        ..addAll([
          for (final r in (data['room_images'] as List? ?? []))
            _Img(
              id: r['id'] as String,
              url: (r['image_url'] ?? '') as String,
              sort: (r['sort_order'] ?? 0) as int,
            ),
        ]);
      _images.sort((a, b) => a.sort.compareTo(b.sort));

      // Inclusions
      final incRows = (data['room_inclusions'] as List?) ?? [];
      _inclusions = [
        for (final r in incRows)
          if (r['inclusion_options'] != null &&
              r['inclusion_options']['name'] != null)
            r['inclusion_options']['name'] as String,
      ];

      // Preferences
      final prefRows = (data['room_preferences'] as List?) ?? [];
      _preferences = [
        for (final r in prefRows)
          if (r['preference_options'] != null &&
              r['preference_options']['name'] != null)
            r['preference_options']['name'] as String,
      ];

      setState(() {
        _loading = false;
        _error = null;
        _selectedIndex = 0;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to load room: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleText = _apartmentName.isEmpty ? 'ROOM INFO' : _apartmentName;

    return Scaffold(
      backgroundColor: const Color(0xFFE6E6E6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF003049),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          titleText,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadRoom,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.black54),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _imageStrip(context),
                        const SizedBox(height: 20),
                        _box1(),
                        _box2(),
                        _box3(),
                        _box4(),
                        _box5(),
                        const SizedBox(height: 20),
                        _roomDetailsBox(),
                      ],
                    ),
                  )),
    );
  }

  /* ------------------- UI blocks ------------------- */

  /// Horizontal thumbnails; tapping opens the Tour screen at that index.
  Widget _imageStrip(BuildContext context) {
    final hasImages = _images.isNotEmpty;

    if (!hasImages) {
      return SizedBox(
        height: 120,
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF767676), width: 3),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/roompano.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 120,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(_images.length, (index) {
          final img = _images[index];
          final isHovered = index == _hoveredIndex;
          final isSelected = index == _selectedIndex;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: MouseRegion(
                onEnter: (_) => setState(() => _hoveredIndex = index),
                onExit: (_) => setState(() => _hoveredIndex = -1),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIndex = index;
                      _hoveredIndex = index;
                    });
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Tour(
                          initialIndex: index,
                          roomId: widget.roomId, // 👈 IMPORTANT
                          titleHint: _apartmentName,
                          addressHint: _location,
                          monthlyHint: _monthlyPayment,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isHovered || isSelected
                            ? const Color.fromARGB(255, 27, 70, 120)
                            : const Color.fromARGB(255, 118, 118, 118),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        img.url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: Colors.black12,
                          child: Center(child: Icon(Icons.broken_image)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // Floor + Monthly
  Widget _box1() {
    final floorText = _floorNumber == null ? '—' : '${_floorNumber!} Floor';
    final priceText = _monthlyPayment == null
        ? '—'
        : '₱${_monthlyPayment!.toStringAsFixed(0)}';

    return _infoTile(
      Icons.apartment,
      floorText,
      Icons.price_change,
      priceText,
      iconSize: 28.0,
    );
  }

  // Deposit (right) + placeholder Room (left)
  Widget _box2() {
    final depositText = _advanceDeposit == null
        ? '—'
        : '₱${_advanceDeposit!.toStringAsFixed(0)}';
    return _infoTile(
      FontAwesomeIcons.doorClosed,
      'Room',
      Icons.attach_money,
      depositText,
      iconSize: 28.0,
    );
  }

  // Location + placeholder on the right
  Widget _box3() {
    return _infoTile(
      Icons.location_on,
      _location.isEmpty ? '—' : _location,
      Icons.flash_on,
      '',
      iconSize: 28.0,
    );
  }

  // Inclusions + Preferences
  Widget _box4() {
    final inc = _inclusions.isEmpty ? '—' : _inclusions.join(', ');
    final pref = _preferences.isEmpty ? '—' : _preferences.join(', ');
    return _infoTile(Icons.chair, inc, Icons.person, pref, iconSize: 28.0);
  }

  // Apartment name (single box)
  Widget _box5() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: _infoBox(
              Icons.apartment,
              _apartmentName.isEmpty ? 'Apartment' : _apartmentName,
              28.0,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Opacity(
              opacity: 0,
              child: _infoBox(Icons.ac_unit, "", 28.0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roomDetailsBox() {
    final tags = <String>[
      ..._inclusions.map((e) => '#$e'),
      ..._preferences.map((e) => '#$e'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
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
            _description.isEmpty ? "No description provided." : _description,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 10),
          if (tags.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags
                  .map(
                    (t) => Chip(
                      label: Text(
                        t,
                        style: const TextStyle(color: Colors.blue),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  /* ------------------- small helpers ------------------- */

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
          Expanded(child: _infoBox(leftIcon, leftText, iconSize)),
          const SizedBox(width: 10),
          Expanded(
            child: (rightIcon != null && rightText.isNotEmpty)
                ? _infoBox(rightIcon, rightText, iconSize)
                : Opacity(
                    opacity: 0,
                    child: _infoBox(Icons.ac_unit, "", iconSize),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _infoBox(IconData icon, String text, double iconSize) {
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
              text.isEmpty ? '—' : text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _Img {
  final String id;
  final String url;
  final int sort;
  _Img({required this.id, required this.url, required this.sort});
}
