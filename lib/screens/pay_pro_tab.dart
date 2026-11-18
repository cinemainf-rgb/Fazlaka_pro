import 'package:flutter/material.dart';
import '../core/colors.dart';

class PayProTab extends StatefulWidget {
  final String host, user, pass;
  const PayProTab({super.key, required this.host, required this.user, required this.pass});

  @override
  State<PayProTab> createState() => _PayProTabState();
}

class _PayProTabState extends State<PayProTab> {
  double todaySales = 0;
  double todayProfit = 0;
  int operationsCount = 0;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _statCard('ربح اليوم', '$todayProfit', Colors.amber)),
              const SizedBox(width: 10),
              Expanded(child: _statCard('المبيعات', '$todaySales', Colors.green)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _statCard('الديون', '0', Colors.red)),
              const SizedBox(width: 10),
              Expanded(child: _statCard('النقدية (الدرج)', '0', Colors.blue)),
            ],
          ),
          const SizedBox(height: 10),
          _statCard('عدد العمليات', '$operationsCount', petrol, fullWidth: true),
          
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('المكن', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: petrol)),
                    Icon(Icons.atm, color: petrol, size: 30),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _machineBtn('فوري رئيسي'),
                    _machineBtn('فوري كروت'),
                    _machineBtn('فوري كاش أوت'),
                    _machineBtn('بساطة'),
                    _machineBtn('موبايل'),
                    _machineBtn('كاش مصر'),
                  ],
