// lib/pages/garage/tabs/user_camera_tab.dart
// Dedicated Live ESP32-CAM Tab for Customers / Vehicle Owners

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/garage_user.dart';
import '../../../services/garage_auth_service.dart';
import '../../../services/garage_rtdb_service.dart';
import '../../../camera_page.dart';

const _kBg      = Color(0xFF0A0A1A);
const _kSurface = Color(0xFF12122A);
const _kCard    = Color(0xFF1A1A35);
const _kAccent  = Color(0xFF00E5CC);
const _kRed     = Color(0xFFFF4757);
const _kYellow  = Color(0xFFFFD32A);
const _kGreen   = Color(0xFF2ED573);
const _kText    = Colors.white;
const _kSub     = Color(0xFF8A8AB0);

class UserCameraTab extends StatefulWidget {
  const UserCameraTab({super.key});

  @override
  State<UserCameraTab> createState() => _UserCameraTabState();
}

class _UserCameraTabState extends State<UserCameraTab>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final WebViewController _controller;
  String _url = 'http://172.17.105.238';
  bool _isLoading = false;
  int _progress = 0;
  String? _errorMessage;

  StreamSubscription<SlotStatus>? _slotSub;
  SlotStatus _slots = const SlotStatus(slot1: 'Empty', slot2: 'Empty', slot3: 'Empty', slot4: 'Empty');

  // ── Camera Access Control (Security Policy) ──
  StreamSubscription<List<GarageUser>>? _cardSub;
  GarageUser? _myCard;
  bool _cameraAccessGranted = false;
  bool _cardLoading = true;
  bool _wasAccessGranted = false; // Track previous state for stream reload

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulse = Tween(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _slotSub = GarageRtdbService.slotsStream().listen((s) {
      if (mounted) setState(() => _slots = s);
    });

    // ── Listen to card status for real-time camera access control ──
    _cardSub = GarageAuthService.myCardsStream().listen((cards) {
      if (mounted) {
        final card = cards.isNotEmpty ? cards.first : null;
        final hasAccess = GarageAuthService.hasCameraAccess(card);
        final justGainedAccess = hasAccess && !_wasAccessGranted && !_cardLoading;
        setState(() {
          _myCard = card;
          _cameraAccessGranted = hasAccess;
          _cardLoading = false;
          _wasAccessGranted = hasAccess;
        });
        // Auto-reload stream when access is newly granted (card punched IN)
        if (justGainedAccess) {
          _reloadStream();
        }
      }
    });

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onPageStarted: (startedUrl) {
            if (mounted) setState(() { _isLoading = true; _errorMessage = null; });
          },
          onPageFinished: (finishedUrl) {
            if (mounted) setState(() => _isLoading = false);
            _controller.runJavaScript('''
              document.body.style.backgroundColor = '#0A0A1A';
              document.body.style.color = '#FFFFFF';
              document.body.style.margin = '0';
              document.body.style.padding = '8px';
              var img = document.querySelector('img');
              if (img) {
                img.style.borderRadius = '14px';
                img.style.maxWidth = '100%';
                img.style.height = 'auto';
                img.style.boxShadow = '0 6px 20px rgba(0,0,0,0.6)';
              }
            ''');
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame ?? false) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _errorMessage = error.description;
                });
              }
            }
          },
        ),
      );

    _loadSavedUrlAndStart();
  }

  Future<void> _loadSavedUrlAndStart() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('garage_camera_url');
    if (saved != null && saved.isNotEmpty) {
      _url = CameraPage.cleanUrl(saved);
    }
    _reloadStream();
  }

  void _reloadStream() {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    _controller.loadRequest(Uri.parse(_url));
  }

  Future<void> _openInExternalBrowser() async {
    final uri = Uri.parse(_url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showEditUrlDialog() {
    final ctrl = TextEditingController(text: _url);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Camera IP / Stream URL', style: TextStyle(color: _kText, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the ESP32-CAM live stream address (e.g. http://172.17.105.238).',
              style: TextStyle(color: _kSub, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: _kText),
              decoration: InputDecoration(
                hintText: 'http://172.17.105.238',
                hintStyle: const TextStyle(color: _kSub),
                filled: true,
                fillColor: _kSurface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.link_rounded, color: _kAccent),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _kSub))),
          FilledButton(
            onPressed: () async {
              final newUrl = ctrl.text.trim();
              if (newUrl.isNotEmpty) {
                final cleaned = CameraPage.cleanUrl(newUrl);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('garage_camera_url', cleaned);
                setState(() => _url = cleaned);
                _reloadStream();
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: _kAccent, foregroundColor: Colors.black),
            child: const Text('Save & Connect'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _slotSub?.cancel();
    _cardSub?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // ── Loading card status ──
    if (_cardLoading) {
      return Scaffold(
        backgroundColor: _kBg,
        body: const Center(child: CircularProgressIndicator(color: _kAccent)),
      );
    }

    // ── CAMERA ACCESS DENIED — Security Lock Screen ──
    if (!_cameraAccessGranted) {
      return _buildLockedScreen();
    }

    // ── CAMERA ACCESS GRANTED — Live Stream ──
    return _buildLiveStreamScreen();
  }

  /// 🔒 Security Lock Screen — shown when customer's vehicle is not parked inside
  Widget _buildLockedScreen() {
    final hasCard = _myCard != null;
    final cardStatus = hasCard ? _myCard!.status : 'N/A';

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        title: Row(
          children: [
            Icon(Icons.lock_rounded, color: _kYellow, size: 20),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Camera Access Restricted',
                  style: TextStyle(color: _kText, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Security Policy Active',
                  style: TextStyle(color: _kYellow.withValues(alpha: 0.8), fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Lock Icon with Shield
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _kYellow.withValues(alpha: 0.15 * _pulse.value),
                        _kYellow.withValues(alpha: 0.05),
                        Colors.transparent,
                      ],
                    ),
                    border: Border.all(
                      color: _kYellow.withValues(alpha: 0.3 * _pulse.value),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(Icons.shield_rounded, color: _kYellow.withValues(alpha: 0.3), size: 60),
                        Icon(Icons.lock_rounded, color: _kYellow.withValues(alpha: _pulse.value), size: 36),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Title
              const Text(
                '🔒 Camera Access Locked',
                style: TextStyle(
                  color: _kText,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Explanation
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _kYellow.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    Text(
                      hasCard
                          ? 'Your vehicle is currently OUTSIDE the garage.\n\nCamera feed is only accessible while your vehicle is parked inside for security reasons.'
                          : 'No RFID card linked to your account.\n\nLink your parking card first, then swipe at the entry gate to unlock camera access.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _kSub.withValues(alpha: 0.9), fontSize: 14, height: 1.5),
                    ),
                    if (hasCard) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _kSurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _kRed.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.credit_card_rounded, color: _kAccent, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Card ${_myCard!.uid}',
                              style: const TextStyle(color: _kText, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _kRed.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'STATUS: $cardStatus',
                                style: const TextStyle(color: _kRed, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // How to unlock steps
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _kSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kAccent.withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: _kAccent, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'HOW TO UNLOCK CAMERA',
                          style: TextStyle(
                            color: _kAccent.withValues(alpha: 0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildStep('1', 'Swipe your RFID card at the entry gate', Icons.contactless_rounded),
                    const SizedBox(height: 8),
                    _buildStep('2', 'Park your vehicle inside the garage', Icons.local_parking_rounded),
                    const SizedBox(height: 8),
                    _buildStep('3', 'Camera feed activates automatically!', Icons.videocam_rounded),
                    const SizedBox(height: 10),
                    Divider(color: _kSub.withValues(alpha: 0.2)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.security_rounded, color: _kYellow.withValues(alpha: 0.7), size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Camera access is revoked automatically when you swipe to exit.',
                            style: TextStyle(color: _kSub.withValues(alpha: 0.7), fontSize: 11, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(String num, String text, IconData icon) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: _kAccent.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(num, style: const TextStyle(color: _kAccent, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, color: _kAccent.withValues(alpha: 0.6), size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(color: _kSub.withValues(alpha: 0.9), fontSize: 12)),
        ),
      ],
    );
  }

  /// ✅ Live Camera Stream — shown when card is punched IN (access granted)
  Widget _buildLiveStreamScreen() {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        title: Row(
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kRed.withValues(alpha: _pulse.value),
                  boxShadow: [
                    BoxShadow(color: _kRed.withValues(alpha: 0.6 * _pulse.value), blurRadius: 8, spreadRadius: 2),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Live Vehicle Camera',
                  style: TextStyle(color: _kText, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  _url,
                  style: const TextStyle(color: _kSub, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _kAccent),
            tooltip: 'Reload Stream',
            onPressed: _reloadStream,
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser_rounded, color: _kSub),
            tooltip: 'Open in Browser',
            onPressed: _openInExternalBrowser,
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: _kSub),
            tooltip: 'Change Camera IP',
            onPressed: _showEditUrlDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Loading Progress Bar
          if (_isLoading && _progress > 0 && _progress < 100)
            LinearProgressIndicator(
              value: _progress / 100.0,
              backgroundColor: _kSurface,
              color: _kAccent,
              minHeight: 2,
            ),

          // Stream Viewport
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),

                // Loading Overlay
                if (_isLoading)
                  Container(
                    color: Colors.black54,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: _kAccent),
                          const SizedBox(height: 14),
                          Text('Connecting to ESP32-CAM stream...',
                              style: TextStyle(color: _kSub.withValues(alpha: 0.9), fontSize: 12)),
                        ],
                      ),
                    ),
                  ),

                // Error Message Overlay
                if (_errorMessage != null)
                  Container(
                    color: _kBg,
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _kRed.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.videocam_off_rounded, color: _kRed, size: 40),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Unable to load live camera feed',
                            style: TextStyle(color: _kText, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Make sure your phone is connected to the same Wi-Fi/Hotspot as ESP32-CAM.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _kSub.withValues(alpha: 0.9), fontSize: 12),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _showEditUrlDialog,
                                icon: const Icon(Icons.tune_rounded, size: 16, color: _kAccent),
                                label: const Text('Edit IP', style: TextStyle(color: _kAccent)),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: _kAccent.withValues(alpha: 0.5)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              FilledButton.icon(
                                onPressed: _reloadStream,
                                icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.black),
                                label: const Text('Try Again', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                style: FilledButton.styleFrom(backgroundColor: _kAccent),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Bottom Bar: Live Slot Parking Availability (P1 - P4)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: _kSurface,
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_parking_rounded, color: _kAccent, size: 18),
                        const SizedBox(width: 6),
                        const Text(
                          'SLOT PARKING STATUS',
                          style: TextStyle(color: _kSub, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                        ),
                      ],
                    ),
                    Text(
                      '${_slots.availableCount} / 4 SLOTS FREE',
                      style: TextStyle(
                        color: _slots.isFull ? _kRed : _kGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: List.generate(4, (i) {
                    final slotNum = i + 1;
                    final isOccupied = _slots.statusOf(slotNum) == 'Full';
                    final color = isOccupied ? _kRed : _kGreen;
                    return Expanded(
                      child: Container(
                        margin: EdgeInsets.only(right: i < 3 ? 8 : 0),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _kCard,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: color.withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'P$slotNum',
                              style: const TextStyle(color: _kText, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              isOccupied ? 'Occupied' : 'Free',
                              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

