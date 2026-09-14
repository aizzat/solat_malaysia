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
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

class SolatWidgetProvider : HomeWidgetProvider() {
    
    companion object {
        const val ACTION_EXACT_UPDATE = "my.i906.solat.solat_malaysia.ACTION_EXACT_UPDATE"
        // SharedPreferences name used by Flutter home_widget package
        const val PREFERENCES = "HomeWidgetPreferences"
        // Use distinct request codes per alarm slot to prevent PendingIntent collisions
        const val ALARM_REQUEST_CODE = 1001
        const val FALLBACK_ALARM_REQUEST_CODE = 1002
    }

    private fun getWidgetPreferences(context: Context): SharedPreferences {
        return context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val action = intent.action
        if (action == ACTION_EXACT_UPDATE ||
            action == Intent.ACTION_BOOT_COMPLETED ||
            action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, SolatWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            
            // Re-read data from the correct SharedPreferences and update widgets immediately
            val widgetData = getWidgetPreferences(context)
            onUpdate(context, appWidgetManager, appWidgetIds, widgetData)
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        if (appWidgetIds.isEmpty()) return
        val now = System.currentTimeMillis()
        
        // Base fallback values from SharedPreferences
        var hijriDate = widgetData.getString("hijri_date", "") ?: ""
        var location = widgetData.getString("location", "Malaysia") ?: "Malaysia"
        if (location.trim().isEmpty() || location == "Unknown Location") {
            location = "Malaysia"
        }
        var fajr = widgetData.getString("fajr", "--:--") ?: "--:--"
        var dhuhr = widgetData.getString("dhuhr", "--:--") ?: "--:--"
        var asr = widgetData.getString("asr", "--:--") ?: "--:--"
        var maghrib = widgetData.getString("maghrib", "--:--") ?: "--:--"
        var isha = widgetData.getString("isha", "--:--") ?: "--:--"

        var nextPrayerName = ""
        var nextPrayerTimestamp = 0L

        // Parse full multi-day schedule if available
        val scheduleJsonStr = widgetData.getString("prayer_schedule", null)
        if (!scheduleJsonStr.isNullOrEmpty()) {
            try {
                val scheduleArray = JSONArray(scheduleJsonStr)
                val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
                val todayKey = dateFormat.format(Date(now))

                var todayObj: JSONObject? = null

                // 1. Locate today's object to update display strings for today
                for (i in 0 until scheduleArray.length()) {
                    val dayObj = scheduleArray.getJSONObject(i)
                    if (dayObj.optString("date") == todayKey) {
                        todayObj = dayObj
                        break
                    }
                }

                // If today's object found, load today's prayer times and hijri
                if (todayObj != null) {
                    hijriDate = todayObj.optString("hijri", hijriDate)
                    fajr = todayObj.optString("fajr", fajr)
                    dhuhr = todayObj.optString("dhuhr", dhuhr)
                    asr = todayObj.optString("asr", asr)
                    maghrib = todayObj.optString("maghrib", maghrib)
                    isha = todayObj.optString("isha", isha)
                }

                // 2. Find the earliest prayer timestamp strictly in the future
                for (i in 0 until scheduleArray.length()) {
                    val dayObj = scheduleArray.getJSONObject(i)
                    val dayPrayers = listOf(
                        Pair("Fajr", dayObj.optLong("fajr_ts", 0L)),
                        Pair("Sunrise", dayObj.optLong("sunrise_ts", 0L)),
                        Pair("Dhuhr", dayObj.optLong("dhuhr_ts", 0L)),
                        Pair("Asr", dayObj.optLong("asr_ts", 0L)),
                        Pair("Maghrib", dayObj.optLong("maghrib_ts", 0L)),
                        Pair("Isha", dayObj.optLong("isha_ts", 0L))
                    )

                    for (prayer in dayPrayers) {
                        if (prayer.second > now) {
                            nextPrayerName = prayer.first
                            nextPrayerTimestamp = prayer.second
                            break
                        }
                    }
                    if (nextPrayerTimestamp > 0L) {
                        break
                    }
                }
            } catch (e: Exception) {
                Log.e("SolatWidgetProvider", "Error parsing prayer_schedule JSON", e)
            }
        }

        // Backward compatibility fallback to individual single-day keys
        if (nextPrayerTimestamp == 0L) {
            val fallbackPrayers = listOf(
                Pair("Fajr", widgetData.getLong("fajr_ts", 0L)),
                Pair("Sunrise", widgetData.getLong("sunrise_ts", 0L)),
                Pair("Dhuhr", widgetData.getLong("dhuhr_ts", 0L)),
                Pair("Asr", widgetData.getLong("asr_ts", 0L)),
                Pair("Maghrib", widgetData.getLong("maghrib_ts", 0L)),
                Pair("Isha", widgetData.getLong("isha_ts", 0L)),
                Pair("Fajr", widgetData.getLong("next_fajr_ts", 0L))
            )
            for (prayer in fallbackPrayers) {
                if (prayer.second > now) {
                    nextPrayerName = prayer.first
                    nextPrayerTimestamp = prayer.second
                    break
                }
            }
        }

        // Calculate midnight rollover timestamp (tomorrow 00:00:02)
        val calendar = Calendar.getInstance().apply {
            timeInMillis = now
            add(Calendar.DAY_OF_YEAR, 1)
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 2)
            set(Calendar.MILLISECOND, 0)
        }
        val midnightTimestamp = calendar.timeInMillis

        if (nextPrayerTimestamp > 0L) {
            // Schedule alarm at the next prayer or midnight, whichever comes first.
            // This ensures that after Isha, the widget wakes at midnight to flip to the new day's 5 prayer rows!
            val alarmTargetTime = if (midnightTimestamp < nextPrayerTimestamp) {
                midnightTimestamp
            } else {
                nextPrayerTimestamp
            }
            scheduleExactAlarm(context, alarmTargetTime, ALARM_REQUEST_CODE)
        } else {
            // All stored timestamps have passed. Schedule a fallback check in 1 hour.
            val fallbackTime = now + (60 * 60 * 1000L)
            scheduleExactAlarm(context, fallbackTime, FALLBACK_ALARM_REQUEST_CODE)
            Log.w("SolatWidgetProvider", "All prayer timestamps expired. Scheduled fallback refresh in 1 hour.")
        }

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                setTextViewText(R.id.widget_hijri_date, hijriDate)
                setTextViewText(R.id.widget_location, location)
                
                if (nextPrayerTimestamp > 0L) {
                    // Valid next prayer found — show name and live countdown
                    setTextViewText(R.id.widget_next_prayer_name, nextPrayerName)
                    val timeDiff = nextPrayerTimestamp - System.currentTimeMillis()
                    val base = android.os.SystemClock.elapsedRealtime() + timeDiff
                    setChronometer(R.id.widget_next_prayer_countdown, base, "%s", true)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
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
