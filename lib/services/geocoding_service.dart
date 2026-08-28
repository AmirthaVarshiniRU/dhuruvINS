import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class SearchSuggestion {
  final String name;
  final LatLng coordinates;
  SearchSuggestion({required this.name, required this.coordinates});
  
  @override
  String toString() => name; // Helps Autocomplete widget display the name
}

class GeocodingService {
  static const String _photonUrl = 'https://photon.komoot.io/api';

  /// Fetches autocomplete suggestions from Photon API, prioritized by distance if currentLocation is given
  Future<List<SearchSuggestion>> getSuggestions(String query, [LatLng? currentLocation]) async {
    if (query.isEmpty) return [];
    
    try {
      // Use current location for API bias, otherwise default to center of India
      final String latStr = currentLocation != null ? currentLocation.latitude.toString() : '20.5937';
      final String lonStr = currentLocation != null ? currentLocation.longitude.toString() : '78.9629';
      
      // Fetch a larger pool (25) so we can filter and sort accurately
      final url = Uri.parse('$_photonUrl/?q=${Uri.encodeComponent(query)}&limit=25&lat=$latStr&lon=$lonStr');
      final response = await http.get(url, headers: {
        'User-Agent': 'com.sih.idr',
      });
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List features = data['features'] ?? [];
        
        // Strictly filter to only show locations inside India
        features = features.where((f) {
          final props = f['properties'];
          final cc = props['countrycode']?.toString().toUpperCase() ?? '';
          final c = props['country']?.toString().toLowerCase() ?? '';
          return cc == 'IN' || c == 'india';
        }).toList();
        
        List<SearchSuggestion> suggestions = features.map<SearchSuggestion>((f) {
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

        // If we know where the user is, mathematically sort by real-world distance
        if (currentLocation != null) {
          suggestions.sort((a, b) {
            final distA = Geolocator.distanceBetween(
              currentLocation.latitude, currentLocation.longitude,
              a.coordinates.latitude, a.coordinates.longitude,
            );
            final distB = Geolocator.distanceBetween(
              currentLocation.latitude, currentLocation.longitude,
              b.coordinates.latitude, b.coordinates.longitude,
            );
            return distA.compareTo(distB);
          });
        }

        return suggestions.take(5).toList();
      }
      return [];
    } catch (e) {
      print('Autocomplete error: $e');
      return [];
    }
  }
}
