import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteInstruction {
  final String instruction;
  final double distance;
  final LatLng maneuverLocation;

  RouteInstruction({
    required this.instruction,
    required this.distance,
    required this.maneuverLocation,
  });
}

class RouteData {
  final List<LatLng> points;
  final double distance; // in meters
  final double duration; // in seconds
  final List<RouteInstruction> instructions;

  RouteData({
    required this.points, 
    required this.distance, 
    required this.duration,
    required this.instructions,
  });
}

class RoutingService {
  static const String _osrmUrl = 'https://router.project-osrm.org/route/v1/foot';

  Future<RouteData?> getRoute(LatLng start, LatLng destination) async {
    try {
      final url = Uri.parse(
          '$_osrmUrl/${start.longitude},${start.latitude};${destination.longitude},${destination.latitude}?overview=full&geometries=geojson&steps=true');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          
          final double distance = route['distance'].toDouble();
          final double duration = route['duration'].toDouble();
          
          final geometry = route['geometry']['coordinates'] as List;
          final points = geometry.map((coord) {
            return LatLng(coord[1].toDouble(), coord[0].toDouble());
          }).toList();
          
          List<RouteInstruction> routeInstructions = [];
          if (route['legs'] != null && route['legs'].isNotEmpty) {
            final steps = route['legs'][0]['steps'] as List;
            for (var step in steps) {
              final maneuver = step['maneuver'];
              final location = maneuver['location'] as List;
              
              String modifier = maneuver['modifier'] ?? '';
              String type = maneuver['type'] ?? '';
              String name = step['name'] ?? '';
              
              String instruction = '';
              if (type == 'turn') {
                instruction = 'Turn $modifier onto $name';
              } else if (type == 'new name') {
                instruction = 'Continue onto $name';
              } else if (type == 'depart') {
                instruction = 'Head $modifier on $name';
              } else if (type == 'arrive') {
                instruction = 'You have arrived at your destination';
              } else {
                instruction = '$type $modifier $name'.trim();
              }
              
              if (instruction.trim().isEmpty) {
                instruction = 'Continue straight';
              }
              
              routeInstructions.add(RouteInstruction(
                instruction: instruction,
                distance: step['distance'].toDouble(),
                maneuverLocation: LatLng(location[1].toDouble(), location[0].toDouble()),
              ));
            }
          }
          
          return RouteData(
            points: points, 
            distance: distance, 
            duration: duration,
            instructions: routeInstructions,
          );
        }
      }
      return null;
    } catch (e) {
      print('Routing error: $e');
      return null;
    }
  }
}
