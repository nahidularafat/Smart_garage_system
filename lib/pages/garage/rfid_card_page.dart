import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/garage_user.dart';
import '../../services/garage_rtdb_service.dart';

const _kBg = Color(0xFF0A0A1A); const _kSurface = Color(0xFF12122A);
const _kCard = Color(0xFF1A1A35); const _kAccent = Color(0xFF00E5CC);
const _kRed = Color(0xFFFF4757); const _kYellow = Color(0xFFFFD32A);
const _kGreen = Color(0xFF2ED573); const _kText = Colors.white;
const _kSub = Color(0xFF8A8AB0);

class RfidCardPage extends StatefulWidget {
  final String uid;
  const RfidCardPage({super.key, required this.uid});
  @override
  State<RfidCardPage> createState() => _RfidCardPageState();
}

class _RfidCardPageState extends State<RfidCardPage> with TickerProviderStateMixin {
  GarageUser? _user;
  bool _loading = true;
  StreamSubscription<List<GarageUser>>? _sub;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulse = Tween(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _sub = GarageRtdbService.usersStream().listen((users) {
      final u = users.where((x) => x.uid == widget.uid).firstOrNull;
      debugPrint('🔍 [RfidCard] UID=${widget.uid} found=${u != null} balance=${u?.balance} status=${u?.status}');
      if (mounted) setState(() { _user = u; _loading = false; });
    });
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) { if (mounted) setState((){}); });
  }

  @override
  void dispose() { _sub?.cancel(); _pulseCtrl.dispose(); _ticker?.cancel(); super.dispose(); }

  Future<void> _topUp(int amount) async {
    if (_user == null) return;
    final newBal = _user!.balance + amount;
    final ok = await GarageRtdbService.topUpBalance(_user!.uid, amount);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'BDT $amount added! New balance: BDT $newBal' : 'Top-up failed.',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: ok ? _kGreen : _kRed, behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  Future<void> _resetToOut() async {
    if (_user == null) return;
    final ok = await GarageRtdbService.resetCardToOut(_user!.uid);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Card status reset to OUT!' : 'Failed to reset card.',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: ok ? _kGreen : _kRed, behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  void _showSetBalanceDialog() {
    if (_user == null) return;
    final ctrl = TextEditingController(text: _user!.balance.toString());
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: _kCard, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Set Balance', style: TextStyle(color: _kText, fontWeight: FontWeight.bold)),
      content: TextField(
        controller: ctrl, keyboardType: TextInputType.number,
        style: const TextStyle(color: _kText, fontSize: 20, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: 'New Balance (BDT)', hintStyle: const TextStyle(color: _kSub),
          filled: true, fillColor: _kSurface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          prefixIcon: const Icon(Icons.account_balance_wallet_rounded, color: _kAccent),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _kSub))),
        FilledButton(
          onPressed: () async {
            final a = int.tryParse(ctrl.text.trim());
            if (a != null && a >= 0) {
              Navigator.pop(ctx);
              final ok = await GarageRtdbService.setBalance(_user!.uid, a);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok ? 'Balance set to BDT $a' : 'Failed to set balance',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  backgroundColor: ok ? _kGreen : _kRed, behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                ));
              }
            }
          },
          style: FilledButton.styleFrom(backgroundColor: _kAccent, foregroundColor: Colors.black),
          child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ));
  }

  void _showAssignOwnerDialog() {
    if (_user == null) return;
    final ctrl = TextEditingController(text: _user!.ownerEmail ?? '');
    final nameCtrl = TextEditingController(text: _user!.ownerName ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Assign Card Owner', style: TextStyle(color: _kText, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter user email to bind this card. Only this user account will be able to access this card.',
              style: TextStyle(color: _kSub, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: _kText),
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'e.g. student@bubt.edu.bd',
                hintStyle: const TextStyle(color: _kSub),
                filled: true,
                fillColor: _kSurface,
                prefixIcon: const Icon(Icons.email_outlined, color: _kAccent),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: _kText),
              decoration: InputDecoration(
                hintText: 'Owner Name (optional)',
                hintStyle: const TextStyle(color: _kSub),
                filled: true,
                fillColor: _kSurface,
                prefixIcon: const Icon(Icons.person_outline_rounded, color: _kAccent),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          if (_user!.hasOwner)
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await GarageRtdbService.unlinkCard(_user!.uid);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Card unassigned.'),
                    backgroundColor: _kYellow,
                  ));
                }
              },
              child: const Text('Remove Owner', style: TextStyle(color: _kRed)),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _kSub))),
          FilledButton(
            onPressed: () async {
              final email = ctrl.text.trim().toLowerCase();
              final name = nameCtrl.text.trim();
              if (email.isEmpty) return;
              Navigator.pop(ctx);
              final ok = await GarageRtdbService.linkCardToUser(uid: _user!.uid, ownerEmail: email, ownerName: name);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok ? 'Card assigned to $email' : 'Failed to assign card.'),
                  backgroundColor: ok ? _kGreen : _kRed,
                ));
              }
            },
            style: FilledButton.styleFrom(backgroundColor: _kAccent, foregroundColor: Colors.black),
            child: const Text('Assign'),
          ),
        ],
      ),
    );
  }

  void _showCustomTopUp() {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: _kCard, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Custom Top-up', style: TextStyle(color: _kText, fontWeight: FontWeight.bold)),
      content: TextField(
        controller: ctrl, keyboardType: TextInputType.number,
        style: const TextStyle(color: _kText, fontSize: 20, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: 'Amount (BDT)', hintStyle: const TextStyle(color: _kSub),
          filled: true, fillColor: _kSurface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          prefixIcon: const Icon(Icons.currency_exchange_rounded, color: _kAccent),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _kSub))),
        FilledButton(
          onPressed: () { final a = int.tryParse(ctrl.text.trim()) ?? 0; if (a > 0) { Navigator.pop(ctx); _topUp(a); } },
          style: FilledButton.styleFrom(backgroundColor: _kAccent, foregroundColor: Colors.black),
          child: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) { return const Scaffold(backgroundColor: _kBg, body: Center(child: CircularProgressIndicator(color: _kAccent))); }
    if (_user == null) {
      return Scaffold(backgroundColor: _kBg,
          appBar: AppBar(backgroundColor: _kSurface, foregroundColor: _kText, title: const Text('Card Not Found')),
          body: const Center(child: Text('Card not registered yet.', style: TextStyle(color: _kSub))));
    }

    final u = _user!;
    final dur = u.parkedDuration;
    final balColor = u.balance >= 100 ? _kGreen : u.balance >= 20 ? _kYellow : _kRed;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface, foregroundColor: _kText,
        title: const Text('Card Details', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, size: 22),
            tooltip: 'Set Balance',
            onPressed: _showSetBalanceDialog,
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18),
            tooltip: 'Copy UID',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: u.uid));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('UID copied!'), duration: Duration(seconds: 1)));
            },
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Corrupt / missing session warning
        if (u.isInside && u.entryEpoch == null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kRed.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kRed.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: _kRed, size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Session Corrupted (No entryEpoch)',
                          style: TextStyle(color: _kRed, fontWeight: FontWeight.bold, fontSize: 13)),
                      SizedBox(height: 2),
                      Text('This causes ESP32 to calculate millions in fare and show Low Balance! Tap Fix.',
                          style: TextStyle(color: _kSub, fontSize: 11)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _resetToOut,
                  style: TextButton.styleFrom(foregroundColor: _kAccent),
                  child: const Text('Fix Now', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Hero card
        AnimatedBuilder(
          animation: _pulse,
          builder: (_,__) => Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1A1A35), Color(0xFF0F0F2A)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: (u.isInside ? _kAccent : _kSub).withValues(alpha: 0.4)),
              boxShadow: [BoxShadow(
                  color: (u.isInside ? _kAccent : _kSub).withValues(alpha: 0.08 * _pulse.value),
                  blurRadius: 24, spreadRadius: 4)],
            ),
            child: Column(children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: (u.isInside ? _kAccent : _kSub).withValues(alpha: 0.1)),
                child: Icon(Icons.credit_card_rounded, color: u.isInside ? _kAccent : _kSub, size: 36),
              ),
              const SizedBox(height: 14),
              Text(u.uid, style: const TextStyle(color: _kText, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: u.isInside ? _kGreen : _kSub)),
                const SizedBox(width: 8),
                Text(u.isInside ? 'Currently Inside' : 'Outside',
                    style: TextStyle(color: u.isInside ? _kGreen : _kSub, fontSize: 13)),
              ]),
              const SizedBox(height: 12),
              // Action buttons: Toggle Status / Set Balance
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _resetToOut,
                    icon: Icon(u.isInside ? Icons.exit_to_app_rounded : Icons.replay_rounded, size: 14, color: _kYellow),
                    label: Text(u.isInside ? 'Force Exit (OUT)' : 'Reset Status',
                        style: const TextStyle(color: _kYellow, fontSize: 11, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _kYellow.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _showSetBalanceDialog,
                    icon: const Icon(Icons.edit_rounded, size: 14, color: _kAccent),
                    label: const Text('Edit Balance',
                        style: TextStyle(color: _kAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _kAccent.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(color: _kSurface, borderRadius: BorderRadius.circular(16)),
                child: Column(children: [
                  const Text('BALANCE', style: TextStyle(color: _kSub, fontSize: 11, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text('৳${u.balance}', style: TextStyle(color: balColor, fontSize: 36, fontWeight: FontWeight.bold)),
                  if (u.balance < 20)
                    const Padding(padding: EdgeInsets.only(top: 4),
                        child: Text('Low Balance! Top-up now.', style: TextStyle(color: _kRed, fontSize: 11))),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 14),

        // ── Card Owner Section (Admin Management) ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kAccent.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _kAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.person_rounded, color: _kAccent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('CARD OWNER', style: TextStyle(color: _kSub, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    u.hasOwner ? (u.ownerEmail ?? 'Assigned') : 'Unassigned (Open for any user)',
                    style: TextStyle(
                      color: u.hasOwner ? _kText : _kYellow,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (u.ownerName != null && u.ownerName!.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(u.ownerName!, style: const TextStyle(color: _kSub, fontSize: 11)),
                  ],
                ]),
              ),
              OutlinedButton(
                onPressed: _showAssignOwnerDialog,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _kAccent.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  u.hasOwner ? 'Change' : 'Assign',
                  style: const TextStyle(color: _kAccent, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Session info
        if (u.isInside) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kAccent.withValues(alpha: 0.2))),
            child: Column(children: [
              _Row(icon: Icons.timer_rounded, label: 'Parked Duration',
                  value: '${dur.inHours}h ${dur.inMinutes % 60}m', color: _kAccent),
              const _Sep(),
              _Row(icon: Icons.payments_rounded, label: 'Estimated Fee',
                  value: '৳${u.estimatedFare}', color: _kYellow),
              if (u.entryTime != null) ...[const _Sep(),
                _Row(icon: Icons.login_rounded, label: 'Entry Time', value: u.entryTime!)],
            ]),
          ),
          const SizedBox(height: 14),
        ] else if (u.exitTime != null || u.lastFare != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kSub.withValues(alpha: 0.15))),
            child: Column(children: [
              if (u.exitTime != null) _Row(icon: Icons.logout_rounded, label: 'Last Exit', value: u.exitTime!),
              if (u.exitTime != null && u.lastFare != null) const _Sep(),
              if (u.lastFare != null) _Row(icon: Icons.receipt_rounded, label: 'Last Fare',
                  value: '৳${u.lastFare}', color: _kYellow),
            ]),
          ),
          const SizedBox(height: 14),
        ],

        // Quick top-up grid
        const Text('Quick Top-up', style: TextStyle(color: _kText, fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.2,
          children: [50, 100, 200, 300, 500, 1000].map((amt) => GestureDetector(
            onTap: () => _topUp(amt),
            child: Container(
              decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kAccent.withValues(alpha: 0.25))),
              child: Center(child: Text('+৳$amt',
                  style: const TextStyle(color: _kAccent, fontWeight: FontWeight.bold, fontSize: 14))),
            ),
          )).toList(),
        ),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          onPressed: _showCustomTopUp,
          icon: const Icon(Icons.add_rounded, color: _kAccent),
          label: const Text('Custom Amount', style: TextStyle(color: _kAccent, fontWeight: FontWeight.bold)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: _kAccent.withValues(alpha: 0.4)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        )),
        const SizedBox(height: 30),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon; final String label, value; final Color? color;
  const _Row({required this.icon, required this.label, required this.value, this.color});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: _kAccent, size: 16),
    const SizedBox(width: 10),
    Text(label, style: const TextStyle(color: _kSub, fontSize: 13)),
    const Spacer(),
    Text(value, style: TextStyle(color: color ?? _kText, fontSize: 13, fontWeight: FontWeight.bold)),
  ]);
}

class _Sep extends StatelessWidget {
  const _Sep();
  @override
  Widget build(_) => Divider(color: _kSub.withValues(alpha: 0.15), height: 20);
}
