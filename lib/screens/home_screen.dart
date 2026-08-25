import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:hijri/hijri_calendar.dart';
import 'dart:async';
import '../providers/prayer_provider.dart';
import '../models/prayer_time.dart';
import '../services/notification_service.dart';
import '../theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    NotificationService.requestPermissions();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) return "00:00:00";
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  Widget _buildPrayerRow(String name, DateTime time, bool isNext, bool isDark, PrayerProvider provider) {
    final formatString = provider.use24HourFormat ? 'HH:mm' : 'hh:mm a';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      decoration: BoxDecoration(
        color: isNext ? AppTheme.petronasGreen.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isNext ? AppTheme.petronasGreen : Colors.grey.shade300,
          width: isNext ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 18,
              fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
              color: isNext ? AppTheme.petronasGreen : (isDark ? AppTheme.white : AppTheme.black),
            ),
          ),
          Text(
            DateFormat(formatString).format(time),
            style: TextStyle(
              fontSize: 18,
              fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
              color: isNext ? AppTheme.petronasGreen : (isDark ? AppTheme.white : AppTheme.black),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PrayerProvider>(
      builder: (context, provider, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.petronasGreen));
        }

        if (provider.errorMessage.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error: ${provider.errorMessage}'),
                ElevatedButton(
                  onPressed: () => provider.fetchData(),
                  child: const Text('Retry'),
                )
              ],
            ),
          );
        }

        final todayPrayer = provider.getTodayPrayer();
        if (todayPrayer == null) {
          return const Center(child: Text('No prayer times available for today.'));
        }

        // Determine next prayer
        final prayers = [
          {'name': 'Fajr', 'time': todayPrayer.fajr},
          {'name': 'Sunrise', 'time': todayPrayer.sunrise},
          {'name': 'Dhuhr', 'time': todayPrayer.dhuhr},
          {'name': 'Asr', 'time': todayPrayer.asr},
          {'name': 'Maghrib', 'time': todayPrayer.maghrib},
          {'name': 'Isha', 'time': todayPrayer.isha},
        ];

        Map<String, dynamic>? nextPrayer;
        for (var p in prayers) {
          if ((p['time'] as DateTime).isAfter(_now)) {
            nextPrayer = p;
            break;
          }
        }
        // If all passed, next is Fajr tomorrow (simplification for UI)
        nextPrayer ??= {'name': 'Fajr (Tomorrow)', 'time': todayPrayer.fajr.add(const Duration(days: 1))};

        final durationToNext = (nextPrayer['time'] as DateTime).difference(_now);
        final hijriDate = HijriCalendar.fromDate(_now);
        final gregorianDate = DateFormat('EEEE, d MMMM y').format(_now);
        
        final loc = provider.locationResult;
        String locationStr = loc?.city ?? (loc?.country ?? 'Unknown Location');

        return RefreshIndicator(
          onRefresh: () => provider.fetchData(),
          color: AppTheme.petronasGreen,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            children: [
              // Date and Location Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Text(
                      gregorianDate,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${hijriDate.hDay} ${hijriDate.longMonthName} ${hijriDate.hYear}H',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark ? AppTheme.petronasGreen : AppTheme.petronasBlue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_on, color: AppTheme.petronasYellow, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            locationStr,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Countdown Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.petronasGreen, AppTheme.petronasBlue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.petronasGreen.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Time to ${nextPrayer['name']}',
                      style: const TextStyle(color: AppTheme.white, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatDuration(durationToNext),
                      style: const TextStyle(
                        color: AppTheme.petronasYellow,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Prayer Times List
              ...prayers.map((p) => _buildPrayerRow(
                p['name'] as String,
                p['time'] as DateTime,
                p['name'] == nextPrayer?['name'],
                isDark,
                provider,
              )),
            ],
          ),
        );
      },
    );
  }
}
