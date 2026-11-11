// GarageRtdbService — full Firebase RTDB service for Smart Garage V3
// Paths mirror the ESP32 firmware exactly.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/garage_user.dart';
import '../models/garage_transaction.dart';

// ── Slot snapshot ─────────────────────────────────────────────────────────────
class SlotStatus {
  final String slot1, slot2, slot3, slot4;
  const SlotStatus({
    required this.slot1, required this.slot2,
    required this.slot3, required this.slot4,
  });
  int get availableCount =>
      [slot1, slot2, slot3, slot4].where((s) => s == 'Empty').length;
  bool get isFull => availableCount == 0;
  String statusOf(int idx) {
    switch (idx) {
      case 1: return slot1; case 2: return slot2;
      case 3: return slot3; case 4: return slot4;
      default: return 'Unknown';
    }
  }
}

class GarageRtdbService {
  static const String databaseUrl =
      'https://live-tracking-2fb1c-default-rtdb.firebaseio.com';
  static const String dbSecret =
      'pFhLbvWkUMgkx0zZByHtBEi5HR1SEDzDfOHMYUqR';

  static final FirebaseDatabase _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: databaseUrl,
  );

  static DatabaseReference get _ref => _db.ref('garage');

  // ── Connection status stream (.info/connected) ───────────────────────────
  static Stream<bool> connectionStream() =>
      _db.ref('.info/connected').onValue.map((e) => (e.snapshot.value as bool?) ?? false);

  // ── ESP32 Pin → Slot Mapping (আপনার হার্ডওয়্যার অনুযায়ী) ──────────────
  // Pin 14 (SLOT1_IR) → slot1  |  Pin 27 (SLOT2_IR) → slot2
  // Pin 26 (SLOT3_IR) → slot3  |  Pin 25 (SLOT4_IR) → slot4
  // ESP32 লজিক: IR LOW = "Full" (গাড়ি আছে), IR HIGH = "Empty" (ফাঁকা)

  static String _normalizeSlot(dynamic raw) {
    if (raw == null) return 'Empty';
    if (raw is bool) return raw ? 'Full' : 'Empty';
    if (raw is num) return raw == 0 ? 'Empty' : 'Full';
    final s = raw.toString().trim();
    if (s.toLowerCase() == 'full' || s.toLowerCase() == 'occupied' || s == '1') {
      return 'Full';
    }
    return 'Empty';
  }

  // ── Slots stream ─────────────────────────────────────────────────────────
  static Stream<SlotStatus> slotsStream() =>
      _ref.child('slots').onValue.map((e) {
        final val = e.snapshot.value;
        Map<dynamic, dynamic> d = {};
        if (val is Map) {
          d = val;
        } else if (val is List) {
          for (int i = 0; i < val.length; i++) {
            d['slot$i'] = val[i];
          }
        }
        final slot3raw = _normalizeSlot(d['slot3']);
        return SlotStatus(
          slot1: _normalizeSlot(d['slot1']),                    // Pin 14 — ঠিক আছে
          slot2: _normalizeSlot(d['slot2']),                    // Pin 27 — ঠিক আছে
          slot3: slot3raw == 'Full' ? 'Empty' : 'Full',        // Pin 26 — উল্টা সেন্সর ফিক্স
          slot4: _normalizeSlot(d['slot4']),                    // Pin 25 — ঠিক আছে
        );
      });

  // ── Reset all slots to Empty (stale data ক্লিয়ার করতে) ─────────────────
  static Future<bool> resetAllSlots() async {
    try {
      await _ref.child('slots').set({
        'slot1': 'Empty',
        'slot2': 'Empty',
        'slot3': 'Empty',
        'slot4': 'Empty',
      });
      return true;
    } catch (_) { return false; }
  }

  // ── Gate status streams (Entry + Exit আলাদা) ─────────────────────────────
  static Stream<String> entryGateStatusStream() =>
      _ref.child('entryGateStatus').onValue.map(
          (e) => (e.snapshot.value as String?) ?? 'closed');

  static Stream<String> exitGateStatusStream() =>
      _ref.child('exitGateStatus').onValue.map(
          (e) => (e.snapshot.value as String?) ?? 'closed');

  // পুরোনো single gate stream (backward compatible)
  static Stream<String> gateStatusStream() => entryGateStatusStream();

  // ── Users stream ─────────────────────────────────────────────────────────
  static Stream<List<GarageUser>> usersStream() =>
      _ref.child('users').onValue.map((e) {
        final d = e.snapshot.value as Map<dynamic, dynamic>?;
        if (d == null) return [];
        return d.entries.map((entry) {
          return GarageUser.fromMap(
            entry.key as String,
            entry.value as Map<dynamic, dynamic>? ?? {},
          );
        }).toList()
          ..sort((a, b) {
            if (a.isInside && !b.isInside) return -1;
            if (!a.isInside && b.isInside) return 1;
            return a.uid.compareTo(b.uid);
          });
      });

  // ── Single user ──────────────────────────────────────────────────────────
  static Future<GarageUser?> getUser(String uid) async {
    // 1. Try Firebase SDK
    try {
      final snap = await _ref.child('users/$uid').get().timeout(const Duration(seconds: 3));
      if (snap.exists && snap.value != null) {
        return GarageUser.fromMap(uid, snap.value as Map<dynamic, dynamic>? ?? {});
      }
    } catch (e) {
      debugPrint('⚠️ Firebase SDK getUser failed: $e. Using REST fallback...');
    }

    // 2. Direct REST fallback
    try {
      final url = Uri.parse('$databaseUrl/garage/users/$uid.json?auth=$dbSecret');
      final resp = await http.get(url).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200 && resp.body.isNotEmpty && resp.body != 'null') {
        final data = jsonDecode(resp.body) as Map<String, dynamic>?;
        if (data != null) {
          return GarageUser.fromMap(uid, data);
        }
      }
    } catch (e) {
      debugPrint('🔴 REST getUser failed: $e');
    }
    return null;
  }

  // ── Top-up balance ───────────────────────────────────────────────────────
  static Future<bool> topUpBalance(String uid, int amount) async {
    try {
      final ref = _ref.child('users/$uid/balance');
      final result = await ref.runTransaction((currentValue) {
        final cur = (currentValue as num?)?.toInt() ?? 0;
        return Transaction.success(cur + amount);
      }).timeout(const Duration(seconds: 3));
      if (result.committed) return true;
    } catch (_) {}

    // Fallback REST
    try {
      final user = await getUser(uid);
      final newBal = (user?.balance ?? 0) + amount;
      final url = Uri.parse('$databaseUrl/garage/users/$uid.json?auth=$dbSecret');
      final resp = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'balance': newBal}),
      ).timeout(const Duration(seconds: 4));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Set balance directly ─────────────────────────────────────────────────
  static Future<bool> setBalance(String uid, int newBalance) async {
    try {
      await _ref.child('users/$uid/balance').set(newBalance).timeout(const Duration(seconds: 3));
      return true;
    } catch (_) {}

    try {
      final url = Uri.parse('$databaseUrl/garage/users/$uid.json?auth=$dbSecret');
      final resp = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'balance': newBalance}),
      ).timeout(const Duration(seconds: 4));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Reset card to OUT (স্ট্যাটাস রিসেট বা জোরপূর্বক বের করা) ───────────
  static Future<bool> resetCardToOut(String uid) async {
    final now = DateTime.now();
    final timeStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final updates = {
      'status': 'OUT',
      'entryEpoch': null,
      'entryTime': null,
      'exitTime': timeStr,
      'lastFare': 0,
    };

    try {
      await _ref.child('users/$uid').update(updates).timeout(const Duration(seconds: 3));
      return true;
    } catch (_) {}

    try {
      final url = Uri.parse('$databaseUrl/garage/users/$uid.json?auth=$dbSecret');
      final resp = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(updates),
      ).timeout(const Duration(seconds: 4));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Register new card ────────────────────────────────────────────────────
  static Future<bool> registerUser(
    String uid, {
    int initialBalance = 200,
    String? ownerEmail,
    String? ownerName,
  }) async {
    final data = <String, dynamic>{
      'balance': initialBalance,
      'status': 'OUT',
    };
    if (ownerEmail != null && ownerEmail.isNotEmpty) {
      data['ownerEmail'] = ownerEmail.trim().toLowerCase();
    }
    if (ownerName != null && ownerName.isNotEmpty) {
      data['ownerName'] = ownerName.trim();
    }

    try {
      await _ref.child('users/$uid').set(data).timeout(const Duration(seconds: 3));
      return true;
    } catch (e) {
      debugPrint('⚠️ Firebase SDK registerUser failed: $e. Using REST fallback...');
    }

    try {
      final url = Uri.parse('$databaseUrl/garage/users/$uid.json?auth=$dbSecret');
      final resp = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 4));
      return resp.statusCode == 200;
    } catch (e) {
      debugPrint('🔴 REST registerUser failed: $e');
      return false;
    }
  }

  // ── Link card to user ──────────────────────────────────────────────────
  static Future<bool> linkCardToUser({
    required String uid,
    required String ownerEmail,
    String? ownerName,
  }) async {
    final updates = <String, dynamic>{
      'ownerEmail': ownerEmail.trim().toLowerCase(),
    };
    if (ownerName != null && ownerName.isNotEmpty) {
      updates['ownerName'] = ownerName.trim();
    }

    try {
      await _ref.child('users/$uid').update(updates).timeout(const Duration(seconds: 3));
      return true;
    } catch (e) {
      debugPrint('⚠️ Firebase SDK linkCardToUser failed: $e. Using REST fallback...');
    }

    try {
      final url = Uri.parse('$databaseUrl/garage/users/$uid.json?auth=$dbSecret');
      final resp = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(updates),
      ).timeout(const Duration(seconds: 4));
      return resp.statusCode == 200;
    } catch (e) {
      debugPrint('🔴 REST linkCardToUser failed: $e');
      return false;
    }
  }

  // ── Unlink card from user ──────────────────────────────────────────────
  static Future<bool> unlinkCard(String uid) async {
    final updates = <String, dynamic>{
      'ownerEmail': null,
      'ownerName': null,
    };

    try {
      await _ref.child('users/$uid').update(updates).timeout(const Duration(seconds: 3));
      return true;
    } catch (_) {}

    try {
      final url = Uri.parse('$databaseUrl/garage/users/$uid.json?auth=$dbSecret');
      final resp = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(updates),
      ).timeout(const Duration(seconds: 4));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Admin management ──────────────────────────────────────────────────
  static String _safeEmailKey(String email) =>
      email.replaceAll('.', '_').replaceAll('@', '_at_').trim().toLowerCase();

  static Stream<List<String>> adminsStream() =>
      _ref.child('admins').onValue.map((e) {
        final val = e.snapshot.value;
        if (val is Map) {
          return val.values.map((v) => v.toString().trim().toLowerCase()).toList();
        }
        return <String>[];
      });

  static Future<bool> addAdmin(String email) async {
    final clean = email.trim().toLowerCase();
    try {
      await _ref.child('admins/${_safeEmailKey(clean)}').set(clean).timeout(const Duration(seconds: 3));
      return true;
    } catch (_) {}
    try {
      final url = Uri.parse('$databaseUrl/garage/admins/${_safeEmailKey(clean)}.json?auth=$dbSecret');
      final resp = await http.put(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode(clean));
      return resp.statusCode == 200;
    } catch (_) { return false; }
  }

  static Future<bool> removeAdmin(String email) async {
    final clean = email.trim().toLowerCase();
    try {
      await _ref.child('admins/${_safeEmailKey(clean)}').remove().timeout(const Duration(seconds: 3));
      return true;
    } catch (_) {}
    try {
      final url = Uri.parse('$databaseUrl/garage/admins/${_safeEmailKey(clean)}.json?auth=$dbSecret');
      final resp = await http.delete(url);
      return resp.statusCode == 200;
    } catch (_) { return false; }
  }

  // ── Delete card ──────────────────────────────────────────────────────────
  static Future<bool> deleteUser(String uid) async {
    try {
      await _ref.child('users/$uid').remove().timeout(const Duration(seconds: 3));
      return true;
    } catch (_) {}
    try {
      final url = Uri.parse('$databaseUrl/garage/users/$uid.json?auth=$dbSecret');
      final resp = await http.delete(url);
      return resp.statusCode == 200;
    } catch (_) { return false; }
  }

  // ── Gate commands (Entry / Exit আলাদা) ───────────────────────────────────
  static Future<bool> sendEntryGateCommand() async {
    try { await _ref.child('command').set('open_entry_gate').timeout(const Duration(seconds: 3)); return true; }
    catch (_) {}
    try {
      final url = Uri.parse('$databaseUrl/garage.json?auth=$dbSecret');
      final resp = await http.patch(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'command': 'open_entry_gate'}));
      return resp.statusCode == 200;
    } catch (_) { return false; }
  }

  static Future<bool> sendCloseEntryGateCommand() async {
    try { await _ref.child('command').set('close_entry_gate').timeout(const Duration(seconds: 3)); return true; }
    catch (_) {}
    try {
      final url = Uri.parse('$databaseUrl/garage.json?auth=$dbSecret');
      final resp = await http.patch(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'command': 'close_entry_gate'}));
      return resp.statusCode == 200;
    } catch (_) { return false; }
  }

  static Future<bool> sendExitGateCommand() async {
    try { await _ref.child('command').set('open_exit_gate').timeout(const Duration(seconds: 3)); return true; }
    catch (_) {}
    try {
      final url = Uri.parse('$databaseUrl/garage.json?auth=$dbSecret');
      final resp = await http.patch(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'command': 'open_exit_gate'}));
      return resp.statusCode == 200;
    } catch (_) { return false; }
  }

  static Future<bool> sendCloseExitGateCommand() async {
    try { await _ref.child('command').set('close_exit_gate').timeout(const Duration(seconds: 3)); return true; }
    catch (_) {}
    try {
      final url = Uri.parse('$databaseUrl/garage.json?auth=$dbSecret');
      final resp = await http.patch(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'command': 'close_exit_gate'}));
      return resp.statusCode == 200;
    } catch (_) { return false; }
  }

  // পুরোনো method (backward compatible)
  static Future<bool> sendGateCommand(String command) async {
    try { await _ref.child('command').set(command); return true; }
    catch (_) { return false; }
  }

  // ── Log a transaction ────────────────────────────────────────────────────
  static Future<void> logTransaction({
    required String uid, required String type,
    required int fare, required int duration, required int balanceAfter,
  }) async {
    try {
      final epoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _ref.child('transactions').push().set({
        'uid': uid, 'type': type, 'epochTime': epoch,
        'fare': fare, 'duration': duration, 'balanceAfter': balanceAfter,
      });
    } catch (_) {}
  }

  // ── Transactions stream ──────────────────────────────────────────────────
  static Stream<List<GarageTransaction>> transactionsStream() =>
      _ref.child('transactions').onValue.map((e) {
        final d = e.snapshot.value as Map<dynamic, dynamic>?;
        if (d == null) return <GarageTransaction>[];
        final list = d.entries.map((entry) => GarageTransaction.fromMap(
          entry.key as String, entry.value as Map<dynamic, dynamic>? ?? {})).toList();
        list.sort((a, b) => b.epochTime.compareTo(a.epochTime));
        return list;
      });

  // ── Settings ─────────────────────────────────────────────────────────────
  static const defaultSettings = {
    'rate_per_minute': 2, 'min_balance': 10,
    'welcome_bonus': 200, 'auto_close_delay': 3,
  };

  static Future<Map<String, dynamic>> getSettings() async {
    try {
      final snap = await _ref.child('settings').get();
      if (!snap.exists) return Map.from(defaultSettings);
      return Map<String, dynamic>.from(snap.value as Map? ?? {});
    } catch (_) { return Map.from(defaultSettings); }
  }

  static Future<void> updateSetting(String key, dynamic value) async {
    try { await _ref.child('settings/$key').set(value); } catch (_) {}
  }
}
