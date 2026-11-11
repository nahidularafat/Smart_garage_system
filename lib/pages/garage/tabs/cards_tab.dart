import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/garage_user.dart';
import '../../../services/garage_rtdb_service.dart';
import '../rfid_card_page.dart';
import 'package:get/get.dart';

const _kBg = Color(0xFF0A0A1A); const _kSurface = Color(0xFF12122A);
const _kCard = Color(0xFF1A1A35); const _kAccent = Color(0xFF00E5CC);
const _kRed = Color(0xFFFF4757); const _kYellow = Color(0xFFFFD32A);
const _kGreen = Color(0xFF2ED573); const _kText = Colors.white;
const _kSub = Color(0xFF8A8AB0);

enum _Filter { all, inside, outside, lowBalance }

class CardsTab extends StatefulWidget {
  const CardsTab({super.key});
  @override
  State<CardsTab> createState() => _CardsTabState();
}

class _CardsTabState extends State<CardsTab> {
  StreamSubscription<List<GarageUser>>? _sub;
  List<GarageUser> _all = [];
  String _query = '';
  _Filter _filter = _Filter.all;
  bool _showSearch = false;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sub = GarageRtdbService.usersStream().listen((u) {
      if (mounted) setState(() => _all = u);
    });
  }

  @override
  void dispose() { _sub?.cancel(); _searchCtrl.dispose(); super.dispose(); }

  List<GarageUser> get _filtered {
    var list = _all;
    if (_query.isNotEmpty) list = list.where((u) => u.uid.toLowerCase().contains(_query.toLowerCase())).toList();
    switch (_filter) {
      case _Filter.inside:      return list.where((u) => u.isInside).toList();
      case _Filter.outside:     return list.where((u) => !u.isInside).toList();
      case _Filter.lowBalance:  return list.where((u) => u.balance < 20).toList();
      default: return list;
    }
  }

  void _showRegisterDialog() {
    final ctrl = TextEditingController();
    final emailCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: _kCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Register New Card', style: TextStyle(color: _kText, fontWeight: FontWeight.bold)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Enter RFID card UID and optional user email to bind ownership.', style: TextStyle(color: _kSub, fontSize: 12)),
        const SizedBox(height: 12),
        TextField(
          controller: ctrl,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(color: _kText, letterSpacing: 1),
          decoration: InputDecoration(
            hintText: 'Card UID (e.g. C156191D)', hintStyle: const TextStyle(color: _kSub),
            filled: true, fillColor: _kSurface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            prefixIcon: const Icon(Icons.credit_card_rounded, color: _kAccent),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: _kText),
          decoration: InputDecoration(
            hintText: 'Owner Email (optional)', hintStyle: const TextStyle(color: _kSub),
            filled: true, fillColor: _kSurface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            prefixIcon: const Icon(Icons.person_outline_rounded, color: _kAccent),
          ),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: _kSub))),
        FilledButton(
          onPressed: () async {
            final uid = ctrl.text.trim().toUpperCase();
            final ownerEmail = emailCtrl.text.trim().toLowerCase();
            if (uid.isEmpty) return;
            Navigator.pop(ctx);
            final ok = await GarageRtdbService.registerUser(
              uid,
              ownerEmail: ownerEmail.isNotEmpty ? ownerEmail : null,
            );
            if (mounted) _snack(ok ? 'Card registered with BDT 200 bonus!' : 'Registration failed.', ok ? _kGreen : _kRed);
          },
          style: FilledButton.styleFrom(backgroundColor: _kAccent, foregroundColor: Colors.black),
          child: const Text('Register'),
        ),
      ],
    ));
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: color, behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final shown = _filtered;
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        title: _showSearch
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(color: _kText),
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Search by card UID...',
                  hintStyle: TextStyle(color: _kSub),
                  border: InputBorder.none,
                ),
              )
            : const Text('RFID Cards', style: TextStyle(color: _kText, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search_rounded, color: _kSub),
            onPressed: () => setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) { _searchCtrl.clear(); _query = ''; }
            }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showRegisterDialog,
        backgroundColor: _kAccent,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_card_rounded),
        label: const Text('Add Card', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(children: [
        // Filter chips
        Container(
          color: _kSurface,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: _Filter.values.map((f) {
              final sel = _filter == f;
              final label = f == _Filter.all ? 'All (${_all.length})'
                  : f == _Filter.inside ? 'Inside'
                  : f == _Filter.outside ? 'Outside'
                  : 'Low Balance';
              final col = f == _Filter.inside ? _kGreen
                  : f == _Filter.outside ? _kSub
                  : f == _Filter.lowBalance ? _kRed : _kAccent;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _filter = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel ? col.withValues(alpha: 0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? col : _kSub.withValues(alpha: 0.3)),
                    ),
                    child: Text(label, style: TextStyle(
                        color: sel ? col : _kSub, fontSize: 12, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                  ),
                ),
              );
            }).toList()),
          ),
        ),
        // Card list
        Expanded(
          child: shown.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.credit_card_off_rounded, color: _kSub, size: 48),
                  const SizedBox(height: 10),
                  Text(_query.isNotEmpty ? 'No cards match "$_query"' : 'No cards found',
                      style: const TextStyle(color: _kSub, fontSize: 14)),
                ]))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: shown.length,
                  separatorBuilder: (_,__) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _CardTile(user: shown[i]),
                ),
        ),
      ]),
    );
  }
}

class _CardTile extends StatelessWidget {
  final GarageUser user;
  const _CardTile({required this.user});

  Color get _balColor => user.balance >= 100 ? _kGreen : user.balance >= 20 ? _kYellow : _kRed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.to(() => RfidCardPage(uid: user.uid), transition: Transition.rightToLeft),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kCard, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: user.isInside ? _kAccent.withValues(alpha: 0.35) : _kSub.withValues(alpha: 0.15)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (user.isInside ? _kAccent : _kSub).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.credit_card_rounded, color: user.isInside ? _kAccent : _kSub, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(user.uid, style: const TextStyle(color: _kText, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: user.hasOwner ? _kAccent.withValues(alpha: 0.15) : Colors.white10,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  user.hasOwner ? (user.ownerEmail?.split('@').first ?? 'Owned') : 'Unassigned',
                  style: TextStyle(
                    color: user.hasOwner ? _kAccent : _kSub,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 3),
            Row(children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: user.isInside ? _kGreen : _kSub)),
              const SizedBox(width: 6),
              Text(user.isInside ? 'Currently Inside' : 'Outside',
                  style: TextStyle(color: user.isInside ? _kGreen : _kSub, fontSize: 11)),
              if (user.isInside && user.entryTime != null) ...[
                const Text('  •  ', style: TextStyle(color: _kSub, fontSize: 11)),
                Text('Entry: ${user.entryTime}', style: const TextStyle(color: _kSub, fontSize: 11)),
              ],
            ]),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _balColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _balColor.withValues(alpha: 0.35)),
              ),
              child: Text('৳${user.balance}', style: TextStyle(color: _balColor, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const SizedBox(height: 4),
            const Icon(Icons.chevron_right_rounded, color: _kSub, size: 18),
          ]),
        ]),
      ),
    );
  }
}
