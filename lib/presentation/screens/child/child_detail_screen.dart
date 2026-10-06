// lib/presentation/screens/child/child_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ecap/domain/entities/child.dart';               // <-- ADD THIS
import '../../providers/children_provider.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/app_error.dart';

class ChildDetailScreen extends ConsumerWidget {
  final int childId;
  const ChildDetailScreen({required this.childId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childrenAsync = ref.watch(childrenListProvider);
    return childrenAsync.when(
      data: (children) {
        // Find the child with the given id, or leave null
        Child? child;
        final index = children.indexWhere((c) => c.id == childId);
        if (index != -1) {
          child = children[index];
        }

        if (child == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Child not found')),
          );
        }
        return Scaffold(
          appBar: AppBar(title: Text('${child.name}\'s Details')),
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
                _StatCard(icon: Icons.timer, title: 'Screen Time Today', value: '0 min / 60 min'),
                const SizedBox(height: 12),
                _StatCard(icon: Icons.stars, title: 'Points', value: '0'),
                const SizedBox(height: 12),
                _StatCard(icon: Icons.flag, title: 'Missions', value: 'None'),
              ],
            ),
          ),
        );
      },
      loading: () => const AppLoader(message: 'Loading child...'),
      error: (e, _) => AppError(message: e.toString()),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _StatCard({required this.icon, required this.title, required this.value});

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