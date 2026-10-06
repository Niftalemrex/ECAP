// lib/presentation/screens/auth/sign_up_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/app_error.dart';
import '../../../domain/entities/user.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _familyNameController = TextEditingController();
  final _pinController = TextEditingController();
  bool _obscurePin = true;

  @override
  void dispose() {
    _nameController.dispose();
    _familyNameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Call signUp and wait for it to finish
    final notifier = ref.read(authStateProvider.notifier);
    await notifier.signUp(
      name: _nameController.text.trim(),
      role: UserRole.parent,
      pin: _pinController.text.trim(),
      familyName: _familyNameController.text.trim().isNotEmpty
          ? _familyNameController.text.trim()
          : null,
    );

    if (!mounted) return;

    // Check the result of the sign‑up operation
    final authState = ref.read(authStateProvider);
    if (authState.hasError) {
      // Show a snackbar with the error (in addition to the inline error widget)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign up failed: ${authState.error}'),
          backgroundColor: Colors.red,
        ),
      );
      return; // stay on sign‑up screen
    }

    // Sign‑up was successful
    debugPrint('✅ Sign-up successful, navigating to device protection');
    context.go('/device-protection');
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authStateProvider);

    if (authAsync.isLoading) {
      return Scaffold(
        body: AppLoader(message: 'Creating account...'),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Create Parent Account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Your Name',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter your name' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _familyNameController,
                    decoration: const InputDecoration(
                      labelText: 'Family Name (e.g., Smith Family)',
                      prefixIcon: Icon(Icons.family_restroom),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _pinController,
                    obscureText: _obscurePin,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: 'PIN',
                      counterText: '',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscurePin ? Icons.visibility_off : Icons.visibility),
                        onPressed: () =>
                            setState(() => _obscurePin = !_obscurePin),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'PIN is required';
                      if (v.trim().length < 4) {
                        return 'PIN must be at least 4 digits';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  if (authAsync.hasError)
                    AppError(
                      message: authAsync.error.toString(),
                      onRetry: _submit,
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submit,
                      child: const Text('Sign Up'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}