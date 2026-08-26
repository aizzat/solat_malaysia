package my.i906.solat.solat_malaysia

import android.app.AlarmManager
import android.appwidget.AppWidgetManager
import android.app.PendingIntent
import android.content.Intent
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import android.os.Build
import android.util.Log
import es.antonborri.home_widget.HomeWidgetProvider
import android.content.ComponentName

class SolatWidgetProvider : HomeWidgetProvider() {
    
    companion object {
        const val ACTION_EXACT_UPDATE = "my.i906.solat.solat_malaysia.ACTION_EXACT_UPDATE"
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_EXACT_UPDATE) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, SolatWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            
            // Re-read data and update widgets immediately
            val widgetData = context.getSharedPreferences("es.antonborri.home_widget.Preferences", Context.MODE_PRIVATE)
            onUpdate(context, appWidgetManager, appWidgetIds, widgetData)
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        val now = System.currentTimeMillis()
        
        // Read all timestamps
        val prayers = listOf(
            Pair("Fajr", widgetData.getLong("fajr_ts", 0L)),
            Pair("Sunrise", widgetData.getLong("sunrise_ts", 0L)),
            Pair("Dhuhr", widgetData.getLong("dhuhr_ts", 0L)),
            Pair("Asr", widgetData.getLong("asr_ts", 0L)),
            Pair("Maghrib", widgetData.getLong("maghrib_ts", 0L)),
            Pair("Isha", widgetData.getLong("isha_ts", 0L)),
            Pair("Fajr", widgetData.getLong("next_fajr_ts", 0L))
        )
        
        // Find next prayer
        var nextPrayerName = "Next Prayer"
        var nextPrayerTimestamp = 0L
        for (prayer in prayers) {
            if (prayer.second > now) {
                nextPrayerName = prayer.first
                nextPrayerTimestamp = prayer.second
                break
            }
        }
        
        // Schedule exact alarm for next prayer update
        if (nextPrayerTimestamp > 0L) {
            scheduleExactAlarm(context, nextPrayerTimestamp)
        }

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                val hijriDate = widgetData.getString("hijri_date", "")
                val location = widgetData.getString("location", "Unknown Location")
                val fajr = widgetData.getString("fajr", "--:--")
                val dhuhr = widgetData.getString("dhuhr", "--:--")
                val asr = widgetData.getString("asr", "--:--")
                val maghrib = widgetData.getString("maghrib", "--:--")
                val isha = widgetData.getString("isha", "--:--")

                setTextViewText(R.id.widget_hijri_date, hijriDate)
                setTextViewText(R.id.widget_location, location)
                setTextViewText(R.id.widget_next_prayer_name, nextPrayerName)
                
                if (nextPrayerTimestamp > 0L) {
                    val timeDiff = nextPrayerTimestamp - System.currentTimeMillis()
                    val base = android.os.SystemClock.elapsedRealtime() + timeDiff
                    setChronometer(R.id.widget_next_prayer_countdown, base, "%s", true)
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
                        setChronometerCountDown(R.id.widget_next_prayer_countdown, true)
                    }
                } else {
                    setChronometer(R.id.widget_next_prayer_countdown, android.os.SystemClock.elapsedRealtime(), "--:--", false)
                }
                
                setTextViewText(R.id.widget_fajr, fajr)
                setTextViewText(R.id.widget_dhuhr, dhuhr)
                setTextViewText(R.id.widget_asr, asr)
                setTextViewText(R.id.widget_maghrib, maghrib)
                setTextViewText(R.id.widget_isha, isha)

                val intent = Intent(context, MainActivity::class.java)
                val pendingIntent = PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun scheduleExactAlarm(context: Context, timestamp: Long) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, SolatWidgetProvider::class.java).apply {
            action = ACTION_EXACT_UPDATE
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (alarmManager.canScheduleExactAlarms()) {
                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timestamp, pendingIntent)
                } else {
                    alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timestamp, pendingIntent)
                }
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timestamp, pendingIntent)
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, timestamp, pendingIntent)
            }
        } catch (e: SecurityException) {
            Log.e("SolatWidgetProvider", "Missing SCHEDULE_EXACT_ALARM permission", e)
        }
    }
}
