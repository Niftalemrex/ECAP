// lib/presentation/screens/shared/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/children_provider.dart';
import '../../providers/child_auth_provider.dart';
import 'package:ecap/domain/entities/user.dart';
import '../../providers/sync_apps_provider.dart';
import '../../providers/apps_provider.dart';
import '../../providers/protection_status.dart';            // <-- NEW
import '../../widgets/app_loader.dart';
import '../../widgets/app_error.dart';
import '../parent/device_protection_screen.dart';           // <-- NEW

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _pinController = TextEditingController();
  bool _obscurePin = true;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _submit() {
    final pin = _pinController.text.trim();
    if (pin.isEmpty) return;
    // The auth provider now hashes the PIN with SHA‑256 before checking
    ref.read(authStateProvider.notifier).login(pin);
  }

  void _onChildSelected(int childId) {
    ref.read(selectedChildIdProvider.notifier).state = childId;
    ref.read(isChildModeProvider.notifier).state = true;
    context.go('/child-dashboard');
  }

  void _showChildLoginSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ChildLoginSheet(
        onChildSelected: _onChildSelected,
      ),
    );
  }

  // ── Called after a successful parent login ──
  Future<void> _onParentLoggedIn(User user) async {
    // Sync installed apps
    ref.read(syncInstalledAppsProvider(false));
    ref.invalidate(appsProvider);

    // Check protection status
    final status = await getProtectionStatus();
    if (!mounted) return;

    final missingAdmin = !status['deviceAdmin']!;
    final missingA11y = !status['accessibility']!;

    if (missingAdmin || missingA11y) {
      // Redirect to the protection screen to fix things
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DeviceProtectionScreen()),
      );
    } else {
      // All good – go to parent dashboard
      context.go('/parent');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authStateProvider);

    // ── Listen to auth state changes ──
    ref.listen<AsyncValue<User?>>(authStateProvider, (_, state) {
      state.whenOrNull(
        data: (user) {
          if (user != null && user.role == UserRole.parent) {
            _onParentLoggedIn(user);
          }
        },
      );
    });

    if (authAsync.isLoading) {
      return const Scaffold(body: AppLoader(message: 'Signing in...'));
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 24),
              Text('Welcome', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 48),

              // PIN field
              TextField(
                controller: _pinController,
                obscureText: _obscurePin,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: 'PIN',
                  counterText: '',
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscurePin ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePin = !_obscurePin),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),

              if (authAsync.hasError)
                AppError(
                  message: authAsync.error.toString(),
                  onRetry: () =>
                      ref.read(authStateProvider.notifier).login(_pinController.text.trim()),
                ),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Login'),
                ),
              ),
              const SizedBox(height: 16),

              TextButton(
                onPressed: () => context.go('/sign-up'),
                child: const Text("Don't have an account? Sign up"),
              ),

              const Divider(height: 32),
              Text('Or', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _showChildLoginSheet,
                icon: const Icon(Icons.child_care),
                label: const Text('Child Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Child login sheet (unchanged)
// ─────────────────────────────────────────────────────────────
class _ChildLoginSheet extends ConsumerStatefulWidget {
  final void Function(int childId) onChildSelected;
  const _ChildLoginSheet({required this.onChildSelected});

  @override
  ConsumerState<_ChildLoginSheet> createState() => _ChildLoginSheetState();
}

class _ChildLoginSheetState extends ConsumerState<_ChildLoginSheet> {
  int? _selectedFamilyId;

  @override
  Widget build(BuildContext context) {
    final familiesAsync = ref.watch(allFamiliesProvider);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Who is using the device?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: familiesAsync.when(
                data: (families) {
                  if (families.isEmpty) {
                    return const Text('No families available');
                  }
                  if (_selectedFamilyId == null) {
                    _selectedFamilyId = families.first.id;
                  }
                  return DropdownButtonFormField<int>(
                    value: _selectedFamilyId,
                    items: families
                        .map((f) => DropdownMenuItem<int>(
                      value: f.id,
                      child: Text(f.name),
                    ))
                        .toList(),
                    onChanged: (id) {
                      setState(() => _selectedFamilyId = id!);
                    },
                    decoration: const InputDecoration(labelText: 'Family'),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),
            ),
            const SizedBox(height: 16),
            if (_selectedFamilyId != null)
              _ChildrenList(
                familyId: _selectedFamilyId!,
                onChildSelected: widget.onChildSelected,
              )
            else
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Select a family first'),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChildrenList extends ConsumerWidget {
  final int familyId;
  final void Function(int childId) onChildSelected;
  const _ChildrenList({
    required this.familyId,
    required this.onChildSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childrenAsync = ref.watch(childrenForFamilyProvider(familyId));

    return childrenAsync.when(
      data: (children) {
        if (children.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No children in this family'),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          itemCount: children.length,
          itemBuilder: (_, i) {
            final child = children[i];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(child.name[0].toUpperCase()),
                ),
                title: Text(child.name),
                subtitle: const Text('Tap to login'),
                trailing: const Icon(Icons.login),
                onTap: () {
                  Navigator.of(context).pop();
                  onChildSelected(child.id);
                },
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text('Error: $e'),
      ),
    );
  }
}