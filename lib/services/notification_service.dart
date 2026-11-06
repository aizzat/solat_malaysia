import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prayer_time.dart';
import '../l10n/app_strings.dart';
import '../providers/locale_provider.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(settings: initializationSettings);

  }

  // Channel IDs are versioned on purpose: Android never lets an app change the
  // sound/importance of an existing channel, so a channel created by an older
  // build (or muted by the user) keeps its old behaviour forever. A new ID gives
  // a fresh channel with the correct sound.
  static const String _chDefault = 'prayer_v2_default';
  static const String _chBeep = 'prayer_v2_beep';
  static const String _chChime = 'prayer_v2_chime';
  // Malay male voice announcements: one channel (and clip) per prayer, because a
  // channel's sound is fixed. Keys are the English prayer names used below.
  static const Map<String, String> _voiceClips = {
    'Fajr': 'voice_subuh',
    'Dhuhr': 'voice_zohor',
    'Asr': 'voice_asar',
    'Maghrib': 'voice_maghrib',
    'Isha': 'voice_isyak',
  };
  static const Map<String, String> _malayNames = {
    'Fajr': 'Subuh',
    'Dhuhr': 'Zohor',
    'Asr': 'Asar',
    'Maghrib': 'Maghrib',
    'Isha': 'Isyak',
  };
  static String _voiceChannelId(String prayer) => 'prayer_v2_voice_${_voiceClips[prayer]}';

  static const List<String> _legacyChannels = [
    'prayer_channel_default',
    'prayer_channel_beep',
    'prayer_channel_chime',
  ];

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// Idempotent. Safe to call from the UI isolate and from background workers.
  static Future<void> ensureChannels() async {
    final android = _android;
    if (android == null) return;

    for (final id in _legacyChannels) {
      await android.deleteNotificationChannel(channelId: id);
    }

    await android.createNotificationChannel(const AndroidNotificationChannel(
      _chDefault,
      'Prayer Notifications (Default)',
      description: 'Notifications for prayer times (Default Sound)',
      importance: Importance.max,
      playSound: true,
    ));
    await android.createNotificationChannel(const AndroidNotificationChannel(
      _chBeep,
      'Prayer Notifications (Beep)',
      description: 'Notifications for prayer times (Beep Sound)',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('beep'),
    ));
    await android.createNotificationChannel(const AndroidNotificationChannel(
      _chChime,
      'Prayer Notifications (Chime)',
      description: 'Notifications for prayer times (Chime Sound)',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('chime'),
    ));
    for (final entry in _voiceClips.entries) {
      await android.createNotificationChannel(AndroidNotificationChannel(
        _voiceChannelId(entry.key),
        'Prayer Voice - ${_malayNames[entry.key]}',
        description: 'Malay voice announcement for ${_malayNames[entry.key]}',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(entry.value),
      ));
    }
  }

  static Future<void> requestPermissions() async {
    final android = _android;
    if (android == null) return;
    await android.requestNotificationsPermission();
    await android.requestExactAlarmsPermission();
    await ensureChannels();
  }

  static Future<String> _getSelectedSound() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('notification_sound') ?? 'voice';
  }

  static AndroidNotificationDetails _buildAndroidDetails(String sound, [String? prayer]) {
    if (sound == 'voice' && prayer != null && _voiceClips.containsKey(prayer)) {
      return AndroidNotificationDetails(
        _voiceChannelId(prayer),
        'Prayer Voice - ${_malayNames[prayer]}',
        channelDescription: 'Malay voice announcement',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(_voiceClips[prayer]!),
      );
    }
    if (sound == 'beep') {
      return const AndroidNotificationDetails(
        _chBeep,
        'Prayer Notifications (Beep)',
        channelDescription: 'Notifications for prayer times',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('beep'),
      );
    } else if (sound == 'chime') {
      return const AndroidNotificationDetails(
        _chChime,
        'Prayer Notifications (Chime)',
        channelDescription: 'Notifications for prayer times',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('chime'),
      );
    } else {
      return const AndroidNotificationDetails(
        _chDefault,
        'Prayer Notifications (Default)',
        channelDescription: 'Notifications for prayer times',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
      );
    }
  }

  static Future<void> schedulePrayerNotifications(List<PrayerTime> prayerTimes) async {
    await ensureChannels();
    // Cancel existing notifications
    await flutterLocalNotificationsPlugin.cancelAll();

    int id = 0;
    final now = DateTime.now();

    for (var pt in prayerTimes) {
      if (pt.date.isBefore(now.subtract(const Duration(days: 1)))) continue; // Skip past days

      await _schedule(id++, 'Fajr', pt.fajr);
      await _schedule(id++, 'Dhuhr', pt.dhuhr);
      await _schedule(id++, 'Asr', pt.asr);
      await _schedule(id++, 'Maghrib', pt.maghrib);
      await _schedule(id++, 'Isha', pt.isha);
    }
  }

  static Future<void> _schedule(int id, String prayerName, DateTime time) async {
    if (time.isBefore(DateTime.now())) return;

    final sound = await _getSelectedSound();
    final lang = await LocaleProvider.savedLanguage();
    final canExact = await _android?.canScheduleExactNotifications() ?? false;
    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id: id,
        title: sound == 'voice' ? 'Waktu ${_malayNames[prayerName]}' : AppStrings.get(lang, 'notif.title'),
        body: sound == 'voice'
            ? 'Telah masuk waktu ${_malayNames[prayerName]}. Marilah menunaikan solat.'
            : AppStrings.get(lang, 'notif.body', {'prayer': AppStrings.prayer(lang, prayerName)}),
        scheduledDate: tz.TZDateTime.from(time, tz.local),
        notificationDetails: NotificationDetails(
          android: _buildAndroidDetails(sound, prayerName),
        ),
        // Without the exact-alarm permission an exact schedule throws and the
        // notification (and its sound) is lost; fall back to an inexact alarm.
        androidScheduleMode: canExact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Failed to schedule $prayerName notification: $e');
    }
  }

  static Future<void> testNotification() async {
    // Wait 5 seconds using Dart's Future, then call .show() directly.
    // This bypasses exact alarm limitations which sometimes silently fail on certain OEM skins.
    final sound = await _getSelectedSound();
    final lang = await LocaleProvider.savedLanguage();
    
    await Future.delayed(const Duration(seconds: 5));
    await flutterLocalNotificationsPlugin.show(
      id: 999,
      title: AppStrings.get(lang, 'notif.testTitle'),
      body: AppStrings.get(lang, 'notif.testBody'),
      notificationDetails: NotificationDetails(
        android: _buildAndroidDetails(sound, 'Dhuhr'),
      ),
    );
  }
}
