import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../utils/jakim_zones.dart';

class LocationResult {
  final bool isMalaysia;
  final String? jakimZoneCode;
  final String? country;
  final String? city;
  final double? latitude;
  final double? longitude;

  LocationResult({
    required this.isMalaysia,
    this.jakimZoneCode,
    this.country,
    this.city,
    this.latitude,
    this.longitude,
  });
}

class LocationService {
  Future<LocationResult> determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.');
    } 

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    final Position position = await quickPosition();

    // Reverse geocode to find country (bounded: this can hang without network)
    try {
      final Geocoding geocoding = Geocoding();
      List<Placemark> placemarks = await geocoding
          .placemarkFromCoordinates(position.latitude, position.longitude)
          .timeout(const Duration(seconds: 6));

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String country = place.country ?? '';
        String state = place.administrativeArea ?? '';
        List<String> cityParts = [
          place.locality,
          place.subLocality,
          place.subAdministrativeArea,
        ].where((s) => s != null && s.isNotEmpty).cast<String>().toList();
        
        String city = cityParts.join(' ');
        
        // Use a more readable display name for the UI, e.g. "Sublocality, Locality" or fallback to the full string
        String displayCity = cityParts.isNotEmpty ? cityParts.take(2).join(', ') : city;
        bool isMalaysia = country.toLowerCase().contains('malaysia');

        if (isMalaysia) {
          String zoneCode = JakimZones.guessZoneForStateAndCity(state, city);
          return LocationResult(
            isMalaysia: true,
            jakimZoneCode: zoneCode,
            country: country,
            city: '$displayCity, $state',
            latitude: position.latitude,
            longitude: position.longitude,
          );
        } else {
          return LocationResult(
            isMalaysia: false,
            country: country,
            city: city,
            latitude: position.latitude,
            longitude: position.longitude,
          );
        }
      }
    } catch (e) {
      // Ignore geocoding errors and fallback to coordinates (international)
    }

    // Geocoding failed/timed out. Don't misreport Malaysians as international:
    // use a rough bounding box so the caller can fall back to the saved JAKIM zone.
    return LocationResult(
      isMalaysia: _insideMalaysia(position.latitude, position.longitude),
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  static bool _insideMalaysia(double lat, double lng) =>
      lat >= 0.8 && lat <= 7.5 && lng >= 99.5 && lng <= 119.5;

  /// Fast position: a recent cached fix is used immediately; otherwise a
  /// low-accuracy fix (plenty for prayer zones and Qibla) with a hard time limit.
  /// Callers must have location permission already.
  static Future<Position> quickPosition() async {
    final last = await Geolocator.getLastKnownPosition();
    if (last != null &&
        DateTime.now().difference(last.timestamp).inMinutes < 15) {
      return last;
    }
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } on TimeoutException {
      if (last != null) return last;
      rethrow;
    }
  }

  /// Like [quickPosition] but checks service/permission first and returns null on any failure.
  static Future<Position?> tryQuickPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return await quickPosition();
    } catch (_) {
      return null;
    }
  }

  Future<LocationResult?> searchLocation(String address) async {
    try {
      final Geocoding geocoding = Geocoding();
      List<Location> locations = await geocoding.locationFromAddress(address);
      if (locations.isNotEmpty) {
        Location loc = locations.first;
        List<Placemark> placemarks = await geocoding.placemarkFromCoordinates(
          loc.latitude,
          loc.longitude,
        );
        String city = address;
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          city = [place.locality, place.administrativeArea, place.country]
              .where((s) => s != null && s.isNotEmpty)
              .join(', ');
        }
        return LocationResult(
          isMalaysia: false,
          city: city,
          latitude: loc.latitude,
          longitude: loc.longitude,
        );
      }
    } catch (e) {
      return null;
    }
    return null;
  }
}
