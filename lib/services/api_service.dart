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
  // Method to fetch directions from the Google Maps Directions API
  static Future<List<LatLng>> getWalkingDirections(LatLng origin, LatLng destination) async {
    final String url =
      'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&mode=walking&key=$kGooglePlacesApiKey';

    final response = await http.get(Uri.parse(url));

    print('Directions API Response: ${response.body}'); // Log the response

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if ((data['routes'] as List).isEmpty) {
        throw Exception('No routes found');
      }

      final points = data['routes'][0]['overview_polyline']['points'];
      return _decodePolyline(points);
    } else {
      throw Exception('Failed to load directions');
    }
  }

  // Helper function to decode the polyline points
  static List<LatLng> _decodePolyline(String polyline) {
    List<LatLng> polylineCoordinates = [];
    int index = 0, len = polyline.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int shift = 0, result = 0;
      int b;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int deltaLat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += deltaLat;

      shift = 0;
      result = 0;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int deltaLng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += deltaLng;

      polylineCoordinates.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return polylineCoordinates;
  }
}
