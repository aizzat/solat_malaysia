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
        // Use distinct request codes per alarm slot to prevent PendingIntent collisions
        const val ALARM_REQUEST_CODE = 1001
        const val FALLBACK_ALARM_REQUEST_CODE = 1002
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
        
        // Read all timestamps — today's prayers + tomorrow's Fajr as a rollover sentinel
        val prayers = listOf(
            Pair("Fajr", widgetData.getLong("fajr_ts", 0L)),
            Pair("Sunrise", widgetData.getLong("sunrise_ts", 0L)),
            Pair("Dhuhr", widgetData.getLong("dhuhr_ts", 0L)),
            Pair("Asr", widgetData.getLong("asr_ts", 0L)),
            Pair("Maghrib", widgetData.getLong("maghrib_ts", 0L)),
            Pair("Isha", widgetData.getLong("isha_ts", 0L)),
            Pair("Fajr", widgetData.getLong("next_fajr_ts", 0L))
        )
        
        // Find next prayer (first timestamp strictly in the future)
        var nextPrayerName = ""
        var nextPrayerTimestamp = 0L
        for (prayer in prayers) {
            if (prayer.second > now) {
                nextPrayerName = prayer.first
                nextPrayerTimestamp = prayer.second
                break
            }
        }

        if (nextPrayerTimestamp > 0L) {
            // Schedule exact alarm at the next prayer time to refresh the widget
            scheduleExactAlarm(context, nextPrayerTimestamp, ALARM_REQUEST_CODE)
        } else {
            // All stored timestamps (including next_fajr_ts) have passed —
            // data is stale. Schedule a fallback check in 1 hour so WorkManager
            // has time to fetch fresh data and push it to SharedPreferences.
            val fallbackTime = now + (60 * 60 * 1000L) // 1 hour from now
            scheduleExactAlarm(context, fallbackTime, FALLBACK_ALARM_REQUEST_CODE)
            Log.w("SolatWidgetProvider", "All prayer timestamps expired. Scheduled fallback refresh in 1 hour.")
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
                
                if (nextPrayerTimestamp > 0L) {
                    // Valid next prayer found — show name and live countdown
                    setTextViewText(R.id.widget_next_prayer_name, nextPrayerName)
                    val timeDiff = nextPrayerTimestamp - System.currentTimeMillis()
                    val base = android.os.SystemClock.elapsedRealtime() + timeDiff
                    setChronometer(R.id.widget_next_prayer_countdown, base, "%s", true)
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
                        setChronometerCountDown(R.id.widget_next_prayer_countdown, true)
                    }
                } else {
                    // Stale data — show a friendly "Updating..." message instead of blank
                    setTextViewText(R.id.widget_next_prayer_name, "Updating...")
                    setChronometer(R.id.widget_next_prayer_countdown, android.os.SystemClock.elapsedRealtime(), "--:--:--", false)
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

    private fun scheduleExactAlarm(context: Context, timestamp: Long, requestCode: Int) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, SolatWidgetProvider::class.java).apply {
            action = ACTION_EXACT_UPDATE
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            requestCode,
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
