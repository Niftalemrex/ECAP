import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/apps_provider.dart';
import '../../providers/children_provider.dart';
import '../../providers/app_rules_provider.dart';
import '../../providers/sync_apps_provider.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/app_error.dart';

class AddAppScreen extends ConsumerStatefulWidget {
  const AddAppScreen({super.key});

  @override
  ConsumerState<AddAppScreen> createState() => _AddAppScreenState();
}

class _AddAppScreenState extends ConsumerState<AddAppScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  /// -1 = not selected, 0 = global, >0 = specific child
  int? _selectedChildId;
  int? _selectedAppId;
  String _ruleMode = 'allowed';
  int _dailyLimitMinutes = 60;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  bool _includeSystemApps = false;

  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final childrenAsync = ref.watch(childrenListProvider);
    final appsAsync = ref.watch(appsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add App Rule'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Select Child (or global)',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              childrenAsync.when(
                data: (children) {
                  // Build list with "Global" option first
                  final items = <DropdownMenuItem<int>>[
                    const DropdownMenuItem(
                      value: 0,
                      child: Text('Global (all children)'),
                    ),
                    ...children.map((child) => DropdownMenuItem(
                      value: child.id,
                      child: Text(child.name),
                    )),
                  ];
                  return DropdownButtonFormField<int>(
                    value: _selectedChildId,
                    items: items,
                    onChanged: (value) =>
                        setState(() => _selectedChildId = value),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Choose a child or global',
                    ),
                    validator: (value) =>
                    value == null ? 'Please select a child or global' : null,
                  );
                },
                loading: () => const Center(child: AppLoader()),
                error: (e, _) => AppError(message: e.toString()),
              ),
              const SizedBox(height: 24),

              Text('Select App',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  hintText: 'Search apps...',
                ),
                onChanged: (value) =>
                    setState(() => _searchQuery = value.trim().toLowerCase()),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: appsAsync.when(
                  data: (apps) {
                    final filtered = _searchQuery.isEmpty
                        ? apps
                        : apps
                        .where((app) =>
                    app.appName
                        .toLowerCase()
                        .contains(_searchQuery) ||
                        app.packageName
                            .toLowerCase()
                            .contains(_searchQuery))
                        .toList();

                    if (filtered.isEmpty) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('No apps found'),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Include system apps'),
                              Switch(
                                value: _includeSystemApps,
                                onChanged: (value) {
                                  setState(() => _includeSystemApps = value);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () async {
                              await ref.read(
                                syncInstalledAppsProvider(_includeSystemApps),
                              );
                              ref.invalidate(appsProvider);
                            },
                            icon: const Icon(Icons.sync),
                            label: const Text('Sync Apps'),
                          ),
                        ],
                      );
                    }

                    return ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final app = filtered[index];
                        final isSelected = _selectedAppId == app.id;
                        return ListTile(
                          leading: app.icon != null
                              ? Image.memory(
                            base64Decode(app.icon!),
                            width: 40,
                          )
                              : const Icon(Icons.android),
                          title: Text(app.appName),
                          subtitle: Text(app.packageName),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle,
                              color: Colors.green)
                              : null,
                          selected: isSelected,
                          onTap: () {
                            setState(() => _selectedAppId = app.id);
                          },
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: AppLoader()),
                  error: (e, _) => AppError(message: e.toString()),
                ),
              ),
              const SizedBox(height: 24),

              Text('Rule Mode',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'allowed', label: Text('Allowed')),
                  ButtonSegment(value: 'blocked', label: Text('Blocked')),
                  ButtonSegment(value: 'limited', label: Text('Limited')),
                ],
                selected: {_ruleMode},
                onSelectionChanged: (newSelection) {
                  setState(() => _ruleMode = newSelection.first);
                },
              ),
              const SizedBox(height: 24),

              if (_ruleMode == 'limited') ...[
                Text('Daily Limit (minutes)',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: _dailyLimitMinutes.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'e.g. 60',
                  ),
                  onChanged: (value) {
                    final parsed = int.tryParse(value);
                    if (parsed != null && parsed > 0) {
                      _dailyLimitMinutes = parsed;
                    }
                  },
                  validator: (value) {
                    final num = int.tryParse(value ?? '');
                    if (num == null || num <= 0) {
                      return 'Enter a positive number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _TimePickerTile(
                        label: 'Start time',
                        time: _startTime,
                        onPicked: (t) => setState(() => _startTime = t),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _TimePickerTile(
                        label: 'End time',
                        time: _endTime,
                        onPicked: (t) => setState(() => _endTime = t),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              ElevatedButton.icon(
                onPressed: _saveRule,
                icon: const Icon(Icons.save),
                label: const Text('Save Rule'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveRule() async {
    if (!_formKey.currentState!.validate()) return;

    // Child dropdown is validated, so _selectedChildId is not null.
    // (0 = global, otherwise >0)
    final childIdForDb = _selectedChildId!; // 0 means global
    if (_selectedAppId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an app')),
      );
      return;
    }

    int? startMinutes = _startTime != null
        ? _startTime!.hour * 60 + _startTime!.minute
        : null;
    int? endMinutes = _endTime != null
        ? _endTime!.hour * 60 + _endTime!.minute
        : null;

    try {
      await ref.read(
        addOrUpdateAppRuleProvider(
          AddOrUpdateRuleParams(
            childId: childIdForDb,
            appId: _selectedAppId!,
            mode: _ruleMode,
            dailyLimitMinutes:
            _ruleMode == 'limited' ? _dailyLimitMinutes : 0,
            startTime: startMinutes,
            endTime: endMinutes,
          ),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rule saved successfully!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

class _TimePickerTile extends StatelessWidget {
  final String label;
  final TimeOfDay? time;
  final ValueChanged<TimeOfDay> onPicked;

  const _TimePickerTile({
    required this.label,
    required this.time,
    required this.onPicked,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time ?? const TimeOfDay(hour: 9, minute: 0),
        );
        if (picked != null) {
          onPicked(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.access_time),
        ),
        child: Text(
          time != null ? time!.format(context) : 'Not set',
          style: TextStyle(
            color: time != null ? null : Colors.grey,
          ),
        ),
      ),
    );
  }
}