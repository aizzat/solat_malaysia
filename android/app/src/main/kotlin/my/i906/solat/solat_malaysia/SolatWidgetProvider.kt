package my.i906.solat.solat_malaysia

import android.appwidget.AppWidgetManager
import android.app.PendingIntent
import android.content.Intent
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class SolatWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                val location = widgetData.getString("location", "Unknown Location")
                val nextPrayerName = widgetData.getString("next_prayer_name", "Next Prayer")
                val nextPrayerTime = widgetData.getString("next_prayer_time", "--:--")
                val fajr = widgetData.getString("fajr", "--:--")
                val dhuhr = widgetData.getString("dhuhr", "--:--")
                val asr = widgetData.getString("asr", "--:--")
                val maghrib = widgetData.getString("maghrib", "--:--")
                val isha = widgetData.getString("isha", "--:--")

                setTextViewText(R.id.widget_location, location)
                setTextViewText(R.id.widget_next_prayer_name, nextPrayerName)
                setTextViewText(R.id.widget_next_prayer_time, nextPrayerTime)
                
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
}
