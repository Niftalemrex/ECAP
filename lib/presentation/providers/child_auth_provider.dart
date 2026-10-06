// lib/presentation/providers/child_auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// When `true`, a child has tapped their name on the child login screen
/// and the app is in child-only mode (no parent controls).
final isChildModeProvider = StateProvider<bool>((ref) => false);