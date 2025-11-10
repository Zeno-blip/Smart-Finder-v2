// TENANT/TOUR.dart
// Tenant viewer aligned with LANDLORD/TOUR.dart behavior:
// - Pads any source to 2:1 without stretching (blur bands when needed)
// - Horizontal-only pan with HARD stops (no 360 wrap)
// - Vertical locked, fixed zoom-out to avoid the "too zoomed" look
// - Soft edge "walls" fade in near the limits

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:panorama/panorama.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import 'TROOMINFO.dart';

class Tour extends StatefulWidget {
  final int initialIndex;
  final String roomId;
  final String? titleHint;
  final String? addressHint;
  final double? monthlyHint;

  const Tour({
    super.key,
    required this.initialIndex,
    required this.roomId,
    this.titleHint,
    this.addressHint,
    this.monthlyHint,
  });

  @override
  State<Tour> createState() => _TourState();
}

class _TourState extends State<Tour> {
  final _sb = Supabase.instance.client;

  // Images + lookup
  final List<_NetImage> _images = [];
  final Map<String, int> _indexById = {};
  final Map<int, List<_HS>> _hotspotsByIndex = {};

  // Cache
  int _currentIndex = 0;
  final Map<int, Uint8List> _panoCache = {};
  Uint8List? _currentBytes;

  // UI state
  bool _loading = true;
  String? _error;
  bool _imageLoading = false;
  String? _imageError;

  // -------- VIEW WINDOW (same as Landlord) --------
  static const double kTotalSpanDeg = 240.0; // widen/narrow if you like
  static const double _edgeEpsDeg = 0.6;
  double get _minYawDeg => -kTotalSpanDeg / 2 + _edgeEpsDeg;
  double get _maxYawDeg => kTotalSpanDeg / 2 - _edgeEpsDeg;

  // Fixed zoom-out (lower = farther)
  static const double kFixedZoom = 0.65;

  // Edge visuals
  static const double kEdgeFadeStartDeg = 10.0;
  static const double kEdgeFadeMaxOpacity = 0.85;
  static const double kEdgeBlurSigma = 10.0;

  // Optional concave bow (0 = off)
  static const double kCurveMaxDeg = 0.0;
  static const double kCurvePower = 1.2;

  // Camera (degrees)
  double _viewLonDeg = 0.0;
  double _viewLatDeg = 0.0;

  // Haptic flags
  bool _edgeBuzzedLeft = false, _edgeBuzzedRight = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _applyYaw(0);
    _bootstrap();
  }

  // ---------------- Bootstrap ----------------
  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
      _imageError = null;
    });

    try {
      // Load images
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
              url: (() {
                final direct = (r['image_url'] as String?)?.trim();
                if (direct != null && direct.isNotEmpty) return direct;
                final sp = r['storage_path'] as String?;
                if (sp != null && sp.trim().isNotEmpty) {
                  return _sb.storage.from('room-images').getPublicUrl(sp);
                }
                return '';
              })(),
            ),
        ]);

      _indexById
        ..clear()
        ..addEntries(
          _images.asMap().entries.map((e) => MapEntry(e.value.id, e.key)),
        );

      // Load hotspots
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

          final lonAny = r['dx'] as num?;
          final latAny = r['dy'] as num?;
          if (lonAny == null || latAny == null) continue;

          double lonDeg;
          if (lonAny >= 0 && lonAny <= 1) {
            lonDeg = (lonAny.toDouble() * 360.0) - 180.0;
          } else if (lonAny.abs() <= math.pi + 1e-6) {
            lonDeg = lonAny.toDouble() * 180.0 / math.pi;
          } else {
            lonDeg = lonAny.toDouble();
          }

          double latDeg;
          if (latAny >= 0 && latAny <= 1) {
            latDeg = (latAny.toDouble() - 0.5) * 180.0;
          } else if (latAny.abs() <= (math.pi / 2 + 1e-6)) {
            latDeg = latAny.toDouble() * 180.0 / math.pi;
          } else {
            latDeg = latAny.toDouble();
          }
          latDeg = latDeg.clamp(-90.0, 90.0);

          final hs = _HS(
            longitudeDeg: lonDeg,
            latitudeDeg: latDeg,
            targetIndex: tgtIdx,
            label: r['label'] as String?,
          );
          _hotspotsByIndex.putIfAbsent(srcIdx, () => []).add(hs);
        }
      }

      setState(() => _loading = false);

      if (_images.isNotEmpty) {
        await _preparePano(_currentIndex);
      } else {
        setState(() => _imageError = 'No panoramas uploaded.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load tour: $e';
      });
    }
  }

  // -------- Loader: pad to 2:1 WITHOUT stretching (blur bands) --------
  Future<Uint8List> _load2to1NoStretch(String url) async {
    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) {
      throw Exception('Fetch failed: ${resp.statusCode}');
    }
    final src = img.decodeImage(resp.bodyBytes);
    if (src == null) throw Exception('Cannot decode image');

    final w = src.width;
    final h = src.height;
    final ratio = w / h;

    if ((ratio - 2.0).abs() < 0.01) {
      // Already ~2:1 -> standardize encode
      return Uint8List.fromList(img.encodeJpg(src, quality: 92));
    }

    // Build 2:1 canvas using blurred background, paste original unscaled
    late final int outW;
    late final int outH;
    int dstX = 0, dstY = 0;

    if (ratio < 2.0) {
      // Too narrow/tall -> add left/right bands
      outW = 2 * h;
      outH = h;
      dstX = ((outW - w) / 2).round();
      dstY = 0;
    } else {
      // Too wide/short -> add top/bottom bands
      outW = w;
      outH = (w / 2).round();
      dstX = 0;
      dstY = ((outH - h) / 2).round();
    }

    final bgSquare = img.copyResizeCropSquare(src, size: math.min(outW, outH));
    final bg = img.gaussianBlur(
      img.copyResize(bgSquare, width: outW, height: outH),
      radius: 18,
    );

    img.compositeImage(bg, src, dstX: dstX, dstY: dstY);
    return Uint8List.fromList(img.encodeJpg(bg, quality: 92));
  }

  // Normalize and cache.
  Future<void> _preparePano(int index) async {
    if (!mounted) return;
    setState(() {
      _imageLoading = true;
      _imageError = null;
    });

    try {
      if (_panoCache.containsKey(index)) {
        _currentBytes = _panoCache[index];
      } else {
        final url = _images[index].url;
        if (url.isEmpty) throw Exception('Panorama URL is empty.');
        final bytes = await _load2to1NoStretch(url);
        _panoCache[index] = bytes;
        _currentBytes = bytes;
      }

      // center camera within allowed slice
      final centerYaw = (_minYawDeg + _maxYawDeg) / 2.0;
      setState(() {
        _applyYaw(centerYaw);
        _imageLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _imageError = 'Could not load panorama.';
        _imageLoading = false;
      });
    }
  }

  Future<void> _goTo(int index) async {
    final clamped = index.clamp(0, _images.length - 1);
    if (!mounted) return;
    setState(() => _currentIndex = clamped);
    await _preparePano(clamped);
  }

  // -------- camera helpers --------
  double _curvedLatitudeForYaw(double lonDeg) {
    if (kCurveMaxDeg == 0.0) return 0.0;
    final span = (_maxYawDeg - _minYawDeg);
    if (span <= 0) return 0.0;
    final t = ((lonDeg - _minYawDeg) / span) * 2.0 - 1.0; // [-1,1]
    final absPow = math.pow(t.abs(), kCurvePower).toDouble();
    final factor = (1.0 - absPow).clamp(0.0, 1.0);
    return -kCurveMaxDeg * factor;
  }

  void _applyYaw(double lonDeg) {
    final clamped = lonDeg.clamp(_minYawDeg, _maxYawDeg).toDouble();
    _viewLonDeg = clamped;
    _viewLatDeg = _curvedLatitudeForYaw(clamped);

    if (clamped <= _minYawDeg + 1e-3) {
      if (!_edgeBuzzedLeft) HapticFeedback.selectionClick();
      _edgeBuzzedLeft = true;
      _edgeBuzzedRight = false;
    } else if (clamped >= _maxYawDeg - 1e-3) {
      if (!_edgeBuzzedRight) HapticFeedback.selectionClick();
      _edgeBuzzedRight = true;
      _edgeBuzzedLeft = false;
    } else {
      _edgeBuzzedLeft = false;
      _edgeBuzzedRight = false;
    }
  }

  double _leftEdgeOpacity() {
    final d = (_viewLonDeg - _minYawDeg).clamp(0.0, kEdgeFadeStartDeg);
    final t = 1.0 - (d / kEdgeFadeStartDeg);
    return (t * kEdgeFadeMaxOpacity).clamp(0.0, kEdgeFadeMaxOpacity);
  }

  double _rightEdgeOpacity() {
    final d = (_maxYawDeg - _viewLonDeg).clamp(0.0, kEdgeFadeStartDeg);
    final t = 1.0 - (d / kEdgeFadeStartDeg);
    return (t * kEdgeFadeMaxOpacity).clamp(0.0, kEdgeFadeMaxOpacity);
  }

  void _openDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TenantRoomInfo(
          roomId: widget.roomId,
          titleHint: widget.titleHint,
          addressHint: widget.addressHint,
          monthlyHint: widget.monthlyHint,
        ),
      ),
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final leftOpacity = _leftEdgeOpacity();
    final rightOpacity = _rightEdgeOpacity();

    return Scaffold(
      backgroundColor: const Color(0xFF0A3D62),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : (_error != null
                  ? _ErrorBox(text: _error!)
                  : Column(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: _imageError != null
                                    ? _ErrorBox(text: _imageError!)
                                    : (_imageLoading || _currentBytes == null)
                                    ? const Center(
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                        ),
                                      )
                                    : Panorama(
                                        sensorControl: SensorControl.None,
                                        longitude: _viewLonDeg,
                                        latitude: _viewLatDeg,

                                        // Hard stops (no wrap)
                                        minLongitude: _minYawDeg,
                                        maxLongitude: _maxYawDeg,

                                        // Lock vertical & fixed zoom-out
                                        minLatitude: _viewLatDeg,
                                        maxLatitude: _viewLatDeg,
                                        minZoom: kFixedZoom,
                                        maxZoom: kFixedZoom,

                                        // No fling
                                        animSpeed: 0.0,

                                        onViewChanged:
                                            (lonDeg, latDeg, tiltDeg) {
                                              if (!lonDeg.isFinite) return;
                                              setState(() => _applyYaw(lonDeg));
                                            },

                                        onTap: (lon, lat, tilt) =>
                                            _openDetails(),

                                        child: Image.memory(
                                          _currentBytes!,
                                          gaplessPlayback: true,
                                          filterQuality: FilterQuality.high,
                                        ),

                                        hotspots: [
                                          for (final hs
                                              in _hotspotsByIndex[_currentIndex] ??
                                                  const <_HS>[])
                                            Hotspot(
                                              longitude: hs.longitudeDeg,
                                              latitude: 0,
                                              width: 64,
                                              height: 64,
                                              widget: GestureDetector(
                                                onTap: () =>
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
                                                      Icons
                                                          .radio_button_checked,
                                                      color: Colors.redAccent,
                                                      size: 28,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                              ),

                              // Edge “force field”
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 56,
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
                                                      Colors.black54,
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
                                        width: 56,
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
                                                    begin:
                                                        Alignment.centerRight,
                                                    end: Alignment.centerLeft,
                                                    colors: [
                                                      Colors.black54,
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

                        // Bottom info panel (tenant)
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
                                widget.titleHint ?? 'Apartment',
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
                                      widget.addressHint ?? '—',
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
                              if (widget.monthlyHint != null)
                                Text(
                                  '₱${widget.monthlyHint} / mo',
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
                                  onPressed: _openDetails,
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
}

/* ---------- helpers ---------- */

class _NetImage {
  final String id;
  final String url;
  _NetImage({required this.id, required this.url});
}

class _HS {
  final double longitudeDeg; // degrees
  final double latitudeDeg; // degrees (unused; locked to 0)
  final int targetIndex;
  final String? label;
  _HS({
    required this.longitudeDeg,
    required this.latitudeDeg,
    required this.targetIndex,
    this.label,
  });
}

class _ErrorBox extends StatelessWidget {
  final String text;
  const _ErrorBox({required this.text});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
