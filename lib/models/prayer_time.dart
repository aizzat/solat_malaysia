class PrayerTime {
  final DateTime date;
  final DateTime fajr;
  final DateTime sunrise;
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;

  PrayerTime({
    required this.date,
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });

  factory PrayerTime.fromWaktuSolatApp(Map<String, dynamic> json) {
    // API returns seconds since epoch for prayer times
    return PrayerTime(
      date: DateTime.fromMillisecondsSinceEpoch(json['fajr'] * 1000), // use fajr as base date
      fajr: DateTime.fromMillisecondsSinceEpoch(json['fajr'] * 1000),
      sunrise: DateTime.fromMillisecondsSinceEpoch(json['syuruk'] * 1000),
      dhuhr: DateTime.fromMillisecondsSinceEpoch(json['dhuhr'] * 1000),
      asr: DateTime.fromMillisecondsSinceEpoch(json['asr'] * 1000),
      maghrib: DateTime.fromMillisecondsSinceEpoch(json['maghrib'] * 1000),
      isha: DateTime.fromMillisecondsSinceEpoch(json['isha'] * 1000),
    );
  }

  factory PrayerTime.fromAladhan(Map<String, dynamic> json, String dateStr) {
    // API returns HH:mm (e.g. "05:43 (MYT)")
    DateTime parseTime(String timeStr) {
      final time = timeStr.split(' ')[0]; // extract "05:43"
      final parts = time.split(':');
      final dateParts = dateStr.split('-'); // DD-MM-YYYY
      return DateTime(
        int.parse(dateParts[2]),
        int.parse(dateParts[1]),
        int.parse(dateParts[0]),
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
    }

    return PrayerTime(
      date: parseTime(json['Fajr']), // Just using fajr date as base
      fajr: parseTime(json['Fajr']),
      sunrise: parseTime(json['Sunrise']),
      dhuhr: parseTime(json['Dhuhr']),
      asr: parseTime(json['Asr']),
      maghrib: parseTime(json['Maghrib']),
      isha: parseTime(json['Isha']),
    );
  }
}
