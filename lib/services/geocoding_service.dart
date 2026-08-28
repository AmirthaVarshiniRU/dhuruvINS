import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class SearchSuggestion {
  final String name;
  final LatLng coordinates;
  SearchSuggestion({required this.name, required this.coordinates});
  
  @override
  String toString() => name; // Helps Autocomplete widget display the name
}

class GeocodingService {
  static const String _photonUrl = 'https://photon.komoot.io/api';

  /// Fetches autocomplete suggestions from Photon API
  Future<List<SearchSuggestion>> getSuggestions(String query) async {
    if (query.isEmpty) return [];
    
    try {
      final url = Uri.parse('$_photonUrl/?q=${Uri.encodeComponent(query)}&limit=5');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List features = data['features'] ?? [];
        
        return features.map((f) {
          final props = f['properties'];
          final coords = f['geometry']['coordinates']; // Photon returns [lon, lat]
          final lat = coords[1];
          final lon = coords[0];
          
          String displayName = props['name'] ?? 'Unknown Location';
          
          // Append city or state for context
          if (props['city'] != null && props['city'] != props['name']) {
            displayName += ', ${props['city']}';
          } else if (props['state'] != null && props['state'] != props['name']) {
             displayName += ', ${props['state']}';
          }

          return SearchSuggestion(
            name: displayName,
            coordinates: LatLng(lat, lon),
          );
        }).toList();
      }
      return [];
    } catch (e) {
      print('Autocomplete error: $e');
      return [];
    }
  }
}
