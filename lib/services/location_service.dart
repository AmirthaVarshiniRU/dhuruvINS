import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  Future<bool> checkAndRequestPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('DEBUG: Location services (GPS) are disabled on the device.');
      return false;
    }

    permission = await Geolocator.checkPermission();
    print('DEBUG: Current permission status is: $permission');
    
    if (permission == LocationPermission.denied) {
      print('DEBUG: Requesting permission...');
      permission = await Geolocator.requestPermission();
      print('DEBUG: Permission status after request is: $permission');
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('DEBUG: Permissions are permanently denied. Dialog cannot be shown.');
      return false;
    }

    return true;
  }

  Stream<Position> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1, // update every 1 meter
      ),
    );
  }

  Future<Position?> getCurrentPosition() async {
    final hasPermission = await checkAndRequestPermissions();
    if (!hasPermission) return null;
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }
}
