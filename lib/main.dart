import 'package:flutter/material.dart';
import 'fazlaka/fazlaka_app.dart';
import 'pay/pay_app.dart';

void main() => runApp(const FazlakaPayProApp());
const petrol = Color(0xFF0A3D3E);
const bgColor = Color(0xFFDFF5F2);

class FazlakaPayProApp extends StatelessWidget {
  const FazlakaPayProApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(debugShowCheckedModeBanner: false, home: PayProHome());
  }
}

class PayProHome extends StatefulWidget {
  const PayProHome({super.key});
  @override State<PayProHome> createState() => _PayProHomeState();
}

class _PayProHomeState extends State<PayProHome> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) {
    if (_tab == 1) {
      return Scaffold(body: const FazlakaApp(), bottomNavigationBar: _bottomBar());
    }
    if (_tab == 2) {
      return Scaffold(body: const PayProScreen(), bottomNavigationBar: _bottomBar());
    }
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(backgroundColor: petrol, title: const Text('FAZLAKA PAY PRO', style: TextStyle(color: Colors.white)), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          const SizedBox(height: 20),
          const Text('FAZLAKA PAY PRO', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: petrol)),
          const Text('01016620065 - 01141418040'),
          const SizedBox(height: 30),
          GestureDetector(
            onTap: () => setState(() => _tab = 1),
            child: Container(width: double.infinity, padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: petrol, borderRadius: BorderRadius.circular(20)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.wifi, color: Colors.white, size: 40), SizedBox(height: 12), Text('FAZLAKA', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)), Text('كروت - هوتسبوت - PPPoE - مبيعات', style: TextStyle(color: Colors.white70))])),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => setState(() => _tab = 2),
            child: Container(width: double.infinity, padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.account_balance_wallet, color: petrol, size: 40), SizedBox(height: 12), Text('Pay Pro', style: TextStyle(color: petrol, fontSize: 24, fontWeight: FontWeight.bold)), Text('محفظة - شحن - دفع فواتير - تحويل', style: TextStyle(color: Colors.grey))])),
          ),
        ]),
      ),
      bottomNavigationBar: _bottomBar(),
    );
  }
  Widget _bottomBar() {
    return BottomNavigationBar(
      currentIndex: _tab,
      backgroundColor: petrol,
      selectedItemColor: Colors.white,
      unselectedItemColor: Colors.white70,
      type: BottomNavigationBarType.fixed,
      onTap: (i) => setState(() => _tab = i),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'الرئيسية'),
        BottomNavigationBarItem(icon: Icon(Icons.wifi), label: 'FAZLAKA'),
        BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Pay Pro'),
      ],
    );
  }
}
