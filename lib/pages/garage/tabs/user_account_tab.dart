import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/garage_user.dart';
import '../../../services/garage_auth_service.dart';

const _kBg      = Color(0xFF0A0A1A);
const _kSurface = Color(0xFF12122A);
const _kCard    = Color(0xFF1A1A35);
const _kAccent  = Color(0xFF00E5CC);
const _kRed     = Color(0xFFFF4757);
const _kYellow  = Color(0xFFFFD32A);
const _kGreen   = Color(0xFF2ED573);
const _kText    = Colors.white;
const _kSub     = Color(0xFF8A8AB0);

class UserAccountTab extends StatefulWidget {
  const UserAccountTab({super.key});

  @override
  State<UserAccountTab> createState() => _UserAccountTabState();
}

class _UserAccountTabState extends State<UserAccountTab> {
  StreamSubscription<List<GarageUser>>? _sub;
  GarageUser? _myCard;

  @override
  void initState() {
    super.initState();
    _sub = GarageAuthService.myCardsStream().listen((cards) {
      if (mounted) setState(() => _myCard = cards.isNotEmpty ? cards.first : null);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _showChangeCardDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Change RFID Card', style: TextStyle(color: _kText, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your new RFID Card UID. This will link the new card to your account.',
              style: TextStyle(color: _kSub, fontSize: 13),
            ),
            const SizedBox(height: 14),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _kSub))),
          FilledButton(
            onPressed: () async {
              final uid = ctrl.text.trim().toUpperCase();
              if (uid.isEmpty) return;
              Navigator.pop(ctx);
              final res = await GarageAuthService.claimCard(uid);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(res.message, style: const TextStyle(fontWeight: FontWeight.w600)),
                  backgroundColor: res.ok ? _kGreen : _kRed,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.all(16),
                ));
              }
            },
            style: FilledButton.styleFrom(backgroundColor: _kAccent, foregroundColor: Colors.black),
            child: const Text('Save Card'),
          ),
        ],
      ),
    );
  }

  void _confirmUnlink() {
    if (_myCard == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Unlink Card?', style: TextStyle(color: _kText, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to unlink card ${_myCard!.uid}? You can re-link it later.',
          style: const TextStyle(color: _kSub, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _kSub))),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await GarageAuthService.unlinkCard(_myCard!.uid);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Card unlinked successfully'),
                  backgroundColor: _kYellow,
                  behavior: SnackBarBehavior.floating,
                ));
              }
            },
            style: FilledButton.styleFrom(backgroundColor: _kRed),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = GarageAuthService.currentEmail;
    final name = GarageAuthService.displayName;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        title: const Text('My Account', style: TextStyle(color: _kText, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kSub.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: _kAccent.withValues(alpha: 0.15),
                  child: const Icon(Icons.person_rounded, color: _kAccent, size: 36),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: const TextStyle(color: _kText, fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 4),
                    Text(email, style: const TextStyle(color: _kSub, fontSize: 13)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: _kAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${GarageAuthService.roleLabel} • VEHICLE OWNER',
                        style: const TextStyle(color: _kAccent, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Linked Card Section
          _SectionTitle('Linked RFID Card'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _kAccent.withValues(alpha: 0.2)),
            ),
            child: _myCard == null
                ? Row(
                    children: [
                      const Icon(Icons.credit_card_off_rounded, color: _kSub),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('No card currently linked', style: TextStyle(color: _kSub, fontSize: 13)),
                      ),
                      FilledButton(
                        onPressed: _showChangeCardDialog,
                        style: FilledButton.styleFrom(backgroundColor: _kAccent, foregroundColor: Colors.black),
                        child: const Text('Link Card'),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            const Icon(Icons.credit_card_rounded, color: _kAccent, size: 24),
                            const SizedBox(width: 10),
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('CARD: ${_myCard!.uid}',
                                  style: const TextStyle(color: _kText, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1.2)),
                              Text('Balance: ৳${_myCard!.balance}', style: const TextStyle(color: _kGreen, fontSize: 12, fontWeight: FontWeight.bold)),
                            ]),
                          ]),
                          IconButton(
                            onPressed: _confirmUnlink,
                            icon: const Icon(Icons.link_off_rounded, color: _kRed),
                            tooltip: 'Unlink Card',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _showChangeCardDialog,
                          icon: const Icon(Icons.swap_horiz_rounded, size: 16, color: _kAccent),
                          label: const Text('Change Linked Card', style: TextStyle(color: _kAccent)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: _kAccent.withValues(alpha: 0.3)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 20),

          // Tariff & Garage Rules
          _SectionTitle('Parking Tariffs & Rules'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _kSub.withValues(alpha: 0.15)),
            ),
            child: const Column(
              children: [
                _RuleRow(icon: Icons.timer_outlined, label: 'Parking Rate', val: '৳2.00 / minute'),
                Divider(color: Colors.white10, height: 20),
                _RuleRow(icon: Icons.account_balance_wallet_outlined, label: 'Min Balance to Enter', val: '৳10.00'),
                Divider(color: Colors.white10, height: 20),
                _RuleRow(icon: Icons.card_giftcard_outlined, label: 'Welcome Bonus', val: '৳200.00 upon new card'),
                Divider(color: Colors.white10, height: 20),
                _RuleRow(icon: Icons.security_rounded, label: 'Gate Security', val: 'Automated RFID entry & exit'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(color: _kSub, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
    );
  }
}

class _RuleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String val;

  const _RuleRow({required this.icon, required this.label, required this.val});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _kAccent, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(color: _kText, fontSize: 13))),
        Text(val, style: const TextStyle(color: _kYellow, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}

