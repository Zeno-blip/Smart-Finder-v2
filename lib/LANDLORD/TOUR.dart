// LANDLORD/TOUR.dart
// Hero panorama (non-360) with HARD stops, smooth pan, edge “walls”,
// larger clickable hotspots, and a labeled thumbnail strip below the pano.
// Images are normalized to 2:1 (blur padding) so nothing looks stretched.
//
// Key tweaks vs your last version:
// - Bigger hero pano with fixed height and rounded corners
// - kFixedZoom = 0.80 (zoomed out a little)
// - Larger hotspots and labels
// - Thumbnail strip with labels to jump between views
// - All original protections: no wrap, edge force-field, smooth easing

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:panorama/panorama.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import 'package:smart_finder/LANDLORD/ROOMINFO.dart';

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

class _LTourState extends State<LTour> with SingleTickerProviderStateMixin {
  final _sb = Supabase.instance.client;

  // Images + lookup
  final List<_NetImage> _images = [];
  final Map<String, int> _indexById = {};
  final Map<int, List<_HS>> _hotspotsByIndex = {};

  // Pano cache
  int _currentIndex = 0;
  final Map<int, Uint8List> _panoCache = {};
  Uint8List? _currentBytes;

  // UI state
  bool _loading = true;
  String? _error;
  bool _imageLoading = false;
  String? _imageError;

  // Room info
  String? _title, _address, _status, _desc;
  num? _monthly, _advance;
  int? _floor;

  // -------- VIEW WINDOW (tighter span + a little more zoomed out) --------
  static const double kTotalSpanDeg = 210.0; // keep calm edges
  static const double _edgeEpsDeg = 0.6;
  double get _minYawDeg => -kTotalSpanDeg / 2 + _edgeEpsDeg;
  double get _maxYawDeg => kTotalSpanDeg / 2 - _edgeEpsDeg;

  // Zoom: smaller number = farther. 0.80 gives a calmer, wider feel.
  static const double kFixedZoom = 0.80;

  // Edge visuals (walls)
  static const double kEdgeFadeStartDeg = 10.0;
  static const double kEdgeFadeMaxOpacity = 0.85;
  static const double kEdgeBlurSigma = 10.0;

  // Optional concave bow (disabled)
  static const double kCurveMaxDeg = 0.0;
  static const double kCurvePower = 1.2;

  // Camera (degrees)
  double _viewLonDeg = 0.0;
  double _viewLatDeg = 0.0;

  // Smooth pan target + ticker
  double _targetLonDeg = 0.0;
  late final Ticker _ticker;

  // Realtime
  RealtimeChannel? _chImages, _chHotspots, _chRooms;

  // Haptic flags
  bool _edgeBuzzedLeft = false, _edgeBuzzedRight = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _applyYaw(0);

    _ticker = createTicker((_) {
      final diff = (_targetLonDeg - _viewLonDeg);
      if (diff.abs() < 0.01) {
        _viewLonDeg = _targetLonDeg;
      } else {
        _viewLonDeg += diff * 0.18; // smoothing factor
      }
      _viewLatDeg = _curvedLatitudeForYaw(_viewLonDeg);
      if (mounted) setState(() {});
    });
    _ticker.start();

    _bootstrap();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _chImages?.unsubscribe();
    _chHotspots?.unsubscribe();
    _chRooms?.unsubscribe();
    super.dispose();
  }

  // ---------------- Realtime ----------------
  void _subscribeRealtime() {
    _chImages = _sb
        .channel('room_images_${widget.roomId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'room_images',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: widget.roomId,
          ),
          callback: (_) => _reloadImagesAndMaybeResetIndex(),
        )
        .subscribe();

    _chHotspots = _sb
        .channel('hotspots_${widget.roomId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'hotspots',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: widget.roomId,
          ),
          callback: (_) => _reloadHotspots(),
        )
        .subscribe();

    _chRooms = _sb
        .channel('rooms_${widget.roomId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'rooms',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.roomId,
          ),
          callback: (_) => _reloadRoomInfo(),
        )
        .subscribe();
  }

  Future<void> _reloadImagesAndMaybeResetIndex() async {
    try {
      final imgs = await _sb
          .from('room_images')
          .select('id,image_url,sort_order,storage_path')
          .eq('room_id', widget.roomId)
          .order('sort_order', ascending: true);

      final newImages = <_NetImage>[
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
      ];

      final changed =
          newImages.length != _images.length ||
          newImages.asMap().entries.any(
            (e) => _images.length <= e.key || _images[e.key].url != e.value.url,
          );

      if (!mounted) return;
      setState(() {
        _images
          ..clear()
          ..addAll(newImages);
        _indexById
          ..clear()
          ..addEntries(
            _images.asMap().entries.map((e) => MapEntry(e.value.id, e.key)),
          );
      });

      if (changed) {
        _panoCache.clear();
        if (_images.isNotEmpty) {
          await _preparePano(_currentIndex.clamp(0, _images.length - 1));
        } else {
          setState(() {
            _currentBytes = null;
            _imageError = 'No panoramas uploaded.';
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _reloadHotspots() async {
    try {
      _hotspotsByIndex.clear();
      if (_images.isEmpty) return;

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
          label: (r['label'] as String?),
        );
        _hotspotsByIndex.putIfAbsent(srcIdx, () => []).add(hs);
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _reloadRoomInfo() async {
    try {
      final room = await _sb
          .from('rooms')
          .select(
            'apartment_name, location, monthly_payment, advance_deposit, '
            'status, floor_number, description, availability_status',
          )
          .eq('id', widget.roomId)
          .maybeSingle();

      if (room != null && mounted) {
        setState(() {
          _title = (room['apartment_name'] as String?)?.trim();
          _address = (room['location'] as String?)?.trim();
          _monthly = room['monthly_payment'] as num?;
          _advance = room['advance_deposit'] as num?;
          _status =
              (room['availability_status'] as String?) ??
              (room['status'] as String?);
          _floor = (room['floor_number'] as int?);
          _desc = (room['description'] as String?);
        });
      }
    } catch (_) {}
  }

  // ---------------- Bootstrap ----------------
  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
      _imageError = null;
    });

    try {
      await _reloadImagesAndMaybeResetIndex();
      await _reloadHotspots();
      await _reloadRoomInfo();
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

  // -------- Loader: pad to 2:1 WITHOUT stretching --------
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
      // already ~2:1 → standardize
      return Uint8List.fromList(img.encodeJpg(src, quality: 92));
    }

    // Blur-pad to exact 2:1 without scaling the subject.
    late final int outW;
    late final int outH;
    int dstX = 0, dstY = 0;

    if (ratio < 2.0) {
      // Narrow/tall → add left & right bands
      outW = 2 * h;
      outH = h;
      dstX = ((outW - w) / 2).round();
      dstY = 0;
    } else {
      // Wide/short → add top & bottom bands
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
      _applyYaw(centerYaw);
      _targetLonDeg = centerYaw;

      setState(() => _imageLoading = false);
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
    _targetLonDeg = clamped; // keep in sync

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

  // Just set the target; the ticker eases the camera toward it.
  void _aimYaw(double lonDeg) {
    _targetLonDeg = lonDeg.clamp(_minYawDeg, _maxYawDeg).toDouble();
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

  void _openRoomInfo() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => Roominfo(roomId: widget.roomId)),
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final leftOpacity = _leftEdgeOpacity();
    final rightOpacity = _rightEdgeOpacity();

    final heroHeight = math.min(
      420.0,
      MediaQuery.of(context).size.height * 0.43,
    ); // big hero pano

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
                        // ---------- HERO PANORAMA ----------
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                          child: SizedBox(
                            height: heroHeight,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: _imageError != null
                                        ? _ErrorBox(text: _imageError!)
                                        : (_imageLoading ||
                                              _currentBytes == null)
                                        ? const Center(
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                            ),
                                          )
                                        : Panorama(
                                            sensorControl: SensorControl.None,
                                            longitude: _viewLonDeg,
                                            latitude: _viewLatDeg,

                                            // Hard stops
                                            minLongitude: _minYawDeg,
                                            maxLongitude: _maxYawDeg,

                                            // Lock vertical & fixed zoom
                                            minLatitude: _viewLatDeg,
                                            maxLatitude: _viewLatDeg,
                                            minZoom: kFixedZoom,
                                            maxZoom: kFixedZoom,

                                            // smoothing ticker handles easing
                                            animSpeed: 0.0,

                                            onViewChanged: (lonDeg, _, __) {
                                              if (!lonDeg.isFinite) return;
                                              _aimYaw(lonDeg);
                                            },

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
                                                  width: 84,
                                                  height: 84,
                                                  widget: GestureDetector(
                                                    behavior:
                                                        HitTestBehavior.opaque,
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
                                                                  horizontal:
                                                                      10,
                                                                  vertical: 6,
                                                                ),
                                                            margin:
                                                                const EdgeInsets.only(
                                                                  bottom: 8,
                                                                ),
                                                            decoration:
                                                                BoxDecoration(
                                                                  color: Colors
                                                                      .black54,
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        8,
                                                                      ),
                                                                ),
                                                            child: Text(
                                                              hs.label!,
                                                              style: const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                          ),
                                                        const Icon(
                                                          Icons
                                                              .radio_button_checked,
                                                          color:
                                                              Colors.redAccent,
                                                          size: 34,
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
                                                    decoration:
                                                        const BoxDecoration(
                                                          gradient: LinearGradient(
                                                            begin: Alignment
                                                                .centerLeft,
                                                            end: Alignment
                                                                .centerRight,
                                                            colors: [
                                                              Colors.black54,
                                                              Colors
                                                                  .transparent,
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
                                                    decoration:
                                                        const BoxDecoration(
                                                          gradient: LinearGradient(
                                                            begin: Alignment
                                                                .centerRight,
                                                            end: Alignment
                                                                .centerLeft,
                                                            colors: [
                                                              Colors.black54,
                                                              Colors
                                                                  .transparent,
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

                                  // Back button
                                  Positioned(
                                    top: 10,
                                    left: 10,
                                    child: GestureDetector(
                                      onTap: () => Navigator.pop(context),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.9),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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
                          ),
                        ),

                        // ---------- THUMBNAIL STRIP ----------
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF5A7689),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.all(10),
                            height: 112,
                            child: _images.isEmpty
                                ? const SizedBox()
                                : ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _images.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: 10),
                                    itemBuilder: (context, i) {
                                      final url = _images[i].url;
                                      return GestureDetector(
                                        onTap: () => _goTo(i),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          child: Stack(
                                            children: [
                                              // Use network thumbs (lightweight)
                                              Image.network(
                                                url,
                                                width: 120,
                                                height: double.infinity,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    Container(
                                                      width: 120,
                                                      color: Colors.black12,
                                                      alignment:
                                                          Alignment.center,
                                                      child: const Icon(
                                                        Icons
                                                            .image_not_supported,
                                                        color: Colors.white70,
                                                      ),
                                                    ),
                                              ),
                                              Positioned(
                                                left: 8,
                                                bottom: 8,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black54,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    'View ${i + 1}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              if (i == _currentIndex)
                                                Positioned.fill(
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      border: Border.all(
                                                        color: Colors.white,
                                                        width: 2,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ),

                        // ---------- BOTTOM INFO PANEL ----------
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            color: const Color(0xFF5A7689),
                            padding: const EdgeInsets.all(16),
                            child: SingleChildScrollView(
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
                                          avatar: const Icon(
                                            Icons.place,
                                            size: 18,
                                          ),
                                          label: Text(
                                            h.label ??
                                                'View ${h.targetIndex + 1}',
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
                                      if (_floor != null)
                                        _pill('Floor: $_floor'),
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
                                        backgroundColor: const Color(
                                          0xFF003049,
                                        ),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      onPressed: _openRoomInfo,
                                      child: const Text('View full room info'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
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

/* helpers */
class _NetImage {
  final String id;
  final String url;
  _NetImage({required this.id, required this.url});
}

class _HS {
  final double longitudeDeg; // degrees
  final double latitudeDeg; // degrees
  final int targetIndex;
  final String? label;
  _HS({
    required this.longitudeDeg,
    required this.latitudeDeg,
    required this.targetIndex,
    this.label,
  });
}
