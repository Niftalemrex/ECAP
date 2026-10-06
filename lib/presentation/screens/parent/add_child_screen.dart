// lib/presentation/screens/parent/add_child_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/children_provider.dart';
import '../../providers/database_provider.dart';
import '../../../core/database.dart';

class AddChildScreen extends ConsumerStatefulWidget {
  const AddChildScreen({super.key});

  @override
  ConsumerState<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends ConsumerState<AddChildScreen> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addChild() async {
    if (!_formKey.currentState!.validate()) return;
    final familyId = ref.read(currentFamilyIdProvider);
    if (familyId == null) return;

    final db = await ref.read(databaseFutureProvider.future);
    await db.insert('children', {
      'name': _nameController.text.trim(),
      'family_id': familyId,
    });
    ref.invalidate(childrenListProvider);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Child')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Child Name'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _addChild,
                child: const Text('Add Child'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}