// lib/pages/garage/tabs/user_camera_tab.dart
// Dedicated Live ESP32-CAM Tab for Customers / Vehicle Owners

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/garage_user.dart';
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
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

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

