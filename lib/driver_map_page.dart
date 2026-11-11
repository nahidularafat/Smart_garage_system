// lib/driver_map_page.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

class DriverMapPage extends StatefulWidget {
  final String busId;
  const DriverMapPage({super.key, required this.busId});

  @override
  State<DriverMapPage> createState() => _DriverMapPageState();
}

class _DriverMapPageState extends State<DriverMapPage> {
  GoogleMapController? _mapController;
  final Location _location = Location();
  bool _isOnline = false;

  StreamSubscription<LocationData>? _locationSubscription;
  StreamSubscription<DocumentSnapshot>? _busStatusSubscription;

  @override
  void initState() {
    super.initState();
    _listenToBusStatus();
    _trackDriverLocation();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _busStatusSubscription?.cancel();
    super.dispose();
  }

  void _listenToBusStatus() {
    _busStatusSubscription = FirebaseFirestore.instance
        .collection('buses')
        .doc(widget.busId)
        .snapshots()
        .listen((snapshot) {
      if (mounted && snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        setState(() {
          _isOnline = data['isOnline'] ?? false;
        });
      }
    });
  }

  void _trackDriverLocation() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return;
    }

    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    _locationSubscription = _location.onLocationChanged.listen((currentLocation) {
      if (currentLocation.latitude != null && currentLocation.longitude != null) {
        if (mounted) {
          final newLocation = LatLng(currentLocation.latitude!, currentLocation.longitude!);
          _mapController?.animateCamera(CameraUpdate.newLatLng(newLocation));
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Current Location')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: LatLng(23.8759, 90.3795), zoom: 14), // BUBT Permanent Campus
            onMapCreated: (controller) => _mapController = controller,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          if (!_isOnline)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.power_off, color: Colors.yellow.shade700, size: 60),
                      const SizedBox(height: 20),
                      const Text(
                        'Please go ONLINE from the Home screen to view the map.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
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