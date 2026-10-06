// lib/presentation/screens/parent/app_rules_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/children_provider.dart';
import '../../providers/app_rules_provider.dart';
import '../../providers/apps_provider.dart';
import '../../providers/sync_apps_provider.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/app_error.dart';
import 'add_app_screen.dart';

class AppRulesScreen extends ConsumerStatefulWidget {
  const AppRulesScreen({super.key});

  @override
  ConsumerState<AppRulesScreen> createState() => _AppRulesScreenState();
}

class _AppRulesScreenState extends ConsumerState<AppRulesScreen> {
  int? _selectedChildId;   // null = none, 0 = global, >0 = specific child

  @override
  Widget build(BuildContext context) {
    final childrenAsync = ref.watch(childrenListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Rules'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync Apps (User only)',
            onPressed: () async {
              await ref.read(syncInstalledAppsProvider(false));
              ref.invalidate(appsProvider);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Apps synced successfully')),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          childrenAsync.when(
            data: (children) => Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<int>(
                value: _selectedChildId,
                // Add a “Global” option on top of the child list
                items: [
                  const DropdownMenuItem<int>(
                    value: 0,
                    child: Text('Global (all children)'),
                  ),
                  ...children.map(
                        (child) => DropdownMenuItem<int>(
                      value: child.id,
                      child: Text(child.name),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != _selectedChildId) {
                    setState(() => _selectedChildId = value);
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Select Child or Global',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            loading: () => const Center(child: AppLoader()),
            error: (e, _) => AppError(message: e.toString()),
          ),
          Expanded(
            child: _selectedChildId == null
                ? const Center(child: Text('Pick a child or global to see rules'))
                : _buildRulesList(_selectedChildId!),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddAppScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Rule'),
      ),
    );
  }

  Widget _buildRulesList(int childId) {
    final rulesAsync = ref.watch(childAppRulesProvider(childId));
    final appsAsync = ref.watch(appsProvider);

    return rulesAsync.when(
      data: (rules) {
        if (rules.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(childId == 0
                      ? 'No global rules yet.'
                      : 'No rules set for this child.'),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AddAppScreen()),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Rule'),
                  ),
                ],
              ),
            ),
          );
        }

        return appsAsync.when(
          data: (apps) {
            if (apps.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('No apps available.'),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await ref.read(syncInstalledAppsProvider(false));
                        ref.invalidate(appsProvider);
                      },
                      icon: const Icon(Icons.sync),
                      label: const Text('Sync Apps'),
                    ),
                  ],
                ),
              );
            }

            final appMap = {for (final app in apps) app.id: app};

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: rules.length,
              itemBuilder: (context, index) {
                final rule = rules[index];
                final app = appMap[rule.appId];
                final appName = app?.appName ?? 'Unknown app';

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _colorForMode(rule.mode),
                      child: Icon(
                        _iconForMode(rule.mode),
                        color: Colors.white,
                      ),
                    ),
                    title: Text(appName),
                    subtitle: Text(_ruleDescription(rule)),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AddAppScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: AppLoader()),
          error: (e, _) => AppError(message: e.toString()),
        );
      },
      loading: () => const Center(child: AppLoader()),
      error: (e, _) => AppError(message: e.toString()),
    );
  }

  Color _colorForMode(String mode) {
    switch (mode) {
      case 'allowed':
        return Colors.green;
      case 'blocked':
        return Colors.red;
      case 'limited':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _iconForMode(String mode) {
    switch (mode) {
      case 'allowed':
        return Icons.check;
      case 'blocked':
        return Icons.block;
      case 'limited':
        return Icons.timer;
      default:
        return Icons.help;
    }
  }

  String _ruleDescription(AppRule rule) {
    switch (rule.mode) {
      case 'allowed':
        return 'Always allowed';
      case 'blocked':
        return 'Always blocked';
      case 'limited':
        final StringBuffer sb = StringBuffer('Max ${rule.dailyLimitMinutes} min/day');
        if (rule.startTime != null && rule.endTime != null) {
          final start = _formatMinutes(rule.startTime!);
          final end = _formatMinutes(rule.endTime!);
          sb.write(' • $start – $end');
        }
        return sb.toString();
      default:
        return '';
    }
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final ampm = h < 12 ? 'AM' : 'PM';
    final hour12 = h % 12 == 0 ? 12 : h % 12;
    return '${hour12}:${m.toString().padLeft(2, '0')} $ampm';
  }
}