// my_order.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class MyOrder {
  String? id;
  double? latitude;
  double? longitude;
  bool isOnline;
  DateTime? lastUpdated;

  MyOrder({
    this.id,
    this.latitude,
    this.longitude,
    this.isOnline = false,
    this.lastUpdated,
  });

  // Firestore থেকে ডেটা পড়ার জন্য
  factory MyOrder.fromJson(Map<String, dynamic> json) => MyOrder(
        id: json["id"],
        // Firestore-এ num হিসেবে থাকতে পারে, তাই .toDouble() ব্যবহার করা হয়েছে।
        latitude: (json["latitude"] as num?)?.toDouble(),
        longitude: (json["longitude"] as num?)?.toDouble(),
        isOnline: json["isOnline"] ?? false,
        // Firestore Timestamp object থেকে Dart DateTime-এ কনভার্ট করা হয়েছে।
        lastUpdated: (json["lastUpdated"] as Timestamp?)?.toDate(),
      );

  // Firestore-এ ডেটা লেখার জন্য
  Map<String, dynamic> toJson() => {
        "id": id,
        "latitude": latitude,
        "longitude": longitude,
        "isOnline": isOnline,
        // 'lastUpdated' ফিল্ডটি DriverController দ্বারা FieldValue.serverTimestamp() দিয়ে আপডেট হবে।
      };
}