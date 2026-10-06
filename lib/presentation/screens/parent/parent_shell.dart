// lib/presentation/screens/parent/parent_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'home_screen.dart';
import 'rewards_screen.dart';
import '../../providers/auth_provider.dart';// to watch auth state
import '../../providers/protection_status.dart';          // getProtectionStatus()
import 'device_protection_screen.dart';
import '../../../domain/entities/user.dart';  // to fix missing protection

class ParentShell extends ConsumerStatefulWidget {
  const ParentShell({super.key});

  @override
  ConsumerState<ParentShell> createState() => _ParentShellState();
}

class _ParentShellState extends ConsumerState<ParentShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    RewardsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Run the check after the first frame (so context is ready)
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkProtection());
  }

  // Call this whenever the auth state changes (parent logs in again)
  void _onAuthChanged(AsyncValue<User?> state) {
    state.whenOrNull(data: (user) {
      if (user != null) {
        _checkProtection();
      }
    });
  }

  Future<void> _checkProtection() async {
    // Make sure the channel is ready – add a small delay if needed
    await Future.delayed(const Duration(milliseconds: 300));
    final status = await getProtectionStatus();
    if (!mounted) return;

    final missingAdmin = !status['deviceAdmin']!;
    final missingA11y = !status['accessibility']!;

    if (missingAdmin || missingA11y) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('⚠️ Protection Incomplete'),
          content: Text(
            missingAdmin && missingA11y
                ? 'Both device admin and accessibility are off.\neCap cannot block apps properly.'
                : missingAdmin
                ? 'Device admin is off – eCap can be uninstalled.'
                : 'Accessibility service is off – blocking will not work.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Ignore'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                // Navigate to the screen that lets you fix both
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DeviceProtectionScreen(),
                  ),
                );
              },
              child: const Text('Fix Now'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to auth state changes and call our check
    ref.listen<AsyncValue<User?>>(authStateProvider, (_, next) {
      _onAuthChanged(next);
    });

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.child_care),
            label: 'Children',
          ),
          NavigationDestination(
            icon: Icon(Icons.card_giftcard),
            label: 'Rewards',
          ),
        ],
      ),
    );
  }
}