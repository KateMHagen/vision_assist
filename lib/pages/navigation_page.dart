import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:vision_assist/services/api_service.dart';

class NavigationScreen extends StatefulWidget {
  final List<Map<String, dynamic>> directions;
  final LatLng origin;
  final LatLng destination;
  final ApiService apiService; // Add this line

  const NavigationScreen({
    Key? key,
    required this.directions,
    required this.origin,
    required this.destination,
    required this.apiService,
  }) : super(key: key);

  @override
  _NavigationScreenState createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  late GoogleMapController? _mapController;
  final Set<Polyline> _polylines = {};
  Position? _currentPosition;
  double _currentHeading = 0.0;
  bool _isLoading = true;
  late StreamSubscription<Position> _positionStreamSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription;
  int _currentStepIndex = 0;
  double _distanceToNextStep = 0;
  bool _arrived = false;


  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _startListeningToCompass();
    _updatePolylines();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _positionStreamSubscription.cancel();
    _compassSubscription?.cancel();
    widget.apiService.stopSpeaking();
    //_mapController.dispose();
    super.dispose();
  }

  void _startLocationTracking() {
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update every 5 meters
      ),
    ).listen((Position position) {
      setState(() {
        _currentPosition = position;
      });
      
      _updateNavigation(position);
    });
  }

  void _updateNavigation(Position position) {
    if (_currentStepIndex >= widget.directions.length) {
      return;
    }

    // Check if we've reached the destination
    LatLng currentLatLng = LatLng(position.latitude, position.longitude);
    double distanceToDestination = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      widget.destination.latitude,
      widget.destination.longitude,
    );

    // If we've reached the destination
    if (distanceToDestination < 20 && !_arrived) {
      widget.apiService.announceArrival();
      setState(() {
        _arrived = true;
      });
      return;
    }

    // Periodically announce destination distance when getting close
    if (distanceToDestination < 200) {
      widget.apiService.announceDestinationDistance(distanceToDestination);
    }

    // Check if we need to move to the next step
    if (_currentStepIndex < widget.directions.length - 1) {
      List<LatLng> nextStepPolyline = widget.directions[_currentStepIndex + 1]['polyline'];
      
      if (nextStepPolyline.isNotEmpty) {
        LatLng nextManeuverPoint = nextStepPolyline.first;
        double distanceToNextManeuver = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          nextManeuverPoint.latitude,
          nextManeuverPoint.longitude,
        );
        
        setState(() {
          _distanceToNextStep = distanceToNextManeuver;
        });
        
        // Announce upcoming maneuver based on distance
        widget.apiService.announceNextDirection(
          widget.directions[_currentStepIndex + 1], 
          distanceToNextManeuver
        );
        
        // Move to next step if we're very close to it
        if (distanceToNextManeuver < 10) {
          setState(() {
            _currentStepIndex++;
          });
          widget.apiService.announceDirection(widget.directions[_currentStepIndex]);
        }
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation);
      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });
      _updateMapCamera();
    } catch (e) {
      setState(() => _isLoading = false);
    }
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      setState(() {
        _currentPosition = position;
      });
      _updateMapCamera();
    });
  }

  void _startListeningToCompass() {
    _compassSubscription =
        FlutterCompass.events?.listen((CompassEvent? heading) {
      if (heading != null) {
        setState(() {
          _currentHeading = heading.heading ?? 0.0;
        });
        _updateMapCamera();
      }
    });
  }

  void _updateMapCamera() {
    if (_mapController == null || _currentPosition == null) return;

    double bearing = 0;
    if (widget.directions.isNotEmpty) {
      List<LatLng> polylinePoints =
          widget.directions[0]['polyline']?.cast<LatLng>() ?? [];
      if (polylinePoints.isNotEmpty) {
        LatLng nextPoint = polylinePoints[0];
        bearing = _calculateBearing(
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            nextPoint);
      }
    }
    double finalHeading = _currentHeading;

    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          zoom: 17,
          bearing: finalHeading,
          tilt: 60,
        ),
      ),
    );
  }

  double _calculateBearing(LatLng origin, LatLng destination) {
    double startLat = _toRadians(origin.latitude);
    double startLng = _toRadians(origin.longitude);
    double destLat = _toRadians(destination.latitude);
    double destLng = _toRadians(destination.longitude);

    double y = math.sin(destLng - startLng) * math.cos(destLat);
    double x = math.cos(startLat) * math.sin(destLat) -
        math.sin(startLat) * math.cos(destLat) * math.cos(destLng - startLng);
    double brng = math.atan2(y, x);
    brng = _toDegrees(brng);
    return (brng + 360) % 360;
  }

  double _toRadians(double degree) => degree * math.pi / 180;
  double _toDegrees(double radian) => radian * 180 / math.pi;

  void _updatePolylines() {
    setState(() {
      _polylines.clear();
      _polylines.addAll(_buildPolylines());
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: ClipRRect(
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(24)),
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
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                ),
                zoom: 17,
              ),
              mapType: MapType.normal,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              polylines: _polylines,
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
            ),
          ),
          _buildDirectionsList(),
        ],
      ),
    );
  }

  Set<Polyline> _buildPolylines() {
    List<LatLng> allPoints = [];
    for (var direction in widget.directions) {
      List<LatLng> polyline = direction['polyline']?.cast<LatLng>() ?? [];
      allPoints.addAll(polyline);
    }

    if (allPoints.isEmpty) return {};

    return {
      Polyline(
        polylineId: const PolylineId('route'),
        color: Colors.blue,
        width: 5,
        points: allPoints,
      ),
    };
  }

  Widget _buildDirectionsList() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(8.0),
      child: ListView.builder(
        itemCount: widget.directions.length,
        itemBuilder: (context, index) {
          final direction = widget.directions[index];
          return ListTile(
            leading: _getManeuverIcon(direction['maneuver']),
            title: Text(
              direction['instruction'].replaceAll(RegExp(r'<[^>]*>'), ''),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle:
                Text('${direction['distance']} • ${direction['duration']}'),
          );
        },
      ),
    );
  }

  Widget _getManeuverIcon(String? maneuver) {
    switch (maneuver) {
      case 'turn-slight-left':
        return const Icon(Icons.turn_slight_left);
      case 'turn-left':
        return const Icon(Icons.turn_left);
      case 'turn-sharp-left':
        return const Icon(Icons.turn_sharp_left);
      case 'turn-slight-right':
        return const Icon(Icons.turn_slight_right);
      case 'turn-right':
        return const Icon(Icons.turn_right);
      case 'turn-sharp-right':
        return const Icon(Icons.turn_sharp_right);
      case 'straight':
        return const Icon(Icons.arrow_upward);
      case 'ramp-on':
        return const Icon(Icons.call_made);
      case 'ramp-off':
        return const Icon(Icons.call_received);
      case 'fork-left':
        return const Icon(Icons.fork_left);
      case 'fork-right':
        return const Icon(Icons.fork_right);
      case 'merge':
        return const Icon(Icons.merge);
      case 'roundabout-left':
        return const Icon(Icons.roundabout_left);
      case 'roundabout-right':
        return const Icon(Icons.roundabout_right);
      default:
        return const Icon(Icons.directions);
    }
  }
}
