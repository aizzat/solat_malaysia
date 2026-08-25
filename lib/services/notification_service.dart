import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prayer_time.dart';

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

  static Future<void> requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();
      
      const AndroidNotificationChannel channelDefault = AndroidNotificationChannel(
        'prayer_channel_default',
        'Prayer Notifications (Default)',
        description: 'Notifications for prayer times (Default Sound)',
        importance: Importance.max,
        playSound: true,
      );
      
      const AndroidNotificationChannel channelBeep = AndroidNotificationChannel(
        'prayer_channel_beep',
        'Prayer Notifications (Beep)',
        description: 'Notifications for prayer times (Beep Sound)',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('beep'),
      );
      
      const AndroidNotificationChannel channelChime = AndroidNotificationChannel(
        'prayer_channel_chime',
        'Prayer Notifications (Chime)',
        description: 'Notifications for prayer times (Chime Sound)',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('chime'),
      );

      await androidImplementation.createNotificationChannel(channelDefault);
      await androidImplementation.createNotificationChannel(channelBeep);
      await androidImplementation.createNotificationChannel(channelChime);
    }
  }

  static Future<String> _getSelectedSound() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('notification_sound') ?? 'default';
  }

  static AndroidNotificationDetails _buildAndroidDetails(String sound) {
    if (sound == 'beep') {
      return const AndroidNotificationDetails(
        'prayer_channel_beep',
        'Prayer Notifications (Beep)',
        channelDescription: 'Notifications for prayer times',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('beep'),
      );
    } else if (sound == 'chime') {
      return const AndroidNotificationDetails(
        'prayer_channel_chime',
        'Prayer Notifications (Chime)',
        channelDescription: 'Notifications for prayer times',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('chime'),
      );
    } else {
      return const AndroidNotificationDetails(
        'prayer_channel_default',
        'Prayer Notifications (Default)',
        channelDescription: 'Notifications for prayer times',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
      );
    }
  }

  static Future<void> schedulePrayerNotifications(List<PrayerTime> prayerTimes) async {
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

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: 'Solat Time',
      body: 'It is time for $prayerName prayer.',
      scheduledDate: tz.TZDateTime.from(time, tz.local),
      notificationDetails: NotificationDetails(
        android: _buildAndroidDetails(sound),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  static Future<void> testNotification() async {
    // Wait 5 seconds using Dart's Future, then call .show() directly.
    // This bypasses exact alarm limitations which sometimes silently fail on certain OEM skins.
    final sound = await _getSelectedSound();
    
    await Future.delayed(const Duration(seconds: 5));
    await flutterLocalNotificationsPlugin.show(
      id: 999,
      title: 'Test Notification',
      body: 'This is a test notification. Sound is working!',
      notificationDetails: NotificationDetails(
        android: _buildAndroidDetails(sound),
      ),
    );
  }
}
