import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../bus_constants.dart';
import '../models/garage_user.dart';
import 'garage_rtdb_service.dart';

class GarageAuthService {
  static final GarageAuthService _instance = GarageAuthService._internal();
  factory GarageAuthService() => _instance;
  GarageAuthService._internal();

  static const String _prefAdminOverride = 'garage_admin_preview_user';

  // State
  static final ValueNotifier<bool> previewAsUser = ValueNotifier<bool>(false);
  static final ValueNotifier<List<String>> _adminEmails = ValueNotifier<List<String>>([]);
  static StreamSubscription? _adminSub;

  /// River names designated as Admin accounts
  static const List<String> riverAdmins = [
    'padma',
    'meghna',
    'jamuna',
    'buriganga',
    'shitalakhya',
  ];

  /// Call once when app starts or when SmartGarage opens
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    previewAsUser.value = prefs.getBool(_prefAdminOverride) ?? false;

    _adminSub?.cancel();
    _adminSub = GarageRtdbService.adminsStream().listen((admins) {
      _adminEmails.value = admins.map((e) => e.trim().toLowerCase()).toList();
    });
  }

  static void dispose() {
    _adminSub?.cancel();
  }

  /// Logged-in user email
  static String get currentEmail {
    final user = FirebaseAuth.instance.currentUser;
    return user?.email?.trim().toLowerCase() ?? 'user@bubt.edu.bd';
  }

  /// Display name
  static String get displayName {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      return user.displayName!;
    }
    final email = currentEmail;
    final prefix = email.split('@').first;
    return prefix.replaceAll('.', ' ').toUpperCase();
  }

  /// True if user genuinely has Admin rights:
  /// - River names (Padma, Meghna, Jamuna, Buriganga, Shitalakhya) are Admins
  /// - Emails containing 'admin'
  /// - Emails in RTDB admin whitelist
  /// All other users (students/general) are Customers.
  static bool get isActualAdmin {
    final email = currentEmail;

    // 1. River names check
    for (final river in riverAdmins) {
      if (email.startsWith(river) || email.contains(river)) {
        return true;
      }
    }
    for (final bus in BusConstants.allBusNames) {
      final b = bus.toLowerCase();
      if (email.startsWith(b) || email.contains(b)) {
        return true;
      }
    }

    // 2. Admin keyword check
    if (email.contains('admin')) return true;

    // 3. RTDB whitelist check
    if (_adminEmails.value.contains(email)) return true;

    return false;
  }

  /// User friendly role badge
  static String get roleLabel => isActualAdmin ? 'GARAGE ADMIN' : 'CUSTOMER';

  /// Effective role (takes "preview as user" toggle into account)
  static bool get isAdmin {
    if (!isActualAdmin) return false;
    return !previewAsUser.value;
  }

  /// Toggle preview as regular user for demo/testing
  static Future<void> toggleAdminPreview() async {
    previewAsUser.value = !previewAsUser.value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefAdminOverride, previewAsUser.value);
  }

  /// Stream of cards that belong to the current user
  static Stream<List<GarageUser>> myCardsStream() {
    final email = currentEmail;
    return GarageRtdbService.usersStream().map((users) {
      return users.where((u) => u.isOwnedBy(email)).toList();
    });
  }

  /// Claim or link a card to current user account
  /// Returns a record with (success, message)
  static Future<({bool ok, String message})> claimCard(String rawUid) async {
    final uid = rawUid.trim().toUpperCase();
    if (uid.isEmpty) {
      return (ok: false, message: 'Card UID cannot be empty');
    }
    if (uid.length < 4) {
      return (ok: false, message: 'Invalid Card UID format');
    }

    final email = currentEmail;
    final name = displayName;

    try {
      // Check if card exists in database
      final existing = await GarageRtdbService.getUser(uid);
      if (existing != null) {
        // If card already has an owner
        if (existing.hasOwner) {
          if (existing.isOwnedBy(email)) {
            return (ok: true, message: 'Card $uid is already linked to your account!');
          } else if (!isActualAdmin) {
            // Linked to someone else, and caller is not Admin!
            return (
              ok: false,
              message: 'Security Alert: Card $uid is already registered to another user (${existing.ownerEmail})! Each user must use their own unique card.'
            );
          }
          // If isActualAdmin, admin can re-assign or claim
        }
        // Card exists but unassigned (e.g. created by ESP32 physical swipe)
        final success = await GarageRtdbService.linkCardToUser(
          uid: uid,
          ownerEmail: email,
          ownerName: name,
        );
        if (success) {
          return (ok: true, message: 'Card $uid successfully linked to your account!');
        } else {
          return (ok: false, message: 'Failed to link card. Please check your internet connection.');
        }
      } else {
        // New card registration by user
        final success = await GarageRtdbService.registerUser(
          uid,
          ownerEmail: email,
          ownerName: name,
          initialBalance: 200,
        );
        if (success) {
          return (ok: true, message: 'Card $uid registered and linked! ৳200 bonus added.');
        } else {
          return (ok: false, message: 'Failed to register card. Please check your internet connection.');
        }
      }
    } catch (e) {
      debugPrint('🔴 claimCard error: $e');
      return (ok: false, message: 'Error linking card: $e');
    }
  }

  /// Unlink a card from current user (with ownership check)
  static Future<bool> unlinkCard(String uid) async {
    final card = await GarageRtdbService.getUser(uid);
    if (card != null && !isActualAdmin && !card.isOwnedBy(currentEmail)) {
      return false; // Security: Customers cannot unlink someone else's card
    }
    return GarageRtdbService.unlinkCard(uid);
  }
}

