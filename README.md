# Solat Malaysia

A modern, cross-platform Flutter application that provides highly accurate prayer (Solat) times for Muslims in Malaysia and worldwide.

Designed and developed by **dr. aizzat (maizzat.my)**.

## Features

- **Dual-API Accuracy**: 
  - Automatically uses the official JAKIM (waktusolat.app) API for absolute accuracy when you are in Malaysia.
  - Seamlessly falls back to the Aladhan API (ISNA method) when traveling internationally.
- **Smart GPS Detection**: Auto-detects your location and maps your coordinates to the official JAKIM zones instantly.
- **Sleek Android Widget**: Includes a premium, native Android Homescreen Widget that shows all 5 daily prayers, highlights the next prayer, and updates silently in the background.
- **Background Sync**: Uses Workmanager to sync your prayer times automatically without needing to open the app.
- **Beautiful UI**: Designed with an elegant, modern Petronas color palette (Green, Navy, Yellow).
- **Silent Notifications**: Silently alerts you exactly when it's time to pray, keeping you mindful without loud interruptions.

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
