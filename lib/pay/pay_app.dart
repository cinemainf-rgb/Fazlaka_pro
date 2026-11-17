import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

const petrol = Color(0xFF0A3D3E);

class PayProScreen extends StatefulWidget {
  const PayProScreen({super.key});
  @override State<PayProScreen> createState() => _PayProScreenState();
}

class _PayProScreenState extends State<PayProScreen> {
  double _balance = 0;
  List<Map<String,dynamic>> _trans = [];

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    setState(() {
      _balance = sp.getDouble('pay_balance') ?? 0;
      final raw = sp.getString('pay_trans');
      if (raw != null) _trans = List<Map<String,dynamic>>.from(jsonDecode(raw));
    });
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setDouble('pay_balance', _balance);
    await sp.setString('pay_trans', jsonEncode(_trans));
  }

  Future<void> _addMoney() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('شحن رصيد'),
      content: TextField(controller: c, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ')),
      actions: [TextButton(onPressed: () => Navigator.pop(context,false), child: const Text('الغاء')), TextButton(onPressed: () => Navigator.pop(context,true), child: const Text('شحن'))],
    ));
    if (ok == true) {
      final amt = double.tryParse(c.text) ?? 0;
      if (amt > 0) {
        setState(() { _balance += amt; _trans.insert(0, {'type':'شحن رصيد','amount':amt,'date':DateTime.now().toString().substring(0,16)}); });
        await _save();
      }
    }
  }

  Future<void> _pay(String title) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: Text('دفع - $title'),
      content: TextField(controller: c, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ')),
      actions: [TextButton(onPressed: () => Navigator.pop(context,false), child: const Text('الغاء')), TextButton(onPressed: () => Navigator.pop(context,true), child: const Text('دفع'))],
    ));
    if (ok == true) {
      final amt = double.tryParse(c.text) ?? 0;
      if (amt > 0 && amt <= _balance) {
        setState(() { _balance -= amt; _trans.insert(0, {'type':title,'amount':-amt,'date':DateTime.now().toString().substring(0,16)}); });
        await _save();
      }
    }
  }

  @override Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Container(width: double.infinity, padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: petrol, borderRadius: BorderRadius.circular(20)), child: Column(children: [
          const Text('الرصيد الحالي', style: TextStyle(color: Colors.white70)),
          Text('$_balance ج', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.white), onPressed: _addMoney, child: const Text('شحن رصيد', style: TextStyle(color: petrol, fontWeight: FontWeight.bold)))),
        ])),
        const SizedBox(height: 16),
        Row(children: [Expanded(child: _payBtn('فاتورة نت', Icons.wifi)), const SizedBox(width: 8), Expanded(child: _payBtn('كهرباء', Icons.bolt))]),
        const SizedBox(height: 8),
        Row(children: [Expanded(child: _payBtn('شحن موبايل', Icons.phone_android)), const SizedBox(width: 8), Expanded(child: _payBtn('تحويل فلوس', Icons.send))]),
        const SizedBox(height: 20),
        const Align(alignment: Alignment.centerRight, child: Text('سجل العمليات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: petrol))),
        const SizedBox(height: 8),
        ..._trans.map((t) => Card(child: ListTile(title: Text(t['type']), subtitle: Text(t['date']), trailing: Text('${t['amount']} ج', style: TextStyle(color: (t['amount'] as num) >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold))))),
      ]),
    );
  }

  Widget _payBtn(String title, IconData icon) {
    return GestureDetector(onTap: () => _pay(title), child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: Column(children: [Icon(icon, color: petrol, size: 30), const SizedBox(height: 8), Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))])));
  }
}
