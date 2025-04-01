import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vision_assist/services/api_service.dart';
import 'navigation_page.dart';
import 'package:custom_info_window/custom_info_window.dart';

class GPSPage extends StatefulWidget {
  @override
  _GPSPageState createState() => _GPSPageState();
}

class _GPSPageState extends State<GPSPage> {
  late ApiService _apiService;
  GoogleMapController? _mapController;
  Position? _currentPosition;
  final TextEditingController _searchController = TextEditingController();
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  LatLng? _selectedDestination;
  bool _isLoading = true;
  bool _showNavigationButton = false;
  String _errorMessage = '';
  List<Map<String, dynamic>> _directions = [];
  final CustomInfoWindowController _customInfoWindowController = CustomInfoWindowController();

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(apiKey: ApiService.kGooglePlacesApiKey); // Correct placement
    _checkAndRequestLocationPermission();
  }

  Future<void> _checkAndRequestLocationPermission() async {
    var status = await Permission.locationWhenInUse.status;
    if (status.isDenied || status.isPermanentlyDenied) {
      status = await Permission.locationWhenInUse.request();
    }

    if (status.isGranted) {
      _getCurrentLocation();
    } else {
      _handleLocationPermissionDenied();
    }
  }

  void _handleLocationPermissionDenied() {
    setState(() {
      _isLoading = false;
      _errorMessage = 'Location permission is required to use this feature.';
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Access Needed'),
        content: const Text(
            'This app requires location access to provide navigation services. Please enable location permissions in your device settings.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
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
      _errorMessage = '';
    });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        return _handleLocationPermissionDenied();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
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
        _errorMessage = 'Failed to retrieve current location: $e';
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
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      LatLng currentLatLng =
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
      final results = await ApiService.searchPlaces(query, currentLatLng);

      setState(() {
        _markers.clear();
        _polylines.clear();
        _selectedDestination = null;
        _isLoading = false;

        for (var latLng in results) {
          _markers.add(
            Marker(
              markerId: MarkerId(latLng.toString()),
              position: latLng,
              onTap: () {
                setState(() {
                  _selectedDestination = latLng;
                  _showNavigationButton = true;
                });

                _customInfoWindowController.addInfoWindow!(
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          query,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  latLng,
                );
              },
            ),
          );
        }
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
        LatLng origin = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
        LatLng destination = _selectedDestination!;
        _directions = await ApiService.getWalkingDirections(origin, destination);
        
        // Announce the first direction if available
        if (_directions.isNotEmpty) {
          await _apiService.announceDirection(_directions.first);
        }
        
        setState(() => _isLoading = false);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NavigationScreen(
              directions: _directions,
              origin: origin,
              destination: destination,
              apiService: _apiService, // Pass the apiService to NavigationScreen
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

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  void _showTtsSettingsDialog() {
    double rate = 0.5;
    double pitch = 1.0;
    double volume = 1.0;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Voice Navigation Settings'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Speech Rate: ${rate.toStringAsFixed(1)}'),
                Slider(
                  value: rate,
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  onChanged: (value) {
                    setState(() => rate = value);
                  },
                ),
                Text('Pitch: ${pitch.toStringAsFixed(1)}'),
                Slider(
                  value: pitch,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  onChanged: (value) {
                    setState(() => pitch = value);
                  },
                ),
                Text('Volume: ${volume.toStringAsFixed(1)}'),
                Slider(
                  value: volume,
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  onChanged: (value) {
                    setState(() => volume = value);
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _apiService.updateTtsSettings(
                rate: rate,
                pitch: pitch,
                volume: volume,
              );
              Navigator.of(context).pop();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          )
        : _currentPosition == null
            ? Scaffold(
                body: Center(
                  child: Text(_errorMessage.isNotEmpty
                      ? _errorMessage
                      : 'Unable to retrieve location'),
                ),
              )
            : Scaffold(
                appBar: PreferredSize(
                  preferredSize: const Size.fromHeight(70),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(24),
                    ),
                    child: AppBar(
                      title: const Text(
                        'GPS Navigation',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      centerTitle: true,
                      backgroundColor: Colors.deepPurple,
                      elevation: 4,
                    ),
                  ),
                ),
                body: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          hintText: "Search for a location",
                          hintStyle: const TextStyle(color: Colors.grey),
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: _searchLocation,
                      ),
                    ),
                    if (_showNavigationButton && _selectedDestination != null)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ElevatedButton.icon(
                          onPressed: _getWalkingDirections,
                          icon: const Icon(Icons.directions_walk),
                          label: const Text('Start Navigation'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 14),
                            textStyle: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            GoogleMap(
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
                              onMapCreated: (controller) {
                                _mapController = controller;
                                _customInfoWindowController.googleMapController = controller;
                              },
                              onTap: (position) {
                                _customInfoWindowController.hideInfoWindow!();
                              },
                              onCameraMove: (position) {
                                _customInfoWindowController.onCameraMove!();
                              },
                            ),
                            CustomInfoWindow(
                              controller: _customInfoWindowController,
                              height: 60,
                              width: 120,
                              offset: 70,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
  }
}
