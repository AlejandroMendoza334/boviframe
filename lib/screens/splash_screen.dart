import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _scaleAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();

    _initializeApp();

    Future.delayed(const Duration(milliseconds: 3500), () {
      final user = FirebaseAuth.instance.currentUser;
      final route = user != null ? '/main_menu' : '/login';
      Navigator.pushReplacementNamed(context, route);
    });
  }

  Future<void> _initializeApp() async {
    try {
      // Suscribirse al topic "news"
      await FirebaseMessaging.instance.subscribeToTopic("noticias");
    } catch (e) {
      print("Error al suscribirse al topic: $e");
    }

    await Future.delayed(const Duration(milliseconds: 3500));

    final user = FirebaseAuth.instance.currentUser;
    final route = user != null ? '/main_menu' : '/login';
    if (mounted) {
      Navigator.pushReplacementNamed(context, route);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Image.asset(
                  'assets/icons/logoapp3.png',
                  width: 200,
                  height: 200,
                ),
              ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(color: Colors.blue, strokeWidth: 3),
            const SizedBox(height: 16),
            const Text(
              'Iniciando BOVIFrame...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
