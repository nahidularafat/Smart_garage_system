// main.dart (Safe Non-Blocking Initialization)

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:car_track/notification_controller.dart';
import 'auth_gate.dart';
import 'firebase_options.dart';
import 'themes/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Firebase Initialization with safe fallback
  try {
    await Firebase.initializeApp(options: firebaseOptions);
  } catch (e) {
    debugPrint("Firebase init with options error (handled): $e");
    try {
      // If already initialized by google-services on Android
      await Firebase.initializeApp();
    } catch (_) {}
  }

  // 2. Load theme safely
  bool isDarkMode = false;
  try {
    isDarkMode = await loadThemeFromPrefs();
  } catch (e) {
    debugPrint("Theme load error: $e");
  }

  // 3. Launch App UI IMMEDIATELY to dismiss Flutter splash logo
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(isDarkMode),
      child: const MyApp(),
    ),
  );

  // 4. Initialize FCM notifications asynchronously in background without blocking UI
  WidgetsBinding.instance.addPostFrameCallback((_) {
    try {
      final notificationController = Get.put(NotificationController());
      notificationController.initNotifications().catchError((e) {
        debugPrint("FCM notification error (non-fatal): $e");
      });
    } catch (e) {
      debugPrint("NotificationController error: $e");
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Garage',
      theme: themeProvider.themeData,
      home: const AuthGate(),
    );
  }
}
