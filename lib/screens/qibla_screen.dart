import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../providers/prayer_provider.dart';
import '../theme.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen>
    with SingleTickerProviderStateMixin {
  static const double _kaabatLat = 21.4225;
  static const double _kaabatLng = 39.8262;

  late AnimationController _pulseController;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// Bearing from user to Mecca (degrees, 0–360 clockwise from North)
  double _qiblaBearing(double userLat, double userLng) {
    final lat1 = userLat * math.pi / 180;
    final lat2 = _kaabatLat * math.pi / 180;
    final dLng = (_kaabatLng - userLng) * math.pi / 180;
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  /// Great-circle distance (km) from user to Mecca
  double _distanceToMecca(double userLat, double userLng) {
    const r = 6371.0;
    final dLat = (_kaabatLat - userLat) * math.pi / 180;
    final dLng = (_kaabatLng - userLng) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(userLat * math.pi / 180) *
            math.cos(_kaabatLat * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<PrayerProvider>();
    final loc = provider.locationResult;
    final userLat = loc?.latitude;
    final userLng = loc?.longitude;

    return Column(
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF001122), const Color(0xFF002244)]
                  : [AppTheme.petronasGreen, AppTheme.petronasBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.explore, color: AppTheme.petronasYellow, size: 26),
                  SizedBox(width: 8),
                  Text(
                    'Arah Qibla',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              if (loc?.city != null) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.location_on,
                        color: AppTheme.petronasYellow, size: 14),
                    const SizedBox(width: 4),
                    Text(loc!.city!,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ],
              if (userLat != null && userLng != null) ...[
                const SizedBox(height: 2),
                Text(
                  '${_distanceToMecca(userLat, userLng).toStringAsFixed(0)} km from Mecca',
                  style: TextStyle(
                    color: AppTheme.petronasYellow.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),

        Expanded(child: _buildBody(context, isDark, userLat, userLng, provider)),
      ],
    );
  }

  Widget _buildBody(BuildContext context, bool isDark, double? userLat,
      double? userLng, PrayerProvider provider) {
    if (provider.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.petronasGreen),
            SizedBox(height: 16),
            Text('Getting your location...'),
          ],
        ),
      );
    }

    if (userLat == null || userLng == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text('Location Unavailable',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Qibla direction requires your GPS location.\nPlease enable location in Settings.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => provider.fetchData(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.petronasGreen),
              ),
            ],
          ),
        ),
      );
    }

    final bearing = _qiblaBearing(userLat, userLng);

    return StreamBuilder<CompassEvent>(
      stream: FlutterCompass.events,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _noCompassFallback(context, isDark, bearing, userLat, userLng);
        }
        final heading = snapshot.data?.heading;
        // No heading = no magnetometer or still warming up
        if (!snapshot.hasData || heading == null) {
          if (snapshot.connectionState != ConnectionState.waiting &&
              snapshot.data != null) {
            return _noCompassFallback(
                context, isDark, bearing, userLat, userLng);
          }
          return _compassUI(context, isDark, bearing, null, userLat, userLng);
        }
        return _compassUI(context, isDark, bearing, heading, userLat, userLng);
      },
    );
  }

  Widget _compassUI(BuildContext context, bool isDark, double qiblaBearing,
      double? heading, double userLat, double userLng) {
    // Aligned when phone top is within 5° of Qibla bearing
    final isAligned = heading != null &&
        ((qiblaBearing - heading).abs() % 360 < 5 ||
            (qiblaBearing - heading).abs() % 360 > 355);

    // Rotate the ENTIRE compass rose by -heading so that N always points to
    // geographic North. The Qibla needle is drawn at qiblaBearing inside the
    // rose, so it always points toward Mecca relative to North.
    final roseRotation =
        heading != null ? -heading * math.pi / 180 : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      child: Column(
        children: [
          // ── Compass rose ──────────────────────────────────────────────────
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Pulsing glow ring when aligned
                  if (isAligned)
                    Container(
                      width: 290 + 20 * _pulseController.value,
                      height: 290 + 20 * _pulseController.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.petronasGreen.withValues(
                                alpha: 0.3 * _pulseController.value),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  // The compass rose + needle — rotated so N = geographic North
                  Transform.rotate(
                    angle: roseRotation,
                    child: child,
                  ),
                ],
              );
            },
            child: SizedBox(
              width: 290,
              height: 290,
              child: CustomPaint(
                painter: _CompassPainter(
                  isDark: isDark,
                  // Needle drawn at fixed qibla bearing inside the rose frame.
                  // Transform.rotate handles the heading rotation.
                  qiblaBearingRad: qiblaBearing * math.pi / 180,
                  hasHeading: heading != null,
                  isAligned: isAligned,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Info row ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF001A33) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _infoTile(
                    icon: Icons.navigation,
                    label: 'Qibla',
                    value: '${qiblaBearing.toStringAsFixed(1)}°',
                    isDark: isDark),
                Container(width: 1, height: 44, color: Colors.grey.shade300),
                _infoTile(
                    icon: Icons.compass_calibration,
                    label: 'Heading',
                    value: heading != null
                        ? '${heading.toStringAsFixed(1)}°'
                        : 'N/A',
                    isDark: isDark),
                Container(width: 1, height: 44, color: Colors.grey.shade300),
                _infoTile(
                    icon: Icons.place,
                    label: 'Distance',
                    value:
                        '${_distanceToMecca(userLat, userLng).toStringAsFixed(0)} km',
                    isDark: isDark),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Alignment status ──────────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            decoration: BoxDecoration(
              color: isAligned
                  ? AppTheme.petronasGreen.withValues(alpha: 0.15)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.shade100),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    isAligned ? AppTheme.petronasGreen : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isAligned ? Icons.check_circle : Icons.rotate_right,
                  color: isAligned ? AppTheme.petronasGreen : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    isAligned
                        ? 'You are facing the Qibla!'
                        : heading != null
                            ? 'Rotate phone until needle points up'
                            : 'Point the top of your phone toward Mecca',
                    style: TextStyle(
                      color: isAligned ? AppTheme.petronasGreen : Colors.grey,
                      fontWeight:
                          isAligned ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Tip ───────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.petronasYellow.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppTheme.petronasYellow.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.tips_and_updates,
                    color: AppTheme.petronasYellow, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Hold phone flat and level. The compass rose rotates so N always points to geographic North. The green needle points to Mecca.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Mini Map ──────────────────────────────────────────────────────
          _buildMap(userLat, userLng, heading),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _noCompassFallback(BuildContext context, bool isDark,
      double qiblaBearing, double userLat, double userLng) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 32),
          Icon(Icons.compass_calibration,
              size: 80, color: AppTheme.petronasGreen.withValues(alpha: 0.5)),
          const SizedBox(height: 20),
          const Text('Compass Not Available',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text(
            'This device has no magnetometer.\nYour calculated Qibla bearing is:',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppTheme.petronasGreen, AppTheme.petronasBlue]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text('Qibla Direction',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                Text(
                  '${qiblaBearing.toStringAsFixed(1)}°',
                  style: const TextStyle(
                    color: AppTheme.petronasYellow,
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text('from North',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 6),
                Text(
                  '${_distanceToMecca(userLat, userLng).toStringAsFixed(0)} km from Mecca',
                  style: TextStyle(
                    color: AppTheme.petronasYellow.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          _buildMap(userLat, userLng, null),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _infoTile(
      {required IconData icon,
      required String label,
      required String value,
      required bool isDark}) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.petronasGreen, size: 20),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildMap(double userLat, double userLng, double? heading) {
    return Column(
      children: [
        Container(
          height: 260,
          width: 260,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.petronasGreen, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: LatLng(userLat, userLng),
          initialZoom: 2.5,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}',
            userAgentPackageName: 'my.i906.solat.solat_malaysia',
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: [
                  LatLng(userLat, userLng),
                  const LatLng(_kaabatLat, _kaabatLng),
                ],
                color: AppTheme.petronasGreen,
                strokeWidth: 3.0,
              ),
            ],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(userLat, userLng),
                width: 44,
                height: 44,
                child: heading != null
                    ? Transform.rotate(
                        angle: heading * math.pi / 180,
                        child: const Icon(
                          Icons.navigation,
                          color: Colors.blueAccent,
                          size: 32,
                        ),
                      )
                    : const Icon(
                        Icons.location_on,
                        color: Colors.blueAccent,
                        size: 32,
                      ),
              ),
              Marker(
                point: const LatLng(_kaabatLat, _kaabatLng),
                width: 40,
                height: 40,
                child: const Center(child: Text('🕋', style: TextStyle(fontSize: 24))),
              ),
            ],
          ),
        ],
      ),
    ),
    const SizedBox(height: 16),
    Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton.filledTonal(
          icon: const Icon(Icons.zoom_out),
          onPressed: () {
            final currentZoom = _mapController.camera.zoom;
            _mapController.move(_mapController.camera.center, currentZoom - 1);
          },
        ),
        const SizedBox(width: 16),
        IconButton.filled(
          icon: const Icon(Icons.my_location),
          style: IconButton.styleFrom(
            backgroundColor: AppTheme.petronasGreen,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            _mapController.move(LatLng(userLat, userLng), 10.0);
          },
        ),
        const SizedBox(width: 16),
        IconButton.filledTonal(
          icon: const Icon(Icons.zoom_in),
          onPressed: () {
            final currentZoom = _mapController.camera.zoom;
            _mapController.move(_mapController.camera.center, currentZoom + 1);
          },
        ),
      ],
    ),
      ],
    );
  }
}

/// Draws the compass rose with N/E/S/W labels and a Qibla needle.
/// The WHOLE widget is rotated by -heading via Transform.rotate in the parent,
/// so N always points to geographic North. The needle is drawn at
/// [qiblaBearingRad] relative to North, pointing toward Mecca.
class _CompassPainter extends CustomPainter {
  final bool isDark;
  final double qiblaBearingRad; // Bearing to Mecca in radians from North
  final bool hasHeading;        // False if compass not available (warming up)
  final bool isAligned;

  const _CompassPainter({
    required this.isDark,
    required this.qiblaBearingRad,
    required this.hasHeading,
    required this.isAligned,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // ── Outer ring ──────────────────────────────────────────────────────────
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color =
              isDark ? const Color(0xFF003366) : Colors.grey.shade200
          ..style = PaintingStyle.fill);

    canvas.drawCircle(
        center,
        radius - 2,
        Paint()
          ..color =
              isDark ? AppTheme.petronasGreen : AppTheme.petronasBlue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);

    // ── Tick marks & cardinal labels ────────────────────────────────────────
    final cardinals = ['N', 'E', 'S', 'W'];
    for (int i = 0; i < 36; i++) {
      final angle = i * 10.0 * math.pi / 180;
      final isMajor = i % 9 == 0;
      final tickLen = isMajor ? 16.0 : 8.0;
      final outer =
          center + Offset(math.sin(angle), -math.cos(angle)) * (radius - 4);
      final inner = center +
          Offset(math.sin(angle), -math.cos(angle)) * (radius - 4 - tickLen);
      canvas.drawLine(
          inner,
          outer,
          Paint()
            ..color = isMajor
                ? (isDark ? AppTheme.petronasGreen : AppTheme.petronasBlue)
                : (isDark ? Colors.white24 : Colors.grey.shade400)
            ..strokeWidth = isMajor ? 2.5 : 1.2);

      if (isMajor) {
        // N is red, others dark/white
        final isNorth = i == 0;
        final tp = TextPainter(
          text: TextSpan(
            text: cardinals[i ~/ 9],
            style: TextStyle(
              color: isNorth
                  ? Colors.red
                  : (isDark ? Colors.white : AppTheme.petronasBlue),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final labelPos = center +
            Offset(math.sin(angle), -math.cos(angle)) * (radius - 32) -
            Offset(tp.width / 2, tp.height / 2);
        tp.paint(canvas, labelPos);
      }
    }

    // ── Inner background circle ──────────────────────────────────────────────
    canvas.drawCircle(
        center,
        radius * 0.55,
        Paint()
          ..color = isDark ? const Color(0xFF001122) : Colors.white
          ..style = PaintingStyle.fill);

    // ── Qibla needle ─────────────────────────────────────────────────────────
    if (hasHeading) {
      final nLen = radius * 0.48;
      final tLen = radius * 0.20;
      final a = qiblaBearingRad;

      // Forward needle (toward Mecca)
      canvas.drawPath(
          Path()
            ..moveTo(center.dx, center.dy)
            ..lineTo(center.dx + math.sin(a - 0.13) * nLen * 0.32,
                center.dy - math.cos(a - 0.13) * nLen * 0.32)
            ..lineTo(center.dx + math.sin(a) * nLen,
                center.dy - math.cos(a) * nLen)
            ..lineTo(center.dx + math.sin(a + 0.13) * nLen * 0.32,
                center.dy - math.cos(a + 0.13) * nLen * 0.32)
            ..close(),
          Paint()
            ..color = isAligned
                ? AppTheme.petronasGreen
                : const Color(0xFF00A19C)
            ..style = PaintingStyle.fill);

      // Tail needle
      canvas.drawPath(
          Path()
            ..moveTo(center.dx, center.dy)
            ..lineTo(center.dx + math.sin(a - 0.13) * tLen * 0.32,
                center.dy - math.cos(a - 0.13) * tLen * 0.32)
            ..lineTo(center.dx - math.sin(a) * tLen,
                center.dy + math.cos(a) * tLen)
            ..lineTo(center.dx + math.sin(a + 0.13) * tLen * 0.32,
                center.dy - math.cos(a + 0.13) * tLen * 0.32)
            ..close(),
          Paint()
            ..color = Colors.grey.shade400
            ..style = PaintingStyle.fill);

      // Kaaba symbol at needle tip
      final tipPt = center +
          Offset(math.sin(a) * nLen * 0.82, -math.cos(a) * nLen * 0.82);
      canvas.drawRect(
          Rect.fromCenter(center: tipPt, width: 13, height: 13),
          Paint()
            ..color =
                isAligned ? AppTheme.petronasYellow : Colors.black87);
    } else {
      // Still warming up — show 🕋 in centre
      final tp = TextPainter(
        text: const TextSpan(text: '🕋', style: TextStyle(fontSize: 34)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    }

    // ── Centre pivot dot ─────────────────────────────────────────────────────
    canvas.drawCircle(
        center,
        5,
        Paint()
          ..color = isAligned
              ? AppTheme.petronasGreen
              : Colors.grey.shade600);
  }

  @override
  bool shouldRepaint(_CompassPainter old) =>
      old.qiblaBearingRad != qiblaBearingRad ||
      old.hasHeading != hasHeading ||
      old.isAligned != isAligned ||
      old.isDark != isDark;
}
