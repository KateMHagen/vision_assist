import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vision_assist/services/api_service.dart'; // Import ApiService

class GPSPage extends StatefulWidget {
  const GPSPage({Key? key}) : super(key: key);

  @override
  _GPSPageState createState() => _GPSPageState();
}

class _GPSPageState extends State<GPSPage> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  final TextEditingController _searchController = TextEditingController();
  final Set<Marker> _markers = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showErrorDialog('Location permissions are denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showErrorDialog('Location permissions are permanently denied');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Error getting location: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;

    if (_currentPosition == null) {
    _showErrorDialog('Current location is not available.');
    return;
    }

    try {
      LatLng currentLatLng = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);

      final results = await ApiService.searchPlaces(query, currentLatLng);

      setState(() {
        _markers.clear(); // Clear previous markers
        results.forEach((latLng) {
          _markers.add(
            Marker(
              markerId: MarkerId(latLng.toString()),
              position: latLng,
              infoWindow: InfoWindow(title: query),
            ),
          );
        });
      });

      if (results.isNotEmpty) {
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(results[0]),
        );
      } else {
        _showErrorDialog("No results found for '$query'");
      }
    } catch (e) {
      _showErrorDialog("Error searching for location: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_currentPosition == null) {
      return Scaffold(
        body: const Center(
          child: Text('Unable to retrieve location'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Location'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20.0),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: const Text(
              'Use the search bar below to find locations.',
              style: TextStyle(color: Colors.white, fontSize: 14.0),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search for a location",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (value) {
                _searchLocation(value);
              },
            ),
          ),
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                ),
                zoom: 15,
              ),
              mapType: MapType.normal,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              markers: _markers,
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
