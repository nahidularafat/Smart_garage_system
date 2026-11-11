import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../camera_page.dart';
import '../../../models/garage_user.dart';
import '../../../services/garage_auth_service.dart';
import '../../../services/garage_rtdb_service.dart';

const _kBg      = Color(0xFF0A0A1A);
const _kSurface = Color(0xFF12122A);
const _kCard    = Color(0xFF1A1A35);
const _kAccent  = Color(0xFF00E5CC);
const _kRed     = Color(0xFFFF4757);
const _kYellow  = Color(0xFFFFD32A);
const _kGreen   = Color(0xFF2ED573);
const _kText    = Colors.white;
const _kSub     = Color(0xFF8A8AB0);

class UserHomeTab extends StatefulWidget {
  const UserHomeTab({super.key});

  @override
  State<UserHomeTab> createState() => _UserHomeTabState();
}

class _UserHomeTabState extends State<UserHomeTab> with SingleTickerProviderStateMixin {
  StreamSubscription<List<GarageUser>>? _cardSub;
  StreamSubscription<SlotStatus>? _slotSub;
  StreamSubscription<bool>? _connSub;

  GarageUser? _myCard;
  SlotStatus _slots = const SlotStatus(slot1: 'Empty', slot2: 'Empty', slot3: 'Empty', slot4: 'Empty');
  bool _connected = false;
  bool _loading = true;
  String _camUrl = 'http://172.17.105.238';

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulse = Tween(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _loadCamUrl();
    _startSubscriptions();
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadCamUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('garage_camera_url');
    if (saved != null && saved.isNotEmpty && mounted) {
      setState(() => _camUrl = CameraPage.cleanUrl(saved));
    }
  }

  void _startSubscriptions() {
    _connSub = GarageRtdbService.connectionStream().listen((conn) {
      if (mounted) setState(() => _connected = conn);
    });

    _slotSub = GarageRtdbService.slotsStream().listen((s) {
      if (mounted) setState(() => _slots = s);
    });

    _cardSub = GarageAuthService.myCardsStream().listen((cards) {
      if (mounted) {
        setState(() {
          _myCard = cards.isNotEmpty ? cards.first : null;
          _loading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _cardSub?.cancel();
    _slotSub?.cancel();
    _connSub?.cancel();
    _pulseCtrl.dispose();
    _ticker?.cancel();
    super.dispose();
  }

  void _showLinkCardDialog() {
    final ctrl = TextEditingController();
    bool submitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _kCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            const Icon(Icons.add_card_rounded, color: _kAccent),
            const SizedBox(width: 10),
            const Text('Link RFID Card', style: TextStyle(color: _kText, fontWeight: FontWeight.bold, fontSize: 18)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the UID printed on your RFID card (or scanned at the gate). Once linked, only your account can use this card.',
                style: TextStyle(color: _kSub, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(color: _kText, letterSpacing: 1.5, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: 'e.g. C156191D',
                  hintStyle: const TextStyle(color: _kSub),
                  filled: true,
                  fillColor: _kSurface,
                  prefixIcon: const Icon(Icons.credit_card_rounded, color: _kAccent),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: _kSub)),
            ),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      final uid = ctrl.text.trim().toUpperCase();
                      if (uid.isEmpty) return;
                      setDialogState(() => submitting = true);
                      final res = await GarageAuthService.claimCard(uid);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        _snack(res.message, res.ok ? _kGreen : _kRed);
                      }
                    },
              style: FilledButton.styleFrom(backgroundColor: _kAccent, foregroundColor: Colors.black),
              child: submitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : const Text('Link Card'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _topUp(int amount) async {
    if (_myCard == null) return;
    final ok = await GarageRtdbService.topUpBalance(_myCard!.uid, amount);
    if (mounted) {
      _snack(
        ok ? '৳$amount top-up successful! New balance: ৳${_myCard!.balance + amount}' : 'Top-up failed.',
        ok ? _kGreen : _kRed,
      );
    }
  }

  void _snack(String msg, Color color) {
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
    final email = GarageAuthService.currentEmail;
    final name = GarageAuthService.displayName;

    return Scaffold(
      backgroundColor: _kBg,
      body: RefreshIndicator(
        color: _kAccent,
        backgroundColor: _kCard,
        onRefresh: () async {
          await _loadCamUrl();
          setState(() {});
        },
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              backgroundColor: _kSurface,
              pinned: true,
              title: Row(
                children: [
                  const Icon(Icons.directions_car_rounded, color: _kAccent, size: 22),
                  const SizedBox(width: 8),
                  const Text('My Smart Parking', style: TextStyle(color: _kText, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.videocam_rounded, color: _kRed, size: 22),
                    tooltip: 'Watch Live Camera',
                    onPressed: () => Get.to(() => CameraPage(cameraUrl: _camUrl), transition: Transition.downToUp),
                  ),
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) => Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _connected ? _kGreen.withValues(alpha: _pulse.value) : _kYellow,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(_connected ? 'Live' : 'Connecting',
                      style: TextStyle(color: _connected ? _kGreen : _kYellow, fontSize: 11)),
                  const SizedBox(width: 8),
                ],
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // User Welcome Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFF1E1E40), _kSurface],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _kAccent.withValues(alpha: 0.2)),
                    ),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: _kAccent.withValues(alpha: 0.15),
                        child: const Icon(Icons.person_rounded, color: _kAccent, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name, style: const TextStyle(color: _kText, fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 2),
                          Text(email, style: const TextStyle(color: _kSub, fontSize: 12)),
                        ]),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _kAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _kAccent.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          GarageAuthService.roleLabel,
                          style: const TextStyle(color: _kAccent, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // ── Main Card Section ──
                  if (_loading)
                    const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: _kAccent)))
                  else if (_myCard == null)
                    _buildNoCardBox()
                  else
                    _buildLinkedCardView(_myCard!),

                  const SizedBox(height: 16),

                  // ── Garage Real-time Capacity / Availability ──
                  _buildGarageAvailabilityCard(),

                  const SizedBox(height: 16),

                  // ── Live Security & Vehicle Camera (ESP32-CAM) ──
                  _buildLiveCameraCard(),

                  const SizedBox(height: 24),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoCardBox() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kSub.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _kAccent.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.credit_card_off_rounded, color: _kAccent, size: 40),
          ),
          const SizedBox(height: 16),
          const Text('No RFID Card Linked', style: TextStyle(color: _kText, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text(
            'Link your physical garage RFID card to monitor your balance, track entry/exit, and calculate parking fare.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _kSub, fontSize: 13),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _showLinkCardDialog,
              icon: const Icon(Icons.add_card_rounded, color: Colors.black),
              label: const Text('Link My RFID Card', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                backgroundColor: _kAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedCardView(GarageUser card) {
    final isInside = card.isInside;
    final statusColor = isInside ? _kGreen : _kSub;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isInside
              ? [const Color(0xFF133A2A), const Color(0xFF0F1E2A)]
              : [const Color(0xFF1E1E42), const Color(0xFF14142B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isInside ? _kGreen.withValues(alpha: 0.4) : _kAccent.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: (isInside ? _kGreen : _kAccent).withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Card Chip + Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Icon(Icons.nfc_rounded, color: _kAccent, size: 28),
                const SizedBox(width: 8),
                Text(
                  card.uid,
                  style: const TextStyle(color: _kText, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                ),
              ]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: (isInside ? _kGreen : Colors.grey).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isInside ? 'PARKED INSIDE' : 'OUTSIDE',
                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Balance Display
          const Text('AVAILABLE BALANCE', style: TextStyle(color: _kSub, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text('৳', style: TextStyle(color: _kAccent, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              Text(
                '${card.balance}',
                style: const TextStyle(color: _kText, fontSize: 38, fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 8),
              if (card.balance < 20)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: _kRed.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: const Text('LOW BALANCE', style: TextStyle(color: _kRed, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),

          // Live Parking Meter (if inside)
          if (isInside) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kGreen.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('ENTRY TIME', style: TextStyle(color: _kSub, fontSize: 10, letterSpacing: 1)),
                      const SizedBox(height: 3),
                      Text(card.entryTime ?? 'Active', style: const TextStyle(color: _kText, fontSize: 13, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('PARKED TIME', style: TextStyle(color: _kSub, fontSize: 10, letterSpacing: 1)),
                      const SizedBox(height: 3),
                      Text('${card.parkedDuration.inMinutes} mins', style: const TextStyle(color: _kYellow, fontSize: 14, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('EST. FARE', style: TextStyle(color: _kSub, fontSize: 10, letterSpacing: 1)),
                      const SizedBox(height: 3),
                      Text('৳${card.estimatedFare}', style: const TextStyle(color: _kAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => Get.to(() => CameraPage(cameraUrl: _camUrl), transition: Transition.downToUp),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: _kRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kRed.withValues(alpha: 0.35)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.videocam_rounded, color: _kRed, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Check My Parked Vehicle on Camera',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 14),

          // Quick Top-up buttons
          const Text('QUICK RECHARGE', style: TextStyle(color: _kSub, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 10),
          Row(
            children: [50, 100, 200, 500].map((amt) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: OutlinedButton(
                    onPressed: () => _topUp(amt),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _kAccent.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      backgroundColor: _kSurface.withValues(alpha: 0.5),
                    ),
                    child: Text('+৳$amt', style: const TextStyle(color: _kAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGarageAvailabilityCard() {
    final freeSlots = _slots.availableCount;
    final isFull = _slots.isFull;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: (isFull ? _kRed : _kGreen).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.local_parking_rounded, color: isFull ? _kRed : _kGreen, size: 22),
            const SizedBox(width: 8),
            const Text('GARAGE CAPACITY', style: TextStyle(color: _kSub, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: (isFull ? _kRed : _kGreen).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isFull ? 'FULL' : '$freeSlots / 4 SLOTS FREE',
                style: TextStyle(color: isFull ? _kRed : _kGreen, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ]),
          const SizedBox(height: 14),

          // 4 Slot Indicators
          Row(
            children: List.generate(4, (i) {
              final slotIdx = i + 1;
              final isSlotFull = _slots.statusOf(slotIdx) == 'Full';
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < 3 ? 8 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _kSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: (isSlotFull ? _kRed : _kGreen).withValues(alpha: 0.4)),
                  ),
                  child: Column(children: [
                    Text('SLOT $slotIdx', style: const TextStyle(color: _kSub, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Icon(
                      isSlotFull ? Icons.directions_car_rounded : Icons.check_circle_outline_rounded,
                      color: isSlotFull ? _kRed : _kGreen,
                      size: 18,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isSlotFull ? 'Occupied' : 'Free',
                      style: TextStyle(color: isSlotFull ? _kRed : _kGreen, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ]),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveCameraCard() {
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kRed.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: _kRed.withValues(alpha: 0.08),
            blurRadius: 18,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Get.to(
              () => CameraPage(cameraUrl: _camUrl),
              transition: Transition.downToUp,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Pulsing Live Indicator
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _kRed.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kRed.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.videocam_rounded, color: _kRed, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              AnimatedBuilder(
                                animation: _pulse,
                                builder: (_, __) => Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _kRed.withValues(alpha: _pulse.value),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'ESP32-CAM LIVE SECURITY',
                                style: TextStyle(
                                  color: _kRed,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Vehicle & Slot Camera',
                            style: TextStyle(
                              color: _kText,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _showCamSettingsDialog,
                      icon: const Icon(Icons.tune_rounded, color: _kSub, size: 20),
                      tooltip: 'Configure Camera IP',
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Helper text explaining why customer needs camera
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _kSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: _kAccent, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Check the live camera stream to ensure your car is safely inside slot P1, P2, P3 or P4.',
                          style: TextStyle(color: _kSub.withValues(alpha: 0.9), fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Primary Action Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Get.to(
                        () => CameraPage(cameraUrl: _camUrl),
                        transition: Transition.downToUp,
                      );
                    },
                    icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 20),
                    label: const Text(
                      'Open Live Camera Feed',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _kRed,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCamSettingsDialog() {
    final ctrl = TextEditingController(text: _camUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('ESP32-CAM URL', style: TextStyle(color: _kText, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your ESP32-CAM streaming IP/URL (e.g. http://172.17.105.238).',
              style: TextStyle(color: _kSub, fontSize: 12),
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
                if (mounted) setState(() => _camUrl = cleaned);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: _kAccent, foregroundColor: Colors.black),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

