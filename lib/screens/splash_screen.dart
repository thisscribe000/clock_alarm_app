import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onSplashComplete;
  final Duration duration;

  const SplashScreen({
    super.key,
    required this.onSplashComplete,
    this.duration = const Duration(seconds: 2),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(widget.duration, () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('seenSplash', true);
      widget.onSplashComplete();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      body: Center(
        child: Text(
          'calc_convert',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? const Color(0xFFE0E0E0) : const Color(0xFF1E1E1E),
              ),
        ),
      ),
    );
  }
}
