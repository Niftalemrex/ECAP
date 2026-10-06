// lib/presentation/screens/parent/device_protection_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class DeviceProtectionScreen extends StatefulWidget {
  const DeviceProtectionScreen({super.key});

  @override
  State<DeviceProtectionScreen> createState() => _DeviceProtectionScreenState();
}

class _DeviceProtectionScreenState extends State<DeviceProtectionScreen> {
  static const adminChannel = MethodChannel('com.example.ecap/admin');

  bool _adminActive = false;
  bool _a11yActive = false;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    try {
      final admin = await adminChannel.invokeMethod('isAdminEnabled') as bool?;
      final a11y = await adminChannel.invokeMethod('isAccessibilityServiceEnabled') as bool?;
      setState(() {
        _adminActive = admin ?? false;
        _a11yActive = a11y ?? false;
      });
    } catch (e) {
      // ignore if channel not ready
    }
  }

  Future<void> _enableAdmin() async {
    await adminChannel.invokeMethod('enableAdmin');
    // Wait a bit for the system to update
    await Future.delayed(const Duration(milliseconds: 500));
    await _refreshStatus();
  }

  Future<void> _openAccessibility() async {
    await adminChannel.invokeMethod('openAccessibilitySettings');
    // User must manually toggle the switch; poll after they return
    await Future.delayed(const Duration(seconds: 1));
    await _refreshStatus();
  }

  @override
  Widget build(BuildContext context) {
    final allGood = _adminActive && _a11yActive;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primaryContainer,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Logo
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                allGood ? 'All Set!' : 'Activate Protection',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (!allGood)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'These are required to keep your child safe.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ),
              const SizedBox(height: 32),
              if (!_adminActive)
                _ProtectionButton(
                  icon: Icons.admin_panel_settings,
                  label: 'Enable Device Admin',
                  subtitle: 'Prevents uninstalling eCap',
                  onTap: _enableAdmin,
                ),
              const SizedBox(height: 12),
              if (!_a11yActive)
                _ProtectionButton(
                  icon: Icons.accessible,
                  label: 'Enable Accessibility',
                  subtitle: 'Allows eCap to block apps',
                  onTap: _openAccessibility,
                ),
              if (allGood) ...[
                const Icon(Icons.check_circle, size: 64, color: Colors.white),
                const SizedBox(height: 16),
                const Text('Your child is protected.',
                    style: TextStyle(color: Colors.white70)),
              ],
              const SizedBox(height: 24),
              TextButton(
                onPressed: () {
                  if (allGood) {
                    context.go('/login');
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enable both protections first')),
                    );
                  }
                },
                child: Text(
                  allGood ? 'Continue' : 'Skip anyway',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              const Spacer(),
              const Padding(
                padding: EdgeInsets.only(bottom: 32),
                child: Text(
                  'Powered by NiCol',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProtectionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ProtectionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.15),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }
}