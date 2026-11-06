/// Lightweight app translations (Malay is the default, English is optional).
///
/// Kept dependency-free so it can also be used from background isolates
/// (notifications, home-screen widget) where there is no BuildContext.
class AppStrings {
  static const String ms = 'ms';
  static const String en = 'en';
  static const String defaultLanguage = ms;

  static String get(String lang, String key, [Map<String, String>? params]) {
    final table = lang == en ? _en : _ms;
    var value = table[key] ?? _en[key] ?? key;
    params?.forEach((k, v) => value = value.replaceAll('{$k}', v));
    return value;
  }

  /// Malay prayer names, keyed by the English names used internally.
  static String prayer(String lang, String englishName) =>
      get(lang, 'prayer.$englishName');

  static const Map<String, String> _ms = {
    // Navigation
    'nav.home': 'Utama',
    'nav.qibla': 'Kiblat',
    'nav.settings': 'Tetapan',
    'nav.about': 'Perihal',
    'app.title': 'Solat Malaysia',

    // Prayer names
    'prayer.Fajr': 'Subuh',
    'prayer.Sunrise': 'Syuruk',
    'prayer.Dhuhr': 'Zohor',
    'prayer.Asr': 'Asar',
    'prayer.Maghrib': 'Maghrib',
    'prayer.Isha': 'Isyak',
    'prayer.FajrTomorrow': 'Subuh (Esok)',

    // Home
    'home.timeTo': 'Masa ke {prayer}',
    'home.updating': 'Mengemas kini waktu solat...',
    'home.error': 'Ralat: {message}',
    'home.retry': 'Cuba lagi',
    'home.noTimes': 'Tiada waktu solat untuk hari ini.',
    'home.unknownLocation': 'Lokasi tidak diketahui',
    'home.usingSavedLocation': 'Menggunakan lokasi tersimpan',

    // Update dialog
    'update.title': 'Kemas Kini Tersedia',
    'update.body': 'Versi baharu Solat Malaysia telah tersedia. Muat turun sekarang?',
    'update.later': 'Nanti',
    'update.now': 'Kemas Kini Sekarang',

    // Settings
    'settings.appearance': 'Paparan',
    'settings.theme': 'Tema',
    'settings.themeSystem': 'Ikut Sistem',
    'settings.themeLight': 'Mod Cerah',
    'settings.themeDark': 'Mod Gelap',
    'settings.language': 'Bahasa',
    'settings.languageMs': 'Bahasa Melayu',
    'settings.languageEn': 'English',
    'settings.use24h': 'Guna Format Masa 24 Jam',
    'settings.use24hSub': 'Papar masa dalam format 24 jam dan bukan PG/PTG',
    'settings.notifications': 'Notifikasi',
    'settings.sound': 'Bunyi Notifikasi',
    'settings.soundVoice': 'Suara Melayu (Lelaki)',
    'settings.soundDefault': 'Lalai Sistem',
    'settings.soundBeep': 'Bunyi Beep Pendek',
    'settings.soundChime': 'Loceng',
    'settings.test': 'Uji Notifikasi & Bunyi',
    'settings.testSub': 'Hantar notifikasi ujian dalam 5 saat.',
    'settings.testSnack': 'Notifikasi ujian akan muncul dalam 5 saat.',
    'settings.errorPrefix': 'Ralat: {message}',
    'settings.location': 'Tetapan Lokasi',
    'settings.autoDetect': 'Kesan Lokasi Automatik (GPS)',
    'settings.autoDetectSub': 'Guna GPS peranti untuk menentukan API dan Zon terbaik.',
    'settings.permissions': 'Kebenaran Aplikasi',
    'settings.permissionsSub': 'Urus akses Lokasi dan Notifikasi dalam Tetapan Sistem.',
    'settings.intlSetup': 'Tetapan Manual Antarabangsa',
    'settings.cityHint': 'Masukkan Bandar atau Negara...',
    'settings.jakimZone': 'Pilihan Zon JAKIM Malaysia',
    'settings.state': 'Negeri',
    'settings.zone': 'Zon',
    'settings.locationSet': 'Lokasi ditetapkan ke {city}',
    'settings.locationNotFound': 'Lokasi tidak ditemui.',
    'settings.detectionInfo': 'Maklumat Pengesanan Semasa',
    'settings.isMalaysia': 'Di Malaysia: {value}',
    'settings.country': 'Negara: {value}',
    'settings.cityArea': 'Bandar/Kawasan: {value}',
    'settings.jakimZoneLine': 'Zon JAKIM: {value}',
    'common.yes': 'Ya',
    'common.no': 'Tidak',
    'common.unknown': 'Tidak diketahui',

    // About
    'about.checkUpdate': 'semak versi kemas kini terkini di sini.',
    'about.developedBy': 'Dibangunkan oleh:',
    'about.visit': 'Layari: www.maizzat.my',
    'about.disclaimerTitle': 'Penafian',
    'about.disclaimer':
        'Aplikasi ini disediakan "seperti sedia ada" tanpa sebarang jaminan. '
            'Pembangun tidak bertanggungjawab atas sebarang ketidaktepatan waktu solat yang dipaparkan.',
    'about.data': 'Data daripada e-Solat JAKIM & Aladhan API.',

    // Qibla
    'qibla.title': 'Arah Kiblat',
    'qibla.kmFromMecca': '{km} km dari Mekah',
    'qibla.gettingLocation': 'Mendapatkan lokasi anda...',
    'qibla.unavailable': 'Lokasi Tidak Tersedia',
    'qibla.needsGps': 'Arah kiblat memerlukan lokasi GPS anda.\nSila aktifkan lokasi dalam Tetapan.',
    'qibla.retry': 'Cuba lagi',
    'qibla.qibla': 'Kiblat',
    'qibla.heading': 'Haluan',
    'qibla.distance': 'Jarak',
    'qibla.facing': 'Anda menghadap Kiblat!',
    'qibla.rotate': 'Pusing telefon sehingga jarum menghala ke atas',
    'qibla.point': 'Halakan bahagian atas telefon ke arah Mekah',
    'qibla.hint':
        'Pegang telefon secara mendatar. Roda kompas berputar supaya U sentiasa menunjuk ke Utara geografi. Jarum hijau menunjuk ke Mekah.',
    'qibla.noCompass': 'Kompas Tidak Tersedia',
    'qibla.noMagnetometer': 'Peranti ini tiada magnetometer.\nArah Kiblat yang dikira ialah:',
    'qibla.direction': 'Arah Kiblat',
    'qibla.fromNorth': 'dari Utara',

    // Notifications
    'notif.title': 'Waktu Solat',
    'notif.body': 'Telah masuk waktu {prayer}.',
    'notif.testTitle': 'Notifikasi Ujian',
    'notif.testBody': 'Ini ialah notifikasi ujian. Bunyi berfungsi!',

    // Perihal mini-game
    'game.help': 'Tolong lompatkan saya ke masjid dengan menyentuh saya!',
    'game.help2': 'Sentuh saya! Cepatlah… 🥺',
    'game.giveup': 'Aduh… okeylah, saya tak larat dah…',
    'game.roadGone': 'Eh?! Jalan dah hilang! Aaaah!',
    'game.win': 'Hehehe! Sampai masjid! 🕌',
    'game.hehe1': 'Hehe!',
    'game.hehe2': 'Wheee!',
    'game.hehe3': 'Boing!',
    'game.hint': 'Sentuh untuk melompat 🤖',
    'game.preview': 'Pratonton… sekejap lagi giliran anda! 🤖',

    // Widget
    'widget.next': 'SOLAT SETERUSNYA',
    'widget.updating': 'Mengemas kini...',
    'widget.am': 'PG',
    'widget.pm': 'PTG',
    'widget.fajrLabel': 'SUBUH',
    'widget.dhuhrLabel': 'ZOHOR',
    'widget.asrLabel': 'ASAR',
    'widget.maghribLabel': 'MAGHRIB',
    'widget.ishaLabel': 'ISYAK',
  };

  static const Map<String, String> _en = {
    'nav.home': 'Home',
    'nav.qibla': 'Qibla',
    'nav.settings': 'Settings',
    'nav.about': 'About',
    'app.title': 'Solat Malaysia',

    'prayer.Fajr': 'Fajr',
    'prayer.Sunrise': 'Sunrise',
    'prayer.Dhuhr': 'Dhuhr',
    'prayer.Asr': 'Asr',
    'prayer.Maghrib': 'Maghrib',
    'prayer.Isha': 'Isha',
    'prayer.FajrTomorrow': 'Fajr (Tomorrow)',

    'home.timeTo': 'Time to {prayer}',
    'home.updating': 'Updating prayer times...',
    'home.error': 'Error: {message}',
    'home.retry': 'Retry',
    'home.noTimes': 'No prayer times available for today.',
    'home.unknownLocation': 'Unknown Location',
    'home.usingSavedLocation': 'Using saved location',

    'update.title': 'Update Available',
    'update.body': 'A new version of Solat Malaysia is available. Would you like to download it now?',
    'update.later': 'Later',
    'update.now': 'Update Now',

    'settings.appearance': 'Appearance',
    'settings.theme': 'Theme',
    'settings.themeSystem': 'System Default',
    'settings.themeLight': 'Light Mode',
    'settings.themeDark': 'Dark Mode',
    'settings.language': 'Language',
    'settings.languageMs': 'Bahasa Melayu',
    'settings.languageEn': 'English',
    'settings.use24h': 'Use 24-hour Time Format',
    'settings.use24hSub': 'Display time in 24-hour format instead of AM/PM',
    'settings.notifications': 'Notifications',
    'settings.sound': 'Notification Sound',
    'settings.soundVoice': 'Malay Voice (Male)',
    'settings.soundDefault': 'System Default',
    'settings.soundBeep': 'Short Beep',
    'settings.soundChime': 'Chime',
    'settings.test': 'Test Notification & Sound',
    'settings.testSub': 'Sends a test notification in 5 seconds.',
    'settings.testSnack': 'Test notification will appear in 5 seconds.',
    'settings.errorPrefix': 'Error: {message}',
    'settings.location': 'Location Settings',
    'settings.autoDetect': 'Auto-detect Location (GPS)',
    'settings.autoDetectSub': 'Uses device GPS to determine best API and Zone.',
    'settings.permissions': 'App Permissions',
    'settings.permissionsSub': 'Manage Location and Notification access in System Settings.',
    'settings.intlSetup': 'International Manual Setup',
    'settings.cityHint': 'Enter City or Country...',
    'settings.jakimZone': 'Malaysia JAKIM Zone Selection',
    'settings.state': 'State',
    'settings.zone': 'Zone',
    'settings.locationSet': 'Location set to {city}',
    'settings.locationNotFound': 'Location not found.',
    'settings.detectionInfo': 'Current Detection Info',
    'settings.isMalaysia': 'Is Malaysia: {value}',
    'settings.country': 'Country: {value}',
    'settings.cityArea': 'City/Area: {value}',
    'settings.jakimZoneLine': 'JAKIM Zone: {value}',
    'common.yes': 'Yes',
    'common.no': 'No',
    'common.unknown': 'Unknown',

    'about.checkUpdate': 'check for latest update version here.',
    'about.developedBy': 'Developed by:',
    'about.visit': 'Visit: www.maizzat.my',
    'about.disclaimerTitle': 'Disclaimer',
    'about.disclaimer':
        'This application is provided "as is", without warranty of any kind. '
            'The developer is not responsible for any inaccuracies in the prayer times provided.',
    'about.data': 'Data provided by e-Solat JAKIM & Aladhan API.',

    'qibla.title': 'Qibla Direction',
    'qibla.kmFromMecca': '{km} km from Mecca',
    'qibla.gettingLocation': 'Getting your location...',
    'qibla.unavailable': 'Location Unavailable',
    'qibla.needsGps': 'Qibla direction requires your GPS location.\nPlease enable location in Settings.',
    'qibla.retry': 'Retry',
    'qibla.qibla': 'Qibla',
    'qibla.heading': 'Heading',
    'qibla.distance': 'Distance',
    'qibla.facing': 'You are facing the Qibla!',
    'qibla.rotate': 'Rotate phone until needle points up',
    'qibla.point': 'Point the top of your phone toward Mecca',
    'qibla.hint':
        'Hold phone flat and level. The compass rose rotates so N always points to geographic North. The green needle points to Mecca.',
    'qibla.noCompass': 'Compass Not Available',
    'qibla.noMagnetometer': 'This device has no magnetometer.\nYour calculated Qibla bearing is:',
    'qibla.direction': 'Qibla Direction',
    'qibla.fromNorth': 'from North',

    'notif.title': 'Solat Time',
    'notif.body': 'It is time for {prayer} prayer.',
    'notif.testTitle': 'Test Notification',
    'notif.testBody': 'This is a test notification. Sound is working!',

    // Perihal mini-game
    'game.help': 'Help me jump to the mosque by tapping me!',
    'game.help2': 'Tap me! Pleaseee… 🥺',
    'game.giveup': 'Ouch… okay, I give up…',
    'game.roadGone': 'Whoa?! The road is gone! Aaaah!',
    'game.win': 'Hehehe! Made it to the mosque! 🕌',
    'game.hehe1': 'Hehe!',
    'game.hehe2': 'Wheee!',
    'game.hehe3': 'Boing!',
    'game.hint': 'Tap to jump 🤖',
    'game.preview': 'Preview… your turn in a moment! 🤖',

    'widget.next': 'NEXT PRAYER',
    'widget.updating': 'Updating...',
    'widget.am': 'AM',
    'widget.pm': 'PM',
    'widget.fajrLabel': 'FAJR',
    'widget.dhuhrLabel': 'DHUHR',
    'widget.asrLabel': 'ASR',
    'widget.maghribLabel': 'MAGHRIB',
    'widget.ishaLabel': 'ISHA',
  };
}
