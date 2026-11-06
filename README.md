# Solat Malaysia

A modern, cross-platform Flutter application that provides highly accurate prayer (Solat) times for Muslims in Malaysia and worldwide.

Designed and developed by **dr. aizzat (maizzat.my)**.

## Download

**Free, no ads, source-available.** Get the latest Android APK from the guided download page:

👉 **https://www.research.maizzat.my/downloads/solat_malaysia_download.html**

or from the [GitHub Releases](https://github.com/aizzat/solat_malaysia/releases/latest) page. The app shows an "Update Available" pop-up when a newer release is published.

[![Listed on MakaKami](https://makakami.com.my/badge/solat-malaysia.svg?theme=dark)](https://makakami.com.my/app/solat-malaysia)

> The developer's only request: a doa — may this app be an *amal jariah* and an investment for the akhirat.

## Features

- **Dual-API Accuracy**: 
  - Automatically uses the official JAKIM (waktusolat.app) API for absolute accuracy when you are in Malaysia.
  - Seamlessly falls back to the Aladhan API (ISNA method) when traveling internationally.
- **Smart GPS Detection**: Auto-detects your location and maps your coordinates to the official JAKIM zones instantly.
- **Sleek Android Widget**: Includes a premium, native Android Homescreen Widget that shows all 5 daily prayers, highlights the next prayer, and updates silently in the background.
- **Background Sync**: Uses Workmanager to sync your prayer times automatically without needing to open the app.
- **Beautiful UI**: Designed with an elegant, modern Petronas color palette (Green, Navy, Yellow).
- **Malay Voice Alerts**: Exact-time notifications with a Malay male voice announcement (or Beep / Chime / system sound), in Bahasa Melayu by default with English in Settings.
- **Autonomous-car Countdown Ring**: A top-view self-driving car with path planning and LiDAR animation; swipe it to spin it like a fidget spinner.
- **3D Qibla Globe**: Real rotating globe with a route to Mecca, zoomable down to satellite street level.
- **Robot-to-Mosque Mini Game**: A playful animated game in the Perihal tab.

## Technologies Used

- **Framework:** Flutter & Dart
- **State Management:** Provider
- **Local Storage:** Shared Preferences
- **Background Work:** Workmanager & HomeWidget (for Android Widgets)
- **Location:** Geolocator & Geocoding
- **Network:** HTTP

## Getting Started

### Prerequisites
- Flutter SDK
- Android Studio / Xcode

### Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/aizzat/solat_malaysia.git
   ```
2. Fetch dependencies:
   ```bash
   cd solat_malaysia
   flutter pub get
   ```
3. Run the app:
   ```bash
   flutter run
   ```

### Building for Release
To build a highly optimized APK split by ABI:
```bash
flutter build apk --split-per-abi
```

## Contact
Developed by **dr. aizzat (maizzat.my)**

## License

Copyright (c) 2026 Muhammad Aizzat Zakaria ([maizzat.my](https://www.maizzat.my)).

- ✅ **Free for personal and other non-commercial use** — use it, study it, modify it, share it.
- 🙏 **Credit is required**: keep the `Required Notice` line from [LICENSE](LICENSE) and point back to
  <https://github.com/aizzat/solat_malaysia> — or simply **fork** this repository.
- 💼 **Commercial use needs permission** — please email **maizzat2@gmail.com**.

Licensed under the [PolyForm Noncommercial License 1.0.0](https://polyformproject.org/licenses/noncommercial/1.0.0).
This is a *source-available* license (not an OSI "open source" license). It covers the original code and assets
of this project only; third-party components keep their own licenses (Flutter and pub.dev packages, Poppins font — SIL OFL,
Natural Earth coastlines — public domain; prayer data from e-Solat JAKIM / Aladhan; satellite imagery © Esri, Maxar, Earthstar Geographics).
