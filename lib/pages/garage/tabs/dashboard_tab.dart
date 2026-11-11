import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/garage_user.dart';
import '../../../services/garage_rtdb_service.dart';
import '../../../camera_page.dart';
import '../rfid_card_page.dart';
import 'package:get/get.dart';

const _kBg      = Color(0xFF0A0A1A);
const _kSurface = Color(0xFF12122A);
const _kCard    = Color(0xFF1A1A35);
const _kAccent  = Color(0xFF00E5CC);
const _kRed     = Color(0xFFFF4757);
const _kYellow  = Color(0xFFFFD32A);
const _kGreen   = Color(0xFF2ED573);
const _kText    = Colors.white;
const _kSub     = Color(0xFF8A8AB0);

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});
  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> with TickerProviderStateMixin {
  StreamSubscription<SlotStatus>? _slotSub;
  StreamSubscription<List<GarageUser>>? _userSub;
  StreamSubscription<String>? _entryGateSub;
  StreamSubscription<String>? _exitGateSub;
  StreamSubscription<bool>? _connSub;

  SlotStatus _slots = const SlotStatus(slot1:'Empty',slot2:'Empty',slot3:'Empty',slot4:'Empty');
  List<GarageUser> _users = [];
  String _entryGateStatus = 'closed';
  String _exitGateStatus  = 'closed';
  bool _connected = false;
  String _camUrl = 'http://172.17.105.238';

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;
  late final AnimationController _entryGateCtrl;
  late final Animation<double> _entryGateAnim;
  late final AnimationController _exitGateCtrl;
  late final Animation<double> _exitGateAnim;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync:this, duration:const Duration(seconds:2))..repeat(reverse:true);
    _pulse = Tween(begin:0.4,end:1.0).animate(CurvedAnimation(parent:_pulseCtrl, curve:Curves.easeInOut));
    _entryGateCtrl = AnimationController(vsync:this, duration:const Duration(milliseconds:700));
    _entryGateAnim = CurvedAnimation(parent:_entryGateCtrl, curve:Curves.easeInOut);
    _exitGateCtrl = AnimationController(vsync:this, duration:const Duration(milliseconds:700));
    _exitGateAnim = CurvedAnimation(parent:_exitGateCtrl, curve:Curves.easeInOut);
    _loadCamUrl();
    _connect();
    _ticker = Timer.periodic(const Duration(seconds:20), (_) { if(mounted) setState((){ }); });
  }

  Future<void> _loadCamUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('garage_camera_url');
    if (saved != null && saved.isNotEmpty && mounted) {
      setState(() => _camUrl = CameraPage.cleanUrl(saved));
    }
  }

  @override
  void dispose() {
    _slotSub?.cancel(); _userSub?.cancel();
    _entryGateSub?.cancel(); _exitGateSub?.cancel();
    _connSub?.cancel();
    _pulseCtrl.dispose(); _entryGateCtrl.dispose(); _exitGateCtrl.dispose();
    _ticker?.cancel();
    super.dispose();
  }

  void _connect() {
    _connSub?.cancel();
    _connSub = GarageRtdbService.connectionStream().listen((connected) {
      if (mounted) setState(() => _connected = connected);
    });

    _slotSub?.cancel();
    _slotSub = GarageRtdbService.slotsStream().listen(
      (s) { if(mounted) setState(() { _slots=s; _connected=true; }); },
      onError: (_) {},
    );
    _userSub?.cancel();
    _userSub = GarageRtdbService.usersStream().listen(
      (u) { if(mounted) setState(() { _users=u; _connected=true; }); },
    );
    // Entry gate status
    _entryGateSub?.cancel();
    _entryGateSub = GarageRtdbService.entryGateStatusStream().listen((val) {
      if(mounted) {
        setState(() { _entryGateStatus = val; _connected=true; });
        val=='open' ? _entryGateCtrl.forward() : _entryGateCtrl.reverse();
      }
    });
    // Exit gate status
    _exitGateSub?.cancel();
    _exitGateSub = GarageRtdbService.exitGateStatusStream().listen((val) {
      if(mounted) {
        setState(() { _exitGateStatus = val; _connected=true; });
        val=='open' ? _exitGateCtrl.forward() : _exitGateCtrl.reverse();
      }
    });
  }

  bool get _isEntryOpen => _entryGateStatus == 'open';
  bool get _isExitOpen  => _exitGateStatus  == 'open';

  Future<void> _manualOpenEntryGate() async {
    final ok = await GarageRtdbService.sendEntryGateCommand();
    if(mounted) _snack(ok ? 'Entry gate open command sent!' : 'Failed to send command.', ok ? _kGreen : _kRed);
  }

  Future<void> _manualCloseEntryGate() async {
    final ok = await GarageRtdbService.sendCloseEntryGateCommand();
    if(mounted) _snack(ok ? 'Entry gate close command sent!' : 'Failed to send command.', ok ? _kGreen : _kRed);
  }

  Future<void> _manualOpenExitGate() async {
    final ok = await GarageRtdbService.sendExitGateCommand();
    if(mounted) _snack(ok ? 'Exit gate open command sent!' : 'Failed to send command.', ok ? _kGreen : _kRed);
  }

  Future<void> _manualCloseExitGate() async {
    final ok = await GarageRtdbService.sendCloseExitGateCommand();
    if(mounted) _snack(ok ? 'Exit gate close command sent!' : 'Failed to send command.', ok ? _kGreen : _kRed);
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
    final inside = _users.where((u) => u.isInside).toList();
    final totalRev = _users.fold<int>(0,(s,u)=>s+(u.lastFare??0));
    return Scaffold(
      backgroundColor: _kBg,
      body: RefreshIndicator(
        color: _kAccent, backgroundColor: _kCard,
        onRefresh: () async { _loadCamUrl(); _connect(); },
        child: CustomScrollView(slivers: [
          SliverAppBar(
            backgroundColor: _kSurface, pinned: true,
            title: Row(children: [
              const Icon(Icons.garage_rounded, color: _kAccent, size: 22),
              const SizedBox(width: 8),
              const Text('Dashboard', style: TextStyle(color: _kText, fontWeight: FontWeight.bold)),
              const Spacer(),
              AnimatedBuilder(animation: _pulse, builder: (_,__) => Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _connected ? _kGreen.withValues(alpha: _pulse.value) : _kYellow,
                ),
              )),
              const SizedBox(width: 6),
              Text(_connected ? 'Live' : 'Connecting',
                  style: TextStyle(color: _connected ? _kGreen : _kYellow, fontSize: 11)),
              const SizedBox(width: 8),
            ]),
          ),
          SliverPadding(padding: const EdgeInsets.all(16),
            sliver: SliverList(delegate: SliverChildListDelegate([
              // Entry + Exit gate cards
              _GateCard(
                label: 'ENTRY GATE',
                icon: Icons.login_rounded,
                isOpen: _isEntryOpen,
                pulse: _pulse,
                gateAnim: _entryGateAnim,
                onOpen: _manualOpenEntryGate,
                onClose: _manualCloseEntryGate,
                openMsg: 'Vehicle entering',
                closedMsg: 'Scan RFID card to enter',
              ),
              const SizedBox(height: 10),
              _GateCard(
                label: 'EXIT GATE',
                icon: Icons.logout_rounded,
                isOpen: _isExitOpen,
                pulse: _pulse,
                gateAnim: _exitGateAnim,
                onOpen: _manualOpenExitGate,
                onClose: _manualCloseExitGate,
                openMsg: 'Vehicle exiting',
                closedMsg: 'Scan RFID card to exit',
              ),
              const SizedBox(height: 14),
              // Stats row
              Row(children: [
                _StatCard(label:'Cars Inside', value:'${inside.length}', icon:Icons.directions_car_rounded, color:_kAccent),
                const SizedBox(width: 10),
                _StatCard(label:'Free Slots', value:'${_slots.availableCount}/4',
                    icon:Icons.local_parking, color:_slots.isFull?_kRed:_kGreen),
                const SizedBox(width: 10),
                _StatCard(label:'Revenue', value:'৳$totalRev', icon:Icons.payments_rounded, color:_kYellow),
              ]),
              const SizedBox(height: 16),

              // ── Live Security Camera Card ─────────────────────────────────
              GestureDetector(
                onTap: () => Get.to(() => CameraPage(cameraUrl: _camUrl),
                    transition: Transition.downToUp),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E1528), Color(0xFF12122A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _kRed.withValues(alpha: 0.35)),
                    boxShadow: [
                      BoxShadow(
                        color: _kRed.withValues(alpha: 0.08),
                        blurRadius: 18,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _kRed.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _kRed.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.videocam_rounded, color: _kRed, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8, height: 8,
                                  decoration: const BoxDecoration(color: _kRed, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'ESP32-CAM Live Feed',
                                  style: TextStyle(
                                    color: _kText,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$_camUrl  •  Tap to view',
                              style: const TextStyle(color: _kSub, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _kAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _kAccent.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_arrow_rounded, color: _kAccent, size: 16),
                            SizedBox(width: 4),
                            Text('WATCH', style: TextStyle(color: _kAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Slots grid
              const _SecHead(title: '🅿️  Parking Slots'),
              const SizedBox(height: 10),
              _SlotsGrid(slots: _slots),
              const SizedBox(height: 16),
              // Active sessions
              _SecHead(title: '🚗  Active Sessions', trailing: '${inside.length} parked'),
              const SizedBox(height: 10),
              if (inside.isEmpty)
                _EmptyBox(icon: Icons.directions_car_outlined, msg: 'No cars currently inside')
              else
                ...inside.map((u) => _ActiveCard(user: u)),
              const SizedBox(height: 24),
            ])),
          ),
        ]),
      ),
    );
  }
}

// ── Gate Card (Entry / Exit) ──────────────────────────────────────────────────
class _GateCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isOpen;
  final Animation<double> pulse;
  final Animation<double> gateAnim;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final String openMsg;
  final String closedMsg;
  const _GateCard({
    required this.label, required this.icon,
    required this.isOpen, required this.pulse,
    required this.gateAnim, required this.onOpen,
    required this.onClose,
    required this.openMsg, required this.closedMsg,
  });

  @override
  Widget build(BuildContext context) {
    final col = isOpen ? _kGreen : _kRed;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF1A1A35), Color(0xFF12122A)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: col.withValues(alpha: 0.4)),
        boxShadow: [BoxShadow(color: col.withValues(alpha: 0.1), blurRadius: 24, spreadRadius: 2)],
      ),
      child: Row(children: [
        // Traffic light
        _TrafficLight(isOpen: isOpen, pulse: pulse),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Label row
          Row(children: [
            Icon(icon, color: _kSub, size: 14),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: _kSub, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          ]),
          const SizedBox(height: 4),
          Text(isOpen ? '$label OPEN' : '$label CLOSED',
              style: TextStyle(color: col, fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(isOpen ? openMsg : closedMsg,
              style: const TextStyle(color: _kSub, fontSize: 11)),
          const SizedBox(height: 10),
          // Gate arm bar
          AnimatedBuilder(animation: gateAnim, builder: (_,__) {
            final open = gateAnim.value;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('GATE ARM', style: TextStyle(color: _kSub, fontSize: 9, letterSpacing: 1.2)),
              const SizedBox(height: 4),
              Stack(children: [
                Container(height: 5, decoration: BoxDecoration(
                    color: _kSurface, borderRadius: BorderRadius.circular(3))),
                FractionallySizedBox(
                  widthFactor: isOpen ? open : 1.0,
                  child: Container(height: 5, decoration: BoxDecoration(
                    gradient: LinearGradient(colors: isOpen ? [_kGreen,_kAccent] : [_kRed, Colors.orange]),
                    borderRadius: BorderRadius.circular(3),
                  )),
                ),
              ]),
            ]);
          }),
          const SizedBox(height: 10),
          if (!isOpen)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.lock_open_rounded, size: 14, color: Colors.black),
                label: const Text('Manual Open', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                style: FilledButton.styleFrom(
                  backgroundColor: _kAccent,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onClose,
                icon: const Icon(Icons.lock_rounded, size: 14, color: Colors.white),
                label: const Text('Manual Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                style: FilledButton.styleFrom(
                  backgroundColor: _kRed,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
        ])),
      ]),
    );
  }
}

class _TrafficLight extends StatelessWidget {
  final bool isOpen;
  final Animation<double> pulse;
  const _TrafficLight({required this.isOpen, required this.pulse});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: pulse, builder: (_,__) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(children: [
        _Bulb(color: _kRed,    on: !isOpen, pulse: pulse),
        const SizedBox(height: 6),
        _Bulb(color: _kYellow, on: false,   pulse: pulse),
        const SizedBox(height: 6),
        _Bulb(color: _kGreen,  on: isOpen,  pulse: pulse),
      ]),
    ));
  }
}

class _Bulb extends StatelessWidget {
  final Color color; final bool on; final Animation<double> pulse;
  const _Bulb({required this.color, required this.on, required this.pulse});
  @override
  Widget build(BuildContext context) => Container(
    width: 26, height: 26,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: on ? color.withValues(alpha: pulse.value) : color.withValues(alpha: 0.10),
      boxShadow: on ? [BoxShadow(color: color.withValues(alpha: 0.8 * pulse.value), blurRadius: 14, spreadRadius: 2)] : null,
    ),
  );
}

// ── Slots Grid ────────────────────────────────────────────────────────────────
// ESP32 হার্ডওয়্যার Pin → Slot ম্যাপিং (নির্দিষ্ট, র‍্যান্ডম নয়)
const Map<int, int> _slotPins = {1: 14, 2: 27, 3: 26, 4: 25};

class _SlotsGrid extends StatelessWidget {
  final SlotStatus slots;
  const _SlotsGrid({required this.slots});
  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 2, shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.2,
    children: List.generate(4, (i) {
      final slotNum = i + 1;
      final isFull = slots.statusOf(slotNum) == 'Full';
      return _ParkingBay(index: slotNum, pin: _slotPins[slotNum]!, isFull: isFull);
    }),
  );
}

class _ParkingBay extends StatelessWidget {
  final int index;
  final int pin;
  final bool isFull;
  const _ParkingBay({required this.index, required this.pin, required this.isFull});

  @override
  Widget build(BuildContext context) {
    // ESP32 লজিক: IR LOW = Full (গাড়ি আছে, লাল), IR HIGH = Empty (ফাঁকা, সবুজ)
    final Color statusColor = isFull ? _kRed : _kGreen;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(color: statusColor.withValues(alpha: 0.15), blurRadius: 16, spreadRadius: 1),
        ],
      ),
      child: Stack(
        children: [
          // ── বাম পাশে পার্কিং বে লাইন ──
          Positioned(
            left: 0, top: 0, bottom: 0,
            child: Container(
              width: 5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [statusColor.withValues(alpha: 0.7), statusColor.withValues(alpha: 0.2)],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16), bottomLeft: Radius.circular(16),
                ),
              ),
            ),
          ),
          // ── স্ট্যাটাস ইন্ডিকেটর (উপরে ডানে) ──
          Positioned(
            top: 8, right: 8,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: 10, height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor,
                boxShadow: [BoxShadow(color: statusColor.withValues(alpha: 0.7), blurRadius: 8, spreadRadius: 2)],
              ),
            ),
          ),
          // ── মূল কন্টেন্ট ──
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // স্লট নম্বর ও ESP32 Pin
                Text(
                  'P$index  •  Pin $pin',
                  style: TextStyle(
                    color: _kSub, fontSize: 10, fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                // গাড়ি আভাতার / খালি পার্কিং
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                  child: isFull
                      ? Container(
                          key: const ValueKey('car'),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _kRed.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _kRed.withValues(alpha: 0.25)),
                          ),
                          child: const Icon(Icons.directions_car_filled_rounded, color: _kRed, size: 28),
                        )
                      : Container(
                          key: const ValueKey('empty'),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _kGreen.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _kGreen.withValues(alpha: 0.2)),
                          ),
                          child: const Icon(Icons.local_parking_rounded, color: _kGreen, size: 28),
                        ),
                ),
                const SizedBox(height: 5),
                // স্ট্যাটাস ব্যাজ
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    isFull ? '🚗 OCCUPIED' : '✅ AVAILABLE',
                    style: TextStyle(
                      color: statusColor, fontSize: 9,
                      fontWeight: FontWeight.bold, letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Active Session Card ───────────────────────────────────────────────────────
class _ActiveCard extends StatelessWidget {
  final GarageUser user;
  const _ActiveCard({required this.user});
  @override
  Widget build(BuildContext context) {
    final dur = user.parkedDuration;
    return GestureDetector(
      onTap: () => Get.to(() => RfidCardPage(uid: user.uid), transition: Transition.rightToLeft),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kCard, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kAccent.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _kAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.directions_car_rounded, color: _kAccent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user.uid, style: const TextStyle(color: _kText, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            const SizedBox(height: 2),
            Text('${dur.inHours}h ${dur.inMinutes % 60}m parked  •  Entry: ${user.entryTime ?? "-"}',
                style: const TextStyle(color: _kSub, fontSize: 11)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('~৳${user.estimatedFare}', style: const TextStyle(color: _kYellow, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _kGreen.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: const Text('INSIDE', style: TextStyle(color: _kGreen, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ── Misc helpers ──────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, value; final IconData icon; final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: _kSub, fontSize: 10)),
      ]),
    ),
  );
}

class _SecHead extends StatelessWidget {
  final String title; final String? trailing;
  const _SecHead({required this.title, this.trailing});
  @override
  Widget build(BuildContext context) => Row(children: [
    Text(title, style: const TextStyle(color: _kText, fontSize: 14, fontWeight: FontWeight.bold)),
    const Spacer(),
    if (trailing != null) Text(trailing!, style: const TextStyle(color: _kSub, fontSize: 12)),
  ]);
}

class _EmptyBox extends StatelessWidget {
  final IconData icon; final String msg;
  const _EmptyBox({required this.icon, required this.msg});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: _kSub.withValues(alpha: 0.15))),
    child: Column(children: [
      Icon(icon, color: _kSub, size: 36),
      const SizedBox(height: 8),
      Text(msg, style: const TextStyle(color: _kSub, fontSize: 13), textAlign: TextAlign.center),
    ]),
  );
}
