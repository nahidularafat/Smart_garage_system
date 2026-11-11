import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/garage_transaction.dart';
import '../../../models/garage_user.dart';
import '../../../services/garage_auth_service.dart';
import '../../../services/garage_rtdb_service.dart';

const _kBg      = Color(0xFF0A0A1A);
const _kSurface = Color(0xFF12122A);
const _kCard    = Color(0xFF1A1A35);
const _kAccent  = Color(0xFF00E5CC);
const _kYellow  = Color(0xFFFFD32A);
const _kGreen   = Color(0xFF2ED573);
const _kText    = Colors.white;
const _kSub     = Color(0xFF8A8AB0);

class UserHistoryTab extends StatefulWidget {
  const UserHistoryTab({super.key});

  @override
  State<UserHistoryTab> createState() => _UserHistoryTabState();
}

class _UserHistoryTabState extends State<UserHistoryTab> {
  StreamSubscription<List<GarageTransaction>>? _txSub;
  StreamSubscription<List<GarageUser>>? _cardSub;

  List<GarageTransaction> _myTransactions = [];
  String? _myCardUid;
  bool _loading = true;
  final _dateFmt = DateFormat('dd MMM yyyy, hh:mm a');

  @override
  void initState() {
    super.initState();
    _startSubscriptions();
  }

  void _startSubscriptions() {
    _cardSub = GarageAuthService.myCardsStream().listen((cards) {
      final uid = cards.isNotEmpty ? cards.first.uid : null;
      if (mounted) setState(() => _myCardUid = uid);
    });

    _txSub = GarageRtdbService.transactionsStream().listen((all) {
      if (mounted) {
        setState(() {
          if (_myCardUid != null && _myCardUid!.isNotEmpty) {
            _myTransactions = all.where((t) => t.uid == _myCardUid).toList();
          } else {
            _myTransactions = [];
          }
          _loading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _cardSub?.cancel();
    _txSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exits = _myTransactions.where((t) => t.isExit).toList();
    final totalSpent = exits.fold<int>(0, (sum, t) => sum + t.fare);

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        title: const Text('My Parking History', style: TextStyle(color: _kText, fontWeight: FontWeight.bold)),
      ),
      body: _myCardUid == null
          ? _buildNoCardState()
          : Column(
              children: [
                // Personal Summary Bar
                Container(
                  color: _kSurface,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatPill(
                          label: 'TOTAL TRIPS',
                          value: '${_myTransactions.length}',
                          color: _kAccent,
                          icon: Icons.directions_car_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatPill(
                          label: 'TOTAL SPENT',
                          value: '৳$totalSpent',
                          color: _kYellow,
                          icon: Icons.payments_rounded,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator(color: _kAccent))
                      : _myTransactions.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _myTransactions.length,
                              itemBuilder: (ctx, i) {
                                final tx = _myTransactions[i];
                                return _buildTxTile(tx);
                              },
                            ),
                ),
              ],
            ),
    );
  }

  Widget _buildNoCardState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.credit_card_off_rounded, color: _kSub, size: 50),
          const SizedBox(height: 16),
          const Text('No Card Linked', style: TextStyle(color: _kText, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text(
            'Link your RFID card on the Home tab to see your personal parking history.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _kSub, fontSize: 13),
          ),
        ]),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.receipt_long_outlined, color: _kSub, size: 48),
          const SizedBox(height: 16),
          const Text('No Parking History Yet', style: TextStyle(color: _kText, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text(
            'Your entry and exit records will appear here whenever you scan your card at the garage gate.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _kSub, fontSize: 12),
          ),
        ]),
      ),
    );
  }

  Widget _buildTxTile(GarageTransaction tx) {
    final isEntry = tx.isEntry;
    final color = isEntry ? _kAccent : _kGreen;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isEntry ? Icons.login_rounded : Icons.logout_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                isEntry ? 'GARAGE ENTRY' : 'GARAGE EXIT',
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                _dateFmt.format(tx.dateTime),
                style: const TextStyle(color: _kSub, fontSize: 11),
              ),
              if (!isEntry && tx.duration > 0) ...[
                const SizedBox(height: 3),
                Text('Duration: ${tx.duration} minutes', style: const TextStyle(color: _kYellow, fontSize: 11)),
              ],
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
              isEntry ? 'FREE' : '-৳${tx.fare}',
              style: TextStyle(
                color: isEntry ? _kSub : _kYellow,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Bal: ৳${tx.balanceAfter}',
              style: const TextStyle(color: _kSub, fontSize: 11),
            ),
          ]),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatPill({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: _kSub, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
      ]),
    );
  }
}

