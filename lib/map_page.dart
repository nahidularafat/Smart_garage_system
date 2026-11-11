// map_page.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;
import 'bus_constants.dart';

class MapPage extends StatefulWidget {
  final String busId;
  final String title;

  const MapPage({super.key, required this.busId, required this.title});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  GoogleMapController? mapController;
  LatLng? _busLocation;
  LatLng? _userLocation;

  double? _distance;
  String? _etaText;
  List<LatLng> _polylineCoordinates = [];

  final Location location = Location();

  // 🔥 IMPORTANT: Replace with your real Google Directions API Key
  final String googleApiKey = "AIzaSyABBdIvW5co6bFBg3ds4c1BFMmrImjFTng";

  Timer? _routeTimer;
  String _locationMessage = "Waiting for your location...";
  bool _requestingLocation = false;

  static const LatLng _defaultInitialLocation = LatLng(23.8103, 90.4125);

  // --- Location Getters and Setters ---

  LatLng? get busLocation => _busLocation;
  set busLocation(LatLng? newLocation) {
    if (_busLocation == null ||
        newLocation == null ||
        _busLocation!.latitude != newLocation.latitude ||
        _busLocation!.longitude != newLocation.longitude) {
      if (mounted) {
        setState(() {
          _busLocation = newLocation;
        });
        // ✅ Follow the bus smoothly
        if (mapController != null && newLocation != null) {
          mapController!.animateCamera(CameraUpdate.newLatLng(newLocation));
        }
      }
      if (_busLocation != null && _userLocation != null) {
        _updateDistance();
        _scheduleRouteUpdate();
      }
    }
  }

  LatLng? get userLocation => _userLocation;
  set userLocation(LatLng? newLocation) {
    if (_userLocation == null ||
        newLocation == null ||
        _userLocation!.latitude != newLocation.latitude ||
        _userLocation!.longitude != newLocation.longitude) {
      if (mounted) {
        setState(() {
          _userLocation = newLocation;
        });
      }
      if (_busLocation != null && _userLocation != null) {
        _updateDistance();
        _scheduleRouteUpdate();
        if (_busLocation != null && mapController != null) {
          _fitBounds();
        }
      }
    }
  }
  // --- End Location Getters and Setters ---

  @override
  void initState() {
    super.initState();
    _requestLocation();
    _etaText = "Calculating ETA...";
  }

  @override
  void dispose() {
    _routeTimer?.cancel();
    super.dispose();
  }

  /// Requests permission, reads an initial location, and then tracks updates.
  Future<void> _requestLocation() async {
    if (_requestingLocation) return;
    setState(() {
      _requestingLocation = true;
      _locationMessage = "Requesting location permission...";
    });

    try {
      var serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
      }
      if (!serviceEnabled) {
        throw Exception("Location service is disabled");
      }

      final permissionStatus = await location.requestPermission();
      if (permissionStatus != PermissionStatus.granted) {
        throw Exception("Location permission was denied");
      }

      final currentLocation = await location.getLocation();
      if (currentLocation.latitude != null &&
          currentLocation.longitude != null) {
        userLocation = LatLng(
          currentLocation.latitude!,
          currentLocation.longitude!,
        );
      }

      location.onLocationChanged.listen((locationData) {
        if (locationData.latitude != null && locationData.longitude != null) {
          userLocation = LatLng(
            locationData.latitude!,
            locationData.longitude!,
          );
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _locationMessage =
              "Location পাওয়া যায়নি। Permission allow করে Retry চাপুন।";
        });
      }
    } finally {
      if (mounted) setState(() => _requestingLocation = false);
    }
  }

  /// Haversine Formula: Calculates the straight-line distance (in kilometers)
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    var p = 0.017453292519943295;
    var c = cos;
    var a =
        0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  /// Updates the direct distance
  void _updateDistance() {
    if (busLocation != null && userLocation != null) {
      if (mounted) {
        setState(() {
          _distance = _calculateDistance(
            userLocation!.latitude,
            userLocation!.longitude,
            busLocation!.latitude,
            busLocation!.longitude,
          );
        });
      }
    }
  }

  /// Zooms the map to fit both the bus and student markers
  void _fitBounds() {
    if (mapController != null && busLocation != null && userLocation != null) {
      mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(
              min(busLocation!.latitude, userLocation!.latitude),
              min(busLocation!.longitude, userLocation!.longitude),
            ),
            northeast: LatLng(
              max(busLocation!.latitude, userLocation!.latitude),
              max(busLocation!.longitude, userLocation!.longitude),
            ),
          ),
          80, // Padding
        ),
      );
    }
  }

  /// Schedules route update with debounce
  void _scheduleRouteUpdate() {
    if (_routeTimer != null && _routeTimer!.isActive) _routeTimer!.cancel();
    _routeTimer = Timer(const Duration(seconds: 5), () => _getRoute());
  }

  /// Starts fetching the route using Driving mode
  Future<void> _getRoute() async {
    if (mounted) {
      setState(() {
        _etaText = "Calculating Route...";
      });
    }
    await _tryGetRoute("driving");
  }

  /// Fetches the route using Google Directions API
  Future<void> _tryGetRoute(String mode) async {
    if (userLocation == null ||
        busLocation == null ||
        googleApiKey.isEmpty ||
        googleApiKey == "YOUR_GOOGLE_DIRECTIONS_API_KEY") {
      if (mounted) setState(() => _etaText = "API Key Missing/Invalid");
      return;
    }

    final url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${userLocation!.latitude},${userLocation!.longitude}&destination=${busLocation!.latitude},${busLocation!.longitude}&mode=$mode&key=$googleApiKey";

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["routes"].isNotEmpty) {
          final route = data["routes"][0];
          final points = route["overview_polyline"]["points"];
          final legs = route["legs"][0];

          final decodedPolyline = _decodePolyline(points);

          if (mounted) {
            setState(() {
              _polylineCoordinates = decodedPolyline;
              _etaText =
                  "${legs["duration"]["text"]} (${mode == 'driving' ? 'Bus ETA' : 'Walk'})";
            });
          }
        } else {
          if (mode == "driving") {
            await _tryGetRoute("walking");
          } else {
            if (mounted) {
              setState(() {
                _etaText = "No route found";
                _polylineCoordinates = [];
              });
            }
          }
        }
      } else {
        debugPrint(
          "Google API Error: ${response.statusCode}, Body: ${response.body}",
        );
        if (mounted) {
          setState(() {
            _etaText = "API Error: Check Key/Quota";
            _polylineCoordinates = [];
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching route: $e");
      if (mounted) {
        setState(() {
          _etaText = "Connection Error";
          _polylineCoordinates = [];
        });
      }
    }
  }

  /// Decodes the Polyline string
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> polyline = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      polyline.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return polyline;
  }

  CameraPosition _getInitialCameraPosition() {
    return CameraPosition(
      target: busLocation ?? _defaultInitialLocation,
      zoom: 12,
    );
  }

  void _recenterMap() {
    final target = busLocation ?? userLocation;
    if (target != null && mapController != null) {
      mapController!.animateCamera(CameraUpdate.newLatLngZoom(target, 14));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              BusConstants.stationName(widget.busId),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const Text(
              'LIVE TRACKING',
              style: TextStyle(fontSize: 10, letterSpacing: 1.4),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Center map',
            onPressed: _recenterMap,
            icon: const Icon(Icons.my_location_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream:
                FirebaseFirestore.instance
                    .collection("buses")
                    .doc(widget.busId)
                    .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || userLocation == null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_requestingLocation)
                        const CircularProgressIndicator(),
                      const SizedBox(height: 10),
                      if (userLocation == null)
                        Text(_locationMessage, textAlign: TextAlign.center),
                      if (userLocation == null && !_requestingLocation)
                        TextButton.icon(
                          onPressed: _requestLocation,
                          icon: const Icon(Icons.my_location),
                          label: const Text("Retry Location"),
                        ),
                      if (!snapshot.hasData)
                        Text("Waiting for ${widget.busId} bus data..."),
                    ],
                  ),
                );
              }

              var data = snapshot.data!.data() as Map<String, dynamic>?;
              final bool hasLocation =
                  data != null &&
                  data.containsKey("latitude") &&
                  data.containsKey("longitude");
              final bool isExplicitlyOffline = data?["isOnline"] == false;

              if (isExplicitlyOffline || !hasLocation) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text(
                      "আজ ${BusConstants.stationName(widget.busId)} বন্ধ থাকবে।",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                );
              }

              if (hasLocation) {
                try {
                  final newBusLocation = LatLng(
                    (data["latitude"] as num).toDouble(),
                    (data["longitude"] as num).toDouble(),
                  );
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    busLocation = newBusLocation;
                  });
                } catch (e) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(
                        "Error: Bus location data type is incorrect in Firestore.",
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
              }

              if (busLocation == null || userLocation == null) {
                return const Center(
                  child: Text("Initializing map data... (Station Online)"),
                );
              }

              return GoogleMap(
                onMapCreated: (controller) {
                  mapController = controller;
                  _fitBounds();
                },
                initialCameraPosition: _getInitialCameraPosition(),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                compassEnabled: true,
                zoomControlsEnabled: false,
                markers: {
                  Marker(
                    markerId: const MarkerId("bus"),
                    position: busLocation!,
                    infoWindow: InfoWindow(title: "${widget.busId} Bus"),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueRed,
                    ),
                  ),
                  Marker(
                    markerId: const MarkerId("student"),
                    position: userLocation!,
                    infoWindow: const InfoWindow(title: "Your Location"),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueBlue,
                    ),
                  ),
                },
                polylines: {
                  if (_polylineCoordinates.isNotEmpty)
                    Polyline(
                      polylineId: const PolylineId("route"),
                      points: _polylineCoordinates,
                      color: Colors.blue,
                      width: 5,
                    ),
                },
              );
            },
          ),

          // Tracking summary overlay
          Positioned(
            top: 14,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surface.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.teal.shade700,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.directions_bus_filled,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _distance == null
                                ? 'Locating bus...'
                                : '${_distance!.toStringAsFixed(2)} km away',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _etaText == null
                                ? 'Calculating route'
                                : 'ETA  $_etaText',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color
                                  ?.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
