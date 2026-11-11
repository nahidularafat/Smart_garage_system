// lib/home_page.dart (Standard & Professional Design)

import 'package:car_track/components/my_drawer.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'driver_controller.dart';
import 'map_page.dart';
import 'bus_constants.dart';
import 'smart_garage_page.dart';

class HomePage extends StatelessWidget {
  final String role;
  final String busId;

  HomePage({super.key, required this.role, required this.busId});

  @override
  Widget build(BuildContext context) {
    final stationName = BusConstants.stationName(busId);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.garage_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                role == "driver" ? stationName : "Smart Garage & Stations",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.directions_car_rounded, size: 24),
            tooltip: 'Smart Garage',
            onPressed: () => Get.to(() => const SmartGaragePage()),
          ),
        ],
      ),
      drawer: const MyDrawer(),
      body: Center(
        child:
            role == "driver" ? DriverView(busId: busId) : const StudentView(),
      ),
    );
  }
}

// ------------------- Driver View (Standard Design) -------------------
class DriverView extends StatelessWidget {
  final String busId;
  DriverView({super.key, required this.busId});

  @override
  Widget build(BuildContext context) {
    final DriverController driverController = Get.put(
      DriverController(busId),
      tag: busId,
    );

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Route Control for ${BusConstants.stationName(busId)}",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 50),
          StreamBuilder<DocumentSnapshot>(
            stream:
                FirebaseFirestore.instance
                    .collection("buses")
                    .doc(busId)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              bool isOnline =
                  (snapshot.data?.data()
                      as Map<String, dynamic>?)?["isOnline"] ??
                  false;

              return Column(
                children: [
                  Icon(
                    Icons.bus_alert_rounded,
                    size: 80,
                    color:
                        isOnline ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isOnline
                        ? "Station is currently ONLINE"
                        : "Station is currently OFFLINE",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color:
                          isOnline
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (isOnline)
                    Obx(
                      () => Column(
                        children: [
                          Text(
                            "Auto-stop in:",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          Text(
                            driverController.remainingTime.value,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 30),

                  // ✅ স্ট্যান্ডার্ড ElevatedButton ব্যবহার করা হয়েছে
                  if (isOnline)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.stop),
                        label: const Text(
                          "Stop",
                          style: TextStyle(fontSize: 18),
                        ),
                        onPressed: driverController.stopTravel,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: const Text(
                          "Start",
                          style: TextStyle(fontSize: 18),
                        ),
                        onPressed: driverController.startTravel,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ------------------- Student View (Standard Design) -------------------
class StudentView extends StatelessWidget {
  const StudentView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // ── Smart Garage Quick Access Card (with Car Icon) ──
        Card(
          elevation: 4,
          margin: const EdgeInsets.only(bottom: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Get.to(() => const SmartGaragePage()),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E1E42), Color(0xFF101026)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF00E5CC).withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5CC).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.directions_car_rounded, color: Color(0xFF00E5CC), size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SMART GARAGE SYSTEM',
                          style: TextStyle(
                            color: Color(0xFF00E5CC),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'RFID card balance, parking slots & live camera',
                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF00E5CC), size: 16),
                ],
              ),
            ),
          ),
        ),

        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'Bus Stations',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),

        ...BusConstants.allBusNames.map((busName) => BusStatusCard(busName: busName)),
      ],
    );
  }
}

// ------------------- Bus Status Card (Standard Design) -------------------
class BusStatusCard extends StatelessWidget {
  final String busName;
  const BusStatusCard({super.key, required this.busName});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: StreamBuilder<DocumentSnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection("buses")
                .doc(busName)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ListTile(title: Text("Loading..."));
          }
          bool isOnline =
              (snapshot.data?.data() as Map<String, dynamic>?)?['isOnline'] ??
              false;

          // ✅ স্ট্যান্ডার্ড ListTile ডিজাইন
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              vertical: 10,
              horizontal: 20,
            ),
            leading: Icon(
              Icons.directions_bus,
              color: isOnline ? Colors.green.shade600 : Colors.grey.shade500,
              size: 40,
            ),
            title: Text(
              BusConstants.stationName(busName),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              isOnline ? "Station Online" : "Station Offline",
              style: TextStyle(
                color: isOnline ? Colors.green.shade700 : Colors.red.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: Icon(
              Icons.arrow_forward_ios,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
            ),
            onTap:
                () => Get.to(
                  () => MapPage(
                    busId: busName,
                    title: "${BusConstants.stationName(busName)} Tracking",
                  ),
                ),
            tileColor: isOnline ? Colors.green.withOpacity(0.05) : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          );
        },
      ),
    );
  }
}
