import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class HapticService {
  // Light tap for button presses
  static Future<void> lightTap(BuildContext context) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (!settings.hapticFeedback) return;
    
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: 10);
    }
  }

  // Medium impact for operations (equals, convert, etc.)
  static Future<void> mediumImpact(BuildContext context) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (!settings.hapticFeedback) return;
    
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: 20);
    }
  }

  // Success feedback for copy, add favorite, etc.
  static Future<void> success(BuildContext context) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (!settings.hapticFeedback) return;
    
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(pattern: [0, 10, 10, 10]);
    }
  }

  // Error feedback
  static Future<void> error(BuildContext context) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (!settings.hapticFeedback) return;
    
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(pattern: [0, 30, 20, 30]);
    }
  }

  // Swipe feedback (for opening history)
  static Future<void> swipe(BuildContext context) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (!settings.hapticFeedback) return;
    
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: 15);
    }
  }
}