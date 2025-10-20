// addroom.dart
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:panorama_viewer/panorama_viewer.dart'; // ✅ swapped in
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smart_finder/LANDLORD/LOGIN.dart';

class _NeedsLogin implements Exception {
  const _NeedsLogin();
  @override
  String toString() => '_NeedsLogin';
}

/// Make sure this storage bucket exists and is PUBLIC in Supabase.
const String kRoomImagesBucket = 'room-images';

class LocalImage {
  final Uint8List bytes;
  LocalImage(this.bytes);
  ImageProvider provider() => MemoryImage(bytes);
  Widget widget({double? width, double? height, BoxFit fit = BoxFit.cover}) =>
      Image.memory(bytes, width: width, height: height, fit: fit);
}

class Hotspot {
  final double dx; // radians (longitude)
  final double dy; // radians (latitude)
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

  /// Hotspots keyed by *source* image index.
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
    _loadLandlordInfo(); // auto-fill apartment name + address
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

  /// Fetch landlord address + default apartment name.
  /// First try landlord_profile; fallback to users table (per your ERD).
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
    } catch (e) {
      debugPrint('Failed to load landlord profile: $e');
    }
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

  // ---- small helper: label widget (so we don't touch existing functions)
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
                      // ---- Images
                      _fieldLabel('Room Images / Panoramas'),
                      _buildImagesGrid(),
                      const SizedBox(height: 20),

                      // ---- Floor number
                      _fieldLabel('Floor Number'),
                      _buildTextField(
                        Icons.stairs,
                        "Enter Floor Number",
                        isNumber: true,
                        controller: floorCtrl,
                      ),

                      // ---- Apartment name (auto)
                      _fieldLabel('Apartment Name'),
                      _buildTextField(
                        Icons.apartment,
                        "Apartment Name (auto-filled)",
                        controller: nameCtrl,
                        readOnly: true, // set to false if you want it editable
                      ),

                      // ---- Address (auto)
                      _fieldLabel('Address'),
                      _buildTextField(
                        Icons.location_on,
                        "Landlord Address (auto-filled)",
                        controller: locationCtrl,
                        readOnly: true, // set to false if you want it editable
                      ),

                      // ---- Monthly rate
                      _fieldLabel('Monthly Rate'),
                      _buildTextField(
                        Icons.payments,
                        "Enter Monthly Rate",
                        isNumber: true,
                        controller: monthlyCtrl,
                      ),

                      // ---- Advance deposit
                      _fieldLabel('Advance Deposit'),
                      _buildTextField(
                        Icons.attach_money,
                        "Enter Advance Deposit",
                        isNumber: true,
                        controller: depositCtrl,
                      ),

                      // ---- Inclusion
                      _fieldLabel('Inclusions'),
                      _buildMultiSelect(
                        icon: Icons.chair,
                        hint: "Choose Inclusion",
                        options: inclusionOptions,
                        selectedValues: inclusions,
                        onConfirm: (selected) =>
                            setState(() => inclusions = selected),
                      ),

                      // ---- Preference
                      _fieldLabel('Preference'),
                      _buildMultiSelect(
                        icon: Icons.sell,
                        hint: "Preference",
                        options: preferenceOptions,
                        selectedValues: preferences,
                        onConfirm: (selected) =>
                            setState(() => preferences = selected),
                      ),

                      // ---- Description
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

  // ---------- Images grid ----------
  Widget _buildImagesGrid() {
    final tiles = <Widget>[
      for (int i = 0; i < roomImages.length; i++)
        GestureDetector(
          onTap: () => _replaceImage(i),
          onLongPress: () => _confirmDeleteImage(i),
          child: Container(
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
            child: Align(
              alignment: Alignment.topRight,
              child: Container(
                margin: const EdgeInsets.all(6),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '#${i + 1}',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
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

    // Ensure we have latest landlord info (guard against cleared text)
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

    // 1) Create room (status defaults to 'pending')
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
          'status': 'pending', // important
        })
        .select('id')
        .single();

    final String roomId = room['id'] as String;

    // 2) Upload images + insert room_images
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

    // sort_order -> image_id
    final Map<int, String> imageIdBySort = {
      for (final r in imageRows) (r['sort_order'] as int): (r['id'] as String),
    };

    // 3) Insert hotspots: radians -> normalized [0,1] for DB
    for (final entry in hotspotsByImageIndex.entries) {
      final srcIdx = entry.key;
      final srcId = imageIdBySort[srcIdx];
      if (srcId == null) continue;

      for (final h in entry.value) {
        final tgtId = imageIdBySort[h.targetImageIndex];
        if (tgtId == null) continue;

        // normalize
        double lon = h.dx % (2 * math.pi);
        if (lon <= -math.pi) lon += 2 * math.pi;
        if (lon > math.pi) lon -= 2 * math.pi;
        final double lat = _clamp(h.dy, -math.pi / 2, math.pi / 2);

        final double dxDb = _clamp((lon + math.pi) / (2 * math.pi), 0.0, 1.0);
        final double dyDb = _clamp((lat + math.pi / 2) / math.pi, 0.0, 1.0);

        await supabase.from('hotspots').insert({
          'room_id': roomId,
          'source_image_id': srcId,
          'target_image_id': tgtId,
          'dx': _round(dxDb, 6),
          'dy': _round(dyDb, 6),
          'label': h.label,
        });
      }
    }

    // 4) Inclusions
    if (inclusions.isNotEmpty) {
      final incList =
          await supabase
                  .from('inclusion_options')
                  .select('id,name')
                  .or(_orEq('name', inclusions))
              as List;
      for (final o in incList) {
        await supabase.from('room_inclusions').insert({
          'room_id': roomId,
          'inclusion_id': o['id'],
        });
      }
    }

    // 5) Preferences
    if (preferences.isNotEmpty) {
      final prefList =
          await supabase
                  .from('preference_options')
                  .select('id,name')
                  .or(_orEq('name', preferences))
              as List;
      for (final o in prefList) {
        await supabase.from('room_preferences').insert({
          'room_id': roomId,
          'preference_id': o['id'],
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
          builder: (_) => HotspotEditor(
            images: List<LocalImage>.from(roomImages),
            initialHotspotsByImageIndex: {
              for (final e in hotspotsByImageIndex.entries)
                e.key: List<Hotspot>.from(e.value),
            },
          ),
        ),
      );
      if (result != null) setState(() => hotspotsByImageIndex = result);
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

class HotspotEditor extends StatefulWidget {
  final List<LocalImage> images;
  final Map<int, List<Hotspot>> initialHotspotsByImageIndex;

  const HotspotEditor({
    super.key,
    required this.images,
    required this.initialHotspotsByImageIndex,
  });

  @override
  State<HotspotEditor> createState() => _HotspotEditorState();
}

class _HotspotEditorState extends State<HotspotEditor> {
  late Map<int, List<Hotspot>> hotspotsByImageIndex;
  int currentIndex = 0;

  // Which hotspot within current image is selected for editing
  int? selectedHotspotIdx;

  late List<Size?> _imgSizes;

  @override
  void initState() {
    super.initState();
    hotspotsByImageIndex = {
      for (final e in widget.initialHotspotsByImageIndex.entries)
        e.key: List<Hotspot>.from(e.value),
    };
    _imgSizes = List<Size?>.filled(widget.images.length, null);
    _ensureDecoded(currentIndex);
  }

  List<Hotspot> _hotspotsForCurrent() =>
      hotspotsByImageIndex[currentIndex] ?? <Hotspot>[];

  Future<void> _ensureDecoded(int i) async {
    if (_imgSizes[i] != null) return;
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(
        widget.images[i].bytes,
      );
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ui.Image img = frame.image;
      _imgSizes[i] = Size(img.width.toDouble(), img.height.toDouble());
      img.dispose();
      codec.dispose();
      if (mounted) setState(() {});
    } catch (_) {}
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

  Future<void> _addHotspotFlow() async {
    final target = await _pickTargetImageIndex();
    if (target == null) return;
    final label = await _askLabel();

    setState(() {
      final list = _hotspotsForCurrent();
      list.add(
        Hotspot(
          dx: 0.0, // radians (longitude)
          dy: 0.0, // radians (latitude)
          targetImageIndex: target,
          label: label,
        ),
      );
      hotspotsByImageIndex[currentIndex] = List.from(list);
      selectedHotspotIdx = list.length - 1;
    });
  }

  void _deleteHotspot(int idx) {
    setState(() {
      final list = _hotspotsForCurrent();
      list.removeAt(idx);
      hotspotsByImageIndex[currentIndex] = List.from(list);
      if (selectedHotspotIdx != null) {
        if (list.isEmpty) {
          selectedHotspotIdx = null;
        } else {
          selectedHotspotIdx = (selectedHotspotIdx!.clamp(0, list.length - 1));
        }
      }
    });
  }

  String _fmtRad(num r) =>
      '${r.toStringAsFixed(3)} rad (${(r * 180 / math.pi).toStringAsFixed(1)}°)';

  @override
  Widget build(BuildContext context) {
    final spots = _hotspotsForCurrent();
    final hasSelection =
        selectedHotspotIdx != null &&
        selectedHotspotIdx! >= 0 &&
        selectedHotspotIdx! < spots.length;
    final selected = hasSelection ? spots[selectedHotspotIdx!] : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Hotspot Editor • Image ${currentIndex + 1}/${widget.images.length}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, hotspotsByImageIndex),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
        backgroundColor: const Color(0xFF00324E),
      ),
      body: Column(
        children: [
          // --- Top: Image index controls
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: currentIndex > 0
                      ? () => setState(() {
                          currentIndex--;
                          _ensureDecoded(currentIndex);
                          selectedHotspotIdx = null;
                        })
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
                      ? () => setState(() {
                          currentIndex++;
                          _ensureDecoded(currentIndex);
                          selectedHotspotIdx = null;
                        })
                      : null,
                ),
              ],
            ),
          ),

          // --- Panorama viewer (no hotspot overlay; viewer only)
          LayoutBuilder(
            builder: (context, constraints) {
              final Size? natural = _imgSizes[currentIndex];
              final double width = constraints.maxWidth - 16;
              double height;
              if (natural != null && natural.width > 0 && natural.height > 0) {
                height = width * (natural.height / natural.width);
              } else {
                height = 260;
                _ensureDecoded(currentIndex);
              }
              height = height.clamp(180.0, 520.0);

              return SizedBox(
                height: height,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.05),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: PanoramaViewer(
                        child: Image.memory(
                          widget.images[currentIndex].bytes,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // --- List of hotspots for this image
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: spots.isEmpty
                  ? const Center(
                      child: Text(
                        'No hotspots yet. Tap “Add Hotspot” to create one.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    )
                  : ListView.separated(
                      itemCount: spots.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final h = spots[i];
                        return ListTile(
                          leading: const Icon(Icons.place),
                          title: Text(
                            h.label?.isNotEmpty == true
                                ? h.label!
                                : 'Hotspot ${i + 1}',
                          ),
                          subtitle: Text(
                            'Target: Image ${h.targetImageIndex + 1} • '
                            'dx: ${_fmtRad(h.dx)} • dy: ${_fmtRad(h.dy)}',
                          ),
                          selected: selectedHotspotIdx == i,
                          onTap: () => setState(() => selectedHotspotIdx = i),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'jump') {
                                setState(() {
                                  currentIndex = h.targetImageIndex.clamp(
                                    0,
                                    widget.images.length - 1,
                                  );
                                  _ensureDecoded(currentIndex);
                                  selectedHotspotIdx = null;
                                });
                              } else if (v == 'editTarget') {
                                final t = await _pickTargetImageIndex(
                                  currentTarget: h.targetImageIndex,
                                );
                                if (t != null) {
                                  setState(() {
                                    spots[i] = h.copyWith(targetImageIndex: t);
                                    hotspotsByImageIndex[currentIndex] =
                                        List.from(spots);
                                  });
                                }
                              } else if (v == 'editLabel') {
                                final lbl = await _askLabel(
                                  initial: h.label ?? '',
                                );
                                setState(() {
                                  spots[i] = h.copyWith(label: lbl);
                                  hotspotsByImageIndex[currentIndex] =
                                      List.from(spots);
                                });
                              } else if (v == 'delete') {
                                _deleteHotspot(i);
                              }
                            },
                            itemBuilder: (ctx) => const [
                              PopupMenuItem(
                                value: 'jump',
                                child: Text('Jump to target'),
                              ),
                              PopupMenuItem(
                                value: 'editTarget',
                                child: Text('Edit target'),
                              ),
                              PopupMenuItem(
                                value: 'editLabel',
                                child: Text('Edit label'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),

          // --- Sliders for selected hotspot (radian ranges)
          if (hasSelection)
            Container(
              width: double.infinity,
              color: Colors.grey.shade100,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Adjust ${(selected!.label?.isNotEmpty ?? false) ? selected.label! : "Hotspot ${selectedHotspotIdx! + 1}"}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      const SizedBox(width: 86, child: Text('Longitude')),
                      Expanded(
                        child: Slider(
                          value: selected.dx,
                          min: -math.pi,
                          max: math.pi,
                          label: _fmtRad(selected.dx),
                          onChanged: (v) {
                            setState(() {
                              final spots = _hotspotsForCurrent();
                              spots[selectedHotspotIdx!] = selected.copyWith(
                                dx: v,
                              );
                              hotspotsByImageIndex[currentIndex] = List.from(
                                spots,
                              );
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const SizedBox(width: 86, child: Text('Latitude')),
                      Expanded(
                        child: Slider(
                          value: selected.dy,
                          min: -math.pi / 2,
                          max: math.pi / 2,
                          label: _fmtRad(selected.dy),
                          onChanged: (v) {
                            setState(() {
                              final spots = _hotspotsForCurrent();
                              spots[selectedHotspotIdx!] = selected.copyWith(
                                dy: v,
                              );
                              hotspotsByImageIndex[currentIndex] = List.from(
                                spots,
                              );
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),

      // Add Hotspot
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addHotspotFlow,
        backgroundColor: const Color(0xFF00324E),
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Add Hotspot'),
      ),
    );
  }
}
