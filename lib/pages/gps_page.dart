import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vision_assist/services/api_service.dart'; 

class GPSPage extends StatefulWidget {
  @override
  _GPSPageState createState() => _GPSPageState();
}

class _GPSPageState extends State<GPSPage> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  final TextEditingController _searchController = TextEditingController();
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  LatLng? _selectedDestination;
  bool _isLoading = true;
  bool _showNavigationButton = false; // Flag to control visibility of navigation button

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
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
      _showErrorDialog('Failed to retrieve current location: $e');
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;

    if (_currentPosition == null) {
      _showErrorDialog('Current location is not available.');
      return;
    }

    try {
      LatLng currentLatLng = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);

      // Call API to search for places
      final results = await ApiService.searchPlaces(query, currentLatLng);

      setState(() {
        _markers.clear(); // Clear previous markers
        _polylines.clear(); // Clear any existing route lines
        results.forEach((latLng) {
          _markers.add(
            Marker(
              markerId: MarkerId(latLng.toString()),
              position: latLng,
              infoWindow: InfoWindow(title: query),
              onTap: () {
                setState(() {
                  _selectedDestination = latLng; // Update selected destination
                  _showNavigationButton = true; // Show the navigation button after a selection
                });
              },
            ),
          );
        });
        _selectedDestination = null; // Clear destination if new search
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

  Future<void> _getWalkingDirections(LatLng destination) async {
    if (_currentPosition == null) {
      _showErrorDialog('Current location is not available.');
      return;
    }

    try {
      LatLng origin = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);

      // Call API to get directions
      final polylinePoints = await ApiService.getWalkingDirections(origin, destination);

      setState(() {
        _polylines.clear();
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('walking_route'),
            color: Colors.blue,
            width: 5,
            points: polylinePoints,
          ),
        );
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(
          _getLatLngBounds(origin, destination),
          100.0,
        ),
      );
    } catch (e) {
      _showErrorDialog("Error retrieving directions: $e");
    }
  }

  LatLngBounds _getLatLngBounds(LatLng origin, LatLng destination) {
    return LatLngBounds(
      southwest: LatLng(
        origin.latitude < destination.latitude ? origin.latitude : destination.latitude,
        origin.longitude < destination.longitude ? origin.longitude : destination.longitude,
      ),
      northeast: LatLng(
        origin.latitude > destination.latitude ? origin.latitude : destination.latitude,
        origin.longitude > destination.longitude ? origin.longitude : destination.longitude,
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
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
        title: const Text('GPS Navigation'),
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
          // Display "Start Navigation" button only if destination is selected
          if (_showNavigationButton && _selectedDestination != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  _getWalkingDirections(_selectedDestination!);
                },
                icon: const Icon(Icons.directions_walk),
                label: const Text('Start Navigation'),
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
              polylines: _polylines, // Add the polylines to the map
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
            ),
          ),
        ],
      ),
    );
  }
}
