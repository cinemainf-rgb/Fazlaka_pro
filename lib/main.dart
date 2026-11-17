import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';
import 'package:local_auth/local_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const FazlakaPayProApp());
}

const Color petrol = Color(0xFF0A3D3E);
const Color bgColor = Color(0xFFDFF5F2);

class FazlakaPayProApp extends StatelessWidget {
  const FazlakaPayProApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FingerLock(
        child: PayProHome(),
      ),
    );
  }
}

class FingerLock extends StatefulWidget {
  final Widget child;
  const FingerLock({super.key, required this.child});
  @override
  State<FingerLock> createState() => _FingerLockState();
}

class _FingerLockState extends State<FingerLock> {
  bool unlocked = false;
  bool noFinger = false;

  @override
  void initState() {
    super.initState();
    tryFinger();
  }

  Future<void> tryFinger() async {
    final auth = LocalAuthentication();
    try {
      final can = await auth.canCheckBiometrics;
      if (!can) {
        setState(() {
          noFinger = true;
        });
        return;
      }
      final ok = await auth.authenticate(
        localizedReason: 'افتح بصمتك عشان تدخل FAZLAKA PAY PRO',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (ok) {
        setState(() {
          unlocked = true;
        });
      }
    } catch (_) {
      setState(() {
        noFinger = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (unlocked || noFinger) {
      return widget.child;
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: bgColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'FAZLAKA PAY PRO',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: petrol,
                ),
              ),
              const SizedBox(height: 20),
              const Icon(Icons.fingerprint, size: 90, color: petrol),
              const SizedBox(height: 20),
              const Text(
                'حط بصمتك عشان تفتح',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: petrol),
                onPressed: tryFinger,
                child: const Text(
                  'جرب البصمة تاني',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String quotaFor(String p) {
  if (p == '20') return '2';
  if (p == '50') return '8';
  if (p == '100') return '20';
  if (p == '200') return '45';
  return '2';
}

int daysForProfile(String p) {
  if (p == '20') return 3;
  if (p == '50') return 15;
  if (p == '100') return 30;
  if (p == '200') return 30;
  return 30;
}

String bytesFor(String p) {
  if (p == '20') return '2147483648';
  if (p == '50') return '8589934592';
  if (p == '100') return '21474836480';
  if (p == '200') return '48318382080';
  return '2147483648';
}

class MikroTikApi {
  Socket? socket;
  List<int> buf = [];

  Future<List<Map<String, String>>> run(
    String host,
    String user,
    String pass,
    String cmd,
    [List<String> args = const []],
  ) async {
    try {
      return await runLogin(host, user, pass, cmd, args, true);
    } catch (_) {
      return await runLogin(host, user, pass, cmd, args, false);
    }
  }

  Future<List<Map<String, String>>> runLogin(
    String host,
    String user,
    String pass,
    String cmd,
    List<String> args,
    bool useChallenge,
  ) async {
    buf = [];
    try {
      socket = await Socket.connect(host, 8728, timeout: const Duration(seconds: 8));
      socket!.listen((d) {
        buf.addAll(d);
      });
      if (useChallenge) {
        final chal = await loginStep(user);
        List<int> hexToBytes(String hex) {
          final out = <int>[];
          for (int i = 0; i < hex.length; i += 2) {
            out.add(int.parse(hex.substring(i, i + 2), radix: 16));
          }
          return out;
        }
        final resp = md5.convert([0, ...utf8.encode(pass), ...hexToBytes(chal)]).toString();
        await send(['/login', '=name=$user', '=response=00$resp']);
      } else {
        await send(['/login', '=name=$user', '=password=$pass']);
      }
      final loginRes = await readSentence();
      if (loginRes.any((m) => m['__type__'] == '!trap')) {
        throw Exception('login failed');
      }
      await send([cmd, ...args]);
      final result = await readAll();
      return result;
    } finally {
      try {
        await socket?.close();
      } catch (_) {}
      socket = null;
      buf = [];
    }
  }

  Future<String> loginStep(String user) async {
    await send(['/login', '=name=$user']);
    final res = await readSentence();
    for (final m in res) {
      if (m.containsKey('ret')) return m['ret']!;
    }
    throw Exception('no challenge');
  }

  Future<void> send(List<String> words) async {
    final out = <int>[];
    for (final w in words) {
      final b = utf8.encode(w);
      if (b.length < 0x80) {
        out.add(b.length);
      } else if (b.length < 0x4000) {
        out.add(0x80 | (b.length >> 8));
        out.add(b.length & 0xFF);
      } else {
        out.add(0xC0 | (b.length >> 16));
        out.add((b.length >> 8) & 0xFF);
        out.add(b.length & 0xFF);
      }
      out.addAll(b);
    }
    out.add(0);
    socket!.add(out);
    await socket!.flush();
  }

  Future<List<Map<String, String>>> readSentence() async {
    while (true) {
      final parsed = tryParse();
      if (parsed != null) return parsed;
      await Future.delayed(const Duration(milliseconds: 20));
    }
  }

  Future<List<Map<String, String>>> readAll() async {
    final all = <Map<String, String>>[];
    while (true) {
      final s = await readSentence();
      all.addAll(s);
      if (s.any((m) => m['__type__'] == '!done')) break;
    }
    return all;
  }

  List<Map<String, String>>? tryParse() {
    int pos = 0;
    final result = <Map<String, String>>[];
    var cur = <String, String>{};
    while (pos < buf.length) {
      int len = buf[pos];
      pos++;
      if (len == 0) {
        if (cur.isNotEmpty) {
          result.add(cur);
          cur = <String, String>{};
        }
        buf = buf.sublist(pos);
        return result;
      }
      if ((len & 0x80) != 0) {
        if ((len & 0xC0) == 0x80) {
          if (pos >= buf.length) return null;
          len = ((len & 0x3F) << 8) | buf[pos];
          pos++;
        } else if ((len & 0xE0) == 0xC0) {
          if (pos + 1 >= buf.length) return null;
          len = ((len & 0x1F) << 16) | (buf[pos] << 8) | buf[pos + 1];
          pos += 2;
        } else {
          return null;
        }
      }
      if (pos + len > buf.length) return null;
      final word = utf8.decode(buf.sublist(pos, pos + len), allowMalformed: true);
      pos += len;
      if (word.startsWith('!')) {
        if (cur.isNotEmpty) {
          result.add(cur);
          cur = <String, String>{};
        }
        cur['__type__'] = word;
      } else if (word.startsWith('=')) {
        final eq = word.indexOf('=', 1);
        if (eq > 0) {
          cur[word.substring(1, eq)] = word.substring(eq + 1);
        }
      }
    }
    return null;
  }
}

class PayProHome extends StatefulWidget {
  const PayProHome({super.key});
  @override
  State<PayProHome> createState() => _PayProHomeState();
}

class _PayProHomeState extends State<PayProHome> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    if (tab == 1) {
      return Scaffold(
        body: const FazlakaApp(),
        bottomNavigationBar: bottomBar(),
      );
    }
    if (tab == 2) {
      return Scaffold(
        body: const PayProScreen(),
        bottomNavigationBar: bottomBar(),
      );
    }
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: petrol,
        title: const Text('FAZLAKA PAY PRO', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text(
              'FAZLAKA PAY PRO',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: petrol),
            ),
            const Text('01016620065 - 01141418040'),
            const SizedBox(height: 30),
            GestureDetector(
              onTap: () {
                setState(() {
                  tab = 1;
                });
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: petrol, borderRadius: BorderRadius.circular(20)),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.wifi, color: Colors.white, size: 40),
                    SizedBox(height: 12),
                    Text('FAZLAKA', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    Text('كروت - هوتسبوت - PPPoE - مبيعات', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                setState(() {
                  tab = 2;
                });
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.account_balance_wallet, color: petrol, size: 40),
                    SizedBox(height: 12),
                    Text('Pay Pro', style: TextStyle(color: petrol, fontSize: 24, fontWeight: FontWeight.bold)),
                    Text('محفظة - شحن - دفع فواتير - تحويل', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: bottomBar(),
    );
  }

  Widget bottomBar() {
    return BottomNavigationBar(
      currentIndex: tab,
      backgroundColor: petrol,
      selectedItemColor: Colors.white,
      unselectedItemColor: Colors.white70,
      type: BottomNavigationBarType.fixed,
      onTap: (i) {
        setState(() {
          tab = i;
        });
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'الرئيسية'),
        BottomNavigationBarItem(icon: Icon(Icons.wifi), label: 'FAZLAKA'),
        BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Pay Pro'),
      ],
    );
  }
}

class PayProScreen extends StatefulWidget {
  const PayProScreen({super.key});
  @override
  State<PayProScreen> createState() => _PayProScreenState();
}

class _PayProScreenState extends State<PayProScreen> {
  int tab = 0;
  List<Map<String, dynamic>> wallets = [];
  List<Map<String, dynamic>> sales = [];
  String selectedMachine = 'فوري رئيسي';
  final nameCtrl = TextEditingController();
  final qtyCtrl = TextEditingController();
  final buyCtrl = TextEditingController();
  final sellCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final sp = await SharedPreferences.getInstance();
    final wRaw = sp.getString('pay_wallets');
    if (wRaw != null) {
      wallets = List<Map<String, dynamic>>.from(jsonDecode(wRaw));
    } else {
      wallets = [
        {'name': 'الخزنة الرئيسية', 'bal': 0.0, 'limit': 0.0},
        {'name': 'نقدية (كاش الدرج)', 'bal': 0.0, 'limit': 0.0},
        {'name': 'إنستاباي', 'bal': 0.0, 'limit': 4000.0},
        {'name': 'فودافون كاش', 'bal': 0.0, 'limit': 2000.0},
        {'name': 'فوري رئيسي', 'bal': 0.0, 'limit': 0.0},
        {'name': 'فوري كروت', 'bal': 0.0, 'limit': 0.0},
        {'name': 'فوري كاش أوت', 'bal': 0.0, 'limit': 0.0},
        {'name': 'بساطة', 'bal': 0.0, 'limit': 0.0},
        {'name': 'موبايل', 'bal': 0.0, 'limit': 0.0},
        {'name': 'كاش مصر', 'bal': 0.0, 'limit': 0.0},
      ];
    }
    final sRaw = sp.getString('pay_sales2');
    if (sRaw != null) {
      sales = List<Map<String, dynamic>>.from(jsonDecode(sRaw));
    }
    setState(() {});
  }

  Future<void> saveData() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('pay_wallets', jsonEncode(wallets));
    await sp.setString('pay_sales2', jsonEncode(sales));
  }

  double get todaySales {
    final today = DateTime.now().toString().substring(0, 10);
    double t = 0;
    for (final s in sales) {
      if ((s['date'] ?? '').toString().startsWith(today)) {
        t += (s['total'] as num).toDouble();
      }
    }
    return t;
  }

  double get todayProfit {
    final today = DateTime.now().toString().substring(0, 10);
    double t = 0;
    for (final s in sales) {
      if ((s['date'] ?? '').toString().startsWith(today)) {
        t += (s['profit'] as num).toDouble();
      }
    }
    return t;
  }

  Future<void> charge() async {
    final c = TextEditingController();
    final amt = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('شحن'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'المبلغ'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('الغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, double.tryParse(c.text) ?? 0),
            child: const Text('شحن'),
          ),
        ],
      ),
    );
    if (amt != null && amt > 0) {
      setState(() {
        final i = wallets.indexWhere((e) => e['name'] == selectedMachine);
        if (i >= 0) {
          wallets[i]['bal'] = (wallets[i]['bal'] as num).toDouble() + amt;
        }
        sales.insert(0, {
          'name': 'شحن $selectedMachine',
          'total': amt,
          'profit': 0,
          'date': DateTime.now().toString(),
        });
      });
      await saveData();
    }
  }

  Future<void> addProduct() async {
    final name = nameCtrl.text.trim();
    final qty = double.tryParse(qtyCtrl.text) ?? 0;
    final buy = double.tryParse(buyCtrl.text) ?? 0;
    final sell = double.tryParse(sellCtrl.text) ?? 0;
    if (name.isEmpty || qty <= 0 || sell <= 0) return;
    setState(() {
      sales.insert(0, {
        'name': name,
        'total': qty * sell,
        'profit': qty * (sell - buy),
        'date': DateTime.now().toString(),
      });
      nameCtrl.clear();
      qtyCtrl.clear();
      buyCtrl.clear();
      sellCtrl.clear();
    });
    await saveData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: petrol,
        title: const Text('Fazlaka Pay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: topCard('ربح اليوم', '$todayProfit')),
                const SizedBox(width: 10),
                Expanded(child: topCard('المبيعات', '$todaySales')),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('عدد العمليات', style: TextStyle(color: Colors.grey)),
                  Text('${sales.length}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (tab == 0) machineTab(),
            if (tab == 1) salesTab(),
            if (tab == 2) walletsTab(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: tab,
        backgroundColor: Colors.white,
        selectedItemColor: petrol,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (i) {
          setState(() {
            tab = i;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.atm), label: 'المكن'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'مبيعات'),
          BottomNavigationBarItem(icon: Icon(Icons.credit_card), label: 'المحافظ'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: petrol,
        onPressed: charge,
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
    );
  }

  Widget topCard(String title, String val) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          Text(val, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget machineTab() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text('المكن', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: wallets.map((w) {
              final sel = selectedMachine == w['name'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedMachine = w['name'];
                  });
                },
                child: Container(
                  width: 100,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: sel ? petrol : const Color(0xFFEFF8F7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(w['name'], textAlign: TextAlign.center, style: TextStyle(color: sel ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                      Text('${w['bal']}', style: TextStyle(color: sel ? Colors.white : Colors.black)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: petrol),
              onPressed: charge,
              child: const Text('شحن', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget salesTab() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text('المبيعات - إضافة منتج', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          TextField(controller: nameCtrl, textAlign: TextAlign.right, decoration: InputDecoration(hintText: 'اسم المنتج / الموديل', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: TextField(controller: qtyCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.right, decoration: InputDecoration(hintText: 'الكمية', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: buyCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.right, decoration: InputDecoration(hintText: 'سعر الشراء', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
            ],
          ),
          const SizedBox(height: 10),
          TextField(controller: sellCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.right, decoration: InputDecoration(hintText: 'سعر البيع', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: petrol),
              onPressed: addProduct,
              child: const Text('إضافة منتج', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
          ...sales.take(10).map((s) => ListTile(
                title: Text(s['name'] ?? '', textAlign: TextAlign.right),
                trailing: Text('${s['total']} ج', style: const TextStyle(fontWeight: FontWeight.bold)),
              )),
        ],
      ),
    );
  }

  Widget walletsTab() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text('المحافظ والخزنة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...wallets.map((w) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(w['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                    Text('الرصيد: ${w['bal']}'),
                    Text('الليميت: ${w['limit']}'),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class FazlakaApp extends StatefulWidget {
  const FazlakaApp({super.key});
  @override
  State<FazlakaApp> createState() => _FazlakaAppState();
}

class _FazlakaAppState extends State<FazlakaApp> {
  bool logged = false;
  String host = '10.10.10.1';
  String user = '';
  String pass = '';

  @override
  Widget build(BuildContext context) {
    if (!logged) {
      return LoginScreen(
        onLogin: (h, u, p) {
          setState(() {
            host = h;
            user = u;
            pass = p;
            logged = true;
          });
        },
      );
    }
    return HomeScreen(
      host: host,
      user: user,
      pass: pass,
      onLogout: () {
        setState(() {
          logged = false;
        });
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  final void Function(String, String, String) onLogin;
  const LoginScreen({super.key, required this.onLogin});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final hostCtrl = TextEditingController(text: '10.10.10.1');
  final userCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool busy = false;
  String msg = '';

  Future<void> doLogin() async {
    final h = hostCtrl.text.trim();
    final u = userCtrl.text.trim();
    final p = passCtrl.text;
    setState(() {
      busy = true;
      msg = '';
    });
    try {
      await MikroTikApi().run(h, u, p, '/system/resource/print');
      widget.onLogin(h, u, p);
    } catch (_) {
      setState(() {
        msg = 'يوزر أو باسورد غلط';
      });
    }
    setState(() {
      busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: petrol,
        title: const Text('FAZLAKA', style: TextStyle(color: Colors.white, letterSpacing: 4)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text('FAZLAKA', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: petrol, letterSpacing: 4)),
            const SizedBox(height: 24),
            TextField(controller: hostCtrl, decoration: InputDecoration(labelText: 'Server IP', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
            const SizedBox(height: 12),
            TextField(controller: userCtrl, decoration: InputDecoration(labelText: 'اسم المستخدم', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
            const SizedBox(height: 12),
            TextField(controller: passCtrl, obscureText: true, decoration: InputDecoration(labelText: 'كلمة السر', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: petrol, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: busy ? null : doLogin,
                child: Text(busy ? '...' : 'دخول / CONNECT', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            if (msg.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(msg, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final String host;
  final String user;
  final String pass;
  final VoidCallback onLogout;
  const HomeScreen({super.key, required this.host, required this.user, required this.pass, required this.onLogout});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: petrol,
        title: const Text('FAZLAKA', style: TextStyle(color: Colors.white, letterSpacing: 4)),
        centerTitle: true,
        actions: [
          IconButton(onPressed: widget.onLogout, icon: const Icon(Icons.logout, color: Colors.white)),
        ],
      ),
      body: tab == 0
          ? HomeTab(host: widget.host, user: widget.user, pass: widget.pass)
          : CardsTab(host: widget.host, user: widget.user, pass: widget.pass),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: tab,
        backgroundColor: petrol,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        type: BottomNavigationBarType.fixed,
        onTap: (i) {
          setState(() {
            tab = i;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'الرئيسية'),
          BottomNavigationBarItem(icon: Icon(Icons.card_membership), label: 'الكروت'),
        ],
      ),
    );
  }
}

class HomeTab extends StatefulWidget {
  final String host;
  final String user;
  final String pass;
  const HomeTab({super.key, required this.host, required this.user, required this.pass});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
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
        if (savedMac.isNotEmpty && d.address == savedMac) {
          target = d;
          break;
        }
        if (n.contains('razytech') || n.contains('5890')) {
          target = d;
          break;
        }
      }
      if (target == null) return;
      if (bt != null && bt!.isConnected) return;
      try {
        bt = await BluetoothConnection.toAddress(target.address);
      } catch (_) {}
      if (bt?.isConnected ?? false) {
        await sp.setString('saved_printer_mac', target.address);
        await sp.setString('saved_printer_name', target.name ?? 'Printer');
        if (!mounted) return;
        setState(() {
          printerName = target!.name ?? 'Printer';
        });
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
          children: bonded
              .map((d) => ListTile(
                    title: Text(d.name ?? 'Printer'),
                    subtitle: Text(d.address),
                    onTap: () async {
                      Navigator.pop(context);
                      bool ok = false;
                      try {
                        bt = await BluetoothConnection.toAddress(d.address);
                        ok = bt?.isConnected ?? false;
                      } catch (_) {
                        ok = false;
                      }
                      if (ok) {
                        final sp = await SharedPreferences.getInstance();
                        await sp.setString('saved_printer_mac', d.address);
                        await sp.setString('saved_printer_name', d.name ?? 'Printer');
                      }
                      if (!mounted) return;
                      setState(() {
                        printerName = ok ? (d.name ?? 'Printer') : 'غير متصلة';
                      });
                    },
                  ))
              .toList(),
        ),
      );
    } catch (_) {}
  }

  Future<void> createCards() async {
    setState(() {
      busy = true;
      msg = '';
      created = [];
    });
    try {
      final rnd = Random();
      final names = <String>[];
      for (int i = 0; i < count; i++) {
        names.add('${1000000 + rnd.nextInt(9000000)}');
      }
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      for (final name in names) {
        final res = await MikroTikApi().run(widget.host, widget.user, widget.pass, '/ip/hotspot/user/add', [
          '=name=$name',
          '=password=',
          '=profile=$profile',
          '=server=all',
          '=comment=created:$todayStr',
        ]);
        if (res.any((m) => m['__type__'] == '!trap')) {
          throw Exception('create failed');
        }
        final check = await MikroTikApi().run(widget.host, widget.user, widget.pass, '/ip/hotspot/user/print');
        final found = check.where((m) => m['name'] == name).toList();
        if (found.isEmpty) throw Exception('not found');
        final id = found.first['.id'] ?? '';
        if (id.isNotEmpty) {
          try {
            await MikroTikApi().run(widget.host, widget.user, widget.pass, '/ip/hotspot/user/set', [
              '=numbers=$id',
              '=limit-uptime=${daysForProfile(profile)}d',
            ]);
          } catch (_) {}
          try {
            await MikroTikApi().run(widget.host, widget.user, widget.pass, '/ip/hotspot/user/set', [
              '=numbers=$id',
              '=limit-bytes-total=${bytesFor(profile)}',
            ]);
          } catch (_) {}
        }
      }
      setState(() {
        created = names;
        msg = 'تم إنشاء $count كارت بنجاح';
      });
    } catch (_) {
      setState(() {
        msg = 'تعذر إنشاء الكارت';
      });
    }
    setState(() {
      busy = false;
    });
  }

  Future<void> printCards() async {
    if (created.isEmpty) {
      setState(() {
        msg = 'أنشئ كارت أولاً';
      });
      return;
    }
    if (bt == null || !(bt?.isConnected ?? false)) {
      setState(() {
        msg = 'جارٍ الاتصال بالطابعة أوتوماتيك...';
      });
      autoTried = false;
      await autoConnectPrinter();
      if (bt == null || !(bt?.isConnected ?? false)) {
        setState(() {
          msg = 'اختر الطابعة أولاً';
        });
        return;
      }
    }
    try {
      for (final num in created) {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, 384, 220));
        canvas.drawRect(ui.Rect.fromLTWH(0, 0, 384, 220), ui.Paint()..color = const Color(0xFFFFFFFF));
        void drawText(String text, double y, double size, bool bold) {
          final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
            textAlign: ui.TextAlign.center,
            fontSize: size,
            fontWeight: bold ? ui.FontWeight.bold : ui.FontWeight.normal,
            textDirection: ui.TextDirection.ltr,
          ));
          builder.pushStyle(ui.TextStyle(
            color: const Color(0xFF000000),
            fontSize: size,
            fontWeight: bold ? ui.FontWeight.bold : ui.FontWeight.normal,
          ));
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
      setState(() {
        msg = 'تمت الطباعة';
      });
    } catch (_) {
      setState(() {
        msg = 'تعذر الطباعة';
      });
    }
  }

  @override
  void dispose() {
    try {
      bt?.close();
    } catch (_) {}
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
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text('انشاء كروت', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: petrol)),
                ),
                const SizedBox(height: 16),
                Row(
                  children: ['20', '50'].map((p) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              profile = p;
                            });
                          },
                          child: Container(
                            height: 58,
                            decoration: BoxDecoration(color: profile == p ? petrol : const Color(0xFFEDEDED), borderRadius: BorderRadius.circular(14)),
                            alignment: Alignment.center,
                            child: Text(p, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: profile == p ? Colors.white : Colors.black)),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: ['100', '200'].map((p) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              profile = p;
                            });
                          },
                          child: Container(
                            height: 58,
                            decoration: BoxDecoration(color: profile == p ? petrol : const Color(0xFFEDEDED), borderRadius: BorderRadius.circular(14)),
                            alignment: Alignment.center,
                            child: Text(p, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: profile == p ? Colors.white : Colors.black)),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Text('${quotaFor(profile)} جيجا - ${daysForProfile(profile)} يوم', style: const TextStyle(fontWeight: FontWeight.bold, color: petrol)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('عدد الكروت', style: TextStyle(fontSize: 16)),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            setState(() {
                              count++;
                            });
                          },
                          icon: const Icon(Icons.add),
                        ),
                        Text('$count', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        IconButton(
                          onPressed: () {
                            if (count > 1) {
                              setState(() {
                                count--;
                              });
                            }
                          },
                          icon: const Icon(Icons.remove),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: petrol, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: busy ? null : createCards,
              child: const Text('انشاء', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(side: const BorderSide(color: petrol), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: printCards,
              child: const Text('طباعة', style: TextStyle(color: petrol, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: petrol))),
              onPressed: pickPrinter,
              icon: const Icon(Icons.bluetooth, color: petrol),
              label: Text(printerName == 'غير متصلة' ? 'توصيل الطابعة - أوتوماتيك' : 'الطابعة: $printerName', style: const TextStyle(color: petrol, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
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
                      child: Column(
                        children: [
                          const Text('FAZLAKA', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 3)),
                          const Text('01016620065 - 01141418040'),
                          const Text('------------------------------'),
                          Text(c, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                          Text('Price: $profile | Quota: ${quotaFor(profile)}GB'),
                        ],
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

class CardsTab extends StatefulWidget {
  final String host;
  final String user;
  final String pass;
  const CardsTab({super.key, required this.host, required this.user, required this.pass});
  @override
  State<CardsTab> createState() => _CardsTabState();
}

class _CardsTabState extends State<CardsTab> {
  List<Map<String, String>> active = [];
  List<Map<String, String>> all = [];
  bool loading = false;
  String status = '';

  @override
  void initState() {
    super.initState();
    loadCards();
  }

  Future<void> loadCards() async {
    setState(() {
      loading = true;
    });
    try {
      final a = await MikroTikApi().run(widget.host, widget.user, widget.pass, '/ip/hotspot/active/print');
      final u = await MikroTikApi().run(widget.host, widget.user, widget.pass, '/ip/hotspot/user/print');
      setState(() {
        active = a;
        all = u;
        status = 'متصل';
      });
    } catch (_) {
      setState(() {
        status = 'غير متصل';
      });
    }
    setState(() {
      loading = false;
    });
  }

  Future<void> kickActive(String id) async {
    try {
      await MikroTikApi().run(widget.host, widget.user, widget.pass, '/ip/hotspot/active/remove', ['=numbers=$id']);
      loadCards();
    } catch (_) {}
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('حالة الراوتر', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(status),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('النشط: ${active.length} | الكروت: ${all.length}'),
          const SizedBox(height: 12),
          if (loading) const CircularProgressIndicator(),
          ...active.map((m) {
            final name = m['user'] ?? '';
            final id = m['.id'] ?? '';
            return Card(
              child: ListTile(
                title: Text('$name - نشط'),
                subtitle: Text('${m['address'] ?? ''} - ${m['uptime'] ?? ''}'),
                trailing: IconButton(icon: const Icon(Icons.logout, color: Colors.red), onPressed: () => kickActive(id)),
              ),
            );
          }),
        ],
      ),
    );
  }
}
