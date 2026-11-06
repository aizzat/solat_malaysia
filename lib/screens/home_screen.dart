import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:hijri/hijri_calendar.dart';
import 'dart:async';
import '../providers/prayer_provider.dart';
import '../providers/locale_provider.dart';
import '../theme.dart';
import '../ui/ds.dart';
import 'dart:math' as math;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  Timer? _timer;
  // Only the widgets listening to this rebuild every second (not the whole screen).
  final ValueNotifier<DateTime> _now = ValueNotifier(DateTime.now());
  late final AnimationController _pulse;
  late final AnimationController _scan; // continuous LiDAR sweep
  late final RingSpin _spin = RingSpin(vsync: this); // fidget-spinner car
  final GlobalKey _ringKey = GlobalKey();
  double _progressNow = 0;
  // Guard to avoid calling fetchData() more than once per end-of-day cycle
  bool _autoRefreshedForTomorrow = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _scan = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      _now.value = DateTime.now();
      _checkEndOfDayAutoRefresh(_now.value);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    _scan.dispose();
    _spin.dispose();
    _now.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honour the system "remove animations" setting.
    if (MediaQuery.of(context).disableAnimations) {
      _pulse.stop();
      _pulse.value = 0.5;
      _scan.stop();
      _scan.value = 0.12;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
      _scan.repeat();
    }
  }

  // ── Fidget-spinner interaction on the car ───────────────────────────────
  double? _touchAngle(Offset global) {
    final box = _ringKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final local = box.globalToLocal(global);
    final c = box.size.center(Offset.zero);
    return math.atan2(local.dy - c.dy, local.dx - c.dx);
  }

  /// Car position inside the ring box (same geometry as RingPainter).
  Offset _carPosition(Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 - 22;
    final ang = -math.pi / 2 + 2 * math.pi * _progressNow + _spin.offset;
    return c + Offset(math.cos(ang), math.sin(ang)) * r;
  }

  /// When all today's prayers have passed, proactively fetch tomorrow's data
  /// so the widget gets fresh timestamps immediately after Isha.
  void _checkEndOfDayAutoRefresh(DateTime now) {
    if (!mounted) return;
    final provider = context.read<PrayerProvider>();
    if (provider.isLoading || provider.prayerTimes.isEmpty) return;

    final todayPrayer = provider.getTodayPrayer();
    if (todayPrayer == null) return;

    // All prayers including Isha have passed
    if (now.isAfter(todayPrayer.isha) && !_autoRefreshedForTomorrow) {
      _autoRefreshedForTomorrow = true;
      provider.fetchData();
    }

    // Reset the guard at midnight so next day it can trigger again
    if (now.hour == 0 && now.minute == 0 && now.second < 2) {
      _autoRefreshedForTomorrow = false;
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) return "00:00:00";
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final l = context.watch<LocaleProvider>();
    return Consumer<PrayerProvider>(
      builder: (context, provider, child) {
        final isDark = isDarkOf(context);

        // Only show full-screen loader if there is NO cached data available yet (e.g. first app launch)
        if (provider.prayerTimes.isEmpty && provider.isLoading) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.petronasGreen));
        }

        // Only show full-screen error if there is NO cached prayer data to display
        if (provider.errorMessage.isNotEmpty && provider.prayerTimes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(l.t('home.error', {'message': provider.errorMessage})),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => provider.fetchData(),
                  child: Text(l.t('home.retry')),
                )
              ],
            ),
          );
        }

        // Provider initialised but no data yet
        if (provider.prayerTimes.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.petronasGreen));
        }

        final todayPrayer = provider.getTodayPrayer();
        if (todayPrayer == null) {
          return Center(child: Text(l.t('home.noTimes')));
        }

        final prayers = <_Prayer>[
          _Prayer('Fajr', todayPrayer.fajr),
          _Prayer('Sunrise', todayPrayer.sunrise),
          _Prayer('Dhuhr', todayPrayer.dhuhr),
          _Prayer('Asr', todayPrayer.asr),
          _Prayer('Maghrib', todayPrayer.maghrib),
          _Prayer('Isha', todayPrayer.isha),
        ];

        final loc = provider.locationResult;
        final String locationStr =
            loc?.city ?? (loc?.country ?? l.t('home.unknownLocation'));
        final subtle = isDark ? Colors.white60 : Colors.black54;

        return RefreshIndicator(
          onRefresh: () => provider.fetchData(),
          color: AppTheme.petronasGreen,
          // Content is exactly one viewport tall, so the page itself never scrolls;
          // the scroll view only exists to allow pull-to-refresh.
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: constraints.maxHeight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: Column(
                    children: [
                      // Thin progress line while refreshing in the background
                      SizedBox(
                        height: 3,
                        child: provider.isLoading
                            ? const LinearProgressIndicator(
                                color: AppTheme.petronasGreen,
                                backgroundColor: Colors.transparent,
                              )
                            : null,
                      ),
                      const SizedBox(height: 6),

                      // ── Date + location header ─────────────────────────
                      EnterAnimation(
                        index: 0,
                        child: ValueListenableBuilder<DateTime>(
                          valueListenable: _now,
                          builder: (context, now, _) {
                            final hijri = HijriCalendar.fromDate(now);
                            return Column(
                              children: [
                                Text(
                                  DateFormat('EEEE, d MMMM y', l.language).format(now),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${hijri.hDay} ${hijri.longMonthName} ${hijri.hYear}H',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppTheme.petronasGreen : AppTheme.petronasBlue,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      EnterAnimation(
                        index: 1,
                        child: GlassPanel(
                          radius: 30,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.my_location, color: AppTheme.petronasYellow, size: 14),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  locationStr,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),

                      // ── Countdown ring + prayer list (rebuild each second) ─
                      Expanded(
                        child: ValueListenableBuilder<DateTime>(
                          valueListenable: _now,
                          builder: (context, now, _) {
                            final nextIdx = prayers.indexWhere((p) => p.time.isAfter(now));
                            final DateTime nextTime;
                            final String nextName;
                            final DateTime prevTime;
                            if (nextIdx == -1) {
                              nextName = 'FajrTomorrow';
                              nextTime = todayPrayer.fajr.add(const Duration(days: 1));
                              prevTime = todayPrayer.isha;
                            } else {
                              nextName = prayers[nextIdx].name;
                              nextTime = prayers[nextIdx].time;
                              prevTime = nextIdx == 0
                                  ? todayPrayer.isha.subtract(const Duration(days: 1))
                                  : prayers[nextIdx - 1].time;
                            }
                            final total = nextTime.difference(prevTime).inSeconds;
                            final elapsed = now.difference(prevTime).inSeconds;
                            final progress = total <= 0 ? 0.0 : (elapsed / total).clamp(0.0, 1.0);
                            final remaining = nextTime.difference(now);
                            final timeFmt = provider.use24HourFormat ? 'HH:mm' : 'hh:mm a';

                            return Column(
                              children: [
                                // Ring takes whatever height is left after the rows
                                Expanded(
                                  flex: 9,
                                  child: EnterAnimation(
                                    index: 2,
                                    child: LayoutBuilder(
                                      builder: (context, box) {
                                        final side = box.biggest.shortestSide;
                                        _progressNow = progress;
                                        final painted = AnimatedBuilder(
                                          animation: Listenable.merge([_pulse, _scan, _spin]),
                                          builder: (context, _) => CustomPaint(
                                            size: Size.infinite,
                                            painter: RingPainter(
                                              progress: progress,
                                              pulse: _pulse.value,
                                              scan: (_scan.value + _spin.extraScan) % 1.0,
                                              spin: _spin.offset,
                                              omega: _spin.omega,
                                              dark: isDark,
                                            ),
                                            child: Center(
                                              child: SizedBox(
                                                width: side * 0.66,
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        l.t('home.timeTo', {'prayer': l.prayer(nextName)}).toUpperCase(),
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          letterSpacing: 1.4,
                                                          fontWeight: FontWeight.w600,
                                                          color: subtle,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        _formatDuration(remaining),
                                                        style: TextStyle(
                                                          fontSize: 44,
                                                          fontWeight: FontWeight.bold,
                                                          color: isDark ? Colors.white : AppTheme.petronasBlue,
                                                          fontFeatures: const [FontFeature.tabularFigures()],
                                                        ),
                                                      ),
                                                      Text(
                                                        DateFormat(timeFmt, l.language).format(nextTime),
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                          fontWeight: FontWeight.w600,
                                                          color: AppTheme.petronasYellow,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                        // Transparent grab-zone that follows the car; only drags that
                                        // start on the car spin it (everything else still scrolls).
                                        return Stack(
                                          key: _ringKey,
                                          children: [
                                            Positioned.fill(child: painted),
                                            AnimatedBuilder(
                                              animation: _spin,
                                              builder: (context, _) {
                                                final pos = _carPosition(box.biggest);
                                                return Positioned(
                                                  left: pos.dx - 48,
                                                  top: pos.dy - 48,
                                                  width: 96,
                                                  height: 96,
                                                  // Eager recognizer: claims the touch at once so the page's
                                                  // scroll/pull-to-refresh can't steal vertical drags.
                                                  child: RawGestureDetector(
                                                    behavior: HitTestBehavior.translucent,
                                                    gestures: {
                                                      EagerGestureRecognizer:
                                                          GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
                                                        () => EagerGestureRecognizer(),
                                                        (_) {},
                                                      ),
                                                    },
                                                    child: Listener(
                                                      behavior: HitTestBehavior.translucent,
                                                      onPointerDown: (e) {
                                                        final a = _touchAngle(e.position);
                                                        if (a != null) _spin.grab(a, e.timeStamp);
                                                      },
                                                      onPointerMove: (e) {
                                                        final a = _touchAngle(e.position);
                                                        if (a != null) _spin.dragTo(a, e.timeStamp);
                                                      },
                                                      onPointerUp: (_) => _spin.release(),
                                                      onPointerCancel: (_) => _spin.release(),
                                                      child: const SizedBox.expand(),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                // All six rows share the remaining height equally
                                Expanded(
                                  flex: 11,
                                  child: Column(
                                    children: List.generate(prayers.length, (i) {
                                      final p = prayers[i];
                                      final isNext = p.name == nextName;
                                      final passed = p.time.isBefore(now) && !isNext;
                                      return Expanded(
                                        flex: p.name == 'Sunrise' ? 8 : 10,
                                        child: EnterAnimation(
                                          index: 3 + i,
                                          child: _PrayerRow(
                                            name: l.prayer(p.name),
                                            time: DateFormat(timeFmt, l.language).format(p.time),
                                            isNext: isNext,
                                            passed: passed,
                                            isMinor: p.name == 'Sunrise',
                                            pulse: _pulse,
                                            isDark: isDark,
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Prayer {
  final String name; // English key (translated only for display)
  final DateTime time;
  const _Prayer(this.name, this.time);
}

class _PrayerRow extends StatelessWidget {
  final String name;
  final String time;
  final bool isNext;
  final bool passed;
  final bool isMinor;
  final Animation<double> pulse;
  final bool isDark;

  const _PrayerRow({
    required this.name,
    required this.time,
    required this.isNext,
    required this.passed,
    required this.isMinor,
    required this.pulse,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = isDark ? Colors.white : AppTheme.black;
    final textColor = isNext ? AppTheme.petronasGreen : baseColor;
    final style = TextStyle(
      fontSize: isMinor ? 14 : 17,
      fontWeight: isNext ? FontWeight.bold : FontWeight.w500,
      color: textColor,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    Widget row(double glow) => GlassPanel(
          highlighted: isNext,
          glow: isNext ? glow : 0,
          opacity: passed ? 0.5 : (isMinor ? 0.8 : 1),
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          radius: 12,
          child: Center(child: Row(
            children: [
              SizedBox(
                width: 26,
                child: passed
                    ? const Icon(Icons.check_circle, size: 18, color: AppTheme.petronasGreen)
                    : isNext
                        ? const Icon(Icons.radio_button_checked, size: 18, color: AppTheme.petronasYellow)
                        : Icon(Icons.circle_outlined, size: 16, color: baseColor.withValues(alpha: 0.3)),
              ),
              Expanded(child: Text(name, style: style)),
              Text(time, style: style),
            ],
          )),
        );

    final content = isNext
        ? AnimatedBuilder(animation: pulse, builder: (context, _) => row(pulse.value))
        : row(0);
    return SizedBox.expand(child: content);
  }
}
