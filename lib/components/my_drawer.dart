// lib/components/my_drawer.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// ফোল্ডার থেকে এক ধাপ বাইরে যাওয়ার জন্য '../' ব্যবহার করা হয়েছে
import '../driver_map_page.dart';
import '../auth_gate.dart';
import '../login_page.dart';
import '../settings_pages.dart';
import '../bus_constants.dart';
import '../smart_garage_page.dart';

class MyDrawer extends StatelessWidget {
  const MyDrawer({super.key});

  void _signOut() async {
    await FirebaseAuth.instance.signOut();
    Get.offAll(() => const AuthGate());
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    final String email = currentUser?.email ?? "guest@example.com";
    final String? busId = BusConstants.getBusNameFromEmail(email);
    final String userLabel =
        busId != null ? BusConstants.stationName(busId) : "Bus Stations";

    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade800, Colors.blue.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.directions_bus, color: Colors.white, size: 40),
                const SizedBox(height: 15),
                const Text(
                  'SMART GARAGE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  userLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                Text(
                  email,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  title: "H O M E",
                  icon: Icons.home_outlined,
                  onTap: () => Get.back(),
                ),
                _buildDrawerItem(
                  title: "SMART GARAGE",
                  icon: Icons.garage_outlined,
                  onTap: () {
                    Get.back();
                    Get.to(() => const SmartGaragePage());
                  },
                ),
                if (busId != null)
                  _buildDrawerItem(
                    title: "VIEW MY LOCATION",
                    icon: Icons.my_location,
                    onTap: () {
                      Get.back();
                      Get.to(() => DriverMapPage(busId: busId));
                    },
                  ),
                _buildDrawerItem(
                  title: "S E T T I N G S",
                  icon: Icons.settings_outlined,
                  onTap: () {
                    Get.back();
                    Get.to(() => const SettingsPage());
                  },
                ),
              ],
            ),
          ),
          const Divider(thickness: 1, color: Colors.grey),
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 8.0,
              horizontal: 16.0,
            ),
            child: _buildDrawerItem(
              title: "L O G O U T",
              icon: Icons.logout_outlined,
              onTap: _signOut,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue.shade700),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade800,
        ),
      ),
      onTap: onTap,
      splashColor: Colors.blue.withOpacity(0.2),
    );
  }
}
