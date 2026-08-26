import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';
import 'package:hijri/hijri_calendar.dart';
import '../models/prayer_time.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';

class PrayerProvider with ChangeNotifier {
  List<PrayerTime> _prayerTimes = [];
  bool _isLoading = true;
  String _errorMessage = '';
  LocationResult? _locationResult;
  bool _useAutoDetect = true;
  bool _use24HourFormat = false;
  String _manualJakimZone = 'WLY01'; // Default manual zone
  double? _manualLat;
  double? _manualLng;
  String? _manualCity;

  List<PrayerTime> get prayerTimes => _prayerTimes;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  LocationResult? get locationResult => _locationResult;
  bool get useAutoDetect => _useAutoDetect;
  bool get use24HourFormat => _use24HourFormat;

  PrayerProvider();

  Future<void> init() async {
    await _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _useAutoDetect = prefs.getBool('useAutoDetect') ?? true;
    _use24HourFormat = prefs.getBool('use24HourFormat') ?? false;
    _manualJakimZone = prefs.getString('manualJakimZone') ?? 'WLY01';
    
    final lat = prefs.getDouble('manualLat');
    final lng = prefs.getDouble('manualLng');
    final city = prefs.getString('manualCity');
    
    if (lat != null && lng != null) {
      _manualLat = lat;
      _manualLng = lng;
      _manualCity = city;
    }
    
    await fetchData();
  }

  Future<void> setUseAutoDetect(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useAutoDetect', value);
    _useAutoDetect = value;
    notifyListeners();
    fetchData();
  }

  Future<void> setUse24HourFormat(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use24HourFormat', value);
    _use24HourFormat = value;
    notifyListeners();
    _updateHomeWidget();
  }

  Future<void> setManualZone(String zoneCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('manualJakimZone', zoneCode);
    _manualJakimZone = zoneCode;
    // Clear manual coordinates if setting JAKIM zone
    await prefs.remove('manualLat');
    await prefs.remove('manualLng');
    _manualLat = null;
    _manualLng = null;
    notifyListeners();
    if (!_useAutoDetect) fetchData();
  }

  Future<void> setManualCoordinates(double lat, double lng, String city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('manualLat', lat);
    await prefs.setDouble('manualLng', lng);
    await prefs.setString('manualCity', city);
    _manualLat = lat;
    _manualLng = lng;
    _manualCity = city;
    notifyListeners();
    if (!_useAutoDetect) fetchData();
  }

  Future<void> fetchData() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      if (_useAutoDetect) {
        final locationService = LocationService();
        _locationResult = await locationService.determinePosition();

        if (_locationResult!.isMalaysia && _locationResult!.jakimZoneCode != null) {
          _prayerTimes = await ApiService.getJakimPrayerTimes(_locationResult!.jakimZoneCode!);
        } else if (_locationResult!.latitude != null && _locationResult!.longitude != null) {
          _prayerTimes = await ApiService.getAladhanPrayerTimes(
            _locationResult!.latitude!, 
            _locationResult!.longitude!
          );
        }
      } else {
        if (_manualLat != null && _manualLng != null) {
          // Manual override for International
          _prayerTimes = await ApiService.getAladhanPrayerTimes(_manualLat!, _manualLng!);
          _locationResult = LocationResult(
            isMalaysia: false,
            city: _manualCity ?? 'Manual Location',
            country: 'Manual',
            latitude: _manualLat,
            longitude: _manualLng,
          );
        } else {
          // Manual override for Malaysia
          _prayerTimes = await ApiService.getJakimPrayerTimes(_manualJakimZone);
          _locationResult = LocationResult(
            isMalaysia: true, 
            jakimZoneCode: _manualJakimZone,
            city: 'Manual Zone: $_manualJakimZone',
            country: 'Malaysia',
          );
        }
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      if (_prayerTimes.isNotEmpty) {
        await NotificationService.schedulePrayerNotifications(_prayerTimes);
        await _updateHomeWidget();
      }
      notifyListeners();
    }
  }

  Future<void> _updateHomeWidget() async {
    try {
      final todayPrayer = getTodayPrayer();
      if (todayPrayer == null) return;

      final now = DateTime.now();
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
        if ((p['time'] as DateTime).isAfter(now)) {
          nextPrayer = p;
          break;
        }
      }
      nextPrayer ??= {'name': 'Fajr', 'time': todayPrayer.fajr.add(const Duration(days: 1))};

      final timeFormat = (DateTime t) {
        if (_use24HourFormat) {
          return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
        } else {
          int h = t.hour;
          final int hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
          final String amPm = h >= 12 ? 'PM' : 'AM';
          return '${hour12.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} $amPm';
        }
      };

      final hijriDate = HijriCalendar.fromDate(now);
      final hijriString = '${hijriDate.hDay} ${hijriDate.longMonthName} ${hijriDate.hYear}H';

      await HomeWidget.saveWidgetData<String>('location', _locationResult?.city ?? 'Unknown Location');
      await HomeWidget.saveWidgetData<String>('hijri_date', hijriString);
      
      await HomeWidget.saveWidgetData<int>('fajr_ts', todayPrayer.fajr.millisecondsSinceEpoch);
      await HomeWidget.saveWidgetData<int>('sunrise_ts', todayPrayer.sunrise.millisecondsSinceEpoch);
      await HomeWidget.saveWidgetData<int>('dhuhr_ts', todayPrayer.dhuhr.millisecondsSinceEpoch);
      await HomeWidget.saveWidgetData<int>('asr_ts', todayPrayer.asr.millisecondsSinceEpoch);
      await HomeWidget.saveWidgetData<int>('maghrib_ts', todayPrayer.maghrib.millisecondsSinceEpoch);
      await HomeWidget.saveWidgetData<int>('isha_ts', todayPrayer.isha.millisecondsSinceEpoch);
      await HomeWidget.saveWidgetData<int>('next_fajr_ts', todayPrayer.fajr.add(const Duration(days: 1)).millisecondsSinceEpoch);
      
      await HomeWidget.saveWidgetData<String>('fajr', timeFormat(todayPrayer.fajr));
      await HomeWidget.saveWidgetData<String>('dhuhr', timeFormat(todayPrayer.dhuhr));
      await HomeWidget.saveWidgetData<String>('asr', timeFormat(todayPrayer.asr));
      await HomeWidget.saveWidgetData<String>('maghrib', timeFormat(todayPrayer.maghrib));
      await HomeWidget.saveWidgetData<String>('isha', timeFormat(todayPrayer.isha));
      
      await HomeWidget.updateWidget(
        name: 'SolatWidgetProvider',
        androidName: 'SolatWidgetProvider',
      );
    } catch (e) {
      debugPrint('Error updating home widget: $e');
    }
  }

  PrayerTime? getTodayPrayer() {
    if (_prayerTimes.isEmpty) return null;
    final today = DateTime.now();
    for (var pt in _prayerTimes) {
      if (pt.date.year == today.year && pt.date.month == today.month && pt.date.day == today.day) {
        return pt;
      }
    }
    // If exact match not found (timezone diff), return the closest one
    return _prayerTimes.first; 
  }
}
