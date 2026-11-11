import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class NotificationController extends GetxController {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> initNotifications() async {
    try {
      await _fcm.requestPermission();
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification != null) {
          Get.snackbar(
            message.notification!.title ?? 'Notification',
            message.notification!.body ?? '',
            snackPosition: SnackPosition.TOP,
          );
        }
      });
    } catch (e) {
      debugPrint("FCM requestPermission non-fatal error: $e");
    }
  }

  Future<void> subscribeToBus(String busName) async {
    try {
      await _fcm.subscribeToTopic(busName.toLowerCase());
      debugPrint('Subscribed to ${busName.toLowerCase()}');
    } catch (_) {}
  }

  Future<void> unsubscribeFromBus(String busName) async {
    try {
      await _fcm.unsubscribeFromTopic(busName.toLowerCase());
      debugPrint('Unsubscribed from ${busName.toLowerCase()}');
    } catch (_) {}
  }
}
