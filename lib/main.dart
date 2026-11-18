import 'package:flutter/material.dart';
import 'core/colors.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const FazlakaApp());
}

class FazlakaApp extends StatelessWidget {
  const FazlakaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fazlaka Pay Pro',
      theme: ThemeData(
        scaffoldBackgroundColor: bgColor,
        primaryColor: petrol,
      ),
      home: const SplashScreen(),
    );
  }
}
