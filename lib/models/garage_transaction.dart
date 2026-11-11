/// A parking transaction (ENTRY or EXIT) stored in Firebase RTDB.
/// Path: /garage/transactions/{pushId}
class GarageTransaction {
  final String id;
  final String uid;
  final String type; // 'ENTRY' | 'EXIT'
  final int epochTime;
  final int fare;     // BDT paid (0 for entry)
  final int duration; // minutes (0 for entry)
  final int balanceAfter;

  const GarageTransaction({
    required this.id,
    required this.uid,
    required this.type,
    required this.epochTime,
    required this.fare,
    required this.duration,
    required this.balanceAfter,
  });

  bool get isEntry => type == 'ENTRY';
  bool get isExit  => type == 'EXIT';

  DateTime get dateTime =>
      DateTime.fromMillisecondsSinceEpoch(epochTime * 1000).toLocal();

  String get shortUid =>
      uid.length > 11 ? '${uid.substring(0, 11)}...' : uid;

  factory GarageTransaction.fromMap(String id, Map<dynamic, dynamic> map) {
    return GarageTransaction(
      id: id,
      uid: (map['uid'] as String?) ?? '',
      type: (map['type'] as String?) ?? 'ENTRY',
      epochTime: (map['epochTime'] as num?)?.toInt() ?? 0,
      fare: (map['fare'] as num?)?.toInt() ?? 0,
      duration: (map['duration'] as num?)?.toInt() ?? 0,
      balanceAfter: (map['balanceAfter'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'type': type,
    'epochTime': epochTime,
    'fare': fare,
    'duration': duration,
    'balanceAfter': balanceAfter,
  };
}
