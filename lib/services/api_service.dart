import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';

class ApiService {
  static const String kGooglePlacesApiKey = 'AIzaSyAbxrh2JQja5pH05lidjgq5ZHfDFW8ZiZM';
  final String apiKey;
  final FlutterTts flutterTts = FlutterTts();
  bool _isSpeaking = false;

  ApiService({required this.apiKey}) {
    _initializeTts();
  }

  Future<void> _initializeTts() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);
    
    flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
    });
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
  Future<void> announceDirection(Map<String, dynamic> direction) async {
    if (_isSpeaking) {
      await flutterTts.stop();
    }
    
    // Clean up HTML tags from instructions
    String cleanInstruction = direction['instruction'].replaceAll(RegExp(r'<[^>]*>'), '');
    
    // Create a more natural speech pattern by adding distance information
    String speechText = "$cleanInstruction in ${direction['distance']}";
    
    _isSpeaking = true;
    await flutterTts.speak(speechText);
  }
  
  Future<void> announceNextDirection(Map<String, dynamic> direction, double distanceInMeters) async {
    // Only announce when we're close to the next maneuver
    if (distanceInMeters <= 50 && distanceInMeters > 20) {
      if (_isSpeaking) {
        await flutterTts.stop();
      }
      
      // Clean up HTML tags from instructions
      String cleanInstruction = direction['instruction'].replaceAll(RegExp(r'<[^>]*>'), '');
      
      // Create an immediate instruction
      String speechText = "In ${distanceInMeters.toInt()} meters, $cleanInstruction";
      
      _isSpeaking = true;
      await flutterTts.speak(speechText);
    }
    else if (distanceInMeters <= 20) {
      if (_isSpeaking) {
        await flutterTts.stop();
      }
      
      // Clean up HTML tags from instructions
      String cleanInstruction = direction['instruction'].replaceAll(RegExp(r'<[^>]*>'), '');
      
      // Create an immediate instruction
      String speechText = "Now $cleanInstruction";
      
      _isSpeaking = true;
      await flutterTts.speak(speechText);
    }
  }
  
  Future<void> announceArrival() async {
    if (_isSpeaking) {
      await flutterTts.stop();
    }
    
    _isSpeaking = true;
    await flutterTts.speak("You have arrived at your destination");
  }
  
  Future<void> announceDestinationDistance(double distanceInMeters) async {
    if (_isSpeaking || distanceInMeters > 200) {
      return;
    }
    
    _isSpeaking = true;
    await flutterTts.speak("Your destination is ${distanceInMeters.toInt()} meters ahead");
  }
  
  // Prepare for voice recognition (to be implemented)
  Future<void> setupVoiceRecognition() async {
    // This would be implemented if you want to add voice command recognition
    // You'll need another package like speech_to_text for this functionality
  }
  
  Future<void> stopSpeaking() async {
    if (_isSpeaking) {
      await flutterTts.stop();
      _isSpeaking = false;
    }
  }
  
  // Check if TTS is currently speaking
  bool isCurrentlySpeaking() {
    return _isSpeaking;
  }
  
  // Change TTS settings
  Future<void> updateTtsSettings({
    double? rate,
    double? pitch,
    double? volume,
    String? language,
  }) async {
    if (rate != null) await flutterTts.setSpeechRate(rate);
    if (pitch != null) await flutterTts.setPitch(pitch);
    if (volume != null) await flutterTts.setVolume(volume);
    if (language != null) await flutterTts.setLanguage(language);
  }
}

