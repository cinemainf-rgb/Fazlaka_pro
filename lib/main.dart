import 'package:flutter/material.dart';

void main() => runApp(const FazlakaPayProApp());
const petrol = Color(0xFF0A3D3E);

class FazlakaPayProApp extends StatelessWidget {
  const FazlakaPayProApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFDFF5F2),
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
              const Text('FAZLAKA PAY PRO', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: petrol)),
              const Text('01016620065 - 01141418040'),
              const SizedBox(height: 30),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: petrol, borderRadius: BorderRadius.circular(20)),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.wifi, color: Colors.white, size: 40),
                    SizedBox(height: 12),
                    Text('FAZLAKA', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    Text('كروت - هوتسبوت - PPPoE', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.account_balance_wallet, color: petrol, size: 40),
                    SizedBox(height: 12),
                    Text('Pay Pro', style: TextStyle(color: petrol, fontSize: 24, fontWeight: FontWeight.bold)),
                    Text('محفظة - شحن - دفع فواتير', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
