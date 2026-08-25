import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
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

    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();
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

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: 'Solat Time',
      body: 'It is time for $prayerName prayer.',
      scheduledDate: tz.TZDateTime.from(time, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'prayer_channel_id',
          'Prayer Notifications',
          channelDescription: 'Notifications for prayer times',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  static Future<void> testNotification() async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: 999,
      title: 'Test Notification',
      body: 'This is a test notification. Sound is working!',
      scheduledDate: tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5)),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'prayer_channel_id',
          'Prayer Notifications',
          channelDescription: 'Notifications for prayer times',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }
}
