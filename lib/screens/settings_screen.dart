import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/settings_provider.dart';
import '../services/currency_api_service.dart';
import '../services/haptic_service.dart';
import '../services/share_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = false;
  DateTime? _lastRateUpdate;

  @override
  void initState() {
    super.initState();
    _loadLastUpdateTime();
  }

  Future<void> _loadLastUpdateTime() async {
    final time = await CurrencyApiService.getLastUpdateTime();
    if (mounted) {
      setState(() {
        _lastRateUpdate = time;
      });
    }
  }

  Future<void> _refreshRates() async {
    HapticService.mediumImpact(context).then((_) async {
      if (!mounted) return;
      setState(() => _isLoading = true);
      await CurrencyApiService.fetchRates();
      await _loadLastUpdateTime();
      if (!mounted) return;
      setState(() => _isLoading = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('rates updated'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  Future<void> _clearAllHistory() async {
    HapticService.mediumImpact(context).then((_) async {
      if (!mounted) return;
      
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('clear history?'),
          content: const Text('this will delete all calculator and currency history.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('clear'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      setState(() => _isLoading = true);

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('calc_history_v1');
        await prefs.remove('currency_history_v1');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('history cleared'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('error: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    });
  }

  Future<void> _showVersionDialog() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('about'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('calc & convert'),
            const SizedBox(height: 8),
            Text(
              'version 1.0.0',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'a beautiful calculator and currency converter with:\n'
              '• 5 decimal precision\n'
              '• espees currency (1 esp = 2050 ngn)\n'
              '• swipe history\n'
              '• live exchange rates\n'
              '• favorites\n'
              '• haptic feedback\n'
              '• share results\n'
              '• light/dark theme',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('close'),
          ),
        ],
      ),
    );
  }

  void _shareApp() {
    ShareService.shareBoth(
      context,
      calcExpression: 'try our calculator',
      calcResult: 'with π, x², √, 1/x',
      convFrom: '100 espees = 205k naira',
      convTo: 'live exchange rates',
    ).then((_) {
      if (mounted) HapticService.success(context);
    });
  }

  Color _getColor(BuildContext context, {required double opacity, required bool isDark}) {
    return isDark 
        ? Colors.white.withValues(alpha: opacity)
        : Colors.black.withValues(alpha: opacity);
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _getColor(context, opacity: 0.5, isDark: isDark),
        ),
      ),
    );
  }

  Widget _buildThemeTile(BuildContext context, SettingsProvider settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ListTile(
      leading: Icon(
        Icons.brightness_6,
        color: _getColor(context, opacity: 0.7, isDark: isDark),
      ),
      title: Text(
        'theme',
        style: TextStyle(color: _getColor(context, opacity: 0.7, isDark: isDark)),
      ),
      trailing: DropdownButton<ThemeMode>(
        value: settings.themeMode,
        dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        icon: Icon(
          Icons.arrow_drop_down,
          color: _getColor(context, opacity: 0.5, isDark: isDark),
        ),
        underline: const SizedBox(),
        items: const [
          DropdownMenuItem(value: ThemeMode.light, child: Text('light')),
          DropdownMenuItem(value: ThemeMode.dark, child: Text('dark')),
          DropdownMenuItem(value: ThemeMode.system, child: Text('system')),
        ],
        onChanged: (ThemeMode? mode) {
          if (mode != null) settings.setThemeMode(mode);
        },
      ),
    );
  }

  Widget _buildDecimalPlacesTile(BuildContext context, SettingsProvider settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ListTile(
      leading: Icon(
        Icons.numbers,
        color: _getColor(context, opacity: 0.7, isDark: isDark),
      ),
      title: Text(
        'decimal places',
        style: TextStyle(color: _getColor(context, opacity: 0.7, isDark: isDark)),
      ),
      trailing: DropdownButton<int>(
        value: settings.decimalPlaces,
        dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        icon: Icon(
          Icons.arrow_drop_down,
          color: _getColor(context, opacity: 0.5, isDark: isDark),
        ),
        underline: const SizedBox(),
        items: const [
          DropdownMenuItem(value: 3, child: Text('3')),
          DropdownMenuItem(value: 5, child: Text('5')),
        ],
        onChanged: (int? places) {
          if (places != null) settings.setDecimalPlaces(places);
        },
      ),
    );
  }

  Widget _buildHapticTile(BuildContext context, SettingsProvider settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return SwitchListTile(
      secondary: Icon(
        Icons.vibration,
        color: _getColor(context, opacity: 0.7, isDark: isDark),
      ),
      title: Text(
        'haptic feedback',
        style: TextStyle(color: _getColor(context, opacity: 0.7, isDark: isDark)),
      ),
      value: settings.hapticFeedback,
      onChanged: (value) => settings.setHapticFeedback(value),
    );
  }

  Widget _buildAutoUpdateTile(BuildContext context, SettingsProvider settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return SwitchListTile(
      secondary: Icon(
        Icons.update,
        color: _getColor(context, opacity: 0.7, isDark: isDark),
      ),
      title: Text(
        'auto‑update rates',
        style: TextStyle(color: _getColor(context, opacity: 0.7, isDark: isDark)),
      ),
      subtitle: Text(
        'refresh on app open',
        style: TextStyle(
          fontSize: 12,
          color: _getColor(context, opacity: 0.5, isDark: isDark),
        ),
      ),
      value: settings.autoUpdateRates,
      onChanged: (value) => settings.setAutoUpdateRates(value),
    );
  }

  Widget _buildFavoritesTile(BuildContext context, SettingsProvider settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final favorites = settings.favoriteCurrencies;
    
    return ExpansionTile(
      leading: const Icon(
        Icons.star,
        color: Colors.amber,
      ),
      title: Text(
        'favorites',
        style: TextStyle(color: _getColor(context, opacity: 0.7, isDark: isDark)),
      ),
      subtitle: Text(
        '${favorites.length} currencies',
        style: TextStyle(
          fontSize: 12,
          color: _getColor(context, opacity: 0.5, isDark: isDark),
        ),
      ),
      children: favorites.isEmpty
          ? [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'no favorites yet',
                  style: TextStyle(
                    color: _getColor(context, opacity: 0.3, isDark: isDark),
                  ),
                ),
              )
            ]
          : favorites.map((fav) {
              return ListTile(
                title: Text(fav),
                trailing: IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.red.withValues(alpha: 0.7),
                  ),
                  onPressed: () => settings.removeFavorite(fav),
                ),
              );
            }).toList(),
    );
  }

  Widget _buildClearHistoryTile(BuildContext context) {
    return ListTile(
      leading: Icon(
        Icons.delete_sweep,
        color: Colors.red.withValues(alpha: 0.7),
      ),
      title: const Text('clear all history'),
      onTap: _clearAllHistory,
    );
  }

  Widget _buildShareAppTile(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ListTile(
      leading: Icon(
        Icons.share,
        color: _getColor(context, opacity: 0.7, isDark: isDark),
      ),
      title: Text(
        'share app',
        style: TextStyle(color: _getColor(context, opacity: 0.7, isDark: isDark)),
      ),
      onTap: _shareApp,
    );
  }

  Widget _buildAboutTile(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ListTile(
      leading: Icon(
        Icons.info_outline,
        color: _getColor(context, opacity: 0.7, isDark: isDark),
      ),
      title: Text(
        'about',
        style: TextStyle(color: _getColor(context, opacity: 0.7, isDark: isDark)),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: _getColor(context, opacity: 0.3, isDark: isDark),
      ),
      onTap: _showVersionDialog,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = Provider.of<SettingsProvider>(context);
    final textColor = _getColor(context, opacity: 0.7, isDark: isDark);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'settings',
          style: TextStyle(color: textColor),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionTitle(context, 'appearance'),
                Card(
                  child: Column(
                    children: [
                      _buildThemeTile(context, settings),
                      _buildDecimalPlacesTile(context, settings),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                _buildSectionTitle(context, 'feedback'),
                Card(
                  child: Column(
                    children: [
                      _buildHapticTile(context, settings),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                _buildSectionTitle(context, 'currency'),
                Card(
                  child: Column(
                    children: [
                      _buildAutoUpdateTile(context, settings),
                      _buildFavoritesTile(context, settings),
                      ListTile(
                        leading: Icon(
                          Icons.update,
                          color: _getColor(context, opacity: 0.7, isDark: isDark),
                        ),
                        title: Text(
                          'last update',
                          style: TextStyle(color: _getColor(context, opacity: 0.7, isDark: isDark)),
                        ),
                        subtitle: Text(
                          _lastRateUpdate != null 
                              ? '${_lastRateUpdate!.day}/${_lastRateUpdate!.month} ${_lastRateUpdate!.hour}:${_lastRateUpdate!.minute.toString().padLeft(2, '0')}'
                              : 'never',
                          style: TextStyle(
                            fontSize: 12,
                            color: _getColor(context, opacity: 0.5, isDark: isDark),
                          ),
                        ),
                        trailing: TextButton(
                          onPressed: _isLoading ? null : _refreshRates,
                          child: const Text('refresh'),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                _buildSectionTitle(context, 'share'),
                Card(
                  child: Column(
                    children: [
                      _buildShareAppTile(context),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                _buildSectionTitle(context, 'data'),
                Card(
                  child: Column(
                    children: [
                      _buildClearHistoryTile(context),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                _buildSectionTitle(context, 'about'),
                Card(
                  child: Column(
                    children: [
                      _buildAboutTile(context),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                Center(
                  child: Text(
                    'calc & convert v1.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      color: _getColor(context, opacity: 0.3, isDark: isDark),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}