import 'package:car_track/home_page.dart';
import 'package:car_track/login_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'bus_constants.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  // ইমেল থেকে রোল এবং বাস আইডি বের করার লজিক
  Map<String, String> _getRoleAndBusId(String email) {
    final busName = BusConstants.getBusNameFromEmail(email);
    if (busName != null) {
      return {"role": "driver", "busId": busName};
    }
    return {"role": "student", "busId": ""};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(
        // এই Streamটি ব্যবহারকারীর লগইন অবস্থার পরিবর্তন ট্র্যাক করে
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // ডেটা লোড হওয়ার সময় লোডিং ইনডিকেটর দেখানো
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // ব্যবহারকারী লগইন করা নেই
          if (!snapshot.hasData) {
            return LoginPage();
          }

          // ব্যবহারকারী লগইন করা আছেন, তাকে HomePage-এ পাঠানো হবে
          final user = snapshot.data!;
          final email = user.email ?? "";
          final authData = _getRoleAndBusId(email);
          final role = authData["role"]!;
          final busId = authData["busId"]!;

          return HomePage(role: role, busId: busId);
        },
      ),
    );
  }
}