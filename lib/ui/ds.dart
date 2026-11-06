import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../theme.dart';

/// Shared building blocks for the "clean cockpit" look:
/// glass panels, a progress ring instrument and a calm entrance animation.

bool isDarkOf(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

/// Frosted panel with a hairline teal border. [glow] (0..1) adds a soft halo.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;
  final bool highlighted;
  final double glow;
  final double opacity;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.radius = 18,
    this.highlighted = false,
    this.glow = 0,
    this.opacity = 1,
  });

  @override
  Widget build(BuildContext context) {
    final dark = isDarkOf(context);
    final borderColor = highlighted
        ? AppTheme.petronasGreen
        : (dark
            ? AppTheme.petronasGreen.withValues(alpha: 0.22)
            : Colors.black.withValues(alpha: 0.08));
    final fill = dark
        ? (highlighted
            ? AppTheme.petronasGreen.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.04))
        : (highlighted
            ? AppTheme.petronasGreen.withValues(alpha: 0.08)
            : Colors.white);

    return Opacity(
      opacity: opacity,
      child: Container(
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: borderColor, width: highlighted ? 1.4 : 1),
          boxShadow: [
            if (glow > 0)
              BoxShadow(
                color: AppTheme.petronasGreen.withValues(alpha: 0.10 + 0.22 * glow),
                blurRadius: 10 + 14 * glow,
                spreadRadius: 0,
              )
            else if (!dark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// Fade + slide up once, staggered by [index]. Respects "reduce animations".
class EnterAnimation extends StatelessWidget {
  final int index;
  final Widget child;
  const EnterAnimation({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + index * 90),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 18), child: child),
      ),
      child: child,
    );
  }
}

/// Fidget-spinner physics for the ring's car.
///
/// Drag the car around the ring: it follows the finger and the LiDAR sweep speeds
/// up with the motion. On release it keeps spinning (many turns for a fast swipe)
/// with friction, then eases in and settles back at its real progress position.
class RingSpin extends ChangeNotifier {
  RingSpin({required TickerProvider vsync}) {
    _ticker = vsync.createTicker(_tick);
  }

  static const double _twoPi = 2 * math.pi;
  late final Ticker _ticker;

  double offset = 0; // radians away from the real progress position (unwrapped)
  double omega = 0; // current angular velocity, rad/s
  double extraScan = 0; // accumulated extra LiDAR sweep phase (turns)

  bool _dragging = false;
  bool _settling = false;
  double _lastTouch = 0;
  double _unwrapped = 0; // finger angle, unwrapped across turns
  // (angle, time) samples of the last ~120 ms of finger motion – timestamps come
  // from the touch events themselves, so bursts of events within one frame are fine.
  final List<(double, Duration)> _samples = [];
  final Stopwatch _sinceMove = Stopwatch();
  double _vel = 0; // finger angular velocity while dragging
  Duration _last = Duration.zero;
  int _hapticStep = 0;

  double _sFrom = 0, _sTo = 0, _sT = 0, _sDur = 1;

  bool get active => _dragging || _settling || omega.abs() > 0.05 || offset.abs() > 0.001;

  void grab(double touchAngle, Duration time) {
    _dragging = true;
    _settling = false;
    _lastTouch = touchAngle;
    _unwrapped = 0;
    _samples
      ..clear()
      ..add((0.0, time));
    _sinceMove
      ..reset()
      ..start();
    _vel = 0;
    omega = 0;
    _start();
  }

  void dragTo(double touchAngle, Duration time) {
    if (!_dragging) return;
    var d = touchAngle - _lastTouch;
    while (d > math.pi) {
      d -= _twoPi;
    }
    while (d < -math.pi) {
      d += _twoPi;
    }
    _lastTouch = touchAngle;
    _unwrapped += d;
    offset += d;

    _samples.add((_unwrapped, time));
    while (_samples.length > 2 && (time - _samples.first.$2).inMilliseconds > 120) {
      _samples.removeAt(0);
    }
    final dt = (time - _samples.first.$2).inMicroseconds / 1e6;
    if (dt > 0.008) {
      _vel = (_unwrapped - _samples.first.$1) / dt;
    }
    _sinceMove
      ..reset()
      ..start();
    omega = _vel;
    notifyListeners();
  }

  void release() {
    if (!_dragging) return;
    _dragging = false;
    omega = _vel.clamp(-45.0, 45.0).toDouble();
    if (omega.abs() < 0.9) _beginSettle();
  }

  void _start() {
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _beginSettle() {
    _settling = true;
    _sFrom = offset;
    final dir = omega == 0 ? (offset >= 0 ? -1.0 : 1.0) : omega.sign;
    // stop at the next full turn in the direction of travel (== original spot)
    final turns = offset / _twoPi;
    var target = (dir > 0 ? turns.ceil() : turns.floor()) * _twoPi;
    if ((target - offset).abs() < 0.2) target += dir * _twoPi;
    // a fling that has nearly stopped should take the short way home
    if (omega.abs() < 0.9 && (offset - (offset / _twoPi).round() * _twoPi).abs() < math.pi) {
      target = (offset / _twoPi).round() * _twoPi;
    }
    _sTo = target;
    _sT = 0;
    _sDur = 0.55 + (target - offset).abs() * 0.35;
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05).toDouble();
    _last = elapsed;

    if (_dragging) {
      // finger resting: velocity bleeds off
      if (_sinceMove.elapsedMilliseconds > 90) {
        _vel *= math.pow(0.02, dt).toDouble();
        omega = _vel;
      }
    } else if (_settling) {
      _sT += dt;
      final t = (_sT / _sDur).clamp(0.0, 1.0);
      final e = Curves.easeOutCubic.transform(t);
      final prev = offset;
      offset = _sFrom + (_sTo - _sFrom) * e;
      omega = dt > 0 ? (offset - prev) / dt : 0;
      if (t >= 1) {
        offset = 0; // a whole number of turns == back at the real position
        omega = 0;
        _settling = false;
        _ticker.stop();
        notifyListeners();
        return;
      }
    } else {
      // free spin with friction
      offset += omega * dt;
      omega *= math.exp(-0.85 * dt);
      omega -= omega.sign * 0.35 * dt;
      if (omega.abs() < 0.9) _beginSettle();
    }

    extraScan += omega.abs() * dt / _twoPi * 1.1;
    final step = (offset / math.pi).floor();
    if (step != _hapticStep) {
      _hapticStep = step;
      if (omega.abs() > 1.5) HapticFeedback.selectionClick();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

/// Circular "road" instrument for the countdown.
///
/// The ring is a lane the car drives around: lane edges + dashed centre line,
/// the solid teal arc is the path already driven, the dashed yellow curve with
/// waypoints (and faint candidate trajectories) is the planned path ahead, and
/// a rotating LiDAR sweep lights up a point cloud on the lane edges around the
/// top-view car at the leading edge.
class RingPainter extends CustomPainter {
  final double progress; // 0..1 along the road
  final double pulse; // 0..1 (ping-pong) – soft glow
  final double scan; // 0..1 (continuous) – LiDAR sweep phase
  final double spin; // radians the car is displaced from its real position
  final double omega; // car angular velocity (rad/s) while spinning
  final bool dark;

  RingPainter({
    required this.progress,
    required this.pulse,
    required this.scan,
    required this.dark,
    this.spin = 0,
    this.omega = 0,
  });

  static const double _twoPi = 2 * math.pi;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 22;
    final p = progress.clamp(0.0, 1.0);
    final s = (radius / 120).clamp(0.6, 1.0); // scale car/lidar with the ring
    const teal = AppTheme.petronasGreen;
    const yellow = AppTheme.petronasYellow;
    final ink = dark ? Colors.white : Colors.black;
    final rect = Rect.fromCircle(center: center, radius: radius);

    Offset at(double ang, double r) =>
        center + Offset(math.cos(ang), math.sin(ang)) * r;

    // ── Distance ticks outside the road ─────────────────────────────────
    final tick = Paint()
      ..strokeCap = StrokeCap.round
      ..color = ink.withValues(alpha: dark ? 0.14 : 0.12);
    for (int i = 0; i < 60; i++) {
      final a = -math.pi / 2 + i * _twoPi / 60;
      final major = i % 5 == 0;
      tick.strokeWidth = major ? 2 : 1;
      canvas.drawLine(at(a, radius + 16), at(a, radius + (major ? 23 : 20)), tick);
    }

    // ── Road: lane edges + dashed centre line ───────────────────────────
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = teal.withValues(alpha: 0.30);
    canvas.drawCircle(center, radius + 11, edge);
    canvas.drawCircle(center, radius - 11, edge);
    final lane = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = teal.withValues(alpha: 0.22);
    const dashes = 72;
    for (int i = 0; i < dashes; i++) {
      canvas.drawArc(rect, -math.pi / 2 + i * _twoPi / dashes, _twoPi / dashes * 0.5, false, lane);
    }

    // ── Path already driven (glowing trace) ─────────────────────────────
    final carAng = -math.pi / 2 + _twoPi * p + spin;
    final dir = omega < -0.4 ? -1.0 : 1.0; // heading follows the spin direction
    final spinning = spin.abs() > 0.02 || omega.abs() > 0.2;
    if (p > 0) {
      final sweep = _twoPi * p;
      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round
          ..color = teal.withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            startAngle: -math.pi / 2,
            endAngle: -math.pi / 2 + _twoPi,
            colors: const [Color(0xFF007A76), AppTheme.petronasGreen, Color(0xFF5CE1DC)],
            stops: const [0.0, 0.7, 1.0],
          ).createShader(rect),
      );
    }

    // ── Path planning ahead of the car ──────────────────────────────────
    final remaining = _twoPi * (1 - p);
    final ahead = spinning ? 1.5 : math.min(remaining, 1.5); // radians planned ahead
    if (ahead > 0.05) {
      // Candidate trajectories (faint) – the planner's alternatives
      for (final side in [-1.0, 1.0]) {
        final path = Path();
        const n = 28;
        for (int i = 0; i <= n; i++) {
          final d = ahead * i / n;
          final off = side * 7 * math.sin(math.pi * i / n) * (0.6 + 0.4 * math.sin(scan * _twoPi));
          final pt = at(carAng + dir * d, radius + off);
          i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
        }
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = teal.withValues(alpha: 0.28),
        );
      }
      // Chosen trajectory: dashed, fading with distance
      const segs = 22;
      for (int i = 0; i < segs; i += 2) {
        final d0 = ahead * i / segs, d1 = ahead * (i + 1) / segs;
        final fadeA = 1 - i / segs;
        canvas.drawArc(
          rect,
          carAng + dir * d0,
          dir * (d1 - d0),
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..strokeCap = StrokeCap.round
            ..color = yellow.withValues(alpha: 0.9 * fadeA),
        );
      }
      // Waypoints
      for (final f in [0.34, 0.67, 1.0]) {
        final wp = at(carAng + dir * ahead * f, radius);
        final a = (1 - f * 0.7);
        canvas.drawCircle(wp, 4.2 * s, Paint()..color = (dark ? AppTheme.bgDeep : Colors.white));
        canvas.drawCircle(
          wp,
          4.2 * s,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = yellow.withValues(alpha: a),
        );
      }
    }

    // ── Speed trail behind a spinning car ───────────────────────────────
    if (omega.abs() > 1.2) {
      final len = math.min(1.6, 0.12 + omega.abs() * 0.045);
      const parts = 14;
      for (int i = 0; i < parts; i++) {
        final f0 = i / parts, f1 = (i + 1) / parts;
        canvas.drawArc(
          rect,
          carAng - dir * len * (1 - f0),
          dir * len * (f1 - f0) * 1.05,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3 + 5 * f1
            ..strokeCap = StrokeCap.round
            ..color = Color.lerp(teal, yellow, f1)!.withValues(alpha: 0.55 * f1),
        );
      }
    }

    // ── LiDAR: sweep, range rings, point cloud on the lane edges ────────
    final car = at(carAng, radius);
    final lidarR = 50 * s;
    final phi = scan * _twoPi;
    canvas.drawCircle(
        car, lidarR, Paint()..style = PaintingStyle.stroke..strokeWidth = 0.8..color = teal.withValues(alpha: 0.18));
    canvas.drawCircle(
        car, lidarR * 0.5, Paint()..style = PaintingStyle.stroke..strokeWidth = 0.8..color = teal.withValues(alpha: 0.12));
    // sweeping wedge with a fading trail
    final wedgeRect = Rect.fromCircle(center: car, radius: lidarR);
    canvas.drawArc(
      wedgeRect,
      phi - 0.9,
      0.9,
      true,
      Paint()
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: 0.9,
          colors: [teal.withValues(alpha: 0), const Color(0xFF5CE1DC).withValues(alpha: 0.42)],
          transform: GradientRotation(phi - 0.9),
        ).createShader(wedgeRect),
    );
    canvas.drawLine(car, car + Offset(math.cos(phi), math.sin(phi)) * lidarR,
        Paint()..strokeWidth = 1.2..color = const Color(0xFF5CE1DC).withValues(alpha: 0.85));
    // point cloud returns from both lane edges, lit as the beam passes
    for (final er in [radius - 11, radius + 11]) {
      for (double da = -0.55; da <= 0.55; da += 0.03) {
        final pt = at(carAng + da, er);
        final v = pt - car;
        if (v.distance > lidarR || v.distance < 4) continue;
        final dir = math.atan2(v.dy, v.dx);
        var behind = (phi - dir) % _twoPi;
        if (behind < 0) behind += _twoPi;
        final lit = behind < 2.2 ? 1 - behind / 2.2 : 0.0;
        canvas.drawCircle(
          pt,
          1.3 + 1.0 * lit,
          Paint()..color = (lit > 0.5 ? yellow : teal).withValues(alpha: 0.18 + 0.8 * lit),
        );
      }
    }

    // ── Top-view autonomous car (heading along the road, clockwise) ─────
    canvas.save();
    canvas.translate(car.dx, car.dy);
    canvas.rotate(carAng + dir * math.pi / 2);
    canvas.scale(s);
    // headlight beams
    for (final y in [-4.5, 4.5]) {
      final beam = Path()
        ..moveTo(12, y)
        ..lineTo(34, y - 6)
        ..lineTo(34, y + 6)
        ..close();
      canvas.drawPath(
        beam,
        Paint()
          ..shader = LinearGradient(
            colors: [Colors.white.withValues(alpha: 0.32), Colors.white.withValues(alpha: 0)],
          ).createShader(const Rect.fromLTWH(12, -12, 22, 24)),
      );
    }
    // glow + body
    final body = RRect.fromRectAndRadius(
        const Rect.fromLTRB(-12.5, -6.8, 12.5, 6.8), const Radius.circular(5));
    canvas.drawRRect(
      body,
      Paint()
        ..color = yellow.withValues(alpha: 0.25 + 0.2 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawRRect(body, Paint()..color = yellow);
    // glass: windshield (front) and rear window
    final glass = Paint()..color = const Color(0xFF00243C);
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTRB(3, -5, 8.5, 5), const Radius.circular(2)), glass);
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTRB(-10, -4.6, -6.5, 4.6), const Radius.circular(1.6)), glass);
    // roof LiDAR puck
    canvas.drawCircle(const Offset(-1, 0), 3.1, Paint()..color = Colors.white);
    canvas.drawCircle(
        const Offset(-1, 0), 3.1, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = teal);
    // headlights + tail lights
    for (final y in [-4.6, 4.6]) {
      canvas.drawCircle(Offset(12, y), 1.6, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(-12, y), 1.3, Paint()..color = const Color(0xFFFF5252));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(RingPainter old) =>
      old.progress != progress || old.pulse != pulse || old.scan != scan || old.dark != dark ||
      old.spin != spin || old.omega != omega;
}
