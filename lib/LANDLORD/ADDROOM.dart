// lib/addroom.dart
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:panorama_viewer/panorama_viewer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smart_finder/LANDLORD/LOGIN.dart';

class _NeedsLogin implements Exception {
  const _NeedsLogin();
  @override
  String toString() => '_NeedsLogin';
}

const String kRoomImagesBucket = 'room-images';

class LocalImage {
  final Uint8List bytes;
  LocalImage(this.bytes);
  ImageProvider provider() => MemoryImage(bytes);
  Widget widget({double? width, double? height, BoxFit fit = BoxFit.cover}) =>
      Image.memory(bytes, width: width, height: height, fit: fit);
}

class Hotspot {
  final double dx; // radians (longitude, -pi..pi)
  final double dy; // radians (latitude, -pi/2..pi/2)
  final int targetImageIndex;
  final String? label;

  Hotspot({
    required this.dx,
    required this.dy,
    required this.targetImageIndex,
    this.label,
  });

  Hotspot copyWith({
    double? dx,
    double? dy,
    int? targetImageIndex,
    String? label,
  }) {
    return Hotspot(
      dx: dx ?? this.dx,
      dy: dy ?? this.dy,
      targetImageIndex: targetImageIndex ?? this.targetImageIndex,
      label: label ?? this.label,
    );
  }
}

class Addroom extends StatefulWidget {
  const Addroom({super.key});
  @override
  State<Addroom> createState() => _AddroomState();
}

class _AddroomState extends State<Addroom> {
  final _sb = Supabase.instance.client;

  List<String> inclusions = [];
  List<String> preferences = [];

  final List<String> inclusionOptions = ["Bed", "WiFi", "Cabinet", "Table"];
  final List<String> preferenceOptions = [
    "Male Only",
    "Female Only",
    "Mixed",
    "Couples",
    "Working Professionals",
  ];

  final List<LocalImage> roomImages = [];
  final ImagePicker _picker = ImagePicker();

  Map<int, List<Hotspot>> hotspotsByImageIndex = {};

  final TextEditingController floorCtrl = TextEditingController();
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController locationCtrl = TextEditingController();
  final TextEditingController monthlyCtrl = TextEditingController();
  final TextEditingController depositCtrl = TextEditingController();
  final TextEditingController descCtrl = TextEditingController();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadLandlordInfo();
  }

  @override
  void dispose() {
    floorCtrl.dispose();
    nameCtrl.dispose();
    locationCtrl.dispose();
    monthlyCtrl.dispose();
    depositCtrl.dispose();
    descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLandlordInfo() async {
    final user = _sb.auth.currentUser;
    if (user == null) return;
    try {
      final lp = await _sb
          .from('landlord_profile')
          .select('address, apartment_name')
          .eq('user_id', user.id)
          .maybeSingle();

      String address = lp?['address'] ?? '';
      String aptName = lp?['apartment_name'] ?? '';

      if (address.isEmpty || aptName.isEmpty) {
        final u = await _sb
            .from('users')
            .select('address, apartment_name')
            .eq('id', user.id)
            .maybeSingle();
        address = address.isEmpty ? (u?['address'] ?? '') : address;
        aptName = aptName.isEmpty ? (u?['apartment_name'] ?? '') : aptName;
      }

      if (!mounted) return;
      setState(() {
        locationCtrl.text = address;
        nameCtrl.text = aptName;
      });
    } catch (_) {}
  }

  String _orEq(String column, List<String> values) =>
      values.map((v) => "$column.eq.$v").join(',');

  Future<void> _ensureAuth() async {
    if (_sb.auth.currentUser != null) return;
    throw const _NeedsLogin();
  }

  double _clamp(double v, double lo, double hi) =>
      v < lo ? lo : (v > hi ? hi : v);

  double _round(double v, [int digits = 6]) =>
      double.parse(v.toStringAsFixed(digits));

  Widget _fieldLabel(String text) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: .2,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF00324E), Color(0xFF005B96)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: _saving ? null : () => Navigator.pop(context),
                ),
                centerTitle: true,
                title: const Text(
                  "ADD ROOM",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 25,
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _fieldLabel('Room Images / Panoramas'),
                      _buildImagesGrid(),
                      const SizedBox(height: 20),

                      _fieldLabel('Floor Number'),
                      _buildTextField(
                        Icons.stairs,
                        "Enter Floor Number",
                        isNumber: true,
                        controller: floorCtrl,
                      ),

                      _fieldLabel('Apartment Name'),
                      _buildTextField(
                        Icons.apartment,
                        "Apartment Name (auto-filled)",
                        controller: nameCtrl,
                        readOnly: true,
                      ),

                      _fieldLabel('Address'),
                      _buildTextField(
                        Icons.location_on,
                        "Landlord Address (auto-filled)",
                        controller: locationCtrl,
                        readOnly: true,
                      ),

                      _fieldLabel('Monthly Rate'),
                      _buildTextField(
                        Icons.payments,
                        "Enter Monthly Rate",
                        isNumber: true,
                        controller: monthlyCtrl,
                      ),

                      _fieldLabel('Advance Deposit'),
                      _buildTextField(
                        Icons.attach_money,
                        "Enter Advance Deposit",
                        isNumber: true,
                        controller: depositCtrl,
                      ),

                      _fieldLabel('Inclusions'),
                      _buildMultiSelect(
                        icon: Icons.chair,
                        hint: "Choose Inclusion",
                        options: inclusionOptions,
                        selectedValues: inclusions,
                        onConfirm: (selected) =>
                            setState(() => inclusions = selected),
                      ),

                      _fieldLabel('Preference'),
                      _buildMultiSelect(
                        icon: Icons.sell,
                        hint: "Preference",
                        options: preferenceOptions,
                        selectedValues: preferences,
                        onConfirm: (selected) =>
                            setState(() => preferences = selected),
                      ),

                      _fieldLabel('Description'),
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: TextField(
                          controller: descCtrl,
                          maxLines: 8,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: "Description...",
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00324E),
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00324E),
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _saving ? null : _openHotspotEditor,
                        child: const Text(
                          "Hotspot",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00324E),
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _saving ? null : _onSavePressed,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                "Save",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                  fontSize: 18,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- Images grid with hotspot counters ----------
  Widget _buildImagesGrid() {
    final tiles = <Widget>[
      for (int i = 0; i < roomImages.length; i++)
        GestureDetector(
          onTap: () => _replaceImage(i),
          onLongPress: () => _confirmDeleteImage(i),
          child: Stack(
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                  image: DecorationImage(
                    image: roomImages[i].provider(),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(top: 6, right: 6, child: _tinyBadge('#${i + 1}')),
              Positioned(
                bottom: 6,
                right: 6,
                child: _tinyBadge(
                  'HS: ${(hotspotsByImageIndex[i] ?? const []).length}',
                ),
              ),
            ],
          ),
        ),
      InkWell(
        onTap: _pickAndAddImage,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white54),
          ),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_a_photo, color: Colors.white),
                SizedBox(height: 6),
                Text('Add image', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    ];

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(spacing: 10, runSpacing: 10, children: tiles),
    );
  }

  Widget _tinyBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
    );
  }

  Future<void> _pickAndAddImage() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() => roomImages.add(LocalImage(bytes)));
      }
    } catch (_) {}
  }

  Future<void> _replaceImage(int index) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() => roomImages[index] = LocalImage(bytes));
      }
    } catch (_) {}
  }

  Future<void> _confirmDeleteImage(int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove this image?'),
        content: const Text(
          "Hotspots on or pointing to this image will be adjusted.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) _removeImage(index);
  }

  void _removeImage(int index) {
    setState(() {
      roomImages.removeAt(index);
      hotspotsByImageIndex = _remapHotspotsAfterDeletion(
        hotspotsByImageIndex,
        index,
      );
    });
  }

  Map<int, List<Hotspot>> _remapHotspotsAfterDeletion(
    Map<int, List<Hotspot>> src,
    int removedIndex,
  ) {
    final Map<int, List<Hotspot>> out = {};
    for (final entry in src.entries) {
      final key = entry.key;
      if (key == removedIndex) continue;

      final newKey = key > removedIndex ? key - 1 : key;
      final newList = <Hotspot>[];

      for (final h in entry.value) {
        if (h.targetImageIndex == removedIndex) continue;
        final newTarget = h.targetImageIndex > removedIndex
            ? h.targetImageIndex - 1
            : h.targetImageIndex;
        newList.add(h.copyWith(targetImageIndex: newTarget));
      }
      out[newKey] = newList;
    }
    return out;
  }

  Future<void> _onSavePressed() async {
    if (roomImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one panorama.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await _ensureAuth();
      final ok = await _saveToSupabase();
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context, {'saved': true});
      } else {
        setState(() => _saving = false);
      }
    } on _NeedsLogin {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to save this room.')),
      );
      Navigator.push(context, MaterialPageRoute(builder: (_) => const Login()));
    } on AuthApiException catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Auth error: ${e.message}')));
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  Future<bool> _saveToSupabase() async {
    final supabase = _sb;
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Authentication required.')));
      return false;
    }

    String location = locationCtrl.text.trim();
    String aptName = nameCtrl.text.trim();
    if (location.isEmpty || aptName.isEmpty) {
      try {
        final lp = await supabase
            .from('landlord_profile')
            .select('address, apartment_name')
            .eq('user_id', user.id)
            .maybeSingle();
        location = location.isEmpty ? (lp?['address'] ?? '') : location;
        aptName = aptName.isEmpty ? (lp?['apartment_name'] ?? '') : aptName;
      } catch (_) {}
    }

    final monthly = double.tryParse(monthlyCtrl.text.trim());
    final deposit = double.tryParse(depositCtrl.text.trim());
    final floor = int.tryParse(floorCtrl.text.trim());

    final room = await supabase
        .from('rooms')
        .insert({
          'landlord_id': user.id,
          'floor_number': floor,
          'apartment_name': aptName,
          'location': location,
          'monthly_payment': monthly,
          'advance_deposit': deposit,
          'description': descCtrl.text.trim(),
          'status': 'pending',
        })
        .select('id')
        .single();

    final String roomId = room['id'] as String;

    final List<Map<String, dynamic>> imageRows = [];
    for (int i = 0; i < roomImages.length; i++) {
      final li = roomImages[i];
      final path = '$roomId/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';

      await supabase.storage
          .from(kRoomImagesBucket)
          .uploadBinary(
            path,
            li.bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      final publicUrl = supabase.storage
          .from(kRoomImagesBucket)
          .getPublicUrl(path);

      final inserted = await supabase
          .from('room_images')
          .insert({
            'room_id': roomId,
            'sort_order': i,
            'image_url': publicUrl,
            'storage_path': path,
          })
          .select('id, sort_order')
          .single();

      imageRows.add(inserted);
    }

    final Map<int, String> imageIdBySort = {
      for (final r in imageRows) (r['sort_order'] as int): (r['id'] as String),
    };

    for (final entry in hotspotsByImageIndex.entries) {
      final srcIdx = entry.key;
      final srcId = imageIdBySort[srcIdx];
      if (srcId == null) continue;

      for (final h in entry.value) {
        final tgtId = imageIdBySort[h.targetImageIndex];
        if (tgtId == null) continue;

        double lon = h.dx;
        while (lon <= -math.pi) lon += 2 * math.pi;
        while (lon > math.pi) lon -= 2 * math.pi;
        final double lat = _clamp(h.dy, -math.pi / 2, math.pi / 2);

        await supabase.from('hotspots').insert({
          'room_id': roomId,
          'source_image_id': srcId,
          'target_image_id': tgtId,
          'dx': _round(lon, 6),
          'dy': _round(lat, 6),
          'label': h.label,
        });
      }
    }

    if (!mounted) return false;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Room saved to Supabase ✅')));
    return true;
  }

  void _openHotspotEditor() async {
    if (roomImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one panorama first.')),
      );
    } else {
      final result = await Navigator.push<Map<int, List<Hotspot>>>(
        context,
        MaterialPageRoute(
          builder: (_) => HotspotEditorPV(
            images: List<LocalImage>.from(roomImages),
            initialHotspotsByImageIndex: {
              for (final e in hotspotsByImageIndex.entries)
                e.key: List<Hotspot>.from(e.value),
            },
          ),
        ),
      );
      if (result != null) {
        setState(() {
          hotspotsByImageIndex = {
            for (final e in result.entries) e.key: List<Hotspot>.from(e.value),
          };
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Saved hotspots. Total: ${hotspotsByImageIndex.values.fold<int>(0, (p, l) => p + l.length)}',
            ),
          ),
        );
      }
    }
  }

  Widget _buildTextField(
    IconData icon,
    String hint, {
    bool isNumber = false,
    bool readOnly = false,
    required TextEditingController controller,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(6),
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        inputFormatters: isNumber
            ? [FilteringTextInputFormatter.digitsOnly]
            : [],
        decoration: InputDecoration(
          icon: Icon(icon, color: Colors.black54),
          border: InputBorder.none,
          hintText: hint,
        ),
      ),
    );
  }

  Widget _buildMultiSelect({
    required IconData icon,
    required String hint,
    required List<String> options,
    required List<String> selectedValues,
    required ValueChanged<List<String>> onConfirm,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(6),
      ),
      child: InkWell(
        onTap: () async {
          final result = await showDialog<List<String>>(
            context: context,
            builder: (context) {
              final tempSelected = List<String>.from(selectedValues);
              return AlertDialog(
                title: Text(hint),
                content: StatefulBuilder(
                  builder: (context, setStateDialog) {
                    return SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: options.map((option) {
                          return CheckboxListTile(
                            value: tempSelected.contains(option),
                            title: Text(option),
                            onChanged: (checked) {
                              setStateDialog(() {
                                if (checked == true) {
                                  tempSelected.add(option);
                                } else {
                                  tempSelected.remove(option);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, selectedValues),
                    child: const Text("CANCEL"),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, tempSelected),
                    child: const Text("OK"),
                  ),
                ],
              );
            },
          );

          if (result != null) onConfirm(result);
        },
        child: Row(
          children: [
            Icon(icon, color: Colors.black54),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selectedValues.isEmpty ? hint : selectedValues.join(", "),
                style: const TextStyle(color: Colors.black),
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.black54),
          ],
        ),
      ),
    );
  }
}

/* ========= Boxed hotspot editor (panorama_viewer) ========= */

class HotspotEditorPV extends StatefulWidget {
  final List<LocalImage> images;
  final Map<int, List<Hotspot>> initialHotspotsByImageIndex;

  const HotspotEditorPV({
    super.key,
    required this.images,
    required this.initialHotspotsByImageIndex,
  });

  @override
  State<HotspotEditorPV> createState() => _HotspotEditorPVState();
}

class _HotspotEditorPVState extends State<HotspotEditorPV> {
  late Map<int, List<Hotspot>> hotspotsByImageIndex;
  int currentIndex = 0;

  bool addMode = false;

  double _viewLon = 0.0; // yaw
  double _viewLat = 0.0; // pitch
  double _viewTilt = 0.0;

  // Field-of-view model (approx): 180° horizontal, 90° vertical.
  static const double _hFov = math.pi; // 180°
  static const double _vFov = math.pi / 2; // 90°

  @override
  void initState() {
    super.initState();
    hotspotsByImageIndex = {
      for (final e in widget.initialHotspotsByImageIndex.entries)
        e.key: List<Hotspot>.from(e.value),
    };
  }

  List<Hotspot> _spots() =>
      hotspotsByImageIndex[currentIndex] ??
      (hotspotsByImageIndex[currentIndex] = <Hotspot>[]);

  double _wrap(double a) {
    while (a > math.pi) a -= 2 * math.pi;
    while (a < -math.pi) a += 2 * math.pi;
    return a;
  }

  // Proper world-anchored projection:
  // - compute delta to current view center
  // - hide when outside FOV
  // - map delta to screen pixels
  Offset? _projectToOverlay(Size box, double lon, double lat) {
    final dLon = _wrap(lon - _viewLon);
    if (dLon.abs() > _hFov / 2) return null;

    final dLat = (lat - _viewLat).clamp(-math.pi / 2, math.pi / 2);
    if (dLat.abs() > _vFov / 2) return null;

    final x = box.width * (0.5 + dLon / _hFov);
    final y = box.height * (0.5 - dLat / _vFov);
    return Offset(x, y);
  }

  void _toggleAddMode() {
    setState(() => addMode = !addMode);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          addMode
              ? 'Tap inside the panorama to place a hotspot'
              : 'Add mode off',
        ),
      ),
    );
  }

  // INSTANT ADD then edit
  Future<void> _onTapPano(double lon, double lat, double tilt) async {
    if (!addMode) return;

    final newHotspot = Hotspot(
      dx: _wrap(lon),
      dy: lat.clamp(-math.pi / 2, math.pi / 2),
      targetImageIndex: currentIndex,
      label: null,
    );

    final idx = _spots().length;
    setState(() {
      _spots().add(newHotspot);
      addMode = false;
    });

    await _editJustAdded(idx);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Hotspot added')));
    }
  }

  Future<void> _editJustAdded(int idx) async {
    final current = _spots()[idx];
    final t = await _pickTargetImageIndex(
      currentTarget: current.targetImageIndex,
    );
    if (t != null && mounted) {
      setState(
        () => _spots()[idx] = _spots()[idx].copyWith(targetImageIndex: t),
      );
    }

    final lbl = await _askLabel(initial: _spots()[idx].label ?? '');
    if (lbl != null && mounted) {
      setState(() => _spots()[idx] = _spots()[idx].copyWith(label: lbl));
    }
  }

  Future<int?> _pickTargetImageIndex({int? currentTarget}) async {
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Link hotspot to image'),
        content: SizedBox(
          width: 360,
          height: 260,
          child: ListView.builder(
            itemCount: widget.images.length,
            itemBuilder: (context, i) {
              return ListTile(
                leading: SizedBox(
                  width: 48,
                  height: 48,
                  child: widget.images[i].widget(fit: BoxFit.cover),
                ),
                title: Text(
                  'Image ${i + 1}${i == currentIndex ? " (current)" : ""}',
                ),
                subtitle: Text(
                  i == currentTarget ? 'Current target' : 'Tap to select',
                ),
                onTap: () => Navigator.pop(context, i),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<String?> _askLabel({String? initial}) async {
    final controller = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Optional label'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'e.g., “Go to Bed Area”'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () {
              final t = controller.text.trim();
              Navigator.pop(ctx, t.isEmpty ? null : t);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _onMarkerTap(Hotspot h, int idx) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.directions),
              title: const Text('Jump to target'),
              onTap: () => Navigator.pop(ctx, 'jump'),
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit target'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.label),
              title: const Text('Edit label'),
              onTap: () => Navigator.pop(ctx, 'label'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;

    if (action == 'jump') {
      setState(
        () => currentIndex = h.targetImageIndex.clamp(
          0,
          widget.images.length - 1,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Jumped to image ${currentIndex + 1}')),
      );
    } else if (action == 'delete') {
      setState(() => _spots().removeAt(idx));
    } else if (action == 'edit') {
      final newTarget = await _pickTargetImageIndex(
        currentTarget: h.targetImageIndex,
      );
      if (newTarget != null) {
        setState(() => _spots()[idx] = h.copyWith(targetImageIndex: newTarget));
      }
    } else if (action == 'label') {
      final newLabel = await _askLabel(initial: h.label ?? '');
      setState(() => _spots()[idx] = h.copyWith(label: newLabel));
    }
  }

  @override
  Widget build(BuildContext context) {
    final double maxWidth = MediaQuery.of(context).size.width;
    final double boxHeight = (maxWidth / 2.0).clamp(240.0, 460.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Hotspot Editor • Image ${currentIndex + 1}/${widget.images.length}',
        ),
        actions: [
          TextButton(
            onPressed: () {
              final payload = <int, List<Hotspot>>{
                for (final e in hotspotsByImageIndex.entries)
                  e.key: [for (final h in e.value) h],
              };
              Navigator.pop(context, payload);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
        backgroundColor: const Color(0xFF00324E),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: currentIndex > 0
                      ? () => setState(() => currentIndex--)
                      : null,
                ),
                Expanded(
                  child: Center(
                    child: Wrap(
                      spacing: 6,
                      children: List.generate(
                        widget.images.length,
                        (i) => CircleAvatar(
                          radius: 6,
                          backgroundColor: i == currentIndex
                              ? const Color(0xFF00324E)
                              : Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: currentIndex < widget.images.length - 1
                      ? () => setState(() => currentIndex++)
                      : null,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Container(
              height: boxHeight,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black, width: 2),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 8,
                    offset: Offset(0, 2),
                    color: Colors.black26,
                  ),
                ],
              ),
              child: ClipRect(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: PanoramaViewer(
                        longitude: _viewLon,
                        latitude: _viewLat.clamp(-1.2, 1.2),
                        onViewChanged: (lon, lat, tilt) {
                          setState(() {
                            _viewLon = lon;
                            _viewLat = lat;
                            _viewTilt = tilt;
                          });
                        },
                        onTap: (lon, lat, tilt) => _onTapPano(lon, lat, tilt),
                        child: Image.memory(widget.images[currentIndex].bytes),
                      ),
                    ),
                    // overlay markers projected to current view using FOV window
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, b) {
                          final box = Size(b.maxWidth, b.maxHeight);
                          final children = <Widget>[];
                          final spots = _spots();
                          for (int i = 0; i < spots.length; i++) {
                            final h = spots[i];
                            final pos = _projectToOverlay(box, h.dx, h.dy);
                            if (pos == null) continue; // offscreen -> hide
                            children.add(
                              Positioned(
                                left: pos.dx - 24,
                                top: pos.dy - 24,
                                child: GestureDetector(
                                  onTap: () => _onMarkerTap(h, i),
                                  child: _marker(h),
                                ),
                              ),
                            );
                          }
                          return Stack(children: children);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (addMode)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0, top: 8),
              child: Text(
                'Add mode: tap anywhere in the panorama to place a hotspot',
                style: TextStyle(color: Colors.black.withOpacity(0.7)),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleAddMode,
        backgroundColor: addMode ? Colors.red : const Color(0xFF00324E),
        icon: Icon(addMode ? Icons.close : Icons.add_location_alt),
        label: Text(addMode ? 'Cancel' : 'Add Hotspot'),
      ),
    );
  }

  // Big arrow marker so your eyes have no excuses
  Widget _marker(Hotspot h) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if ((h.label ?? '').isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              h.label!,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black38)],
            border: Border.all(color: Colors.black87, width: 2),
          ),
          child: const Center(
            child: Icon(Icons.near_me, size: 26, color: Colors.deepPurple),
          ),
        ),
      ],
    );
  }
}
