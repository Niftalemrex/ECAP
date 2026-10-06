// lib/presentation/providers/protection_status.dart
import 'package:flutter/services.dart';

const adminChannel = MethodChannel('com.example.ecap/admin');

Future<bool> isAdminActive() async {
  try {
    return await adminChannel.invokeMethod('isAdminEnabled') ?? false;
  } catch (_) {
    return false;
  }
}

Future<bool> isAccessibilityEnabled() async {
  try {
    return await adminChannel.invokeMethod('isAccessibilityServiceEnabled') ?? false;
  } catch (_) {
    return false;
  }
}

Future<void> enableAdmin() async {
  await adminChannel.invokeMethod('enableAdmin');
}

Future<void> openAccessibilitySettings() async {
  await adminChannel.invokeMethod('openAccessibilitySettings');
}

Future<Map<String, bool>> getProtectionStatus() async {
  final admin = await isAdminActive();
  final a11y = await isAccessibilityEnabled();
  return {'deviceAdmin': admin, 'accessibility': a11y};
}