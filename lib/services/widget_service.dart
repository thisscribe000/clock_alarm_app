import 'package:shared_preferences/shared_preferences.dart';

class WidgetService {
  static const String widgetGroupId = 'calc_convert_widget';
  
  // Keys for widget data
  static const String _lastConversionKey = 'last_conversion';
  static const String _lastCalculationKey = 'last_calculation';
  static const String _lastUpdateKey = 'last_update';

  // Save last conversion for widget
  static Future<void> saveLastConversion({
    required String fromAmount,
    required String fromCurrency,
    required String toAmount,
    required String toCurrency,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final conversion = '$fromAmount $fromCurrency = $toAmount $toCurrency';
    await prefs.setString(_lastConversionKey, conversion);
    await prefs.setString(_lastUpdateKey, DateTime.now().toIso8601String());
    // Widget updates are disabled while widgets are removed from the project.
  }

  // Save last calculation for widget
  static Future<void> saveLastCalculation(String calculation) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastCalculationKey, calculation);
    await prefs.setString(_lastUpdateKey, DateTime.now().toIso8601String());

    try {
      // Widget updates are disabled while widgets are removed from the project.
    } catch (e) {
      // ignore
    }
  }

  // helper removed; widget functionality disabled

  static Future<void> initWidget() async {
    // Widget initialization disabled while widgets are removed.
    return;
  }
}