import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../theme.dart';

/// Mini-game for the Perihal tab: an autonomous robot drives toward a mosque,
/// random obstacles block the road, and the user taps to make it jump.
/// No taps -> it bonks, asks for help, reverses and retries; after a few failed
/// tries the road slides away. A successful run ends with funny hops into the mosque.
class RobotMosqueGame extends StatefulWidget {
  final double width;
  const RobotMosqueGame({super.key, this.width = 300});

  @override
  State<RobotMosqueGame> createState() => _RobotMosqueGameState();
}

enum _Mode { drive, bonk, reverse, finale, rest, roadAway }

class _Obstacle {
  final double pos; // world position (px along the road)
  final int type; // 0 cone, 1 rock, 2 barrier, 3 box
  bool cleared = false;
  _Obstacle(this.pos, this.type);
  double get w => const [14.0, 20.0, 22.0, 18.0][type];
  double get h => const [16.0, 13.0, 14.0, 18.0][type];
}

class _Confetti {
  double x, y, vx, vy, life;
  final Color color;
  _Confetti(this.x, this.y, this.vx, this.vy, this.life, this.color);
}

class _RobotMosqueGameState extends State<RobotMosqueGame> with SingleTickerProviderStateMixin {
  // ── Tunables ─────────────────────────────────────────────────────────────
  static const double _worldLen = 1000; // distance to the mosque
  static const double _speed = 55; // px/s
  static const double _robotX = 70; // robot's fixed screen x
  static const double _jumpDur = 1.25;
  static const double _jumpH = 72;
  static const int _maxTries = 3;
  static const double _stopBeforeMosque = 100;

  final math.Random _rng = math.Random();
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  final ValueNotifier<int> _frame = ValueNotifier(0);

  // ── Game state (read by the painter) ────────────────────────────────────
  _Mode mode = _Mode.drive;
  double modeT = 0;
  double dist = 0; // distance travelled along the road
  double speed = 0;
  double wheelRot = 0;
  int tries = 0;
  List<_Obstacle> obstacles = [];
  double jumpT = -1; // <0 = on the ground
  bool flip = false;
  double squash = 0; // landing squash (+) / takeoff stretch (-)
  double reverseTarget = 0;
  bool demo = true; // first run after opening the tab: auto-jumps to the mosque as a preview
  bool autoJump = false; // user tapped while stuck: next obstacle is jumped automatically
  double finaleT = 0;
  double awayT = 0;
  double fallY = 0;
  double doorGlow = 0;
  final List<_Confetti> confetti = [];

  // ── Speech bubble ───────────────────────────────────────────────────────
  String? _bubble;
  String _lastBubble = '';
  double _bubbleTimer = 0;

  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _reset();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.of(context).disableAnimations;
    if (reduce && !_reduceMotion) {
      _reduceMotion = true;
      _ticker.stop();
      // Calm static frame: robot parked next to the mosque.
      dist = _worldLen - _stopBeforeMosque;
      mode = _Mode.drive;
      doorGlow = 1;
      _frame.value++;
    } else if (!reduce && !_ticker.isActive) {
      _reduceMotion = false;
      _last = Duration.zero;
      _reset();
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────
  LocaleProvider get _l => context.read<LocaleProvider>();

  void _say(String key, {double seconds = 2.4}) {
    setState(() {
      _bubble = _l.t(key);
      _lastBubble = _bubble!;
      _bubbleTimer = seconds;
    });
  }

  void _reset() {
    dist = 0;
    speed = 0;
    tries = 0;
    mode = _Mode.drive;
    modeT = 0;
    jumpT = -1;
    squash = 0;
    autoJump = demo; // preview run jumps every obstacle by itself
    finaleT = 0;
    awayT = 0;
    fallY = 0;
    doorGlow = 0;
    confetti.clear();
    // 3 random obstacles, evenly spread with some jitter
    obstacles = List.generate(3, (i) {
      final pos = 230 + i * 230 + (_rng.nextDouble() * 80 - 40);
      return _Obstacle(pos, _rng.nextInt(4));
    });
    if (mounted) setState(() => _bubble = null);
  }

  double _screenX(_Obstacle o) => _robotX + (o.pos - dist);

  /// Height of the robot above the ground (px) right now.
  double get _lift {
    if (jumpT < 0) return 0;
    final u = (jumpT / _jumpDur).clamp(0.0, 1.0);
    return 4 * _jumpH * u * (1 - u);
  }

  void _onTap() {
    if (_reduceMotion) return;
    switch (mode) {
      case _Mode.drive:
        _jump();
      case _Mode.bonk:
      case _Mode.reverse:
        // "I'll help!": back off a little, then jump every obstacle automatically
        // all the way to the mosque.
        autoJump = true;
        if (mode == _Mode.bonk) {
          mode = _Mode.reverse;
          modeT = 0;
        }
        _say('game.hehe1', seconds: 1.0);
      default:
        break;
    }
  }

  void _jump() {
    if (jumpT >= 0) return;
    jumpT = 0;
    flip = _rng.nextBool();
    squash = -0.3; // stretch on takeoff
    HapticFeedback.lightImpact();
    final key = 'game.hehe${1 + _rng.nextInt(3)}';
    setState(() {
      _bubble = _l.t(key);
      _lastBubble = _bubble!;
      _bubbleTimer = 0.9;
    });
  }

  // ── Simulation ──────────────────────────────────────────────────────────
  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05).toDouble();
    _last = elapsed;
    _update(dt);
    _frame.value++;
  }

  void _update(double dt) {
    // bubble timer
    if (_bubble != null) {
      _bubbleTimer -= dt;
      if (_bubbleTimer <= 0) setState(() => _bubble = null);
    }
    // jump + squash
    if (jumpT >= 0) {
      jumpT += dt;
      if (jumpT >= _jumpDur) {
        jumpT = -1;
        squash = 0.28; // squash on landing
        HapticFeedback.selectionClick();
      }
    }
    squash += (0 - squash) * math.min(1, dt * 9);

    modeT += dt;
    switch (mode) {
      case _Mode.drive:
        speed = math.min(_speed, speed + 110 * dt);
        dist += speed * dt;
        wheelRot += speed * dt / 8;
        doorGlow = ((dist - (_worldLen - 320)) / 220).clamp(0.0, 1.0);

        for (final o in obstacles) {
          if (o.cleared) continue;
          final sx = _screenX(o);
          final frontGap = (sx - o.w / 2) - (_robotX + 13);
          // helper jump when the user already asked for help
          if (autoJump && jumpT < 0 && frontGap <= 12 && frontGap > -6) _jump();
          final overlap = sx - o.w / 2 < _robotX + 13 && sx + o.w / 2 > _robotX - 11;
          if (overlap && _lift < o.h - 3) {
            _bonk(o);
            return;
          }
          if (sx + o.w / 2 < _robotX - 11) {
            o.cleared = true;
          }
        }
        if (dist >= _worldLen - _stopBeforeMosque) {
          mode = _Mode.finale;
          modeT = 0;
          finaleT = 0;
          speed = 0;
          doorGlow = 1;
          _say('game.win', seconds: 3.2);
        }
      case _Mode.bonk:
        speed = 0;
        if (modeT >= 1.5) {
          if (tries >= _maxTries) {
            mode = _Mode.roadAway;
            modeT = 0;
            awayT = 0;
            _say('game.roadGone', seconds: 2.6);
          } else {
            mode = _Mode.reverse;
            modeT = 0;
          }
        }
      case _Mode.reverse:
        dist -= 75 * dt;
        wheelRot -= 75 * dt / 8;
        if (dist <= reverseTarget) {
          dist = reverseTarget;
          mode = _Mode.drive;
          modeT = 0;
          speed = 0;
        }
      case _Mode.finale:
        finaleT = (finaleT + dt / 2.6).clamp(0.0, 1.0);
        wheelRot += 6 * dt;
        if (finaleT >= 1) {
          mode = _Mode.rest;
          modeT = 0;
          _burstConfetti();
        }
      case _Mode.rest:
        _updateConfetti(dt);
        if (modeT > 3.6) {
          demo = false; // preview done: now it's the real game
          _reset();
        }
      case _Mode.roadAway:
        awayT = (awayT + dt / 1.8).clamp(0.0, 1.0);
        if (awayT > 0.55) fallY += (fallY + 60) * dt * 2.2;
        if (modeT > 3.2) _reset();
    }
    if (mode == _Mode.finale || mode == _Mode.rest) _updateConfetti(dt);
  }

  void _bonk(_Obstacle o) {
    mode = _Mode.bonk;
    modeT = 0;
    speed = 0;
    tries++;
    reverseTarget = o.pos - 150;
    HapticFeedback.heavyImpact();
    _say(tries == 1 ? 'game.help' : (tries < _maxTries ? 'game.help2' : 'game.giveup'),
        seconds: 3.0);
  }

  void _burstConfetti() {
    const cols = [AppTheme.petronasYellow, AppTheme.petronasGreen, Colors.white, Color(0xFF5CE1DC)];
    for (var i = 0; i < 36; i++) {
      final a = -math.pi / 2 + (_rng.nextDouble() - 0.5) * 2.2;
      final v = 70 + _rng.nextDouble() * 110;
      confetti.add(_Confetti(170, 118, math.cos(a) * v, math.sin(a) * v, 1.6 + _rng.nextDouble(),
          cols[_rng.nextInt(cols.length)]));
    }
  }

  void _updateConfetti(double dt) {
    for (final c in confetti) {
      c.life -= dt;
      c.vy += 220 * dt;
      c.x += c.vx * dt;
      c.y += c.vy * dt;
    }
    confetti.removeWhere((c) => c.life <= 0);
  }

  // ── UI ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l = context.watch<LocaleProvider>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final k = widget.width / 300;
    final canvasH = widget.width * 170 / 300;
    const bubbleArea = 74.0;

    return SizedBox(
      width: widget.width,
      height: canvasH + bubbleArea + 22,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: bubbleArea,
              left: 0,
              width: widget.width,
              height: canvasH,
              child: CustomPaint(painter: _GamePainter(this, dark, _frame)),
            ),
            // Speech bubble above the robot
            Positioned(
              top: 0,
              left: 0,
              width: widget.width,
              height: bubbleArea,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: EdgeInsets.only(left: math.max(0, (_robotX - 40) * k)),
                  child: AnimatedScale(
                    scale: _bubble == null ? 0 : 1,
                    alignment: Alignment.bottomLeft,
                    duration: const Duration(milliseconds: 380),
                    curve: _bubble == null ? Curves.easeIn : Curves.elasticOut,
                    child: _Bubble(text: _lastBubble, dark: dark, maxWidth: widget.width * 0.78),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  l.t(demo ? 'game.preview' : 'game.hint'),
                  style: TextStyle(
                    fontSize: 11,
                    color: (dark ? Colors.white : Colors.black).withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Comic speech bubble: ONE outline (rounded box + pointer merged into a single
/// shape), so it reads as a single dialog bar.
class _Bubble extends StatelessWidget {
  final String text;
  final bool dark;
  final double maxWidth;
  const _Bubble({required this.text, required this.dark, required this.maxWidth});

  static const double _tail = 9;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BubblePainter(
        fill: dark ? const Color(0xFF00263F) : Colors.white,
        border: AppTheme.petronasYellow,
        tail: _tail,
      ),
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.fromLTRB(13, 8, 13, 8 + _tail),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            height: 1.25,
            color: dark ? Colors.white : AppTheme.petronasBlue,
          ),
        ),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  final Color fill;
  final Color border;
  final double tail;
  _BubblePainter({required this.fill, required this.border, required this.tail});

  @override
  void paint(Canvas canvas, Size size) {
    final bodyH = size.height - tail;
    final box = Path()
      ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, bodyH), const Radius.circular(14)));
    // pointer sits under the box, overlapping it so the union is seamless
    const tx = 24.0;
    final pointer = Path()
      ..moveTo(tx, bodyH - 3)
      ..lineTo(tx + 16, bodyH - 3)
      ..lineTo(tx + 5, size.height)
      ..close();
    final shape = Path.combine(PathOperation.union, box, pointer);

    canvas.drawPath(
      shape,
      Paint()
        ..color = border.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawPath(shape, Paint()..color = fill);
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round
        ..color = border,
    );
  }

  @override
  bool shouldRepaint(_BubblePainter old) => old.fill != fill || old.border != border;
}

class _GamePainter extends CustomPainter {
  final _RobotMosqueGameState g;
  final bool dark;
  _GamePainter(this.g, this.dark, Listenable repaint) : super(repaint: repaint);

  static const double _ground = 140;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 300;
    canvas.scale(k, k);
    final line = dark ? AppTheme.petronasGreen : AppTheme.petronasBlue;
    final ink = dark ? Colors.white : AppTheme.petronasBlue;

    // ── World (road, obstacles, mosque): slides away when the road is lost ──
    canvas.save();
    final slide = g.mode == _Mode.roadAway ? -(g.awayT * g.awayT) * 420 : 0.0;
    canvas.translate(slide, 0);

    // road
    canvas.drawLine(const Offset(-40, _ground), const Offset(900, _ground),
        Paint()..color = line.withValues(alpha: 0.55)..strokeWidth = 1.6);
    final dash = Paint()..color = line.withValues(alpha: 0.25)..strokeWidth = 1.4;
    final shift = (-g.dist) % 24;
    for (double x = -24 + shift; x < 340; x += 24) {
      canvas.drawLine(Offset(x, _ground + 8), Offset(x + 12, _ground + 8), dash);
    }

    // mosque (door x follows the world)
    final doorX = _RobotMosqueGameState._robotX + (_RobotMosqueGameState._worldLen - g.dist);
    if (doorX < 420) _drawMosque(canvas, doorX, line, g.doorGlow);

    // obstacles
    for (final o in g.obstacles) {
      final sx = g._screenX(o);
      if (sx > -30 && sx < 340) _drawObstacle(canvas, o, sx);
    }
    canvas.restore();

    // ── Robot ───────────────────────────────────────────────────────────────
    _drawRobot(canvas, ink);

    // confetti
    for (final c in g.confetti) {
      canvas.drawRect(Rect.fromCenter(center: Offset(c.x, c.y), width: 4, height: 3),
          Paint()..color = c.color.withValues(alpha: (c.life / 1.2).clamp(0.0, 1.0)));
    }
  }

  void _drawMosque(Canvas canvas, double doorX, Color line, double glow) {
    canvas.save();
    canvas.translate(doorX - 213, 0);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeJoin = StrokeJoin.round
      ..color = line;
    final fill = Paint()..color = line.withValues(alpha: dark ? 0.10 : 0.08);

    final hall = RRect.fromRectAndRadius(const Rect.fromLTRB(168, 100, 258, _ground), const Radius.circular(3));
    canvas.drawRRect(hall, fill);
    canvas.drawRRect(hall, stroke);
    final dome = Path()
      ..moveTo(190, 100)
      ..arcToPoint(const Offset(236, 100), radius: const Radius.circular(23), clockwise: true);
    canvas.drawPath(dome, fill);
    canvas.drawPath(dome, stroke);
    canvas.drawLine(const Offset(213, 77), const Offset(213, 66), stroke);
    canvas.drawCircle(const Offset(213, 61), 5, Paint()..color = AppTheme.petronasYellow);
    canvas.drawCircle(Offset(215.2, 59.8), 4.4, Paint()..color = dark ? AppTheme.bgDeep : Colors.white);
    for (final mx in [160.0, 268.0]) {
      final m = Path()
        ..moveTo(mx - 4.5, _ground)
        ..lineTo(mx - 4.5, 62)
        ..lineTo(mx, 44)
        ..lineTo(mx + 4.5, 62)
        ..lineTo(mx + 4.5, _ground);
      canvas.drawPath(m, fill);
      canvas.drawPath(m, stroke);
      canvas.drawLine(Offset(mx - 4.5, 76), Offset(mx + 4.5, 76), stroke);
      canvas.drawLine(Offset(mx - 4.5, 92), Offset(mx + 4.5, 92), stroke);
    }
    final win = Paint()..color = AppTheme.petronasYellow.withValues(alpha: 0.18 + 0.3 * glow);
    for (final wx in [178.0, 244.0]) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(wx - 3, 112, 6, 14), const Radius.circular(3)), win);
    }
    final door = RRect.fromRectAndCorners(const Rect.fromLTRB(203, 112, 223, _ground),
        topLeft: const Radius.circular(10), topRight: const Radius.circular(10));
    canvas.drawRRect(
        door,
        Paint()
          ..color = AppTheme.petronasYellow.withValues(alpha: 0.12 + 0.32 * glow)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    canvas.drawRRect(door, Paint()..color = AppTheme.petronasYellow.withValues(alpha: 0.35 + 0.55 * glow));
    canvas.restore();
  }

  void _drawObstacle(Canvas canvas, _Obstacle o, double sx) {
    canvas.save();
    canvas.translate(sx, _ground);
    final navy = const Color(0xFF002244);
    switch (o.type) {
      case 0: // traffic cone
        canvas.drawPath(
            Path()..moveTo(-7, 0)..lineTo(7, 0)..lineTo(2.5, -16)..lineTo(-2.5, -16)..close(),
            Paint()..color = AppTheme.petronasYellow);
        canvas.drawRect(const Rect.fromLTRB(-4.6, -9, 4.6, -6.2), Paint()..color = navy);
        canvas.drawRect(const Rect.fromLTRB(-8, -1.6, 8, 0), Paint()..color = navy);
      case 1: // rock
        canvas.drawOval(const Rect.fromLTRB(-10, -13, 10, 0), Paint()..color = const Color(0xFF6B7C8C));
        canvas.drawOval(const Rect.fromLTRB(-6, -11, 1, -6), Paint()..color = Colors.white.withValues(alpha: 0.25));
      case 2: // striped barrier
        canvas.drawRect(const Rect.fromLTRB(-10, -14, 10, -7), Paint()..color = Colors.white);
        for (var i = -10.0; i < 10; i += 8) {
          canvas.drawPath(
              Path()..moveTo(i, -14)..lineTo(i + 4, -14)..lineTo(i, -7)..lineTo(i - 4, -7)..close(),
              Paint()..color = AppTheme.petronasGreen);
        }
        canvas.drawLine(const Offset(-8, -7), const Offset(-8, 0), Paint()..color = navy..strokeWidth = 1.6);
        canvas.drawLine(const Offset(8, -7), const Offset(8, 0), Paint()..color = navy..strokeWidth = 1.6);
      default: // crate with "!"
        final r = RRect.fromRectAndRadius(const Rect.fromLTRB(-9, -18, 9, 0), const Radius.circular(2.5));
        canvas.drawRRect(r, Paint()..color = navy);
        canvas.drawRRect(r,
            Paint()..style = PaintingStyle.stroke..strokeWidth = 1.6..color = AppTheme.petronasYellow);
        canvas.drawLine(const Offset(0, -14), const Offset(0, -7.5),
            Paint()..color = AppTheme.petronasYellow..strokeWidth = 2..strokeCap = StrokeCap.round);
        canvas.drawCircle(const Offset(0, -4), 1.2, Paint()..color = AppTheme.petronasYellow);
    }
    canvas.restore();
  }

  void _drawRobot(Canvas canvas, Color ink) {
    // Position & pose
    double x = _RobotMosqueGameState._robotX;
    double lift = g._lift;
    double rot = 0;
    double alpha = 1;
    double scaleX = 1, scaleY = 1;
    final s = g.squash;
    scaleY = 1 - s * 0.6;
    scaleX = 1 + s * 0.5;
    if (g.jumpT >= 0 && g.flip) rot = -(g.jumpT / _RobotMosqueGameState._jumpDur) * 2 * math.pi;

    switch (g.mode) {
      case _Mode.bonk:
        rot = math.sin(g.modeT * 38) * 0.10 * (1 - g.modeT / 1.5).clamp(0.0, 1.0); // dizzy shake
        x -= math.min(g.modeT * 40, 6) * (g.modeT < 0.15 ? 1 : 0); // tiny recoil
      case _Mode.finale:
        // three funny hops from the road into the mosque door
        final t = g.finaleT;
        final doorX = _RobotMosqueGameState._robotX + _RobotMosqueGameState._stopBeforeMosque;
        x = _RobotMosqueGameState._robotX + (doorX - _RobotMosqueGameState._robotX) * Curves.easeOut.transform(t);
        lift = (math.sin(t * 3 * math.pi)).abs() * 38;
        rot = (t > 0.45 && t < 0.78) ? -((t - 0.45) / 0.33) * 2 * math.pi : 0;
        if (t > 0.85) {
          final f = (t - 0.85) / 0.15;
          alpha = 1 - f;
          scaleX = scaleY = 1 - 0.5 * f; // hops into the door
        }
      case _Mode.rest:
        alpha = 0;
      case _Mode.roadAway:
        if (g.awayT > 0.55) {
          lift = -g.fallY * 0.35;
          rot = g.fallY * 0.03;
          alpha = (1 - (g.fallY / 120)).clamp(0.0, 1.0);
        }
      default:
        break;
    }
    if (alpha <= 0) return;
    final bob = (g.mode == _Mode.drive && lift == 0) ? math.sin(g.dist * 0.5) * 0.6 : 0.0;

    canvas.save();
    canvas.translate(x, _ground - 8 - lift + bob);
    canvas.rotate(rot);
    canvas.scale(scaleX, scaleY);
    final a = alpha;
    final pulse = 0.5 + 0.5 * math.sin(g.wheelRot * 0.9);

    // scan cone only while driving normally
    if (g.mode == _Mode.drive || g.mode == _Mode.reverse) {
      final cone = Path()..moveTo(24, -12)..lineTo(88, -34)..lineTo(88, 12)..close();
      canvas.drawPath(
        cone,
        Paint()
          ..shader = LinearGradient(colors: [
            AppTheme.petronasGreen.withValues(alpha: (0.22 + 0.10 * pulse) * a),
            AppTheme.petronasGreen.withValues(alpha: 0),
          ]).createShader(const Rect.fromLTWH(24, -34, 64, 46)),
      );
    }

    // wheels
    for (final wx in [-14.0, 14.0]) {
      canvas.save();
      canvas.translate(wx, 0);
      canvas.drawCircle(Offset.zero, 8, Paint()..color = (dark ? const Color(0xFF00243C) : Colors.white).withValues(alpha: a));
      canvas.drawCircle(Offset.zero, 8, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.6..color = ink.withValues(alpha: a));
      canvas.rotate(g.wheelRot);
      final spoke = Paint()..strokeWidth = 1.4..color = AppTheme.petronasGreen.withValues(alpha: a);
      for (var i = 0; i < 3; i++) {
        final ang = i * math.pi / 3;
        canvas.drawLine(Offset(math.cos(ang) * -6, math.sin(ang) * -6), Offset(math.cos(ang) * 6, math.sin(ang) * 6), spoke);
      }
      canvas.restore();
    }

    // body
    final body = RRect.fromRectAndRadius(const Rect.fromLTRB(-25, -26, 25, -4), const Radius.circular(9));
    canvas.drawRRect(body, Paint()..color = (dark ? const Color(0xFF002E4A) : Colors.white).withValues(alpha: a));
    canvas.drawRRect(body, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.8..color = AppTheme.petronasGreen.withValues(alpha: a));
    canvas.drawLine(const Offset(-18, -22), const Offset(2, -22),
        Paint()..strokeWidth = 1.4..strokeCap = StrokeCap.round..color = ink.withValues(alpha: 0.35 * a));

    // visor: eyes change with mood
    final bonked = g.mode == _Mode.bonk || g.mode == _Mode.roadAway;
    final happy = g.jumpT >= 0 || g.mode == _Mode.finale;
    final visor = Paint()..color = AppTheme.petronasYellow.withValues(alpha: a);
    if (bonked) {
      // dizzy "x x" eyes
      final x1 = Paint()..strokeWidth = 1.8..strokeCap = StrokeCap.round..color = AppTheme.petronasYellow.withValues(alpha: a);
      for (final cx in [9.0, 17.0]) {
        canvas.drawLine(Offset(cx - 2.2, -20.5), Offset(cx + 2.2, -15.5), x1);
        canvas.drawLine(Offset(cx + 2.2, -20.5), Offset(cx - 2.2, -15.5), x1);
      }
    } else if (happy) {
      // happy "^ ^" eyes
      final e = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.8..strokeCap = StrokeCap.round..color = AppTheme.petronasYellow.withValues(alpha: a);
      for (final cx in [9.0, 17.0]) {
        canvas.drawPath(Path()..moveTo(cx - 2.6, -15.5)..quadraticBezierTo(cx, -21.5, cx + 2.6, -15.5), e);
      }
    } else {
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(6, -21, 21, -14), const Radius.circular(3.5)), visor);
    }

    // LiDAR puck + sweep, antenna
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(-7, -32, 7, -26), const Radius.circular(3)),
        Paint()..color = AppTheme.petronasGreen.withValues(alpha: a));
    final sweep = (g.wheelRot * 0.6) % (2 * math.pi);
    canvas.drawArc(Rect.fromCircle(center: const Offset(0, -29), radius: 11), sweep, 1.0, false,
        Paint()..style = PaintingStyle.stroke..strokeWidth = 1.6..strokeCap = StrokeCap.round
          ..color = AppTheme.petronasYellow.withValues(alpha: 0.9 * a));
    canvas.drawLine(const Offset(-16, -26), const Offset(-16, -34), Paint()..strokeWidth = 1.3..color = ink.withValues(alpha: a));
    canvas.drawCircle(const Offset(-16, -35), 2, Paint()..color = AppTheme.petronasYellow.withValues(alpha: a));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GamePainter old) => true;
}
