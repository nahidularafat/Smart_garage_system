/// Model for a prepaid RFID user stored in Firebase RTDB
/// Path: /garage/users/{uid}/
class GarageUser {
  final String uid;
  final int balance;
  final String status; // "IN" or "OUT"
  final int? entryEpoch;
  final String? entryTime;
  final String? exitTime;
  final int? lastFare;
  final String? ownerEmail;
  final String? ownerName;

  const GarageUser({
    required this.uid,
    required this.balance,
    required this.status,
    this.entryEpoch,
    this.entryTime,
    this.exitTime,
    this.lastFare,
    this.ownerEmail,
    this.ownerName,
  });

  bool get isInside => status == 'IN';
  bool get hasOwner => ownerEmail != null && ownerEmail!.trim().isNotEmpty;

  bool isOwnedBy(String? email) {
    if (email == null || email.isEmpty) return false;
    return ownerEmail?.trim().toLowerCase() == email.trim().toLowerCase();
  }

  Duration get parkedDuration {
    if (!isInside || entryEpoch == null) return Duration.zero;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final diff = now - entryEpoch!;
    return Duration(seconds: diff < 0 ? 0 : diff);
  }

  int get estimatedFare {
    final minutes = parkedDuration.inMinutes < 1 ? 1 : parkedDuration.inMinutes;
    return minutes * 2;
  }

  static int _toInt(dynamic val, [int fallback = 0]) {
    if (val == null) return fallback;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val.trim()) ?? fallback;
    if (val is bool) return val ? 1 : 0;
    return fallback;
  }

  factory GarageUser.fromMap(String uid, Map<dynamic, dynamic> map) {
    return GarageUser(
      uid: uid,
      balance: _toInt(map['balance']),
      status: (map['status']?.toString()) ?? 'OUT',
      entryEpoch: map['entryEpoch'] != null ? _toInt(map['entryEpoch']) : null,
      entryTime: map['entryTime']?.toString(),
      exitTime: map['exitTime']?.toString(),
      lastFare: map['lastFare'] != null ? _toInt(map['lastFare']) : null,
      ownerEmail: map['ownerEmail']?.toString(),
      ownerName: map['ownerName']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'balance': balance,
        'status': status,
        if (entryEpoch != null) 'entryEpoch': entryEpoch,
        if (entryTime != null) 'entryTime': entryTime,
        if (exitTime != null) 'exitTime': exitTime,
        if (lastFare != null) 'lastFare': lastFare,
        if (ownerEmail != null) 'ownerEmail': ownerEmail,
        if (ownerName != null) 'ownerName': ownerName,
      };

  GarageUser copyWith({
    String? uid,
    int? balance,
    String? status,
    int? entryEpoch,
    String? entryTime,
    String? exitTime,
    int? lastFare,
    String? ownerEmail,
    String? ownerName,
  }) {
    return GarageUser(
      uid: uid ?? this.uid,
      balance: balance ?? this.balance,
      status: status ?? this.status,
      entryEpoch: entryEpoch ?? this.entryEpoch,
      entryTime: entryTime ?? this.entryTime,
      exitTime: exitTime ?? this.exitTime,
      lastFare: lastFare ?? this.lastFare,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      ownerName: ownerName ?? this.ownerName,
    );
  }
}
