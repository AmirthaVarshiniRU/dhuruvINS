import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class GeocodingService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org/search';

  /// Searches for an address and returns its LatLng coordinates.
  Future<LatLng?> getCoordinates(String address) async {
    try {
      // Create the API URL. format=json returns data we can parse, limit=1 gives the best result.
      final url = Uri.parse('$_baseUrl?q=${Uri.encodeComponent(address)}&format=json&limit=1');
      
      // Nominatim requires a user-agent to identify who is making the request
      final response = await http.get(url, headers: {
        'User-Agent': 'com.sih.idr', 
      });

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          // Parse the latitude and longitude strings into doubles
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          return LatLng(lat, lon);
        }
      }
      return null;
    } catch (e) {
      print('Geocoding error: $e');
      return null;
    }
  }
}
