// lib/presentation/screens/child/child_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/children_provider.dart';
import '../../providers/child_auth_provider.dart';
import '../../widgets/app_loader.dart';

class ChildDashboardScreen extends ConsumerWidget {
  const ChildDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedChildId = ref.watch(selectedChildIdProvider);
    final isChildMode = ref.watch(isChildModeProvider);

    // If no child is selected at all, show an empty state
    if (selectedChildId == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.child_care, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('No child selected.'),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => context.go('/login'),
                icon: const Icon(Icons.login),
                label: const Text('Go to Login'),
              ),
            ],
          ),
        ),
      );
    }

    // Fetch the child directly from the database using the ID
    final childAsync = ref.watch(currentChildProvider(selectedChildId));

    return childAsync.when(
      data: (child) {
        if (child == null) {
          // The child ID existed but was not found (maybe deleted)
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Child not found'),
                  ElevatedButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Go to Login'),
                  ),
                ],
              ),
            ),
          );
        }

        // ---------- DASHBOARD CONTENT ----------
        return Scaffold(
          appBar: AppBar(
            title: Text('${child.name}\'s Dashboard'),
            // Back button visible only when a child is logged in
            leading: isChildMode
                ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                ref.read(selectedChildIdProvider.notifier).state = null;
                ref.read(isChildModeProvider.notifier).state = false;
                context.go('/login');
              },
            )
                : null,
          ),
          body: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text(child.name[0].toUpperCase(),
                      style: TextStyle(fontSize: 36,
                          color: Theme.of(context).colorScheme.onPrimaryContainer)),
                ),
                const SizedBox(height: 16),
                Text(child.name, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 32),

                // Stats cards
                _DashboardCard(
                  icon: Icons.timer,
                  title: 'Screen Time Today',
                  value: '0 min / 60 min',
                ),
                const SizedBox(height: 12),
                _DashboardCard(
                  icon: Icons.stars,
                  title: 'Points',
                  value: '0',
                ),
                const SizedBox(height: 12),
                _DashboardCard(
                  icon: Icons.flag,
                  title: 'Active Missions',
                  value: 'None',
                ),

                const Spacer(),

                // Child mode logout button
                if (isChildMode)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ref.read(selectedChildIdProvider.notifier).state = null;
                        ref.read(isChildModeProvider.notifier).state = false;
                        context.go('/login');
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Switch Child'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: AppLoader(message: 'Loading child data...')),
      error: (e, _) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error: $e'),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => ref.invalidate(currentChildProvider(selectedChildId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Simple reusable card for dashboard stats
class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
            Text(title, style: Theme.of(context).textTheme.bodyLarge),
            const Spacer(),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}