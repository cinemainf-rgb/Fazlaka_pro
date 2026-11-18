import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/colors.dart';
import '../core/mikrotik_api.dart';

class RouterTab extends StatefulWidget {
  final String host, user, pass;
  const RouterTab({super.key, required this.host, required this.user, required this.pass});
  @override
  State<RouterTab> createState() => _RouterTabState();
}

class _RouterTabState extends State<RouterTab> {
  String profile = '20';
  int count = 1;
  List<String> created = [];
  String printerName = 'غير متصلة';
  BluetoothConnection? bt;
  String msg = '';
  bool busy = false;
  bool autoTried = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 500), autoConnectPrinter);
  }

  Future<void> autoConnectPrinter() async {
    if (autoTried) return;
    autoTried = true;
    try {
      await Permission.bluetoothConnect.request();
      await Permission.bluetoothScan.request();
      await Permission.locationWhenInUse.request();
      final sp = await SharedPreferences.getInstance();
      final savedMac = sp.getString('saved_printer_mac') ?? '';
      final enabled = await FlutterBluetoothSerial.instance.isEnabled ?? false;
      if (!enabled) return;
      final bonded = await FlutterBluetoothSerial.instance.getBondedDevices();
      BluetoothDevice? target;
      for (final d in bonded) {
        final n = (d.name ?? '').toLowerCase();
        if (savedMac.isNotEmpty && d.address == savedMac) { target = d; break; }
        if (n.contains('razytech') || n.contains('5890')) { target = d; break; }
      }
      if (target == null) return;
      if (bt != null && bt!.isConnected) return;
      try { bt = await BluetoothConnection.toAddress(target.address); } catch (_) {}
      if (bt?.isConnected ?? false) {
        await sp.setString('saved_printer_mac', target.address);
        await sp.setString('saved_printer_name', target.name ?? 'Printer');
        if (!mounted) return;
        setState(() { printerName = target!.name ?? 'Printer'; });
      }
    } catch (_) {}
  }

  Future<void> pickPrinter() async {
    await Permission.bluetoothConnect.request();
    await Permission.bluetoothScan.request();
    await Permission.locationWhenInUse.request();
    try {
      final bonded = await FlutterBluetoothSerial.instance.getBondedDevices();
      if (!mounted) return;
      if (bonded.isEmpty) return;
      showModalBottomSheet(
        context: context,
        builder: (_) => ListView(
          children: bonded.map((d) => ListTile(
            title: Text(d.name ?? 'Printer'),
            subtitle: Text(d.address),
            onTap: () async {
              Navigator.pop(context);
              bool ok = false;
              try { bt = await BluetoothConnection.toAddress(d.address); ok = bt?.isConnected ?? false; } catch (_) { ok = false; }
              if (ok) {
                final sp = await SharedPreferences.getInstance();
                await sp.setString('saved_printer_mac', d.address);
                await sp.setString('saved_printer_name', d.name ?? 'Printer');
              }
              if (!mounted) return;
              setState(() { printerName = ok ? (d.name ?? 'Printer') : 'غير متصلة'; });
            },
          )).toList(),
        ),
      );
    } catch (_) {}
  }

  Future<void> createCards() async {
    setState(() { busy = true; msg = ''; created = []; });
    try {
      final rnd = Random();
      final names = <String>[];
      for (int i = 0; i < count; i++) {
        names.add('${1000000 + rnd.nextInt(9000000)}');
      }
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      for (final name in names) {
        final res = await MikroTikApi().run(widget.host, widget.user, widget.pass, '/ip/hotspot/user/add', ['=name=$name', '=password=', '=profile=$profile', '=server=all', '=comment=created:$todayStr']);
        if (res.any((m) => m['__type__'] == '!trap')) throw Exception('create failed');
        final check = await MikroTikApi().run(widget.host, widget.user, widget.pass, '/ip/hotspot/user/print');
        final found = check.where((m) => m['name'] == name).toList();
        if (found.isEmpty) throw Exception('not found');
        final id = found.first['.id'] ?? '';
        if (id.isNotEmpty) {
          try { await MikroTikApi().run(widget.host, widget.user, widget.pass, '/ip/hotspot/user/set', ['=numbers=$id', '=limit-uptime=${daysForProfile(profile)}d']); } catch (_) {}
          try { await MikroTikApi().run(widget.host, widget.user, widget.pass, '/ip/hotspot/user/set', ['=numbers=$id', '=limit-bytes-total=${bytesFor(profile)}']); } catch (_) {}
        }
      }
      setState(() { created = names; msg = 'تم إنشاء $count كارت بنجاح'; });
    } catch (_) {
      setState(() { msg = 'تعذر إنشاء الكارت'; });
    }
    setState(() { busy = false; });
  }

  Future<void> printCards() async {
    if (created.isEmpty) { setState(() { msg = 'أنشئ كارت أولاً'; }); return; }
    if (bt == null || !(bt?.isConnected ?? false)) {
      setState(() { msg = 'جارٍ الاتصال بالطابعة أوتوماتيك...'; });
      autoTried = false;
      await autoConnectPrinter();
      if (bt == null || !(bt?.isConnected ?? false)) { setState(() { msg = 'اختر الطابعة أولاً'; }); return; }
    }
    try {
      for (final num in created) {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, 384, 220));
        canvas.drawRect(ui.Rect.fromLTWH(0, 0, 384, 220), ui.Paint()..color = const Color(0xFFFFFFFF));
        void drawText(String text, double y, double size, bool bold) {
          final builder = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: ui.TextAlign.center, fontSize: size, fontWeight: bold ? ui.FontWeight.bold : ui.FontWeight.normal, textDirection: ui.TextDirection.ltr));
          builder.pushStyle(ui.TextStyle(color: const Color(0xFF000000), fontSize: size, fontWeight: bold ? ui.FontWeight.bold : ui.FontWeight.normal));
          builder.addText(text);
          builder.pop();
          final p = builder.build()..layout(ui.ParagraphConstraints(width: 384));
          canvas.drawParagraph(p, ui.Offset(0, y));
        }
        drawText('FAZLAKA', 10, 42, true);
        drawText('01016620065 - 01141418040', 70, 22, false);
        drawText('------------------------------', 105, 22, false);
        drawText(num, 130, 58, true);
        drawText('Price: $profile | Quota: ${quotaFor(profile)}GB', 195, 22, false);
        final pic = recorder.endRecording();
        final img = await pic.toImage(384, 220);
        final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
        final rgba = byteData!.buffer.asUint8List();
        final mono = <int>[];
        for (int y = 0; y < 220; y++) {
          for (int x = 0; x < 384; x += 8) {
            int b = 0;
            for (int bit = 0; bit < 8; bit++) {
              final idx = (y * 384 + x + bit) * 4;
              final r = rgba[idx];
              final g = rgba[idx + 1];
              final bl = rgba[idx + 2];
              final gray = (r + g + bl) ~/ 3;
              if (gray < 150) b |= (0x80 >> bit);
            }
            mono.add(b);
          }
        }
        final bytes = <int>[];
        bytes.addAll([0x1B, 0x40]);
        bytes.addAll([0x1B, 0x61, 0x01]);
        bytes.addAll([0x1D, 0x76, 0x30, 0x00, 48, 0, 220, 0]);
        bytes.addAll(mono);
        bytes.addAll([0x0A, 0x0A, 0x0A]);
        bytes.addAll([0x1D, 0x56, 0x00]);
        bt!.output.add(Uint8List.fromList(bytes));
        await bt!.output.allSent;
        await Future.delayed(const Duration(milliseconds: 800));
      }
      setState(() { msg = 'تمت الطباعة'; });
    } catch (_) {
      setState(() { msg = 'تعذر الطباعة'; });
    }
  }

  @override
  void dispose() {
    try { bt?.close(); } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(
              children: [
                const Align(alignment: Alignment.centerRight, child: Text('انشاء كروت', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: petrol))),
                const SizedBox(height: 16),
                Row(children: ['20', '50'].map((p) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: GestureDetector(onTap: () => setState(() => profile = p), child: Container(height: 58, decoration: BoxDecoration(color: profile == p ? petrol : const Color(0xFFEDEDED), borderRadius: BorderRadius.circular(14)), alignment: Alignment.center, child: Text(p, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: profile == p ? Colors.white : Colors.black))))))).toList()),
                const SizedBox(height: 8),
                Row(children: ['100', '200'].map((p) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: GestureDetector(onTap: () => setState(() => profile = p), child: Container(height: 58, decoration: BoxDecoration(color: profile == p ? petrol : const Color(0xFFEDEDED), borderRadius: BorderRadius.circular(14)), alignment: Alignment.center, child: Text(p, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: profile == p ? Colors.white : Colors.black))))))).toList()),
                const SizedBox(height: 8),
                Text('${quotaFor(profile)} جيجا - ${daysForProfile(profile)} يوم', style: const TextStyle(fontWeight: FontWeight.bold, color: petrol)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('عدد الكروت', style: TextStyle(fontSize: 16)),
                    Row(children: [IconButton(onPressed: () => setState(() => count++), icon: const Icon(Icons.add)), Text('$count', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), IconButton(onPressed: () { if (count > 1) setState(() => count--); }, icon: const Icon(Icons.remove))]),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, height: 52, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: petrol, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), onPressed: busy ? null : createCards, child: const Text('انشاء', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)))),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, height: 52, child: OutlinedButton(style: OutlinedButton.styleFrom(side: const BorderSide(color: petrol), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), onPressed: printCards, child: const Text('طباعة', style: TextStyle(color: petrol, fontSize: 18, fontWeight: FontWeight.bold)))),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: petrol))), onPressed: pickPrinter, icon: const Icon(Icons.bluetooth, color: petrol), label: Text(printerName == 'غير متصلة' ? 'توصيل الطابعة - أوتوماتيك' : 'الطابعة: $printerName', style: const TextStyle(color: petrol, fontSize: 16, fontWeight: FontWeight.bold)))),
          const SizedBox(height: 12),
          if (msg.isNotEmpty) Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
          if (created.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  const Align(alignment: Alignment.centerRight, child: Text('الكروت الجاهزة', style: TextStyle(fontWeight: FontWeight.bold))),
                  const SizedBox(height: 8),
                  for (final c in created)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(children: [const Text('FAZLAKA', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 3)), const Text('01016620065 - 01141418040'), const Text('------------------------------'), Text(c, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)), Text('Price: $profile | Quota: ${quotaFor(profile)}GB')]),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
