import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vision_assist/services/api_service.dart';
import 'navigation_page.dart';

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
  bool _showNavigationButton = false;
  String _errorMessage = ''; // Add error message state
  List<Map<String, dynamic>> _directions = [];

  @override
  void initState() {
    super.initState();
    _checkAndRequestLocationPermission();
  }

  Future<void> _checkAndRequestLocationPermission() async {
    // Check permission status using permission_handler
    var status = await Permission.locationWhenInUse.status;

    if (status.isDenied || status.isPermanentlyDenied) {
      // Request permission
      status = await Permission.locationWhenInUse.request();
    }

    if (status.isGranted) {
      // Permission granted, proceed to get current location
      _getCurrentLocation();
    } else {
      // Handle permission denied
      _handleLocationPermissionDenied();
    }
  }

  void _handleLocationPermissionDenied() {
    setState(() {
      _isLoading = false;
      _errorMessage =
          'Location permission is required to use this feature.'; // Set error message
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Access Needed'),
        content: Text(
            'This app requires location access to provide navigation services. Please enable location permissions in your device settings.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings(); // Opens app settings
            },
            child: const Text('Open Settings'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = ''; // Clear any previous error
    });
    try {
      // Ensure location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        return;
      }

      // Request precise location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        // Permissions are denied forever, handle appropriately
        return _handleLocationPermissionDenied();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        // Retrieve current position with iOS-specific accuracy
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
          timeLimit: const Duration(seconds: 10),
        );

        setState(() {
          _currentPosition = position;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Failed to retrieve current location: $e'; // Set error message
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

    setState(() {
      _isLoading = true; // Start loading
      _errorMessage = '';
    });

    try {
      LatLng currentLatLng =
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude);

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
                  _selectedDestination =
                      latLng; // Update selected destination
                  _showNavigationButton =
                      true; // Show the navigation button after a selection
                });
              },
            ),
          );
        });
        _selectedDestination =
            null; // Clear destination if new search
        _isLoading =
            false; // Stop loading whether results are found or not.
      });

      if (results.isNotEmpty) {
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(results[0]),
        );
      } else {
        _showErrorDialog("No results found for '$query'");
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Error searching for location: $e";
      });
      _showErrorDialog("Error searching for location: $e");
    }
  }

  Future<void> _getWalkingDirections() async {
    if (_currentPosition == null || _selectedDestination == null) {
      _showErrorDialog('Current location or destination is not available.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      LatLng origin =
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
      LatLng destination = _selectedDestination!;

      // Call API to get directions
      _directions = await ApiService.getWalkingDirections(origin, destination);
      setState(() {
        _isLoading = false;
      });

      // Navigate to the NavigationScreen and pass the directions
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NavigationScreen(
            directions: _directions,
            origin: origin,
            destination: destination,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Error retrieving directions: $e";
      });
      _showErrorDialog("Error retrieving directions: $e");
    }
  }

  LatLngBounds _getLatLngBounds(LatLng origin, LatLng destination) {
    return LatLngBounds(
      southwest: LatLng(
        origin.latitude < destination.latitude
            ? origin.latitude
            : destination.latitude,
        origin.longitude < destination.longitude
            ? origin.longitude
            : destination.longitude,
      ),
      northeast: LatLng(
        origin.latitude > destination.latitude
            ? origin.latitude
            : destination.latitude,
        origin.longitude > destination.longitude
            ? origin.longitude
            : destination.longitude,
      ),
    );
  }

  void _showErrorDialog(String message) {
    if (mounted) {
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
        body: Center(
          child: Text(_errorMessage.isNotEmpty
              ? _errorMessage
              : 'Unable to retrieve location'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('GPS Navigation'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(20.0),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
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
                  _getWalkingDirections();
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
              polylines: _polylines,
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