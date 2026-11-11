import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
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

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  String _camUrl = 'http://172.17.105.238';
  Map<String, dynamic> _settings = {};
  bool _loading = true;
  bool _gateLoading = false;
  bool _exitGateLoading = false;
  List<String> _admins = [];
  StreamSubscription<List<String>>? _adminSub;

  @override
  void initState() {
    super.initState();
    _loadCamUrl();
    _loadSettings();
    _adminSub = GarageRtdbService.adminsStream().listen((list) {
      if (mounted) setState(() => _admins = list);
    });
  }

  @override
  void dispose() {
    _adminSub?.cancel();
    super.dispose();
  }

  Future<void> _loadCamUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('garage_camera_url');
    if (saved != null && saved.isNotEmpty && mounted) {
      setState(() => _camUrl = CameraPage.cleanUrl(saved));
    }
  }

  Future<void> _editCameraUrl() async {
    final ctrl = TextEditingController(text: _camUrl);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Camera URL / IP', style: TextStyle(color: _kText, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter ESP32-CAM IP or Stream URL:', style: TextStyle(color: _kSub, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: _kText, fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: _kSurface,
                hintText: 'http://172.17.105.238',
                hintStyle: const TextStyle(color: _kSub),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.videocam_rounded, color: _kAccent),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _kSub))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: _kAccent, foregroundColor: Colors.black),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      final clean = CameraPage.cleanUrl(result);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('garage_camera_url', clean);
      setState(() => _camUrl = clean);
      _snack('Camera URL updated!');
    }
  }

  Future<void> _loadSettings() async {
    final s = await GarageRtdbService.getSettings();
    if (mounted) setState(() { _settings = s; _loading = false; });
  }

  Future<void> _editSetting(String key, String label, dynamic current) async {
    final ctrl = TextEditingController(text: current.toString());
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(label, style: const TextStyle(color: _kText, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: _kText, fontSize: 18, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            filled: true,
            fillColor: _kSurface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _kSub))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: _kAccent, foregroundColor: Colors.black),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) {
      final val = num.tryParse(result);
      if (val != null) {
        await GarageRtdbService.updateSetting(key, val);
        setState(() => _settings[key] = val);
        _snack('$label updated!');
      }
    }
  }

  Future<void> _openGate() async {
    setState(() => _gateLoading = true);
    final ok = await GarageRtdbService.sendEntryGateCommand();
    setState(() => _gateLoading = false);
    _snack(ok ? 'Entry gate open command sent!' : 'Failed to send command.', ok ? _kGreen : _kRed);
  }

  Future<void> _closeGate() async {
    setState(() => _gateLoading = true);
    final ok = await GarageRtdbService.sendCloseEntryGateCommand();
    setState(() => _gateLoading = false);
    _snack(ok ? 'Entry gate close command sent!' : 'Failed to send command.', ok ? _kGreen : _kRed);
  }

  Future<void> _openExitGate() async {
    setState(() => _exitGateLoading = true);
    final ok = await GarageRtdbService.sendExitGateCommand();
    setState(() => _exitGateLoading = false);
    _snack(ok ? 'Exit gate open command sent!' : 'Failed to send command.', ok ? _kGreen : _kRed);
  }

  Future<void> _closeExitGate() async {
    setState(() => _exitGateLoading = true);
    final ok = await GarageRtdbService.sendCloseExitGateCommand();
    setState(() => _exitGateLoading = false);
    _snack(ok ? 'Exit gate close command sent!' : 'Failed to send command.', ok ? _kGreen : _kRed);
  }

  void _showAddAdminDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Admin Email', style: TextStyle(color: _kText, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter user email. This account will have full administrative access (gate controls, camera, user management).',
              style: TextStyle(color: _kSub, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: _kText),
              decoration: InputDecoration(
                hintText: 'e.g. arafat@bubt.edu.bd',
                hintStyle: const TextStyle(color: _kSub),
                filled: true,
                fillColor: _kSurface,
                prefixIcon: const Icon(Icons.admin_panel_settings_rounded, color: _kAccent),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _kSub))),
          FilledButton(
            onPressed: () async {
              final email = ctrl.text.trim().toLowerCase();
              if (email.isEmpty) return;
              Navigator.pop(ctx);
              final ok = await GarageRtdbService.addAdmin(email);
              if (mounted) _snack(ok ? 'Admin $email added successfully!' : 'Failed to add admin.', ok ? _kGreen : _kRed);
            },
            style: FilledButton.styleFrom(backgroundColor: _kAccent, foregroundColor: Colors.black),
            child: const Text('Add Admin'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeAdmin(String email) async {
    final ok = await GarageRtdbService.removeAdmin(email);
    if (mounted) _snack(ok ? 'Admin $email removed.' : 'Failed to remove admin.', ok ? _kYellow : _kRed);
  }

  void _snack(String msg, [Color color = _kAccent]) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final rate = _settings['rate_per_minute'] ?? 2;
    final minBal = _settings['min_balance'] ?? 10;
    final bonus = _settings['welcome_bonus'] ?? 200;
    final delay = _settings['auto_close_delay'] ?? 3;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        title: const Text('Garage Settings (Admin)', style: TextStyle(color: _kText, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kAccent))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Pricing Section ──
                _SectionLabel(icon: Icons.payments_rounded, label: 'Billing & Pricing'),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _kAccent.withValues(alpha: 0.15)),
                  ),
                  child: Column(children: [
                    _SettingRow(
                      label: 'Rate per Minute',
                      value: '৳$rate /min',
                      sub: 'Cost charged per minute of parking',
                      icon: Icons.timer_rounded,
                      iconColor: _kAccent,
                      onTap: () => _editSetting('rate_per_minute', 'Rate per Minute', rate),
                    ),
                    _Divider(),
                    _SettingRow(
                      label: 'Min. Entry Balance',
                      value: '৳$minBal',
                      sub: 'Minimum balance required to enter',
                      icon: Icons.account_balance_wallet_rounded,
                      iconColor: _kYellow,
                      onTap: () => _editSetting('min_balance', 'Minimum Entry Balance', minBal),
                    ),
                    _Divider(),
                    _SettingRow(
                      label: 'Welcome Bonus',
                      value: '৳$bonus',
                      sub: 'Free credit for new card registration',
                      icon: Icons.card_giftcard_rounded,
                      iconColor: _kGreen,
                      onTap: () => _editSetting('welcome_bonus', 'Welcome Bonus', bonus),
                    ),
                    _Divider(),
                    _SettingRow(
                      label: 'Auto-close Delay',
                      value: '${delay}s',
                      sub: 'Gate closes N seconds after car passes',
                      icon: Icons.timer_off_rounded,
                      iconColor: _kSub,
                      onTap: () => _editSetting('auto_close_delay', 'Auto-close Delay (seconds)', delay),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),

                // ── Gate Control Section ──
                _SectionLabel(icon: Icons.garage_rounded, label: 'Gate Control Override'),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _kRed.withValues(alpha: 0.2)),
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Manual Gate Override', style: TextStyle(color: _kText, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    const Text('Force gate open or close. Only visible to Administrators.',
                        style: TextStyle(color: _kSub, fontSize: 12)),
                    const SizedBox(height: 14),
                    // Entry Gate Buttons
                    Row(children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _gateLoading ? null : _openGate,
                          icon: _gateLoading
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                              : const Icon(Icons.login_rounded, color: Colors.black, size: 16),
                          label: const Text('Open Entry', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                          style: FilledButton.styleFrom(
                            backgroundColor: _kAccent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _gateLoading ? null : _closeGate,
                          icon: const Icon(Icons.lock_rounded, color: _kRed, size: 16),
                          label: const Text('Close Entry', style: TextStyle(color: _kRed, fontWeight: FontWeight.bold, fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: _kRed.withValues(alpha: 0.5)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    // Exit Gate Buttons
                    Row(children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _exitGateLoading ? null : _openExitGate,
                          icon: _exitGateLoading
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                              : const Icon(Icons.logout_rounded, color: Colors.black, size: 16),
                          label: const Text('Open Exit', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                          style: FilledButton.styleFrom(
                            backgroundColor: _kYellow,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _exitGateLoading ? null : _closeExitGate,
                          icon: const Icon(Icons.lock_rounded, color: _kRed, size: 16),
                          label: const Text('Close Exit', style: TextStyle(color: _kRed, fontWeight: FontWeight.bold, fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: _kRed.withValues(alpha: 0.5)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ]),
                  ]),
                ),
                const SizedBox(height: 20),

                // ── Slot Reset Section ──
                _SectionLabel(icon: Icons.restart_alt_rounded, label: 'Slot Calibration'),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _kYellow.withValues(alpha: 0.2)),
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Reset All Slots', style: TextStyle(color: _kText, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    const Text('Sets all slots to "Empty". Useful after hardware reboots or IR sensor testing.',
                        style: TextStyle(color: _kSub, fontSize: 12)),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final ok = await GarageRtdbService.resetAllSlots();
                          _snack(ok ? 'All slots reset to Empty!' : 'Failed to reset slots.', ok ? _kGreen : _kRed);
                        },
                        icon: const Icon(Icons.restart_alt_rounded, color: _kYellow),
                        label: const Text('Reset All Slots to Empty', style: TextStyle(color: _kYellow, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: _kYellow.withValues(alpha: 0.4)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),

                // ── Admin Access Control Section ──
                _SectionLabel(icon: Icons.admin_panel_settings_rounded, label: 'Admin Access Control'),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _kAccent.withValues(alpha: 0.2)),
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Authorized Admin Accounts',
                              style: TextStyle(color: _kText, fontWeight: FontWeight.bold, fontSize: 14)),
                          FilledButton.icon(
                            onPressed: _showAddAdminDialog,
                            icon: const Icon(Icons.add, size: 14, color: Colors.black),
                            label: const Text('Add Admin', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
                            style: FilledButton.styleFrom(
                              backgroundColor: _kAccent,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text('Users in this list get full administrative controls (gate override, camera, settings).',
                          style: TextStyle(color: _kSub, fontSize: 12)),
                      const SizedBox(height: 14),
                      if (_admins.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: _kSurface, borderRadius: BorderRadius.circular(10)),
                          child: const Row(children: [
                            Icon(Icons.info_outline, color: _kAccent, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Emails containing "admin" automatically have admin rights. Add specific emails here.',
                                style: TextStyle(color: _kSub, fontSize: 11),
                              ),
                            ),
                          ]),
                        )
                      else
                        ..._admins.map((email) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: _kSurface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _kAccent.withValues(alpha: 0.15)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.shield_rounded, color: _kAccent, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(email, style: const TextStyle(color: _kText, fontSize: 13, fontWeight: FontWeight.w600))),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: _kRed, size: 18),
                                    onPressed: () => _removeAdmin(email),
                                    tooltip: 'Remove Admin Rights',
                                  ),
                                ],
                              ),
                            )),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Security Camera Section ──
                _SectionLabel(icon: Icons.videocam_rounded, label: 'Security Camera'),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => Get.to(() => CameraPage(cameraUrl: _camUrl), transition: Transition.downToUp),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _kCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _kRed.withValues(alpha: 0.2)),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: _kRed.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.videocam_rounded, color: _kRed, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('ESP32-CAM Live View', style: TextStyle(color: _kText, fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(_camUrl, style: const TextStyle(color: _kSub, fontSize: 12)),
                        ]),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, color: _kAccent, size: 18),
                        tooltip: 'Edit Camera IP',
                        onPressed: _editCameraUrl,
                      ),
                      const Icon(Icons.open_in_new_rounded, color: _kSub, size: 18),
                    ]),
                  ),
                ),
                const SizedBox(height: 20),

                // ── About Section ──
                _SectionLabel(icon: Icons.info_outline_rounded, label: 'About System'),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _kSub.withValues(alpha: 0.15)),
                  ),
                  child: Column(children: [
                    _InfoRow(label: 'System', value: 'Smart Garage Enterprise V3.2'),
                    _Divider(),
                    _InfoRow(label: 'Hardware', value: 'ESP32 + Dual Servo + RFID'),
                    _Divider(),
                    _InfoRow(label: 'Security', value: 'Role-Based Access Control (RBAC)'),
                    _Divider(),
                    _InfoRow(label: 'Database', value: 'Firebase RTDB Live-Tracking'),
                    _Divider(),
                    _InfoRow(label: 'Billing Rate', value: '৳$rate per minute'),
                    _Divider(),
                    _InfoRow(label: 'Max Capacity', value: '4 Slots'),
                  ]),
                ),
                const SizedBox(height: 40),
              ],
            ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: _kAccent, size: 16),
    const SizedBox(width: 8),
    Text(label.toUpperCase(), style: const TextStyle(color: _kSub, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
  ]);
}

class _SettingRow extends StatelessWidget {
  final String label, value, sub;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  const _SettingRow({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: _kText, fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(color: _kSub, fontSize: 12)),
        ])),
        Text(value, style: TextStyle(color: iconColor, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(width: 8),
        const Icon(Icons.edit_rounded, color: _kSub, size: 16),
      ]),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: _kSub, fontSize: 13)),
        Text(value, style: const TextStyle(color: _kText, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    ),
  );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Divider(color: Colors.white10, height: 1);
}
