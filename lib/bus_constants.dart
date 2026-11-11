// bus_constants.dart

class BusConstants {
  // আপনার ৫টি বাসের নাম এখানে যোগ করা হয়েছে। Firestore-এ এই নামেই ডকুমেন্ট তৈরি হবে।
  static const List<String> allBusNames = [
    'Padma',
    'Meghna',
    'Jamuna',
    'Buriganga',
    'Shitalakhya',
  ];

  static String stationName(String busName) => '$busName Station';

  // ড্রাইভারের ইমেল থেকে বাসের নাম খুঁজে বের করার লজিক (@bubt.com এবং @bubt.edu.bd দুটোই সাপোর্ট করে)
  static String? getBusNameFromEmail(String email) {
    final normalizedEmail = email.trim().toLowerCase();
    for (var busName in allBusNames) {
      if (normalizedEmail.startsWith(busName.toLowerCase()) &&
          (normalizedEmail.endsWith("@bubt.com") ||
           normalizedEmail.endsWith("@bubt.edu.bd"))) {
        return busName;
      }
    }
    return null;
  }
}
