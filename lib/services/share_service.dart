import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vibration/vibration.dart';
import '../providers/settings_provider.dart';
import 'package:provider/provider.dart';

class ShareService {
  // Share calculator result
  static Future<void> shareCalculation(
    BuildContext context, {
    required String expression,
    required String result,
  }) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final text = '$expression = $result';
    
    if (settings.hapticFeedback) {
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(duration: 15);
      }
    }
    
    await Share.share(
      text,
      subject: 'calculation result',
    );
  }

  // Share currency conversion
  static Future<void> shareConversion(
    BuildContext context, {
    required String fromAmount,
    required String fromCurrency,
    required String toAmount,
    required String toCurrency,
    double? exactRate,
  }) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    
    String text;
    if (exactRate != null) {
      text = '$fromAmount $fromCurrency = $toAmount $toCurrency\n'
             '(rate: 1 $fromCurrency = ${exactRate.toStringAsFixed(4)} $toCurrency)';
    } else {
      text = '$fromAmount $fromCurrency = $toAmount $toCurrency';
    }
    
    if (settings.hapticFeedback) {
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(duration: 15);
      }
    }
    
    await Share.share(
      text,
      subject: 'currency conversion',
    );
  }

  // Share both results (for combined view)
  static Future<void> shareBoth(
    BuildContext context, {
    required String calcExpression,
    required String calcResult,
    required String convFrom,
    required String convTo,
  }) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    
    final text = '📱 calc & convert\n\n'
                 '🧮 Calculator:\n$calcExpression = $calcResult\n\n'
                 '💱 Currency:\n$convFrom = $convTo';
    
    if (settings.hapticFeedback) {
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(duration: 15);
      }
    }
    
    await Share.share(
      text,
      subject: 'calc & convert results',
    );
  }
}