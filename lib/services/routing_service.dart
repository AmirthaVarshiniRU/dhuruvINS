import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteData {
  final List<LatLng> points;
  final double distance; // in meters
  final double duration; // in seconds

  RouteData({required this.points, required this.distance, required this.duration});
}

class RoutingService {
  static const String _osrmUrl = 'https://router.project-osrm.org/route/v1/driving';

  Future<RouteData?> getRoute(LatLng start, LatLng destination) async {
    try {
      // OSRM expects coordinates in lon,lat format
      final url = Uri.parse(
          '$_osrmUrl/${start.longitude},${start.latitude};${destination.longitude},${destination.latitude}?overview=full&geometries=geojson');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          
          final double distance = route['distance'].toDouble();
          final double duration = route['duration'].toDouble();
          
          final geometry = route['geometry']['coordinates'] as List;
          
          // OSRM GeoJSON returns coordinates as [longitude, latitude]
          final points = geometry.map((coord) {
            return LatLng(coord[1].toDouble(), coord[0].toDouble());
          }).toList();
          
          return RouteData(points: points, distance: distance, duration: duration);
        }
      }
      return null;
    } catch (e) {
      print('Routing error: $e');
      return null;
    }
  }
}
