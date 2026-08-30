import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  LocationSettings _phoneGnssSettings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 1),
        forceLocationManager: true,
        useMSLAltitude: true,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Dhuruva INS',
          notificationText: 'GNSS tracking is active',
          notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }

    return AppleSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      activityType: ActivityType.otherNavigation,
      distanceFilter: 0,
      pauseLocationUpdatesAutomatically: false,
      allowBackgroundLocationUpdates: false,
    );
  }

  Future<bool> checkAndRequestPermissions() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      if (!await Geolocator.isLocationServiceEnabled()) {
        return false;
      }
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      await Permission.notification.request();
    }

    return true;
  }

  Stream<Position> getLocationStream() {
    return Geolocator.getPositionStream(locationSettings: _phoneGnssSettings());
  }

  Future<Position?> getCurrentPosition() async {
    final hasPermission = await checkAndRequestPermissions();
    if (!hasPermission) return null;
    return Geolocator.getCurrentPosition(locationSettings: _phoneGnssSettings());
  }
}
