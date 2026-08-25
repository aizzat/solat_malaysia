import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/prayer_time.dart';

class ApiService {
  // Fetch monthly prayer times from Waktu Solat App API (JAKIM)
  static Future<List<PrayerTime>> getJakimPrayerTimes(String zoneCode) async {
    final url = Uri.parse('https://api.waktusolat.app/v2/solat/$zoneCode');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      final List<dynamic> prayers = jsonResponse['prayers'];
      
      return prayers.map((json) => PrayerTime.fromWaktuSolatApp(json)).toList();
    } else {
      throw Exception('Failed to load JAKIM prayer times');
    }
  }

  // Fetch monthly prayer times from Aladhan API
  static Future<List<PrayerTime>> getAladhanPrayerTimes(double lat, double lng) async {
    final now = DateTime.now();
    final url = Uri.parse('https://api.aladhan.com/v1/calendar/${now.year}/${now.month}?latitude=$lat&longitude=$lng&method=2');
    // method 2 = ISNA (Islamic Society of North America) which is widely used internationally.
    // method 17 is JAKIM, but for international, 2 or 3 (MWL) is better.
    
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      final List<dynamic> data = jsonResponse['data'];
      
      return data.map((item) {
        return PrayerTime.fromAladhan(item['timings'], item['date']['gregorian']['date']);
      }).toList();
    } else {
      throw Exception('Failed to load Aladhan prayer times');
    }
  }
}
