import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  static const String kGooglePlacesApiKey =
      'AIzaSyAbxrh2JQja5pH05lidjgq5ZHfDFW8ZiZM'; // Replace with your actual API key

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

  static Future<List<Map<String, dynamic>>> getWalkingDirections(
      LatLng origin, LatLng destination) async {
    final String url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&mode=walking&key=$kGooglePlacesApiKey';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if ((data['routes'] as List).isEmpty) {
        throw Exception('No routes found');
      }

      final steps = (data['routes'][0]['legs'] as List)[0]['steps']
          as List; // Extract steps
      List<Map<String, dynamic>> instructions = steps.map((step) {
        return {
          'distance': step['distance']['text'],
          'duration': step['duration']['text'],
          'instruction': step['html_instructions'],
          'maneuver': step['maneuver'],
          'polyline':
              _decodePolyline(step['polyline']['points']), //polyline for this step
        };
      }).toList();
      return instructions; // Return the list of steps
    } else {
      throw Exception('Failed to load directions');
    }
  }

  static Future<List<LatLng>> searchPlaces(
      String query, LatLng currentLocation) async {
    // Implementation for searchPlaces (not modified, but included for context)
    final String url =
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=${currentLocation.latitude},${currentLocation.longitude}&radius=1000&keyword=$query&key=$kGooglePlacesApiKey';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final results = data['results'] as List;
      return results.map((place) {
        final location = place['geometry']['location'];
        return LatLng(location['lat'], location['lng']);
      }).toList();
    } else {
      throw Exception('Failed to load places');
    }
  }
}
