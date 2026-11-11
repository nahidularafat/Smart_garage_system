// lib/driver_controller.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:location/location.dart';
import 'bus_constants.dart';

class DriverController extends GetxController {
  final String busId;
  late DocumentReference _busDocRef;
  StreamSubscription<LocationData>? _locationSubscription;
  final Location _location = Location();

  // টাইমারের জন্য ভ্যারিয়েবল
  Timer? _autoStopTimer;
  final RxString remainingTime = "16:00:00".obs;

  final int _totalDurationInSeconds = const Duration(hours: 16).inSeconds;

  DriverController(this.busId);

  @override
  void onInit() {
    super.onInit();
    _busDocRef = FirebaseFirestore.instance.collection("buses").doc(busId);
    remainingTime.value = _formatDuration(_totalDurationInSeconds);
  }

  // সময়কে HH:MM:SS ফরম্যাটে দেখানোর জন্য ফাংশন
  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final secs = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$secs";
  }

  // অটো-স্টপ টাইমার চালু করার ফাংশন
  void _startAutoStopTimer() {
    _autoStopTimer?.cancel();
    int secondsRemaining = _totalDurationInSeconds;
    remainingTime.value = _formatDuration(secondsRemaining);

    _autoStopTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (secondsRemaining > 0) {
        secondsRemaining--;
        remainingTime.value = _formatDuration(secondsRemaining);
      } else {
        Get.snackbar(
          "Time's Up!",
          "Travel automatically stopped.",
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        stopTravel();
        timer.cancel();
      }
    });
  }

  // startTravel ফাংশন
  Future<void> startTravel() async {
    try {
      // পারমিশন চেক করার কোড
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

      await _busDocRef.set({
        "isOnline": true,
        "lastUpdated": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _locationSubscription = _location.onLocationChanged.listen((
        locationData,
      ) {
        if (locationData.latitude != null && locationData.longitude != null) {
          _updateLocation(locationData.latitude!, locationData.longitude!);
        }
      });
      _startAutoStopTimer();

      // নোটিফিকেশন পাঠানোর জন্য Cloud Function ট্রিগার করা হচ্ছে
      await FirebaseFirestore.instance.collection("notifications").add({
        "busName": busId,
        "timestamp": FieldValue.serverTimestamp(),
      });

      Get.snackbar(
        "Online",
        "${BusConstants.stationName(busId)} tracking has started.",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar("Error", "Could not start travel. Please try again.");
      print("Start Travel Error: $e");
    }
  }

  Future<void> _updateLocation(double lat, double lng) async {
    try {
      await _busDocRef.update({
        "latitude": lat,
        "longitude": lng,
        "lastUpdated": FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Location Update Error: $e");
    }
  }

  Future<void> stopTravel() async {
    _autoStopTimer?.cancel();
    remainingTime.value = _formatDuration(_totalDurationInSeconds);

    await _locationSubscription?.cancel();
    _locationSubscription = null;

    await _busDocRef.update({
      "isOnline": false,
      "latitude": FieldValue.delete(),
      "longitude": FieldValue.delete(),
      "lastUpdated": FieldValue.serverTimestamp(),
    });

    Get.snackbar(
      "Resting",
      "${BusConstants.stationName(busId)} tracking has stopped.",
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
  }

  @override
  void onClose() {
    _locationSubscription?.cancel();
    _autoStopTimer?.cancel();
    super.onClose();
  }
}
