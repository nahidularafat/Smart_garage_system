import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/garage_auth_service.dart';

class CameraPage extends StatefulWidget {
  final String cameraUrl;

  const CameraPage({
    super.key,
    required this.cameraUrl,
  });

  static String cleanUrl(String? raw) {
    if (raw == null) return 'http://172.17.105.238';
    var s = raw.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
    if (s.isEmpty) return 'http://172.17.105.238';
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      s = 'http://$s';
    }
    return s;
  }

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late final WebViewController _controller;
  late String _url;
  bool _isLoading = false;
  int _progress = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    // ── Security Guard: Block non-admin users whose vehicle is not inside ──
    // Check is deferred to build() so we can use Navigator to pop if denied.

    _url = CameraPage.cleanUrl(widget.cameraUrl);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onPageStarted: (startedUrl) {
            debugPrint('📷 [WebView] onPageStarted: $startedUrl');
            if (mounted) setState(() { _isLoading = true; _errorMessage = null; });
          },
          onPageFinished: (finishedUrl) {
            debugPrint('📷 [WebView] onPageFinished: $finishedUrl');
            if (mounted) setState(() => _isLoading = false);
            // ESP32-CAM এর সাদা ওয়েবপেজকে ডার্ক মোডে সুন্দর করে রেন্ডার করবে
            _controller.runJavaScript('''
              document.body.style.backgroundColor = '#0A0A1A';
              document.body.style.color = '#FFFFFF';
              document.body.style.margin = '0';
              document.body.style.padding = '12px';
              var h2 = document.querySelector('h2');
              if (h2) {
                h2.style.color = '#00E5CC';
                h2.style.fontSize = '16px';
                h2.style.margin = '10px 0';
                h2.style.fontFamily = 'sans-serif';
              }
              var img = document.querySelector('img');
              if (img) {
                img.style.borderRadius = '16px';
                img.style.maxWidth = '100%';
                img.style.height = 'auto';
                img.style.boxShadow = '0 8px 30px rgba(0,0,0,0.5)';
              }
            ''');
          },
          onWebResourceError: (error) {
            debugPrint('📷 [WebView] Error: ${error.description} (mainFrame: ${error.isForMainFrame})');
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
      final cleaned = CameraPage.cleanUrl(saved);
      // Clean invalid null chars from prefs if any
      if (cleaned != saved) {
        await prefs.setString('garage_camera_url', cleaned);
      }
      _url = cleaned;
    }
    _loadUrl();
  }

  void _loadUrl() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    _controller.loadRequest(Uri.parse(_url));
  }

  Future<void> _saveUrl(String newUrl) async {
    final cleaned = CameraPage.cleanUrl(newUrl);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('garage_camera_url', cleaned);
  }

  void _showEditDialog() {
    final ctrl = TextEditingController(text: _url);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Camera IP / URL',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'http://172.17.105.238',
            hintStyle: const TextStyle(color: Color(0xFF8A8AB0)),
            filled: true,
            fillColor: const Color(0xFF12122A),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            prefixIcon: const Icon(Icons.videocam_rounded, color: Color(0xFF00E5CC)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF8A8AB0))),
          ),
          FilledButton(
            onPressed: () {
              final cleaned = CameraPage.cleanUrl(ctrl.text);
              Navigator.pop(ctx);
              setState(() => _url = cleaned);
              _saveUrl(cleaned);
              _loadUrl();
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00E5CC), foregroundColor: Colors.black),
            child: const Text('Save & Reload', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _openInBrowser() async {
    try {
      final uri = Uri.parse(_url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // ── Security Guard: If a customer navigates here directly while vehicle is OUT,
    //    block access and show a denial screen instead of the live feed. ──
    // Admin users bypass this check entirely.
    if (!GarageAuthService.isActualAdmin) {
      return StreamBuilder<bool>(
        stream: GarageAuthService.cameraAccessStream(),
        builder: (context, snapshot) {
          final hasAccess = snapshot.data ?? false;
          if (!hasAccess) {
            return Scaffold(
              backgroundColor: const Color(0xFF0A0A1A),
              appBar: AppBar(
                backgroundColor: const Color(0xFF1A1A35),
                foregroundColor: Colors.white,
                title: const Text('Camera Access Denied', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD32A).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lock_rounded, color: Color(0xFFFFD32A), size: 48),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        '🔒 Access Denied',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Camera feed is only accessible while your vehicle is parked inside the garage.\n\nSwipe your RFID card at the entry gate to unlock.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF8A8AB0), fontSize: 13, height: 1.5),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.black),
                        label: const Text('Go Back', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00E5CC)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          // Access granted — render normal camera
          return _buildCameraView();
        },
      );
    }

    // Admin — always has access
    return _buildCameraView();
  }

  Widget _buildCameraView() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A35),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.fiber_manual_record, color: Colors.red, size: 10),
                SizedBox(width: 6),
                Text('ESP32-CAM Live View', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
            Text(
              _url,
              style: const TextStyle(fontSize: 10, color: Color(0xFF8A8AB0)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Edit IP',
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: _showEditDialog,
          ),
          IconButton(
            tooltip: 'Open in Chrome',
            icon: const Icon(Icons.open_in_browser_rounded, size: 20),
            onPressed: _openInBrowser,
          ),
          IconButton(
            tooltip: 'Reload',
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Loading progress indicator at top (never blocks page)
          if (_isLoading && _progress < 100)
            LinearProgressIndicator(
              value: _progress / 100.0,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF00E5CC)),
              minHeight: 3,
            )
          else
            const SizedBox(height: 3),

          // Error banner if any
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.red.withValues(alpha: 0.15),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Connection error: $_errorMessage',
                      style: const TextStyle(color: Colors.red, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: _loadUrl,
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFF00E5CC)),
                    child: const Text('Retry', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.open_in_browser_rounded, size: 16, color: Colors.white70),
                    tooltip: 'Open in Chrome',
                    onPressed: _openInBrowser,
                  ),
                ],
              ),
            ),

          // Direct clean WebView of http://172.17.105.238
          Expanded(
            child: WebViewWidget(controller: _controller),
          ),
        ],
      ),
    );
  }
}
