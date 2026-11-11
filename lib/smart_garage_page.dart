// Smart Garage V3 — Main Shell
// Role-Based UI: Admin View (4 tabs) vs Regular User View (3 tabs)
// Auto-logs transactions when ESP32 changes user status.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/garage_user.dart';
import 'services/garage_auth_service.dart';
import 'services/garage_rtdb_service.dart';
import 'pages/garage/tabs/dashboard_tab.dart';
import 'pages/garage/tabs/cards_tab.dart';
import 'pages/garage/tabs/transactions_tab.dart';
import 'pages/garage/tabs/settings_tab.dart';
import 'pages/garage/tabs/user_home_tab.dart';
import 'pages/garage/tabs/user_camera_tab.dart';
import 'pages/garage/tabs/user_history_tab.dart';
import 'pages/garage/tabs/user_account_tab.dart';

const _kBg      = Color(0xFF0A0A1A);
const _kSurface = Color(0xFF12122A);
const _kAccent  = Color(0xFF00E5CC);
const _kSub     = Color(0xFF8A8AB0);
const _kYellow  = Color(0xFFFFD32A);

class SmartGaragePage extends StatefulWidget {
  const SmartGaragePage({super.key});

  @override
  State<SmartGaragePage> createState() => _SmartGaragePageState();
}

class _SmartGaragePageState extends State<SmartGaragePage> {
  int _tab = 0;

  // Transaction logger — watches user status changes
  StreamSubscription<List<GarageUser>>? _txSub;
  final Map<String, String> _prevStatus = {};

  static const _adminTabs = [
    DashboardTab(),
    CardsTab(),
    TransactionsTab(),
    SettingsTab(),
  ];

  static const _userTabs = [
    UserHomeTab(),
    UserCameraTab(),
    UserHistoryTab(),
    UserAccountTab(),
  ];

  static const _adminNavItems = [
    (icon: Icons.dashboard_rounded, label: 'Dashboard'),
    (icon: Icons.credit_card_rounded, label: 'Cards'),
    (icon: Icons.receipt_long_rounded, label: 'History'),
    (icon: Icons.settings_rounded, label: 'Settings'),
  ];

  static const _userNavItems = [
    (icon: Icons.directions_car_rounded, label: 'My Vehicle'),
    (icon: Icons.videocam_rounded, label: 'Live Camera'),
    (icon: Icons.receipt_long_rounded, label: 'History'),
    (icon: Icons.person_rounded, label: 'Account'),
  ];

  @override
  void initState() {
    super.initState();
    GarageAuthService.init();
    GarageAuthService.previewAsUser.addListener(_onRoleChanged);
    _startTransactionLogger();
  }

  void _onRoleChanged() {
    if (mounted) {
      setState(() {
        _tab = 0; // reset to first tab on role switch
      });
    }
  }

  @override
  void dispose() {
    GarageAuthService.previewAsUser.removeListener(_onRoleChanged);
    _txSub?.cancel();
    super.dispose();
  }

  // Auto-log transactions when user status changes
  void _startTransactionLogger() {
    _txSub = GarageRtdbService.usersStream().listen((users) {
      for (final user in users) {
        final prev = _prevStatus[user.uid];
        if (prev != null && prev != user.status) {
          if (user.status == 'IN') {
            GarageRtdbService.logTransaction(
              uid: user.uid,
              type: 'ENTRY',
              fare: 0,
              duration: 0,
              balanceAfter: user.balance,
            );
          } else if (user.status == 'OUT' && (user.lastFare ?? 0) > 0) {
            GarageRtdbService.logTransaction(
              uid: user.uid,
              type: 'EXIT',
              fare: user.lastFare ?? 0,
              duration: user.parkedDuration.inMinutes,
              balanceAfter: user.balance,
            );
          }
        }
        _prevStatus[user.uid] = user.status;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    final isAdmin = GarageAuthService.isAdmin;
    final isActualAdmin = GarageAuthService.isActualAdmin;
    final tabs = isAdmin ? _adminTabs : _userTabs;
    final navItems = isAdmin ? _adminNavItems : _userNavItems;

    // Guard tab index out of bounds when switching roles
    if (_tab >= tabs.length) {
      _tab = 0;
    }

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Admin Preview Banner (Only visible if the logged-in user is actually an Admin)
            if (isActualAdmin)
              Container(
                color: isAdmin ? const Color(0xFF1B1B38) : const Color(0xFF382A1B),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      isAdmin ? Icons.admin_panel_settings_rounded : Icons.visibility_rounded,
                      color: isAdmin ? _kAccent : _kYellow,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isAdmin
                            ? 'Admin Mode Active'
                            : 'User View Preview (Testing Mode)',
                        style: TextStyle(
                          color: isAdmin ? _kAccent : _kYellow,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: GarageAuthService.toggleAdminPreview,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isAdmin ? _kAccent : _kYellow).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (isAdmin ? _kAccent : _kYellow).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          isAdmin ? 'Preview as User' : 'Return to Admin',
                          style: TextStyle(
                            color: isAdmin ? _kAccent : _kYellow,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Active Tab Page
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: tabs,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _tab,
        items: navItems,
        onTap: (i) {
          setState(() => _tab = i);
        },
      ),
    );
  }
}

// ── Custom Bottom Navigation ──────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final List<({IconData icon, String label})> items;
  final ValueChanged<int> onTap;

  const _BottomNav({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border(top: BorderSide(color: _kAccent.withValues(alpha: 0.12))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(items.length, (i) {
              final item = items[i];
              final sel = currentIndex == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                          decoration: BoxDecoration(
                            color: sel ? _kAccent.withValues(alpha: 0.12) : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(item.icon, color: sel ? _kAccent : _kSub, size: 22),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          style: TextStyle(
                            color: sel ? _kAccent : _kSub,
                            fontSize: 10,
                            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
