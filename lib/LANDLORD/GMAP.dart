// gmap.dart
// Landlord map (MapLibre + MapTiler), loads real panoramas, opens LTour.

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Offset;
import 'dart:ui'
    as ui
    show
        PictureRecorder,
        Canvas,
        Paint,
        Path,
        ImageByteFormat,
        Image,
        PaintingStyle;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'APARTMENT.dart';
import 'Roominfo.dart';
import 'package:smart_finder/LANDLORD/TOUR.dart' show LTour;

class Gmap extends StatefulWidget {
  const Gmap({super.key, required this.roomId});
  final String roomId;

  @override
  State<Gmap> createState() => _GmapState();
}

class _GmapState extends State<Gmap> {
  // MapTiler
  static const String _mapTilerKey = 'dRFWpeKo0QTp5Fv4hdUM';
  static String get _styleUrl =>
      'https://api.maptiler.com/maps/streets/style.json?key=$_mapTilerKey';

  final SupabaseClient _sb = Supabase.instance.client;

  // Map state
  MaplibreMapController? _controller;
  LatLng? _target;
  Symbol? _pin;
  bool _customPinReady = false;
  bool _loadingMapData = true;

  // Header / address
  String _title = 'Apartment';
  String _address = 'Address not provided';
  bool _loadingInfo = true;

  // Real panoramas from room_images
  final List<_NetImage> _images = [];
  bool _loadingImages = true;
  int _hoveredIndex = -1;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _bootstrapInfo(); // title/address (room)
    _bootstrapMap(); // landlord lat/lng + address resolution
    _loadImages(); // room_images
  }

  Future<void> _bootstrapInfo() async {
    try {
      final row = await _sb
          .from('rooms')
          .select('apartment_name, location')
          .eq('id', widget.roomId)
          .maybeSingle();

      if (row != null) {
        final t = (row['apartment_name'] ?? '').toString().trim();
        final a = (row['location'] ?? '').toString().trim();
        setState(() {
          if (t.isNotEmpty) _title = t;
          if (a.isNotEmpty) _address = a;
        });
      }
    } finally {
      if (mounted) setState(() => _loadingInfo = false);
    }
  }

  Future<void> _bootstrapMap() async {
    try {
      final me = _sb.auth.currentUser?.id;

      final roomRow = await _sb
          .from('rooms')
          .select('location')
          .eq('id', widget.roomId)
          .maybeSingle();
      final String? roomLoc = (roomRow?['location'] as String?)?.trim();

      LatLng? pos;
      String? displayAddr;

      if (me != null) {
        final lp = await _sb
            .from('landlord_profile')
            .select('lat, lng, address')
            .eq('user_id', me)
            .maybeSingle();

        final double? lat = (lp?['lat'] as num?)?.toDouble();
        final double? lng = (lp?['lng'] as num?)?.toDouble();
        final String? addr = (lp?['address'] as String?)?.trim();

        if (lat != null && lng != null) {
          pos = LatLng(lat, lng);
          displayAddr = (addr?.isNotEmpty == true) ? addr : roomLoc;
        } else if (addr != null && addr.isNotEmpty) {
          pos = await _geocodePH(addr);
          displayAddr = addr;
        }
      }

      if (pos == null && (roomLoc?.isNotEmpty ?? false)) {
        pos = await _geocodePH(roomLoc!);
        displayAddr = roomLoc;
      }

      pos ??= const LatLng(14.5995, 120.9842);
      displayAddr ??= _address;

      if (!mounted) return;
      setState(() {
        _target = pos;
        _address = displayAddr!;
        _loadingMapData = false;
      });

      if (_controller != null) {
        await _centerAndPin(pos);
      }
    } finally {
      if (mounted) setState(() => _loadingMapData = false);
    }
  }

  Future<void> _loadImages() async {
    try {
      final rows = await _sb
          .from('room_images')
          .select('id, image_url, sort_order, storage_path')
          .eq('room_id', widget.roomId)
          .order('sort_order', ascending: true);

      _images
        ..clear()
        ..addAll([
          for (final r in (rows as List))
            _NetImage(
              id: r['id'] as String,
              url:
                  (r['image_url'] as String?)?.trim() ??
                  (r['storage_path'] != null
                      ? _sb.storage
                            .from('room-images')
                            .getPublicUrl(r['storage_path'] as String)
                      : ''),
            ),
        ]);
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loadingImages = false);
    }
  }

  Future<LatLng?> _geocodePH(String q) async {
    final uri = Uri.parse(
      'https://api.maptiler.com/geocoding/${Uri.encodeComponent(q)}.json?key=$_mapTilerKey&country=PH&language=en',
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body);
    final feats = data['features'] as List? ?? [];
    if (feats.isEmpty) return null;
    final c = (feats.first['center'] as List?) ?? [];
    if (c.length < 2) return null;
    return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
  }

  Future<Uint8List> _makeRedPinBytes({int size = 128}) async {
    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec);
    final w = size.toDouble(), h = size.toDouble();

    final path = ui.Path();
    final cx = w / 2, cy = h * 0.4, r = w * 0.22;
    path.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    final tail = ui.Path()
      ..moveTo(cx - r * 0.75, cy + r * 0.4)
      ..quadraticBezierTo(cx, h * 0.98, cx + r * 0.75, cy + r * 0.4)
      ..close();
    path.addPath(tail, Offset.zero);

    final fill = ui.Paint()..color = const Color(0xFFE53935);
    canvas.drawPath(path, fill);

    final stroke = ui.Paint()
      ..color = const Color(0xFFB71C1C)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = size * 0.045;
    canvas.drawPath(path, stroke);

    final dot = ui.Paint()..color = const Color(0xFF24343A);
    canvas.drawCircle(Offset(cx, cy), r * 0.45, dot);

    final img = await rec.endRecording().toImage(size, size);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  Future<void> _centerAndPin(LatLng at) async {
    await _controller?.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: at, zoom: 16)),
    );
    if (_pin != null) {
      await _controller!.removeSymbol(_pin!);
      _pin = null;
    }
    _pin = await _controller!.addSymbol(
      SymbolOptions(
        geometry: at,
        iconImage: _customPinReady ? 'custom-pin-red' : 'marker-stroked-15',
        iconSize: _customPinReady ? 0.95 : 1.7,
        iconOffset: const Offset(0, -0.75),
        draggable: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double thumbH = 110;

    return Scaffold(
      backgroundColor: const Color(0xFF04395E),
      body: SafeArea(
        child: Column(
          children: [
            // ── Map ──
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  if (_loadingMapData)
                    const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  else
                    MaplibreMap(
                      styleString: _styleUrl,
                      initialCameraPosition: CameraPosition(
                        target: _target ?? const LatLng(14.5995, 120.9842),
                        zoom: 12.5,
                      ),
                      onMapCreated: (ctl) => _controller = ctl,
                      onStyleLoadedCallback: () async {
                        try {
                          final gen = await _makeRedPinBytes(size: 128);
                          await _controller!.addImage('custom-pin-red', gen);
                          _customPinReady = true;
                        } catch (_) {
                          _customPinReady = false;
                        }
                        if (_target != null) {
                          await _centerAndPin(_target!);
                        }
                      },
                      compassEnabled: true,
                      rotateGesturesEnabled: true,
                      tiltGesturesEnabled: true,
                      myLocationEnabled: false,
                    ),

                  // Back
                  Positioned(
                    top: 20,
                    left: 12,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const Apartment()),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.black54, width: 1.5),
                        ),
                        padding: const EdgeInsets.all(6),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Real thumbnails from room_images ──
            Container(
              width: double.infinity,
              color: const Color(0xFF5A7689),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              child: _loadingImages
                  ? const SizedBox(
                      height: 56,
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    )
                  : (_images.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              'No panoramas uploaded yet.',
                              style: TextStyle(color: Colors.white70),
                            ),
                          )
                        : Row(
                            children: List.generate(_images.length, (i) {
                              final img = _images[i];
                              final isHovered = i == _hoveredIndex;
                              final isSelected = i == _selectedIndex;
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6.0,
                                  ),
                                  child: MouseRegion(
                                    onEnter: (_) =>
                                        setState(() => _hoveredIndex = i),
                                    onExit: (_) =>
                                        setState(() => _hoveredIndex = -1),
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() => _selectedIndex = i);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => LTour(
                                              initialIndex: i,
                                              roomId: widget.roomId,
                                              titleHint: _title,
                                              addressHint: _address,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        height: thumbH,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: (isHovered || isSelected)
                                                ? const Color(0xFF1B4678)
                                                : Colors.white24,
                                            width: 3,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            9,
                                          ),
                                          child: Image.network(
                                            img.url,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const ColoredBox(
                                                  color: Colors.black26,
                                                  child: Center(
                                                    child: Icon(
                                                      Icons.broken_image,
                                                      color: Colors.white70,
                                                    ),
                                                  ),
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          )),
            ),

            // ── Address + actions ──
            Container(
              color: const Color(0xFF5A7689),
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _loadingInfo ? 'Loading…' : _title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _address,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SizedBox(
                        width: 180,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF003049),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            // optional: open chat if you want
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LTour(
                                  initialIndex: 0,
                                  roomId: widget.roomId,
                                  titleHint: _title,
                                  addressHint: _address,
                                ),
                              ),
                            );
                          },
                          child: const Text("More Details"),
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF003049),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => Roominfo(roomId: widget.roomId),
                              ),
                            );
                          },
                          child: const Text("Room Info"),
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

class _NetImage {
  final String id;
  final String url;
  _NetImage({required this.id, required this.url});
}
