// lib/presentation/screens/parent/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/children_provider.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/app_error.dart';
import '../child/child_detail_screen.dart';
import '../parent/add_child_screen.dart';
import '../parent/app_rules_screen.dart';      // <-- new
import '../parent/add_app_screen.dart';        // <-- new

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final familyNameAsync = ref.watch(familyNameProvider);
    final childrenAsync = ref.watch(childrenListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Overview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              ref.read(authStateProvider.notifier).logout();
            },
          ),
        ],
      ),
      // ──────── FAB TO ADD CHILD ────────
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddChildScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(childrenListProvider);
          ref.invalidate(familyNameProvider);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ──────── Greeting block ────────
              authState.when(
                data: (user) {
                  if (user == null) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: Theme.of(context).textTheme.titleLarge,
                          children: [
                            const TextSpan(text: 'Hi, '),
                            TextSpan(
                              text: user.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const TextSpan(text: ' 🎉'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _greetingForTime(),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              // ──────── Family name ────────
              familyNameAsync.when(
                data: (familyName) {
                  if (familyName == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Text(
                      'Family: $familyName',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              // ──────── License Card ────────
              _LicenseCard(),
              const SizedBox(height: 24),

              // ──────── Family Members ────────
              Text(
                'Family Members',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              childrenAsync.when(
                data: (children) {
                  if (children.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.child_care, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No children added yet.'),
                          ],
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: children.map((child) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(child.name[0].toUpperCase()),
                          ),
                          title: Text(child.name),
                          subtitle: const Text(
                            'Screen time: 0 min  |  Daily limit: —',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ChildDetailScreen(childId: child.id),
                              ),
                            );
                          },
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: AppLoader(message: 'Loading children...')),
                error: (e, _) => AppError(message: e.toString()),
              ),
              const SizedBox(height: 24),

              // ──────── Quick Actions ────────
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              _buildQuickActions(context),   // <-- pass context
              const SizedBox(height: 24),

              // ──────── Today's Overview ────────
              Text(
                'Today’s Overview',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              _TodayOverviewCards(),
              const SizedBox(height: 24),

              // ──────── Top Apps ────────
              Text(
                'Top Apps (Today)',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              _TopAppsList(),
            ],
          ),
        ),
      ),
    );
  }

  String _greetingForTime() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning! Here’s your family overview.';
    if (hour < 17) return 'Good afternoon! Here’s your family overview.';
    return 'Good evening! Here’s your family overview.';
  }

  // ─── Build quick actions with working navigations ───
  Widget _buildQuickActions(BuildContext context) {
    final actions = <_QuickAction>[
      _QuickAction(
        label: 'App Rules',
        icon: Icons.rule,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AppRulesScreen()),
        ),
      ),
      _QuickAction(
        label: 'Screen Time',
        icon: Icons.timer,
        onTap: () { /* TODO */ },
      ),
      _QuickAction(
        label: 'Rewards',
        icon: Icons.card_giftcard,
        onTap: () { /* TODO */ },
      ),
      _QuickAction(
        label: 'Add App',
        icon: Icons.add_to_home_screen,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddAppScreen()),
        ),
      ),
      _QuickAction(
        label: 'Reports',
        icon: Icons.bar_chart,
        onTap: () { /* TODO */ },
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: actions
            .map((action) => Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Column(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor:
                Theme.of(context).colorScheme.secondaryContainer,
                child: IconButton(
                  icon: Icon(action.icon,
                      color: Theme.of(context)
                          .colorScheme
                          .onSecondaryContainer),
                  onPressed: action.onTap,
                ),
              ),
              const SizedBox(height: 4),
              Text(action.label,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ))
            .toList(),
      ),
    );
  }
}

// The _QuickAction class stays the same
class _QuickAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _QuickAction({required this.label, required this.icon, required this.onTap});
}

// ─────────────────────────────────────────────────────────────
// License Card
// ─────────────────────────────────────────────────────────────
class _LicenseCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'License Active',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('29 days left'),
            const Text('Valid until 26 May 2025'),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () { /* TODO: navigate to license management */ },
              child: const Text('Manage License'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Today's Overview Cards
// ─────────────────────────────────────────────────────────────
class _TodayOverviewCards extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _OverviewStat(
          icon: Icons.screen_rotation,
          title: 'Total Screen Time',
          value: '13h 35m',
          subtitle: '/ 18h limit',
        ),
        const SizedBox(height: 8),
        _OverviewStat(
          icon: Icons.school,
          title: 'Study Time',
          value: '4h 25m',
          subtitle: 'Good job!',
        ),
        const SizedBox(height: 8),
        _OverviewStat(
          icon: Icons.stars,
          title: 'Points Earned',
          value: '120',
          subtitle: '+30 today',
        ),
        const SizedBox(height: 8),
        _OverviewStat(
          icon: Icons.block,
          title: 'Blocked Apps',
          value: '6',
          subtitle: 'Today',
        ),
      ],
    );
  }
}

class _OverviewStat extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

  const _OverviewStat({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: Theme.of(context).textTheme.bodyLarge)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(value, style: Theme.of(context).textTheme.titleMedium),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Top Apps List
// ─────────────────────────────────────────────────────────────
class _TopAppsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        ListTile(
          leading: Icon(Icons.play_circle_fill, size: 36),
          title: Text('YouTube'),
          subtitle: Text('Entertainment'),
          trailing: Text('2h 45m'),
        ),
        Divider(height: 1),
        ListTile(
          leading: Icon(Icons.school, size: 36),
          title: Text('Duolingo'),
          subtitle: Text('Education'),
          trailing: Text('1h 30m'),
        ),
        Divider(height: 1),
        ListTile(
          leading: Icon(Icons.games, size: 36),
          title: Text('Minecraft'),
          subtitle: Text('Games'),
          trailing: Text('1h 10m'),
        ),
      ],
    );
  }
}