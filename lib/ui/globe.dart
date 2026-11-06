import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../theme.dart';

/// Land outlines (Natural Earth 110m, public domain) pre-converted to radians.
class _World {
  final List<Float32List> lat = [];
  final List<Float32List> lon = [];
  static _World? _cache;

  static Future<_World> load() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/world_110m.json');
    final rings = (jsonDecode(raw) as List).cast<List>();
    final w = _World();
    const d2r = math.pi / 180;
    for (final r in rings) {
      final n = r.length ~/ 2;
      final la = Float32List(n), lo = Float32List(n);
      for (var i = 0; i < n; i++) {
        lo[i] = (r[i * 2] as num).toDouble() * d2r;
        la[i] = (r[i * 2 + 1] as num).toDouble() * d2r;
      }
      w.lat.add(la);
      w.lon.add(lo);
    }
    return _cache = w;
  }
}

/// A real 3D-looking globe (orthographic projection) centred on a movable view
/// point, with the great-circle route from the user to the Kaaba drawn above it.
class QiblaGlobe extends StatefulWidget {
  final double userLat, userLng; // degrees
  final double kaabaLat, kaabaLng; // degrees
  final double? heading;
  final double size;

  const QiblaGlobe({
    super.key,
    required this.userLat,
    required this.userLng,
    required this.kaabaLat,
    required this.kaabaLng,
    this.heading,
    this.size = 300,
  });

  @override
  State<QiblaGlobe> createState() => QiblaGlobeState();
}

class QiblaGlobeState extends State<QiblaGlobe> with TickerProviderStateMixin {
  _World? _world;
  // View centre (radians)
  final ValueNotifier<Offset> _view = ValueNotifier(Offset.zero); // dx = lon, dy = lat
  late final AnimationController _pulse;
  late final AnimationController _route; // route arc draws in
  AnimationController? _move;
  AnimationController? _zoomAnim;
  final ValueNotifier<double> _zoom = ValueNotifier(1.0);
  double _zoomStart = 1.0;
  static const double _minZoom = 0.8, _maxZoom = 4.0;

  // Street level: a flat OpenStreetMap view that the globe "swoops" into.
  bool _street = false;
  final MapController _map = MapController();
  LatLng _streetCenter = const LatLng(0, 0);
  AnimationController? _swoop;
  static const double _streetEntryZoom = 4.0, _streetTargetZoom = 16.0;

  static const double _d2r = math.pi / 180;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat();
    _route = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    _view.value = Offset(widget.userLng * _d2r - 2.2, 0.2); // start rotated away, then glide in
    _World.load().then((w) {
      if (!mounted) return;
      setState(() => _world = w);
      focusRoute();
      _route.forward();
    });
  }

  @override
  void didUpdateWidget(QiblaGlobe old) {
    super.didUpdateWidget(old);
    // Only re-centre for a real move (>~1 km) and never yank the user out of street view.
    final moved = (old.userLat - widget.userLat).abs() > 0.01 ||
        (old.userLng - widget.userLng).abs() > 0.01;
    if (moved && !_street) focusRoute();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _route.dispose();
    _move?.dispose();
    _zoomAnim?.dispose();
    _swoop?.dispose();
    _zoom.dispose();
    _view.dispose();
    super.dispose();
  }

  void _animateTo(double lonRad, double latRad) {
    _move?.dispose();
    final from = _view.value;
    // shortest way around in longitude
    var dLon = (lonRad - from.dx) % (2 * math.pi);
    if (dLon > math.pi) dLon -= 2 * math.pi;
    if (dLon < -math.pi) dLon += 2 * math.pi;
    final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    final curve = CurvedAnimation(parent: c, curve: Curves.easeInOutCubic);
    c.addListener(() {
      _view.value = Offset(from.dx + dLon * curve.value, from.dy + (latRad - from.dy) * curve.value);
    });
    _move = c..forward();
  }

  void _zoomTo(double target) {
    _zoomAnim?.dispose();
    final from = _zoom.value;
    final to = target.clamp(_minZoom, _maxZoom);
    final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    final curve = CurvedAnimation(parent: c, curve: Curves.easeOutCubic);
    c.addListener(() => _zoom.value = from + (to - from) * curve.value);
    _zoomAnim = c..forward();
  }

  double _mapZoomNow() {
    try {
      return _map.camera.zoom;
    } catch (_) {
      return _streetEntryZoom;
    }
  }

  void _enterStreet() {
    _zoomAnim?.stop();
    final v = _view.value;
    setState(() {
      _streetCenter = LatLng(v.dy / _d2r, ((v.dx / _d2r + 540) % 360) - 180);
      _street = true;
    });
    // Land on the user's own street (not the empty ocean at the globe's centre).
    _swoopTo(LatLng(widget.userLat, widget.userLng), _streetTargetZoom);
  }

  void _exitStreet() {
    LatLng c = _streetCenter;
    try {
      c = _map.camera.center;
    } catch (_) {}
    _swoop?.stop();
    _view.value = Offset(c.longitude * _d2r, c.latitude * _d2r);
    _zoom.value = 3.0;
    setState(() => _street = false);
    _zoomTo(1.0);
  }

  /// Animated move of the street map (centre + zoom together).
  void _swoopTo(LatLng target, double zoomTarget) {
    _swoop?.dispose();
    final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    final curve = CurvedAnimation(parent: c, curve: Curves.easeInOutCubic);
    LatLng? from;
    double fromZ = _streetEntryZoom;
    c.addListener(() {
      try {
        if (from == null) {
          from = _map.camera.center;
          fromZ = _map.camera.zoom;
        }
        final t = curve.value;
        _map.move(
          LatLng(
            from!.latitude + (target.latitude - from!.latitude) * t,
            from!.longitude + (target.longitude - from!.longitude) * t,
          ),
          fromZ + (zoomTarget - fromZ) * t,
        );
      } catch (_) {/* map not attached yet; next tick */}
    });
    _swoop = c;
    WidgetsBinding.instance.addPostFrameCallback((_) => c.forward());
  }

  void zoomIn() {
    if (_street) {
      _swoopTo(_map.camera.center, math.min(_mapZoomNow() + 1.5, 19));
    } else if (_zoom.value >= _maxZoom * 0.85) {
      _enterStreet();
    } else {
      _zoomTo(_zoom.value * 1.6);
    }
  }

  void zoomOut() {
    if (_street) {
      final z = _mapZoomNow();
      if (z <= _streetEntryZoom + 1.0) {
        _exitStreet();
      } else {
        _swoopTo(_map.camera.center, math.max(z - 1.5, _streetEntryZoom));
      }
    } else {
      _zoomTo(_zoom.value / 1.6);
    }
  }

  void focusUser() {
    if (_street) return _swoopTo(LatLng(widget.userLat, widget.userLng), 16);
    _animateTo(widget.userLng * _d2r, widget.userLat * _d2r);
  }

  void focusKaaba() {
    if (_street) return _swoopTo(LatLng(widget.kaabaLat, widget.kaabaLng), 17);
    _animateTo(widget.kaabaLng * _d2r, widget.kaabaLat * _d2r);
  }

  /// Centre on the midpoint so the whole route is visible (falls back to the user when far apart).
  void focusRoute() {
    if (_street) {
      _exitStreet();
    }
    final a = _toVec(widget.userLat * _d2r, widget.userLng * _d2r);
    final b = _toVec(widget.kaabaLat * _d2r, widget.kaabaLng * _d2r);
    final dot = a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
    if (dot < 0.25) return focusUser(); // more than ~75° apart: just show the user
    final m = [a[0] + b[0], a[1] + b[1], a[2] + b[2]];
    final len = math.sqrt(m[0] * m[0] + m[1] * m[1] + m[2] * m[2]);
    final lat = math.asin(m[2] / len);
    final lon = math.atan2(m[1], m[0]);
    _animateTo(lon, lat);
  }

  static List<double> _toVec(double lat, double lon) =>
      [math.cos(lat) * math.cos(lon), math.cos(lat) * math.sin(lon), math.sin(lat)];

  @override
  Widget build(BuildContext context) {
    final r = widget.size / 2;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            child: _street
                ? KeyedSubtree(key: const ValueKey('street'), child: _buildStreetMap())
                : KeyedSubtree(
                    key: const ValueKey('globe'),
                    child: GestureDetector(
          onScaleStart: (_) {
            _move?.stop();
            _zoomAnim?.stop();
            _zoomStart = _zoom.value;
          },
          // One finger rotates, two fingers pinch to zoom (and still rotate).
          onScaleUpdate: (d) {
            final wanted = _zoomStart * d.scale;
            if (wanted > _maxZoom * 1.12 && !_street) {
              _enterStreet(); // pinched past the globe's limit: swoop to street level
              return;
            }
            _zoom.value = wanted.clamp(_minZoom, _maxZoom);
            final v = _view.value;
            final k = 1.0 / (r * 0.95 * _zoom.value);
            _view.value = Offset(
              v.dx - d.focalPointDelta.dx * k,
              (v.dy + d.focalPointDelta.dy * k).clamp(-1.35, 1.35),
            );
          },
          onDoubleTap: () => _zoomTo(_zoom.value < 1.5 ? 2.2 : 1.0),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: ClipOval(child: CustomPaint(
              painter: _GlobePainter(
                world: _world,
                view: _view,
                zoom: _zoom,
                pulse: _pulse,
                route: _route,
                userLat: widget.userLat * _d2r,
                userLng: widget.userLng * _d2r,
                kaabaLat: widget.kaabaLat * _d2r,
                kaabaLng: widget.kaabaLng * _d2r,
                heading: widget.heading,
              ),
            )),
          ),
        ),
                  ),
          ),
        ),
        if (_street)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Imagery © Esri, Maxar, Earthstar Geographics',
                style: TextStyle(fontSize: 10, color: Colors.grey)),
          ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filledTonal(
              tooltip: 'Zoom out',
              icon: const Icon(Icons.zoom_out),
              onPressed: zoomOut,
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              tooltip: 'Route',
              icon: const Icon(Icons.public),
              onPressed: focusRoute,
            ),
            const SizedBox(width: 10),
            IconButton.filled(
              tooltip: 'Me',
              icon: const Icon(Icons.my_location),
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.petronasGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: focusUser,
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              tooltip: 'Kaaba',
              icon: const Icon(Icons.mosque),
              onPressed: focusKaaba,
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              tooltip: 'Zoom in',
              icon: const Icon(Icons.zoom_in),
              onPressed: zoomIn,
            ),
          ],
        ),
      ],
    );
  }
}

const double _kDeg2Rad = math.pi / 180;

extension _StreetMap on QiblaGlobeState {
  Widget _buildStreetMap() {
    // Great-circle route sampled into points for the flat map
    final pts = <LatLng>[];
    final a = [math.cos(widget.userLat * _kDeg2Rad) * math.cos(widget.userLng * _kDeg2Rad), math.cos(widget.userLat * _kDeg2Rad) * math.sin(widget.userLng * _kDeg2Rad), math.sin(widget.userLat * _kDeg2Rad)];
    final b = [math.cos(widget.kaabaLat * _kDeg2Rad) * math.cos(widget.kaabaLng * _kDeg2Rad), math.cos(widget.kaabaLat * _kDeg2Rad) * math.sin(widget.kaabaLng * _kDeg2Rad), math.sin(widget.kaabaLat * _kDeg2Rad)];
    final omega = math.acos((a[0] * b[0] + a[1] * b[1] + a[2] * b[2]).clamp(-1.0, 1.0));
    if (omega > 1e-4) {
      for (var i = 0; i <= 60; i++) {
        final t = i / 60;
        final s1 = math.sin((1 - t) * omega) / math.sin(omega), s2 = math.sin(t * omega) / math.sin(omega);
        pts.add(LatLng(
          math.asin((s1 * a[2] + s2 * b[2]).clamp(-1.0, 1.0)) / _kDeg2Rad,
          math.atan2(s1 * a[1] + s2 * b[1], s1 * a[0] + s2 * b[0]) / _kDeg2Rad,
        ));
      }
    }
    return ClipOval(
      child: FlutterMap(
        mapController: _map,
        options: MapOptions(
          initialCenter: _streetCenter,
          initialZoom: QiblaGlobeState._streetEntryZoom,
          minZoom: 2,
          maxZoom: 19,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          // Satellite imagery (Esri World Imagery; note the {z}/{y}/{x} order)
          TileLayer(
            urlTemplate:
                'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
            userAgentPackageName: 'my.i906.solat.solat_malaysia',
            maxNativeZoom: 17,
          ),
          // Place names on top of the imagery
          TileLayer(
            urlTemplate:
                'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
            userAgentPackageName: 'my.i906.solat.solat_malaysia',
            maxNativeZoom: 17,
          ),
          PolylineLayer(polylines: [
            Polyline(points: pts, color: AppTheme.petronasGreen, strokeWidth: 3),
          ]),
          MarkerLayer(markers: [
            Marker(
              point: LatLng(widget.userLat, widget.userLng),
              width: 36,
              height: 36,
              child: widget.heading != null
                  ? Transform.rotate(
                      angle: widget.heading! * math.pi / 180,
                      child: const Icon(Icons.navigation, color: Colors.blueAccent, size: 30),
                    )
                  : const Icon(Icons.location_on, color: Colors.blueAccent, size: 30),
            ),
            Marker(
              point: LatLng(widget.kaabaLat, widget.kaabaLng),
              width: 36,
              height: 36,
              child: const Center(child: Text('🕋', style: TextStyle(fontSize: 24))),
            ),
          ]),
        ],
      ),
    );
  }
}

class _GlobePainter extends CustomPainter {
  final _World? world;
  final ValueNotifier<Offset> view;
  final ValueNotifier<double> zoom;
  final Animation<double> pulse;
  final Animation<double> route;
  final double userLat, userLng, kaabaLat, kaabaLng;
  final double? heading;

  _GlobePainter({
    required this.world,
    required this.view,
    required this.zoom,
    required this.pulse,
    required this.route,
    required this.userLat,
    required this.userLng,
    required this.kaabaLat,
    required this.kaabaLng,
    required this.heading,
  }) : super(repaint: Listenable.merge([view, zoom, pulse, route]));

  late double _lon0, _lat0, _sin0, _cos0, _R;
  late Offset _c;

  /// Returns the screen position, and writes visibility (cos of angular distance from view centre).
  Offset _project(double lat, double lon, [double radiusScale = 1.0]) {
    final dl = lon - _lon0;
    final cl = math.cos(lat), sl = math.sin(lat);
    final x = cl * math.sin(dl);
    final y = _cos0 * sl - _sin0 * cl * math.cos(dl);
    return Offset(_c.dx + _R * radiusScale * x, _c.dy - _R * radiusScale * y);
  }

  double _visibility(double lat, double lon) =>
      _sin0 * math.sin(lat) + _cos0 * math.cos(lat) * math.cos(lon - _lon0);

  @override
  void paint(Canvas canvas, Size size) {
    _c = size.center(Offset.zero);
    _R = (math.min(size.width, size.height) / 2 - 14) * zoom.value;
    canvas.clipPath(Path()..addOval(Offset.zero & size));
    _lon0 = view.value.dx;
    _lat0 = view.value.dy;
    _sin0 = math.sin(_lat0);
    _cos0 = math.cos(_lat0);
    final disc = Rect.fromCircle(center: _c, radius: _R);

    // Atmosphere glow
    canvas.drawCircle(
      _c,
      _R + 6,
      Paint()
        ..color = AppTheme.petronasGreen.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    // Ocean with a lit side (top-left)
    canvas.drawCircle(
      _c,
      _R,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.4, -0.45),
          radius: 1.1,
          colors: [Color(0xFF0A4A63), Color(0xFF052C45), Color(0xFF01101F)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(disc),
    );

    canvas.save();
    canvas.clipPath(Path()..addOval(disc));

    // Graticule
    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = AppTheme.petronasGreen.withValues(alpha: 0.18);
    for (var latD = -60; latD <= 60; latD += 30) {
      _drawLine(canvas, grid, (t) => [latD * math.pi / 180, -math.pi + t * 2 * math.pi], 120);
    }
    for (var lonD = -180; lonD < 180; lonD += 30) {
      _drawLine(canvas, grid, (t) => [-math.pi / 2 + t * math.pi, lonD * math.pi / 180], 60);
    }

    // Land
    final w = world;
    if (w != null) {
      final fill = Paint()..color = const Color(0xFF127F79).withValues(alpha: 0.92);
      final edge = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = const Color(0xFF6FE7E0).withValues(alpha: 0.55);
      for (var i = 0; i < w.lat.length; i++) {
        final la = w.lat[i], lo = w.lon[i];
        final path = Path();
        var anyVisible = false;
        for (var j = 0; j < la.length; j++) {
          final vis = _visibility(la[j], lo[j]);
          var p = _project(la[j], lo[j]);
          if (vis > 0) {
            anyVisible = true;
          } else {
            // Push far-side points onto the horizon so shapes close along the rim
            final v = p - _c;
            final d = v.distance;
            p = d == 0 ? _c + Offset(_R, 0) : _c + v / d * _R;
          }
          j == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        if (!anyVisible) continue;
        path.close();
        canvas.drawPath(path, fill);
        canvas.drawPath(path, edge);
      }
    }

    // Night-side shading + specular highlight → reads as a sphere
    canvas.drawCircle(
      _c,
      _R,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.45, -0.5),
          radius: 1.05,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.18),
            Colors.black.withValues(alpha: 0.62),
          ],
          stops: const [0.35, 0.75, 1.0],
        ).createShader(disc),
    );
    canvas.drawCircle(
      _c + Offset(-_R * 0.38, -_R * 0.42),
      _R * 0.34,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white.withValues(alpha: 0.16), Colors.transparent],
        ).createShader(Rect.fromCircle(center: _c + Offset(-_R * 0.38, -_R * 0.42), radius: _R * 0.34)),
    );

    _drawRoute(canvas);
    canvas.restore();

    // Rim
    canvas.drawCircle(
      _c,
      _R,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = AppTheme.petronasGreen.withValues(alpha: 0.85),
    );
    _drawMarkers(canvas);
  }

  void _drawLine(Canvas canvas, Paint paint, List<double> Function(double t) at, int steps) {
    Path? path;
    for (var i = 0; i <= steps; i++) {
      final ll = at(i / steps);
      if (_visibility(ll[0], ll[1]) > 0) {
        final p = _project(ll[0], ll[1]);
        if (path == null) {
          path = Path()..moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      } else if (path != null) {
        canvas.drawPath(path, paint);
        path = null;
      }
    }
    if (path != null) canvas.drawPath(path, paint);
  }

  /// Great-circle arc, lifted above the surface, drawn progressively.
  void _drawRoute(Canvas canvas) {
    final a = [math.cos(userLat) * math.cos(userLng), math.cos(userLat) * math.sin(userLng), math.sin(userLat)];
    final b = [math.cos(kaabaLat) * math.cos(kaabaLng), math.cos(kaabaLat) * math.sin(kaabaLng), math.sin(kaabaLat)];
    final dot = (a[0] * b[0] + a[1] * b[1] + a[2] * b[2]).clamp(-1.0, 1.0);
    final omega = math.acos(dot);
    if (omega < 1e-4) return;
    const steps = 80;
    final upTo = (steps * route.value).round();

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = AppTheme.petronasYellow.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..color = AppTheme.petronasYellow;

    Path? path;
    for (var i = 0; i <= upTo; i++) {
      final t = i / steps;
      final s1 = math.sin((1 - t) * omega) / math.sin(omega);
      final s2 = math.sin(t * omega) / math.sin(omega);
      final x = s1 * a[0] + s2 * b[0], y = s1 * a[1] + s2 * b[1], z = s1 * a[2] + s2 * b[2];
      final lat = math.asin(z.clamp(-1.0, 1.0)), lon = math.atan2(y, x);
      if (_visibility(lat, lon) <= 0.02) {
        if (path != null) {
          canvas.drawPath(path, glow);
          canvas.drawPath(path, line);
          path = null;
        }
        continue;
      }
      final lift = 1 + 0.16 * math.sin(math.pi * t); // arc floats above the surface
      final p = _project(lat, lon, lift);
      if (path == null) {
        path = Path()..moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    if (path != null) {
      canvas.drawPath(path, glow);
      canvas.drawPath(path, line);
    }
  }

  void _drawMarkers(Canvas canvas) {
    final ph = pulse.value;

    // Kaaba
    if (_visibility(kaabaLat, kaabaLng) > 0) {
      final p = _project(kaabaLat, kaabaLng);
      canvas.drawCircle(p, 9 + 6 * ph, Paint()..color = AppTheme.petronasYellow.withValues(alpha: 0.35 * (1 - ph)));
      canvas.drawCircle(p, 6, Paint()..color = AppTheme.petronasYellow);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: p, width: 6, height: 6), const Radius.circular(1)),
        Paint()..color = const Color(0xFF111111),
      );
    }

    // User
    if (_visibility(userLat, userLng) > 0) {
      final p = _project(userLat, userLng);
      canvas.drawCircle(p, 8 + 12 * ph, Paint()..color = const Color(0xFF5CE1DC).withValues(alpha: 0.4 * (1 - ph)));
      canvas.drawCircle(p, 6, Paint()..color = Colors.white);
      canvas.drawCircle(p, 4, Paint()..color = const Color(0xFF00C2BB));
      if (heading != null) {
        canvas.save();
        canvas.translate(p.dx, p.dy);
        canvas.rotate(heading! * math.pi / 180);
        canvas.drawPath(
          Path()
            ..moveTo(0, -17)
            ..lineTo(5, -8)
            ..lineTo(-5, -8)
            ..close(),
          Paint()..color = Colors.white,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_GlobePainter old) =>
      old.world != world ||
      old.userLat != userLat ||
      old.userLng != userLng ||
      old.heading != heading;
}
