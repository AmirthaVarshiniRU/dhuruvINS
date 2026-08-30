import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class PlaceDetails {
  final String title;
  final String summary;
  final String? imageUrl;

  PlaceDetails({required this.title, required this.summary, this.imageUrl});
}

class WikipediaService {
  Future<PlaceDetails?> getPlaceDetails(LatLng coordinates) async {
    try {
      // Step 1: Geosearch to find nearest article (within 2000 meters)
      final geoUrl = Uri.parse(
          'https://en.wikipedia.org/w/api.php?action=query&list=geosearch&gscoord=${coordinates.latitude}|${coordinates.longitude}&gsradius=2000&gslimit=1&format=json');
      final geoRes = await http.get(geoUrl);
      
      if (geoRes.statusCode == 200) {
        final geoData = jsonDecode(geoRes.body);
        final geoSearch = geoData['query']?['geosearch'] as List?;
        
        if (geoSearch != null && geoSearch.isNotEmpty) {
          final title = geoSearch.first['title'] as String;
          
          // Step 2: Fetch summary and image for that title
          final summaryUrl = Uri.parse('https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(title)}');
          final summaryRes = await http.get(summaryUrl);
          
          if (summaryRes.statusCode == 200) {
            final summaryData = jsonDecode(summaryRes.body);
            final extract = summaryData['extract'] as String?;
            final imageUrl = summaryData['thumbnail']?['source'] as String?;
            
            if (extract != null && extract.isNotEmpty) {
              return PlaceDetails(
                title: title,
                summary: extract,
                imageUrl: imageUrl,
              );
            }
          }
        }
      }
    } catch (e) {
      print('Wikipedia API Error: $e');
    }
    return null;
  }
}
