import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Replace this with your actual Google Places API key
const String kGooglePlacesApiKey = 'AIzaSyAbxrh2JQja5pH05lidjgq5ZHfDFW8ZiZM';

class ApiService {
  // Method to fetch places from the Google Places API based on a query
  static Future<List<LatLng>> searchPlaces(String query, LatLng location) async {
    final String encodedQuery = Uri.encodeComponent(query); // URL encode the query
    final String url =
        'https://maps.googleapis.com/maps/api/place/textsearch/json?query=$encodedQuery&location=${location.latitude},${location.longitude}&key=$kGooglePlacesApiKey';

    final response = await http.get(Uri.parse(url));

    print('API Response: ${response.body}'); // Log the response

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final places = (data['results'] as List)
          .map((placeJson) => LatLng(
                placeJson['geometry']['location']['lat'],
                placeJson['geometry']['location']['lng'],
              ))
          .toList();
      return places;
    } else {
      throw Exception('Failed to load places');
    }
  }
}
