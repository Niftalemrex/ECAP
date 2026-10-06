// lib/presentation/routes/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/child_auth_provider.dart';
import '../screens/shared/splash_screen.dart';
import '../screens/shared/login_screen.dart';
import '../screens/shared/sign_up_screen.dart';
import '../screens/parent/parent_shell.dart';
import '../screens/child/child_dashboard_screen.dart';
import '../screens/parent/device_protection_screen.dart';   // <-- NEW

final routerProvider = Provider<GoRouter>((ref) {
  final container = ref.container;

  final refreshNotifier = ValueNotifier<int>(0);

  ref.listen(authStateProvider, (_, __) {
    refreshNotifier.value++;
  });

  ref.listen(isChildModeProvider, (_, __) {
    refreshNotifier.value++;
  });

  return GoRouter(
    refreshListenable: refreshNotifier,
    initialLocation: '/splash',
    redirect: (context, state) {
      final isChildMode = container.read(isChildModeProvider);
      final authState = container.read(authStateProvider);
      final isLoading = authState.isLoading;
      final isLoggedIn = authState.valueOrNull != null;
      final location = state.matchedLocation;

      // ---- Child mode ----
      if (isChildMode) {
        if (location != '/child-dashboard') {
          return '/child-dashboard';
        }
        return null;
      }

      // ---- Parent mode ----
      if (isLoading) {
        return location == '/splash' ? null : '/splash';
      }

      if (!isLoggedIn) {
        // Allow these routes when not logged in
        if (location == '/login' || location == '/sign-up' || location == '/device-protection') {
          return null;
        }
        return '/login';
      }

      // Logged in: redirect away from auth/protection screens
      if (location == '/splash' || location == '/login' || location == '/sign-up' || location == '/device-protection') {
        return '/parent';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/sign-up', builder: (_, __) => const SignUpScreen()),
      GoRoute(path: '/device-protection', builder: (_, __) => const DeviceProtectionScreen()),  // NEW
      GoRoute(path: '/parent', builder: (_, __) => const ParentShell()),
      GoRoute(path: '/child-dashboard', builder: (_, __) => const ChildDashboardScreen()),
    ],
  );
});