import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../core/colors.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkFingerprint();
  }

  Future<void> _checkFingerprint() async {
    final auth = LocalAuthentication();
    try {
      final canCheck = await auth.canCheckBiometrics;
      if (canCheck) {
        final ok = await auth.authenticate(
          localizedReason: 'افتح بصمتك للدخول لـ FAZLAKA',
          options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
        );
        if (ok) {
          _goToLogin();
          return;
        }
        // لو لغى البصمة، نسيبه على الشاشة ويضغط الزرار
        return;
      } else {
        _goToLogin();
      }
    } catch (_) {
      _goToLogin();
    }
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: petrol,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fingerprint, size: 100, color: Colors.white),
            const SizedBox(height: 20),
            const Text('FAZLAKA PAY PRO', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 20),
            TextButton(
              onPressed: _checkFingerprint,
              child: const Text('اضغط للمحاولة مرة أخرى', style: TextStyle(color: Colors.white70)),
            )
          ],
        ),
      ),
    );
  }
}
