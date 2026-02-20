import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyApiService {
  static const String _baseUrl = 'https://api.exchangerate-api.com/v4/latest/USD';
  static const String _cacheKey = 'cached_rates';
  static const String _timestampKey = 'rates_timestamp';
  
  // Cache duration: 1 hour
  static const Duration _cacheDuration = Duration(hours: 1);

  // Fetch latest rates
  static Future<Map<String, double>?> fetchRates() async {
    const int maxAttempts = 2;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await http.get(Uri.parse(_baseUrl));

        // Debug logging: status and small preview of body
        // ignore: avoid_print
        print('CurrencyApiService: attempt $attempt HTTP ${response.statusCode}');
        // ignore: avoid_print
        print('CurrencyApiService: body preview: ${response.body.length > 200 ? '${response.body.substring(0, 200)}...' : response.body}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);

          final raw = data['rates'];
          if (raw is Map) {
            final Map<String, double> rates = {};
            raw.forEach((key, value) {
              try {
                if (value is num) {
                  rates[key.toString()] = value.toDouble();
                } else if (value is String) {
                  rates[key.toString()] = double.tryParse(value) ?? 0.0;
                }
              } catch (_) {}
            });

            if (rates.isNotEmpty) {
              // Cache the rates
              await _cacheRates(rates);
              return rates;
            }
          }
        } else {
          // ignore: avoid_print
          print('CurrencyApiService non-200 response: ${response.statusCode}');
        }
      } catch (e) {
        // Debug print for failures
        // ignore: avoid_print
        print('CurrencyApiService.fetchRates error (attempt $attempt): $e');
      }

      if (attempt < maxAttempts) await Future.delayed(const Duration(seconds: 1));
    }

    // Return cached rates if available
    return await _getCachedRates();
  }

  // Cache rates to SharedPreferences
  static Future<void> _cacheRates(Map<String, double> rates) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(rates));
    await prefs.setInt(_timestampKey, DateTime.now().millisecondsSinceEpoch);
  }

  // Get cached rates
  static Future<Map<String, double>?> _getCachedRates() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    final timestamp = prefs.getInt(_timestampKey);
    
    if (cached == null || timestamp == null) return null;
    
    // Check if cache is still valid
    final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final age = DateTime.now().difference(cacheTime);
    
    if (age > _cacheDuration) return null; // Cache expired
    
    try {
      return Map<String, double>.from(jsonDecode(cached));
    } catch (e) {
      return null;
    }
  }

  // Get last update time
  static Future<DateTime?> getLastUpdateTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_timestampKey);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  // Clear cache
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_timestampKey);
  }
}