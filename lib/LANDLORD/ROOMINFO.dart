import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_finder/TOUR.dart';

class Roominfo extends StatefulWidget {
  final String roomId;
  const Roominfo({super.key, required this.roomId});

  @override
  State<Roominfo> createState() => _RoominfoState();
}

class _RoominfoState extends State<Roominfo> {
  final supabase = Supabase.instance.client;

  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _room; // rooms row
  List<Map<String, dynamic>> _images = []; // [{id, image_url, sort_order}]
  List<String> _inclusions = [];
  List<String> _preferences = [];

  int _hoveredIndex = -1;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadRoom();
  }

  Future<void> _loadRoom() async {
    try {
      final room = await supabase
          .from('rooms')
          .select(
            'id, floor_number, apartment_name, location, monthly_payment, advance_deposit, description',
          )
          .eq('id', widget.roomId)
          .single();

      final imgs = await supabase
          .from('room_images')
          .select('id, image_url, sort_order')
          .eq('room_id', widget.roomId)
          .order('sort_order', ascending: true);

      List<String> inclusions = [];
      try {
        final incRows = await supabase
            .from('room_inclusions')
            .select('inclusion_options(name)')
            .eq('room_id', widget.roomId);
        inclusions = incRows
            .map<String>(
              (e) => (e['inclusion_options']?['name'] as String?) ?? '',
            )
            .where((s) => s.isNotEmpty)
            .toList();
      } catch (_) {}

      List<String> preferences = [];
      try {
        final prefRows = await supabase
            .from('room_preferences')
            .select('preference_options(name)')
            .eq('room_id', widget.roomId);
        preferences = prefRows
            .map<String>(
              (e) => (e['preference_options']?['name'] as String?) ?? '',
            )
            .where((s) => s.isNotEmpty)
            .toList();
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _room = room;
        _images = List<Map<String, dynamic>>.from(imgs);
        _inclusions = inclusions;
        _preferences = preferences;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  String _money(dynamic v) {
    if (v == null) return '—';
    final n = (v is num) ? v.toDouble() : double.tryParse('$v');
    if (n == null) return '—';
    return '₱${n.toStringAsFixed(2)}';
  }

  String _floorText(int? floor) => floor == null ? 'Floor —' : 'Floor $floor';

  // Reusable thumbnail
  Widget _thumb(String url) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: Colors.black12,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      errorBuilder: (_, __, ___) =>
          const Center(child: Icon(Icons.broken_image)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _room?['apartment_name'] ?? 'Room Info';

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
          title.toString().toUpperCase(),
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'Failed to load room: $_error',
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
                  _boxRow(
                    leftIcon: Icons.apartment,
                    leftText: _floorText(_room?['floor_number'] as int?),
                    rightIcon: Icons.price_change,
                    rightText: _money(_room?['monthly_payment']),
                  ),
                  _boxRow(
                    leftIcon: FontAwesomeIcons.doorClosed,
                    leftText: _room?['apartment_name'] ?? '—',
                    rightIcon: Icons.attach_money,
                    rightText: _money(_room?['advance_deposit']),
                  ),
                  _boxRow(
                    leftIcon: Icons.location_on,
                    leftText: (_room?['location'] ?? '—').toString(),
                    rightIcon: Icons.info_outline,
                    rightText: 'Images: ${_images.length}',
                  ),
                  _boxRow(
                    leftIcon: Icons.chair,
                    leftText: _inclusions.isEmpty
                        ? '—'
                        : _inclusions.join(', '),
                    rightIcon: Icons.people_alt,
                    rightText: _preferences.isEmpty
                        ? '—'
                        : _preferences.join(', '),
                  ),
                  _apartmentBox(_room?['apartment_name'] ?? '—'),
                  const SizedBox(height: 20),
                  _roomDetailsBox(
                    description:
                        (_room?['description'] ?? 'No description provided.')
                            .toString(),
                    tags: [
                      ..._preferences.map((e) => '#$e'),
                      ..._inclusions.map((e) => '#$e'),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  /// Responsive, non-stretch horizontal strip
  Widget _imageStrip(BuildContext context) {
    if (_images.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(child: Text('No photos uploaded yet.')),
      );
    }

    return SizedBox(
      height: 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: _images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final isHovered = index == _hoveredIndex;
          final isSelected = index == _selectedIndex;
          final url = _images[index]['image_url'] as String;

          void openTour() {
            if (!mounted) return;
            _selectedIndex = index; // avoid setState race before push
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => Tour(
                  initialIndex: index,
                  roomId: widget.roomId,
                  titleHint: _room?['apartment_name'] as String?,
                  addressHint: _room?['location'] as String?,
                  monthlyHint: (_room?['monthly_payment'] as num?)?.toDouble(),
                ),
                transitionsBuilder: (_, a, __, child) =>
                    FadeTransition(opacity: a, child: child),
              ),
            );
          }

          return MouseRegion(
            onEnter: (_) => setState(() => _hoveredIndex = index),
            onExit: (_) => setState(() => _hoveredIndex = -1),
            child: GestureDetector(
              onTap: openTour,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (isHovered || isSelected)
                        ? const Color.fromARGB(255, 27, 70, 120)
                        : const Color.fromARGB(255, 118, 118, 118),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: AspectRatio(
                    aspectRatio: 16 / 9, // keeps images proportional
                    child: _thumb(url),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _boxRow({
    required IconData leftIcon,
    required String leftText,
    IconData? rightIcon,
    String rightText = '',
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: _infoBox(leftIcon, leftText, 28.0)),
          const SizedBox(width: 10),
          Expanded(
            child: rightIcon != null && rightText.isNotEmpty
                ? _infoBox(rightIcon, rightText, 28.0)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _apartmentBox(String name) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: _infoBox(Icons.apartment, name, 28.0)),
          const SizedBox(width: 10),
          const Expanded(child: SizedBox.shrink()),
        ],
      ),
    );
  }

  Widget _roomDetailsBox({
    required String description,
    required List<String> tags,
  }) {
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
          Text(description, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 10),
          if (tags.isNotEmpty)
            Wrap(
              spacing: 8,
              children: tags
                  .take(10)
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
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
