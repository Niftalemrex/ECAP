import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // No logic needed – the router handles all navigation.
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}