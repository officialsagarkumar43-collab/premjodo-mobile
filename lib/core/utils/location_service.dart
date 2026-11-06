import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationResult {
  final double latitude;
  final double longitude;
  final String? city;
  final String? state;
  final String? country;

  LocationResult({
    required this.latitude,
    required this.longitude,
    this.city,
    this.state,
    this.country = 'India',
  });
}

class LocationService {
  LocationService._();

  static Future<Position?> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled, opening settings...');
        await Geolocator.openLocationSettings();
        // Wait briefly for user to toggle
        await Future.delayed(const Duration(milliseconds: 1500));
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions are denied by user.');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied, opening app settings...');
        await Geolocator.openAppSettings();
        return null;
      }

      // Try fast last known position first
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        // Fetch fresh position asynchronously if needed or return last known
        try {
          final fresh = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 5),
            ),
          );
          return fresh;
        } catch (_) {
          return lastKnown;
        }
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (e) {
      debugPrint('Error in LocationService: $e');
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }
}
