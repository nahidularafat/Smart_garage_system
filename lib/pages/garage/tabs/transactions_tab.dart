import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/garage_transaction.dart';
import '../../../services/garage_rtdb_service.dart';

const _kBg = Color(0xFF0A0A1A); const _kSurface = Color(0xFF12122A);
const _kCard = Color(0xFF1A1A35); const _kAccent = Color(0xFF00E5CC);
const _kYellow = Color(0xFFFFD32A);
const _kGreen = Color(0xFF2ED573); const _kText = Colors.white;
const _kSub = Color(0xFF8A8AB0);

enum _DateRange { today, week, month, all }

class TransactionsTab extends StatefulWidget {
  const TransactionsTab({super.key});
  @override
  State<TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<TransactionsTab> {
  StreamSubscription<List<GarageTransaction>>? _sub;
  List<GarageTransaction> _all = [];
  _DateRange _range = _DateRange.today;
  final _dateFmt = DateFormat('dd MMM, hh:mm a');

  @override
  void initState() {
    super.initState();
    _sub = GarageRtdbService.transactionsStream().listen((t) {
      if (mounted) setState(() => _all = t);
    });
  }

  @override
  void dispose() { _sub?.cancel(); super.dispose(); }

  List<GarageTransaction> get _filtered {
    final now = DateTime.now();
    return _all.where((t) {
      switch (_range) {
        case _DateRange.today:
          return t.dateTime.day == now.day && t.dateTime.month == now.month && t.dateTime.year == now.year;
        case _DateRange.week:
          return now.difference(t.dateTime).inDays <= 7;
        case _DateRange.month:
          return t.dateTime.month == now.month && t.dateTime.year == now.year;
        default: return true;
      }
    }).toList();
  }

  int get _totalRevenue => _filtered.where((t) => t.isExit).fold(0, (s, t) => s + t.fare);
  int get _totalEntries => _filtered.where((t) => t.isEntry).length;
  int get _totalExits  => _filtered.where((t) => t.isExit).length;

  @override
  Widget build(BuildContext context) {
    final shown = _filtered;
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        title: const Text('Transaction History', style: TextStyle(color: _kText, fontWeight: FontWeight.bold)),
      ),
      body: Column(children: [
        // Date filter pills
        Container(
          color: _kSurface,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Row(children: _DateRange.values.map((r) {
            final sel = _range == r;
            final label = r == _DateRange.today ? 'Today'
                : r == _DateRange.week ? 'This Week'
                : r == _DateRange.month ? 'This Month' : 'All Time';
            return Expanded(child: GestureDetector(
              onTap: () => setState(() => _range = r),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? _kAccent.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: sel ? _kAccent : _kSub.withValues(alpha: 0.3)),
                ),
                child: Text(label, textAlign: TextAlign.center,
                    style: TextStyle(color: sel ? _kAccent : _kSub, fontSize: 11,
                        fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
              ),
            ));
          }).toList()),
        ),
        // Summary card
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1A1A35), Color(0xFF12122A)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kAccent.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              _SumItem(label: 'Total Revenue', value: '৳$_totalRevenue', color: _kYellow),
              _Divider(),
              _SumItem(label: 'Entries', value: '$_totalEntries', color: _kGreen),
              _Divider(),
              _SumItem(label: 'Exits', value: '$_totalExits', color: _kAccent),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        // Transaction list
        Expanded(
          child: shown.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.receipt_long_outlined, color: _kSub, size: 48),
                  const SizedBox(height: 10),
                  const Text('No transactions for this period',
                      style: TextStyle(color: _kSub, fontSize: 13)),
                  const SizedBox(height: 4),
                  const Text('Transactions are logged when the app detects card status changes.',
                      style: TextStyle(color: _kSub, fontSize: 11), textAlign: TextAlign.center),
                ]))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: shown.length,
                  separatorBuilder: (_,__) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _TxCard(tx: shown[i], fmt: _dateFmt),
                ),
        ),
      ]),
    );
  }
}

class _SumItem extends StatelessWidget {
  final String label, value; final Color color;
  const _SumItem({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
    const SizedBox(height: 2),
    Text(label, style: const TextStyle(color: _kSub, fontSize: 10), textAlign: TextAlign.center),
  ]));
}

class _Divider extends StatelessWidget {
  @override
  Widget build(_) => Container(width: 1, height: 36, color: _kSub.withValues(alpha: 0.2), margin: const EdgeInsets.symmetric(horizontal: 4));
}

class _TxCard extends StatelessWidget {
  final GarageTransaction tx; final DateFormat fmt;
  const _TxCard({required this.tx, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final col = tx.isEntry ? _kGreen : _kAccent;
    final icon = tx.isEntry ? Icons.login_rounded : Icons.logout_rounded;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: col.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: col.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: col, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tx.uid, style: const TextStyle(color: _kText, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(fmt.format(tx.dateTime), style: const TextStyle(color: _kSub, fontSize: 11)),
          if (tx.isExit && tx.duration > 0)
            Text('${tx.duration} min parked', style: const TextStyle(color: _kSub, fontSize: 10)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: col.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: col.withValues(alpha: 0.3)),
            ),
            child: Text(tx.isEntry ? 'ENTRY' : 'EXIT',
                style: TextStyle(color: col, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          ),
          const SizedBox(height: 4),
          if (tx.isExit)
            Text('-৳${tx.fare}', style: const TextStyle(color: _kYellow, fontWeight: FontWeight.bold, fontSize: 13))
          else
            const Text('FREE', style: TextStyle(color: _kGreen, fontWeight: FontWeight.bold, fontSize: 12)),
        ]),
      ]),
    );
  }
}
