// ADDROOM.dart
// Uses package:panorama (NOT flutter_panorama).
// Hotspot Editor: horizontal-only pan with HARD STOPS, with “edge wall” overlays.
// Max 180° window; if the source pano is narrower than 2:1, the window shrinks
// so the limits align with the true image tips (no fake wrap).

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:panorama/panorama.dart'; // <-- correct package

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

class AppHotspot {
  // store radians internally (lon=dx, lat=dy)
  final double dx; // [-pi, pi]
  final double dy; // [-pi/2, pi/2]
  final int targetImageIndex;
  final String? label;

  AppHotspot({
    required this.dx,
    required this.dy,
    required this.targetImageIndex,
    this.label,
  });

  AppHotspot copyWith({
    double? dx,
    double? dy,
    int? targetImageIndex,
    String? label,
  }) {
    return AppHotspot(
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

  /// hotspots grouped by panorama index (keeps rooms/panoramas separate)
  Map<int, List<AppHotspot>> hotspotsByImageIndex = {};

  final TextEditingController floorCtrl = TextEditingController();
  final TextEditingController roomNameCtrl = TextEditingController(); // NEW
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
    roomNameCtrl.dispose();
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

                      _fieldLabel('Room Name / Number'), // NEW
                      _buildTextField(
                        Icons.meeting_room,
                        "e.g. Room 101, Bedspace A",
                        controller: roomNameCtrl,
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
    } catch (e, st) {
      debugPrint('pickImage failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Image pick failed: $e')));
    }
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
    } catch (e, st) {
      debugPrint('replaceImage failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Replace failed: $e')));
    }
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

  Map<int, List<AppHotspot>> _remapHotspotsAfterDeletion(
    Map<int, List<AppHotspot>> src,
    int removedIndex,
  ) {
    final Map<int, List<AppHotspot>> out = {};
    for (final entry in src.entries) {
      final key = entry.key;
      if (key == removedIndex) continue;
      final newKey = key > removedIndex ? key - 1 : key;
      final newList = <AppHotspot>[];
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
    final roomName = roomNameCtrl.text.trim(); // NEW

    final room = await supabase
        .from('rooms')
        .insert({
          'landlord_id': user.id,
          'floor_number': floor,
          'room_name': roomName.isEmpty ? null : roomName, // NEW FIELD
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

        double lon = h.dx % (2 * math.pi);
        if (lon <= -math.pi) lon += 2 * math.pi;
        if (lon > math.pi) lon -= 2 * math.pi;

        // store normalized 0..1 (viewer can convert back)
        final double dxDb = _clamp((lon + math.pi) / (2 * math.pi), 0.0, 1.0);
        const double dyDb = 0.0; // vertical locked

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
      return;
    }
    try {
      final result = await Navigator.push<Map<int, List<AppHotspot>>>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (ctx) => HotspotEditor(
            images: List<LocalImage>.from(roomImages),
            initialHotspotsByImageIndex: {
              for (final e in hotspotsByImageIndex.entries)
                e.key: List<AppHotspot>.from(e.value),
            },
          ),
        ),
      );
      if (!mounted) return;
      if (result != null) setState(() => hotspotsByImageIndex = result);
    } catch (e, st) {
      debugPrint('HotspotEditor route failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open hotspot editor: $e')),
      );
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

/* ==================== Hotspot Editor (with 180° hard yaw limits + edge wall) ==================== */

class HotspotEditor extends StatefulWidget {
  final List<LocalImage> images;
  final Map<int, List<AppHotspot>> initialHotspotsByImageIndex;

  const HotspotEditor({
    super.key,
    required this.images,
    required this.initialHotspotsByImageIndex,
  });

  @override
  State<HotspotEditor> createState() => _HotspotEditorState();
}

class _HotspotEditorState extends State<HotspotEditor> {
  late Map<int, List<AppHotspot>> hotspotsByImageIndex;
  int currentIndex = 0;

  // camera (radians)
  double _viewLon = 0.0;

  // vertical locked
  static const double _minLat = 0.0;
  static const double _maxLat = 0.0;

  // optional “straight strip” (UI toggle only)
  bool _useStripMode = false;
  bool _placing = false;

  // cache normalized 2:1 previews + their content fraction
  final Map<int, Future<Uint8List>> _displayBytesFutures = {};
  late List<Size?> _imgSizes;
  final Map<int, double> _contentFracByImage = {}; // 0..1 of real content width

  // tiny margin so we never hit the seam exactly
  static const double _edgeEps = 0.01; // radians ~0.57°

  // Maximum yaw span in radians (π = 180°).
  static const double _maxSpanRad = math.pi;

  // Edge “force field” visuals (radians)
  static const double kEdgeFadeStartDeg = 12.0;
  static final double kEdgeFadeStartRad = kEdgeFadeStartDeg * math.pi / 180.0;
  static const double kEdgeFadeMaxOpacity = 0.85;
  static const double kEdgeBlurSigma = 8.0;

  // --- NEW: overlay key to compute tap x → yaw
  final GlobalKey _viewerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.images.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, <int, List<AppHotspot>>{});
      });
    }
    hotspotsByImageIndex = {
      for (final e in widget.initialHotspotsByImageIndex.entries)
        e.key: List<AppHotspot>.from(e.value),
    };
    _imgSizes = List<Size?>.filled(widget.images.length, null);
    _ensureDecoded(currentIndex);
  }

  List<AppHotspot> _spots() =>
      hotspotsByImageIndex[currentIndex] ?? <AppHotspot>[];

  double _deg(double rad) => rad * 180 / math.pi;
  double _rad(double deg) => deg * math.pi / 180.0;

  double _wrap(double a) {
    while (a > math.pi) a -= 2 * math.pi;
    while (a < -math.pi) a += 2 * math.pi;
    return a;
  }

  // Compute yaw limits for an image from its usable width fraction (centered)
  double _minYawFor(int i) {
    final f = (_contentFracByImage[i] ?? 1.0).clamp(0.0, 1.0);
    final halfSpan = (_maxSpanRad / 2.0) * f;
    return -halfSpan + _edgeEps;
  }

  double _maxYawFor(int i) {
    final f = (_contentFracByImage[i] ?? 1.0).clamp(0.0, 1.0);
    final halfSpan = (_maxSpanRad / 2.0) * f;
    return halfSpan - _edgeEps;
  }

  Future<void> _ensureDecoded(int i) async {
    if (i < 0 || i >= widget.images.length) return;
    if (_imgSizes[i] != null && _contentFracByImage.containsKey(i)) return;
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(
        widget.images[i].bytes,
      );
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ui.Image img = frame.image;
      _imgSizes[i] = Size(img.width.toDouble(), img.height.toDouble());

      // usable fraction for this image relative to a 2:1 canvas:
      final w = img.width.toDouble();
      final h = img.height.toDouble();
      final targetW = h * 2.0;
      final frac = (w / targetW).clamp(0.0, 1.0);
      _contentFracByImage[i] = (w >= targetW) ? 1.0 : frac;

      img.dispose();
      codec.dispose();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<Uint8List> _displayBytesFor(int i) {
    return _displayBytesFutures.putIfAbsent(i, () async {
      final Uint8List src = widget.images[i].bytes;
      final ui.Codec codec = await ui.instantiateImageCodec(src);
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ui.Image img = frame.image;
      final int w = img.width, h = img.height;

      final int targetW = h * 2; // 2:1 canvas
      final int targetH = h;

      final ui.PictureRecorder rec = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(rec);
      final paint = ui.Paint();

      // fill canvas (hidden by limits, but safe)
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, targetW.toDouble(), targetH.toDouble()),
        ui.Paint()..color = const Color(0xFF0E1116),
      );

      final double ar = w / h;
      if (ar >= 2.0) {
        // Source wider/equal → center-crop to 2:1
        final double cropW = 2.0 * h;
        final double left = (w - cropW) / 2.0;
        canvas.drawImageRect(
          img,
          ui.Rect.fromLTWH(left, 0, cropW, h.toDouble()),
          ui.Rect.fromLTWH(0, 0, targetW.toDouble(), targetH.toDouble()),
          paint,
        );
        _contentFracByImage[i] = 1.0;
      } else {
        // Source narrower → center, record usable fraction
        final double drawW = w.toDouble();
        final double dx = (targetW - drawW) / 2.0;
        canvas.drawImageRect(
          img,
          ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
          ui.Rect.fromLTWH(dx, 0, drawW, targetH.toDouble()),
          paint,
        );
        _contentFracByImage[i] = (drawW / targetW).clamp(0.0, 1.0);
      }

      final ui.Picture pic = rec.endRecording();
      final ui.Image out = await pic.toImage(targetW, targetH);
      final bytes = (await out.toByteData(format: ui.ImageByteFormat.png))!;
      out.dispose();
      img.dispose();
      codec.dispose();
      return bytes.buffer.asUint8List();
    });
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
                  child: FutureBuilder<Uint8List>(
                    future: _displayBytesFor(i),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const ColoredBox(color: Colors.black12);
                      }
                      return Image.memory(snap.data!, fit: BoxFit.cover);
                    },
                  ),
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
    final c = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Optional label'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(hintText: 'e.g., “Go to Door”'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              ctx,
              c.text.trim().isEmpty ? null : c.text.trim(),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _placeHotspotAt(double lonRad) async {
    final target = await _pickTargetImageIndex();
    if (target == null) {
      setState(() => _placing = false);
      return;
    }
    final label = await _askLabel();
    setState(() {
      final list = _spots();
      final minYaw = _minYawFor(currentIndex);
      final maxYaw = _maxYawFor(currentIndex);
      final clampedLon = lonRad.clamp(minYaw, maxYaw).toDouble();
      list.add(
        AppHotspot(
          dx: _wrap(clampedLon),
          dy: 0.0, // vertical locked
          targetImageIndex: target,
          label: label,
        ),
      );
      hotspotsByImageIndex[currentIndex] = List.from(list);
      _placing = false;
    });
  }

  Future<void> _placeHotspotAtCenter() => _placeHotspotAt(_viewLon);

  void _deleteHotspot(int idx) {
    setState(() {
      final list = _spots();
      if (idx >= 0 && idx < list.length) list.removeAt(idx);
      hotspotsByImageIndex[currentIndex] = List.from(list);
    });
  }

  void _onHotspotPressed(AppHotspot h) {
    setState(() {
      currentIndex = h.targetImageIndex.clamp(0, widget.images.length - 1);
      _ensureDecoded(currentIndex);
      final mid = (_minYawFor(currentIndex) + _maxYawFor(currentIndex)) / 2.0;
      _viewLon = mid;
    });
  }

  Future<void> _onHotspotLongPress(int idx, AppHotspot h) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.navigation),
              title: const Text('Jump to target'),
              onTap: () => Navigator.pop(ctx, 'jump'),
            ),
            ListTile(
              leading: const Icon(Icons.label),
              title: const Text('Edit label'),
              onTap: () => Navigator.pop(ctx, 'label'),
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit target'),
              onTap: () => Navigator.pop(ctx, 'edit'),
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
      _onHotspotPressed(h);
    } else if (action == 'delete') {
      _deleteHotspot(idx);
    } else if (action == 'edit') {
      final t = await _pickTargetImageIndex(currentTarget: h.targetImageIndex);
      if (t != null) {
        final list = _spots();
        list[idx] = h.copyWith(targetImageIndex: t);
        setState(() => hotspotsByImageIndex[currentIndex] = List.from(list));
      }
    } else if (action == 'label') {
      final lbl = await _askLabel(initial: h.label);
      final list = _spots();
      list[idx] = h.copyWith(label: lbl);
      setState(() => hotspotsByImageIndex[currentIndex] = List.from(list));
    }
  }

  // Edge-wall opacity helpers (radians)
  double _leftEdgeOpacity(double lon, double minYaw) {
    final d = (lon - minYaw).clamp(0.0, kEdgeFadeStartRad);
    final t = 1.0 - (d / kEdgeFadeStartRad);
    return (t * kEdgeFadeMaxOpacity).clamp(0.0, kEdgeFadeMaxOpacity);
  }

  double _rightEdgeOpacity(double lon, double maxYaw) {
    final d = (maxYaw - lon).clamp(0.0, kEdgeFadeStartRad);
    final t = 1.0 - (d / kEdgeFadeStartRad);
    return (t * kEdgeFadeMaxOpacity).clamp(0.0, kEdgeFadeMaxOpacity);
  }

  String _fmtRad(num r) =>
      '${r.toStringAsFixed(3)} rad (${(r * 180 / math.pi).toStringAsFixed(1)}°)';

  @override
  Widget build(BuildContext context) {
    final clampedIndex = currentIndex.clamp(0, widget.images.length - 1);
    if (clampedIndex != currentIndex) currentIndex = clampedIndex;
    final spots = _spots();

    // fixed viewer height = 160
    const double panoHeight = 160.0;

    // dynamic yaw limits for current image
    final minYaw = _minYawFor(currentIndex);
    final maxYaw = _maxYawFor(currentIndex);

    // keep the camera inside safe window
    _viewLon = _viewLon.clamp(minYaw, maxYaw);

    // precompute edge-wall opacity (for curved mode)
    final leftOpacity = _leftEdgeOpacity(_viewLon, minYaw);
    final rightOpacity = _rightEdgeOpacity(_viewLon, maxYaw);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF00324E),
        elevation: 0,
        title: Row(
          children: [
            const SizedBox(width: 8),
            const Text('Hotspot Editor'),
            const Spacer(),
            IconButton(
              tooltip: _useStripMode
                  ? 'Switch to curved panorama'
                  : 'Switch to straight strip',
              onPressed: () => setState(() => _useStripMode = !_useStripMode),
              icon: Icon(
                _useStripMode ? Icons.panorama_photosphere : Icons.straighten,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ======= Viewer (curved or straight) =======
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Card(
              color: const Color(0xFF0F1B2B),
              elevation: 8,
              shadowColor: Colors.black45,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  key: _viewerKey,
                  height: panoHeight,
                  width: double.infinity,
                  child: FutureBuilder<Uint8List>(
                    future: _displayBytesFor(currentIndex),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (_useStripMode) {
                        // STRAIGHT STRIP: flat image; horizontal scroll (clamped physics).
                        return ScrollConfiguration(
                          behavior: const ScrollBehavior().copyWith(
                            scrollbars: false,
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const ClampingScrollPhysics(),
                            child: SizedBox(
                              height: panoHeight,
                              child: Image.memory(
                                snap.data!,
                                height: panoHeight,
                                fit: BoxFit.fitHeight,
                                filterQuality: FilterQuality.high,
                              ),
                            ),
                          ),
                        );
                      }

                      // CURVED PANORAMA with HARD yaw limits and edge walls
                      return Stack(
                        children: [
                          Panorama(
                            sensorControl: SensorControl.None,
                            longitude: _deg(_viewLon),
                            latitude: 0, // lock vertical
                            animSpeed: 0.0, // no fling
                            minLongitude: _deg(minYaw), // hard stops
                            maxLongitude: _deg(maxYaw),
                            minLatitude: _minLat,
                            maxLatitude: _maxLat,
                            minZoom: 0.9,
                            maxZoom: 0.9,

                            // ✅ Use the engine’s precise hit-test for yaw
                            onTap: (lonDeg, latDeg, tiltDeg) {
                              if (!_placing) return;
                              if (!lonDeg.isFinite) return;
                              final lonRad = _rad(lonDeg);
                              final clamped = lonRad
                                  .clamp(minYaw, maxYaw)
                                  .toDouble();
                              _placeHotspotAt(clamped);
                            },

                            onViewChanged: (lon, lat, tilt) {
                              if (!lon.isFinite) return;
                              final lonRad = (lon * math.pi / 180).clamp(
                                minYaw,
                                maxYaw,
                              );
                              if (lonRad != _viewLon && mounted) {
                                setState(() => _viewLon = lonRad.toDouble());
                              }
                            },

                            child: Image.memory(
                              snap.data!,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.high,
                            ),

                            hotspots: [
                              for (int i = 0; i < spots.length; i++)
                                Hotspot(
                                  longitude: _deg(spots[i].dx),
                                  latitude: 0,
                                  width: 52,
                                  height: 38,
                                  widget: GestureDetector(
                                    onTap: () => _onHotspotPressed(spots[i]),
                                    onLongPress: () =>
                                        _onHotspotLongPress(i, spots[i]),
                                    child: _stickyButton(spots[i]),
                                  ),
                                ),
                            ],
                          ),

                          // Edge “force field” overlays
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 32,
                                    child: AnimatedOpacity(
                                      opacity: leftOpacity,
                                      duration: const Duration(
                                        milliseconds: 80,
                                      ),
                                      child: ClipRect(
                                        child: BackdropFilter(
                                          filter: ui.ImageFilter.blur(
                                            sigmaX: kEdgeBlurSigma,
                                            sigmaY: kEdgeBlurSigma,
                                          ),
                                          child: Container(
                                            decoration: const BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.centerLeft,
                                                end: Alignment.centerRight,
                                                colors: [
                                                  Colors.black45,
                                                  Colors.transparent,
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Expanded(child: SizedBox()),
                                  SizedBox(
                                    width: 32,
                                    child: AnimatedOpacity(
                                      opacity: rightOpacity,
                                      duration: const Duration(
                                        milliseconds: 80,
                                      ),
                                      child: ClipRect(
                                        child: BackdropFilter(
                                          filter: ui.ImageFilter.blur(
                                            sigmaX: kEdgeBlurSigma,
                                            sigmaY: kEdgeBlurSigma,
                                          ),
                                          child: Container(
                                            decoration: const BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.centerRight,
                                                end: Alignment.centerLeft,
                                                colors: [
                                                  Colors.black45,
                                                  Colors.transparent,
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // ======= Thumbnails =======
          SizedBox(
            height: 86,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: widget.images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (ctx, i) {
                final selected = i == currentIndex;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      currentIndex = i;
                      _ensureDecoded(currentIndex);
                      final center =
                          (_minYawFor(currentIndex) +
                              _maxYawFor(currentIndex)) /
                          2.0;
                      _viewLon = center;
                    });
                  },
                  child: FutureBuilder<Uint8List>(
                    future: _displayBytesFor(i),
                    builder: (context, snap) {
                      Widget child;
                      if (!snap.hasData) {
                        child = const SizedBox(width: 120, height: 70);
                      } else {
                        child = Image.memory(
                          snap.data!,
                          width: 120,
                          height: 70,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                        );
                      }
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 130,
                        height: 74,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                selected ? .25 : .12,
                              ),
                              blurRadius: selected ? 8 : 4,
                            ),
                          ],
                          border: Border.all(
                            color: selected
                                ? const Color(0xFF3F8EF1)
                                : Colors.black26,
                            width: selected ? 2.2 : 1.0,
                          ),
                          color: Colors.black12,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: child,
                      );
                    },
                  ),
                );
              },
            ),
          ),

          // ======= Hotspot list =======
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: _spots().isEmpty
                  ? const Center(
                      child: Text(
                        'No hotspots yet. Tap “Add Hotspot”, then tap the viewer.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _spots().length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final h = _spots()[i];
                        return ListTile(
                          leading: const Icon(Icons.place),
                          title: Text(
                            h.label?.isNotEmpty == true
                                ? h.label!
                                : 'Hotspot ${i + 1}',
                          ),
                          subtitle: Text(
                            'Target: Image ${h.targetImageIndex + 1} • dx: ${_fmtRad(h.dx)} • dy: 0',
                          ),
                          onTap: () => _onHotspotPressed(h),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'jump') {
                                _onHotspotPressed(h);
                              } else if (v == 'editTarget') {
                                final t = await _pickTargetImageIndex(
                                  currentTarget: h.targetImageIndex,
                                );
                                if (t != null) {
                                  final list = _spots();
                                  list[i] = h.copyWith(targetImageIndex: t);
                                  setState(
                                    () => hotspotsByImageIndex[currentIndex] =
                                        List.from(list),
                                  );
                                }
                              } else if (v == 'editLabel') {
                                final lbl = await _askLabel(initial: h.label);
                                final list = _spots();
                                list[i] = h.copyWith(label: lbl);
                                setState(
                                  () => hotspotsByImageIndex[currentIndex] =
                                      List.from(list),
                                );
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

          // ======= Bottom bar =======
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() => _placing = !_placing);
                        if (_placing) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Tap the viewer to place a hotspot.',
                              ),
                            ),
                          );
                        }
                      },
                      icon: Icon(_placing ? Icons.close : Icons.my_location),
                      label: Text(_placing ? 'Cancel placing' : 'Add Hotspot'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (_placing)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ElevatedButton.icon(
                        onPressed: _placeHotspotAtCenter,
                        icon: const Icon(Icons.add_location_alt),
                        label: const Text('Place at center'),
                      ),
                    ),
                  ElevatedButton(
                    onPressed: () =>
                        Navigator.pop(context, hotspotsByImageIndex),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Sticky clickable UI
  Widget _stickyButton(AppHotspot h) {
    final label = (h.label == null || h.label!.isEmpty) ? 'Go' : h.label!;
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 6,
        backgroundColor: const Color(0xFF3F51B5),
        foregroundColor: Colors.white,
      ),
      onPressed: () => _onHotspotPressed(h),
      icon: const Icon(Icons.place, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}
