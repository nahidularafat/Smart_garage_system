import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // debugPrint ব্যবহারের জন্য
import 'package:location/location.dart';

class StudentController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String busId; // ✅ busId এখন constructor থেকে আসবে

  // ✅ কন্ট্রোলারের constructor, যা একটি busId গ্রহণ করে
  StudentController({required this.busId});

  // দূরত্ব গণনার সূত্র (অপরিবর্তিত)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  /// নির্দিষ্ট বাস থেকে ছাত্রের দূরত্ব কিলোমিটার এককে প্রদান করে।
  /// কোনো সমস্যা হলে null রিটার্ন করে।
  Future<double?> getDistanceFromBus() async {
    try {
      // ✅ "orders" এর পরিবর্তে "buses" কালেকশন ব্যবহার করা হয়েছে
      final doc = await _firestore.collection("buses").doc(busId).get();

      if (!doc.exists || doc.data() == null) {
        debugPrint("Error: Bus document for '$busId' does not exist.");
        return null;
      }

      final data = doc.data()!;
      if (data["latitude"] == null || data["longitude"] == null) {
        debugPrint("Error: Bus '$busId' is not broadcasting location data.");
        return null;
      }
      
      final double busLat = (data["latitude"] as num).toDouble();
      final double busLon = (data["longitude"] as num).toDouble();

      final Location location = Location();
      final myLoc = await location.getLocation();

      // ✅ নিজের লোকেশন পাওয়া গেছে কিনা তা পরীক্ষা করা হচ্ছে
      if (myLoc.latitude == null || myLoc.longitude == null) {
        debugPrint("Error: Could not get the student's current location.");
        return null;
      }

      return _calculateDistance(
        myLoc.latitude!,
        myLoc.longitude!,
        busLat,
        busLon,
      );
    } catch (e) {
      debugPrint("An unexpected error occurred in getDistanceFromBus: $e");
      return null;
    }
  }
}