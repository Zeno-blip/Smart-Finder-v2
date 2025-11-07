// LANDLORD/TOUR.dart
// LTour: Landlord panorama viewer with hotspots + room info panel (no room_size).

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:panorama/panorama.dart';
import 'package:smart_finder/LANDLORD/ROOMINFO.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class LTour extends StatefulWidget {
  final int initialIndex;
  final String roomId;
  final String? titleHint;
  final String? addressHint;

  const LTour({
    super.key,
    required this.initialIndex,
    required this.roomId,
    this.titleHint,
    this.addressHint,
  });

  @override
  State<LTour> createState() => _LTourState();
}

class _LTourState extends State<LTour> {
  final _sb = Supabase.instance.client;

  final List<_NetImage> _images = [];
  final Map<String, int> _indexById = {};
  final Map<int, List<_HS>> _hotspotsByIndex = {};

  int _currentIndex = 0;
  bool _loading = true;
  String? _error;

  // Room info (use only columns that exist in rooms)
  String? _title;
  String? _address;
  num? _monthly;
  num? _advance;
  String? _status;
  int? _floor;
  String? _desc;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _load();
  }

  double _degToRad(num d) => d.toDouble() * math.pi / 180.0;
  double _radToDeg(num r) => r.toDouble() * 180.0 / math.pi;

  double _normLon(double r) {
    while (r > math.pi) r -= 2 * math.pi;
    while (r < -math.pi) r += 2 * math.pi;
    return r;
  }

  double _clampLat(double r) => r.clamp(-math.pi / 2, math.pi / 2);

  double? _toRadiansAuto(num? v, {required bool isLat}) {
    if (v == null) return null;
    final d = v.toDouble();
    final radLimit = isLat ? (math.pi / 2 + 1e-6) : (math.pi + 1e-6);
    if (d.abs() <= radLimit) return isLat ? _clampLat(d) : _normLon(d);
    final r = _degToRad(d);
    return isLat ? _clampLat(r) : _normLon(r);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // 1) images
      final imgs = await _sb
          .from('room_images')
          .select('id,image_url,sort_order,storage_path')
          .eq('room_id', widget.roomId)
          .order('sort_order', ascending: true);

      _images
        ..clear()
        ..addAll([
          for (final r in (imgs as List))
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

      _indexById
        ..clear()
        ..addEntries(
          _images.asMap().entries.map((e) => MapEntry(e.value.id, e.key)),
        );

      // 2) hotspots
      _hotspotsByIndex.clear();
      if (_images.isNotEmpty) {
        final hsRows = await _sb
            .from('hotspots')
            .select('source_image_id,target_image_id,dx,dy,label')
            .eq('room_id', widget.roomId);

        for (final r in (hsRows as List)) {
          final srcId = r['source_image_id'] as String?;
          final tgtId = r['target_image_id'] as String?;
          if (srcId == null || tgtId == null) continue;

          final srcIdx = _indexById[srcId];
          final tgtIdx = _indexById[tgtId];
          if (srcIdx == null || tgtIdx == null) continue;

          final lon = _toRadiansAuto(r['dx'] as num?, isLat: false);
          final lat = _toRadiansAuto(r['dy'] as num?, isLat: true);
          if (lon == null || lat == null) continue;

          final hs = _HS(
            longitude: _normLon(lon),
            latitude: _clampLat(lat),
            targetIndex: tgtIdx,
            label: (r['label'] as String?),
          );
          _hotspotsByIndex.putIfAbsent(srcIdx, () => []).add(hs);
        }
      }

      // 3) room info (NO room_size here)
      final room = await _sb
          .from('rooms')
          .select(
            'apartment_name, location, monthly_payment, advance_deposit, '
            'status, floor_number, description, availability_status',
          )
          .eq('id', widget.roomId)
          .maybeSingle();

      if (room != null) {
        _title = (room['apartment_name'] as String?)?.trim();
        _address = (room['location'] as String?)?.trim();
        _monthly = room['monthly_payment'] as num?;
        _advance = room['advance_deposit'] as num?;
        _status =
            (room['availability_status'] as String?) ??
            (room['status'] as String?);
        _floor = (room['floor_number'] as int?);
        _desc = (room['description'] as String?);
      }

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to load tour: $e';
      });
    }
  }

  void _goTo(int index) {
    setState(() => _currentIndex = index.clamp(0, _images.length - 1));
  }

  void _openRoomInfo() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => Roominfo(roomId: widget.roomId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A3D62),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : (_error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        // Panorama
                        Expanded(
                          flex: 3,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: (_images.isEmpty)
                                    ? const Center(
                                        child: Text(
                                          'No panoramas yet.',
                                          style: TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      )
                                    : Panorama(
                                        sensorControl:
                                            SensorControl.Orientation,
                                        animSpeed: 0.5,
                                        child: Image.network(
                                          _images[_currentIndex].url,
                                          fit: BoxFit.cover,
                                        ),
                                        hotspots: [
                                          for (final hs
                                              in _hotspotsByIndex[_currentIndex] ??
                                                  const <_HS>[])
                                            Hotspot(
                                              longitude: _radToDeg(
                                                hs.longitude,
                                              ),
                                              latitude: _radToDeg(hs.latitude),
                                              width: 60,
                                              height: 60,
                                              widget: GestureDetector(
                                                onDoubleTap: () =>
                                                    _goTo(hs.targetIndex),
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    if ((hs.label ?? '')
                                                        .isNotEmpty)
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 4,
                                                            ),
                                                        margin:
                                                            const EdgeInsets.only(
                                                              bottom: 6,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.black54,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                6,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          hs.label!,
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 11,
                                                              ),
                                                        ),
                                                      ),
                                                    const Icon(
                                                      Icons.place,
                                                      color: Colors.redAccent,
                                                      size: 40,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                              ),
                              // Back
                              Positioned(
                                top: 20,
                                left: 12,
                                child: GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(8),
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

                        // Bottom info
                        Container(
                          width: double.infinity,
                          color: const Color(0xFF5A7689),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                children: [
                                  for (final h
                                      in _hotspotsByIndex[_currentIndex] ??
                                          const <_HS>[])
                                    ActionChip(
                                      onPressed: () => _goTo(h.targetIndex),
                                      avatar: const Icon(Icons.place, size: 18),
                                      label: Text(
                                        h.label ?? 'View ${h.targetIndex + 1}',
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _title ?? widget.titleHint ?? 'Apartment',
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
                                      _address ?? widget.addressHint ?? '—',
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
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 12,
                                runSpacing: 6,
                                children: [
                                  if (_monthly != null)
                                    _pill('₱$_monthly / mo'),
                                  if (_advance != null)
                                    _pill('Advance: ₱$_advance'),
                                  if (_floor != null) _pill('Floor: $_floor'),
                                  if ((_status ?? '').isNotEmpty)
                                    _pill('Status: ${_status!}'),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                (_desc ?? '').isEmpty
                                    ? 'No description provided.'
                                    : _desc!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF003049),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: _openRoomInfo,
                                  child: const Text('View full room info'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )),
      ),
    );
  }

  Widget _pill(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white12,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white24),
    ),
    child: Text(text, style: const TextStyle(color: Colors.white)),
  );
}

/* helpers */
class _NetImage {
  final String id;
  final String url;
  _NetImage({required this.id, required this.url});
}

class _HS {
  final double longitude;
  final double latitude;
  final int targetIndex;
  final String? label;
  _HS({
    required this.longitude,
    required this.latitude,
    required this.targetIndex,
    this.label,
  });
}
