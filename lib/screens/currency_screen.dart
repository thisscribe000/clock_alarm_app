import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/currency_api_service.dart';
import '../providers/settings_provider.dart';
import '../services/haptic_service.dart';
import '../services/share_service.dart';
import '../services/widget_service.dart';

class CurrencyScreen extends StatefulWidget {
  const CurrencyScreen({super.key});

  @override
  State<CurrencyScreen> createState() => _CurrencyScreenState();
}

class _CurrencyScreenState extends State<CurrencyScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _amountController = TextEditingController(text: '100');

  String _fromCurrency = 'espees';
  String _toCurrency = 'naira';
  double _convertedAmount = 205000;

  // Live rates
  bool _isLoadingRates = false;
  DateTime? _lastRateUpdate;
  String? _rateError;

  // History
  final List<String> _history = [];
  static const String _historyKey = 'currency_history_v1';
  bool _historyOpen = false;
  
  // Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Debounced history commit
  Timer? _historyCommitTimer;
  String _lastCommittedKey = '';
  static const Duration _historyCommitDelay = Duration(seconds: 7);

  final List<Map<String, dynamic>> _baseCurrencies = [
    {'code': 'esp', 'name': 'espees', 'symbol': 'ESP', 'rateToUSD': 1.3667, 'isPinned': true},
    {'code': 'usd', 'name': 'us dollar', 'symbol': r'$', 'rateToUSD': 1.0, 'isPinned': false},
    {'code': 'ngn', 'name': 'naira', 'symbol': '₦', 'rateToUSD': 0.000667, 'isPinned': false},
    {'code': 'eur', 'name': 'euro', 'symbol': '€', 'rateToUSD': 1.107, 'isPinned': false},
    {'code': 'gbp', 'name': 'pound', 'symbol': '£', 'rateToUSD': 1.266, 'isPinned': false},
    {'code': 'jpy', 'name': 'yen', 'symbol': '¥', 'rateToUSD': 0.00667, 'isPinned': false},
    {'code': 'cny', 'name': 'yuan', 'symbol': '¥', 'rateToUSD': 0.139, 'isPinned': false},
    {'code': 'cad', 'name': 'canadian dollar', 'symbol': r'C$', 'rateToUSD': 0.741, 'isPinned': false},
    {'code': 'aud', 'name': 'australian dollar', 'symbol': r'A$', 'rateToUSD': 0.658, 'isPinned': false},
    {'code': 'chf', 'name': 'swiss franc', 'symbol': 'CHF', 'rateToUSD': 1.136, 'isPinned': false},
  ];

  late List<Map<String, dynamic>> _currencies;

  @override
  void initState() {
    super.initState();
    _currencies = List.from(_baseCurrencies);
    _updateESPRate();
    _loadHistory();
    _loadLastUpdateTime();
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 0.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _convert(scheduleHistory: false);
      _fetchLiveRates();
    });
  }

  @override
  void dispose() {
    _cancelHistoryCommit();
    _amountController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ---------------------------
  // Live Rates
  // ---------------------------
  Future<void> _loadLastUpdateTime() async {
    final time = await CurrencyApiService.getLastUpdateTime();
    if (mounted) {
      setState(() {
        _lastRateUpdate = time;
      });
    }
  }

  Future<void> _fetchLiveRates() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (!settings.autoUpdateRates && _lastRateUpdate != null) return;

    if (!mounted) return;
    setState(() {
      _isLoadingRates = true;
      _rateError = null;
    });

    try {
      final rates = await CurrencyApiService.fetchRates();

      if (!mounted) return;

      if (rates != null) {
        setState(() {
          for (var currency in _currencies) {
            final code = currency['code'].toString().toUpperCase();
            if (code != 'ESP' && rates.containsKey(code)) {
              currency['rateToUSD'] = rates[code];
            }
          }
          _updateESPRate();
          _lastRateUpdate = DateTime.now();
          _rateError = null;
          _isLoadingRates = false;
        });

        _convert(scheduleHistory: false);
      } else {
        // No live rates; check if we have a cached timestamp to show informative message
        final last = await CurrencyApiService.getLastUpdateTime();
        final msg = last != null
            ? 'offline - using cached rates (last: ${_formatLastUpdate(last)})'
            : 'offline - using built-in rates';

        setState(() {
          _rateError = msg;
          _isLoadingRates = false;
        });
      }
    } catch (e) {
      // Log the exception for debugging and show informative offline message
      // ignore: avoid_print
      print('CurrencyApiService.fetchRates failed: $e');

      final last = await CurrencyApiService.getLastUpdateTime();
      final msg = last != null
          ? 'offline - using cached rates (last: ${_formatLastUpdate(last)})'
          : 'offline - using built-in rates';

      if (!mounted) return;
      setState(() {
        _rateError = msg;
        _isLoadingRates = false;
      });
    }
  }

  // ---------------------------
  // Share
  // ---------------------------
  void _shareConversion() {
    final fromAmount = _formatAmount(double.tryParse(_amountController.text) ?? 0);
    final toAmount = _formatAmount(_convertedAmount);
    
    final from = _currencies.firstWhere((c) => c['name'] == _fromCurrency);
    final to = _currencies.firstWhere((c) => c['name'] == _toCurrency);
    final rate = (from['rateToUSD'] as double) / (to['rateToUSD'] as double);
    
    ShareService.shareConversion(
      context,
      fromAmount: fromAmount,
      fromCurrency: _fromCurrency,
      toAmount: toAmount,
      toCurrency: _toCurrency,
      exactRate: rate,
    ).then((_) {
      if (mounted) HapticService.success(context);
    });
  }

  // ---------------------------
  // Persistence
  // ---------------------------
  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null) return;

    try {
      final List list = jsonDecode(raw);
      if (!mounted) return;
      setState(() {
        _history
          ..clear()
          ..addAll(list.cast<String>());
        if (_history.length > 5) _history.removeRange(5, _history.length);
      });
    } catch (_) {}
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey, jsonEncode(_history));
  }

  void _addToHistory(String line) {
    setState(() {
      _history.insert(0, line);
      if (_history.length > 5) _history.removeLast();
    });
    _saveHistory();
  }

  void _clearHistory() {
    setState(() {
      _history.clear();
      _lastCommittedKey = '';
    });
    _saveHistory();
  }

  // ---------------------------
  // Debounced commit logic
  // ---------------------------
  String _buildHistoryLine(double amount, double result) {
    final fromAmountStr = _formatAmount(amount);
    final toAmountStr = _formatAmount(result);
    return '$fromAmountStr $_fromCurrency = $toAmountStr $_toCurrency';
  }

  String _buildCommitKey(double amount, double result) {
    final a = amount.toStringAsFixed(4);
    final r = result.toStringAsFixed(6);
    return '$a|$_fromCurrency|$r|$_toCurrency';
  }

  void _scheduleHistoryCommit(double amount, double result) {
    _historyCommitTimer?.cancel();
    _historyCommitTimer = Timer(_historyCommitDelay, () {
      final key = _buildCommitKey(amount, result);
      if (key == _lastCommittedKey) return;
      _lastCommittedKey = key;
      _addToHistory(_buildHistoryLine(amount, result));
    });
  }

  void _cancelHistoryCommit() {
    _historyCommitTimer?.cancel();
    _historyCommitTimer = null;
  }

  // ---------------------------
  // Favorites
  // ---------------------------
  void _toggleFavorite(String currencyName) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    
    if (settings.isFavorite(currencyName)) {
      settings.removeFavorite(currencyName).then((_) {
        if (!mounted) return;
        HapticService.success(context).then((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('removed from favorites'),
              duration: Duration(milliseconds: 800),
              behavior: SnackBarBehavior.floating,
            ),
          );
        });
      });
    } else {
      settings.addFavorite(currencyName).then((_) {
        if (!mounted) return;
        HapticService.success(context).then((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('added to favorites'),
              duration: Duration(milliseconds: 800),
              behavior: SnackBarBehavior.floating,
            ),
          );
        });
      });
    }
  }

  // ---------------------------
  // Currency / rates
  // ---------------------------
  void _updateESPRate() {
    final ngnToUSDRate = _currencies.firstWhere((c) => c['code'] == 'ngn')['rateToUSD'] as double;
    final espToUSDRate = 2050 * ngnToUSDRate;
    final espIndex = _currencies.indexWhere((c) => c['code'] == 'esp');
    _currencies[espIndex]['rateToUSD'] = espToUSDRate;
  }

  List<Map<String, dynamic>> get _sortedCurrencies {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    
    final pinned = _currencies.where((c) => c['isPinned'] == true).toList();
    final favorites = _currencies.where((c) => 
      !c['isPinned'] && settings.isFavorite(c['name'])
    ).toList();
    final others = _currencies.where((c) => 
      !c['isPinned'] && !settings.isFavorite(c['name'])
    ).toList();
    
    favorites.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    others.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    
    return [...pinned, ...favorites, ...others];
  }

  Color _withOpacity(Color color, double opacity) => color.withValues(alpha: opacity);

  Color _getColor(BuildContext context, {required double opacity, required bool isDark}) {
    return isDark
        ? Colors.white.withValues(alpha: opacity)
        : Colors.black.withValues(alpha: opacity);
  }

  String _formatLastUpdate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _formatAmount(double amount) {
    if (amount >= 1e9) {
      return '${(amount / 1e9).toStringAsFixed(2)}b';
    } else if (amount >= 1e6) {
      return '${(amount / 1e6).toStringAsFixed(2)}m';
    } else if (amount >= 1e3) {
      return '${(amount / 1e3).toStringAsFixed(2)}k';
    } else {
      return amount.toStringAsFixed(2);
    }
  }

  void _convert({required bool scheduleHistory}) {
  final amount = double.tryParse(_amountController.text) ?? 0;
  final from = _currencies.firstWhere((c) => c['name'] == _fromCurrency);
  final to = _currencies.firstWhere((c) => c['name'] == _toCurrency);
  final amountInUSD = amount * (from['rateToUSD'] as double);
  final result = amountInUSD / (to['rateToUSD'] as double);

  setState(() {
    _convertedAmount = result;
  });

  if (scheduleHistory) {
    _scheduleHistoryCommit(amount, result);
    // Save to widget
    WidgetService.saveLastConversion(
      fromAmount: _formatAmount(amount),
      fromCurrency: _fromCurrency,
      toAmount: _formatAmount(result),
      toCurrency: _toCurrency,
    );
  }
}

  void _swapCurrencies() {
    HapticService.mediumImpact(context).then((_) {
      if (!mounted) return;
      setState(() {
        final temp = _fromCurrency;
        _fromCurrency = _toCurrency;
        _toCurrency = temp;
      });
      _convert(scheduleHistory: true);
    });
  }

  // ---------------------------
  // History overlay
  // ---------------------------
  void _openHistory() {
    if (_history.isEmpty) return;
    setState(() => _historyOpen = true);
  }

  void _closeHistory() {
    setState(() => _historyOpen = false);
  }

  void _useHistoryLine(String line) {
    final parts = line.split('=');
    if (parts.length != 2) return;

    final left = parts[0].trim();
    final right = parts[1].trim();

    final leftTokens = left.split(' ');
    if (leftTokens.length < 2) return;

    final amountStr = leftTokens.first;
    final fromName = leftTokens.sublist(1).join(' ');

    final rightTokens = right.split(' ');
    if (rightTokens.length < 2) return;

    final toName = rightTokens.sublist(1).join(' ');

    setState(() {
      _amountController.text = amountStr.replaceAll(RegExp(r'[^0-9\.\-]'), '');
      _fromCurrency = fromName;
      _toCurrency = toName;
    });

    _convert(scheduleHistory: false);
    _closeHistory();
  }

  // ---------------------------
  // UI Components
  // ---------------------------
  Widget _buildCurrencyCard({
    required BuildContext context,
    required String title,
    required String value,
    required Widget dropdown,
    bool isFrom = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark 
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                dropdown,
              ],
            ),
            const SizedBox(height: 16),
            if (isFrom)
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: '0',
                  hintStyle: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w300,
                    color: isDark ? Colors.white24 : Colors.black12,
                  ),
                ),
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w300,
                  color: isDark ? Colors.white : Colors.black,
                ),
                onChanged: (_) => _convert(scheduleHistory: true),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w300,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '≈ ${_convertedAmount.toStringAsFixed(3)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white38 : Colors.black45,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryOverlay(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final historyTextColor = isDark ? Colors.white : Colors.black87;
    final dividerColor = isDark
        ? _withOpacity(Colors.white, 0.14)
        : _withOpacity(Colors.black, 0.18);

    return Positioned.fill(
      child: GestureDetector(
        onTap: _closeHistory,
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 0) _closeHistory();
        },
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.10),
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Material(
                  color: isDark
                      ? _withOpacity(Colors.white, 0.10)
                      : _withOpacity(Colors.white, 0.78),
                  borderRadius: BorderRadius.circular(26),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(26),
                    onTap: () {},
                    child: SizedBox(
                      height: 260,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                        child: Column(
                          children: [
                            Center(
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 28,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.history,
                                  size: 16,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'last 5 conversions',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: _clearHistory,
                                  child: Text(
                                    'clear',
                                    style: TextStyle(color: historyTextColor),
                                  ),
                                ),
                              ],
                            ),
                            Divider(height: 16, color: dividerColor),
                            Expanded(
                              child: _history.isEmpty
                                  ? Center(
                                      child: Text(
                                        'no history yet',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: _getColor(context, opacity: 0.35, isDark: isDark),
                                        ),
                                      ),
                                    )
                                  : ListView.separated(
                                      physics: const BouncingScrollPhysics(),
                                      itemCount: _history.length,
                                      separatorBuilder: (_, __) => Divider(
                                        height: 12,
                                        color: dividerColor,
                                      ),
                                      itemBuilder: (_, i) {
                                        final line = _history[i];
                                        return Row(
                                          children: [
                                            Expanded(
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: SelectableText(
                                                  line,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: historyTextColor,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: 'Use',
                                              icon: Icon(
                                                Icons.subdirectory_arrow_left_rounded,
                                                color: isDark
                                                    ? Colors.white70
                                                    : Colors.black54,
                                              ),
                                              onPressed: () => _useHistoryLine(line),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sortedCurrencies = _sortedCurrencies;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < 0) {
          HapticService.swipe(context).then((_) {
            if (mounted) _openHistory();
          });
        }
      },
      child: Stack(
        children: [
          Container(
            color: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_isLoadingRates)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        if (_lastRateUpdate != null)
                          Text(
                            '${_lastRateUpdate!.hour}:${_lastRateUpdate!.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white24 : Colors.black26,
                            ),
                          ),
                        IconButton(
                          icon: Icon(
                            Icons.refresh,
                            size: 18,
                            color: isDark ? Colors.white38 : Colors.black45,
                          ),
                          onPressed: () {
                            HapticService.mediumImpact(context).then((_) => _fetchLiveRates());
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.share,
                            size: 18,
                            color: isDark ? Colors.white38 : Colors.black45,
                          ),
                          onPressed: _shareConversion,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    
                    const Spacer(flex: 1),
                    
                    _buildCurrencyCard(
                      context: context,
                      title: _fromCurrency,
                      value: '',
                      dropdown: DropdownButton<String>(
                        value: _fromCurrency,
                        dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        icon: Icon(
                          Icons.arrow_drop_down,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                        underline: const SizedBox(),
                        items: sortedCurrencies.map<DropdownMenuItem<String>>((c) {
                          return DropdownMenuItem<String>(
                            value: c['name'] as String,
                            child: Row(
                              children: [
                                Consumer<SettingsProvider>(
                                  builder: (context, settings, child) {
                                    final isFav = settings.isFavorite(c['name']);
                                    return GestureDetector(
                                      onTap: () => _toggleFavorite(c['name']),
                                      child: Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: Icon(
                                          isFav ? Icons.star : Icons.star_border,
                                          size: 16,
                                          color: isFav 
                                              ? Colors.amber 
                                              : (isDark ? Colors.white38 : Colors.black38),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                if (c['isPinned'] == true)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: Icon(
                                      Icons.push_pin,
                                      size: 12,
                                      color: isDark ? Colors.white38 : Colors.black45,
                                    ),
                                  ),
                                Text(
                                  c['name'] as String,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (String? value) {
                          if (value == null) return;
                          HapticService.lightTap(context).then((_) {
                            if (!mounted) return;
                            setState(() => _fromCurrency = value);
                            _convert(scheduleHistory: true);
                          });
                        },
                      ),
                      isFrom: true,
                    ),
                    
                    const Spacer(flex: 1),
                    
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E1E1E)
                            : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.swap_vert,
                          color: isDark ? Colors.white70 : Colors.black54,
                          size: 22,
                        ),
                        onPressed: _swapCurrencies,
                      ),
                    ),
                    
                    const Spacer(flex: 1),
                    
                    _buildCurrencyCard(
                      context: context,
                      title: _toCurrency,
                      value: _formatAmount(_convertedAmount),
                      dropdown: DropdownButton<String>(
                        value: _toCurrency,
                        dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        icon: Icon(
                          Icons.arrow_drop_down,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                        underline: const SizedBox(),
                        items: sortedCurrencies.map<DropdownMenuItem<String>>((c) {
                          return DropdownMenuItem<String>(
                            value: c['name'] as String,
                            child: Row(
                              children: [
                                Consumer<SettingsProvider>(
                                  builder: (context, settings, child) {
                                    final isFav = settings.isFavorite(c['name']);
                                    return GestureDetector(
                                      onTap: () => _toggleFavorite(c['name']),
                                      child: Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: Icon(
                                          isFav ? Icons.star : Icons.star_border,
                                          size: 16,
                                          color: isFav 
                                              ? Colors.amber 
                                              : (isDark ? Colors.white38 : Colors.black38),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                if (c['isPinned'] == true)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: Icon(
                                      Icons.push_pin,
                                      size: 12,
                                      color: isDark ? Colors.white38 : Colors.black45,
                                    ),
                                  ),
                                Text(
                                  c['name'] as String,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (String? value) {
                          if (value == null) return;
                          HapticService.lightTap(context).then((_) {
                            if (!mounted) return;
                            setState(() => _toCurrency = value);
                            _convert(scheduleHistory: true);
                          });
                        },
                      ),
                      isFrom: false,
                    ),
                    
                    const Spacer(flex: 2),
                    
                    if (_rateError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _rateError!,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.amber.shade200 : Colors.orange.shade700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                if (_lastRateUpdate != null)
                                  Text(
                                    'Last updated: ${_formatLastUpdate(_lastRateUpdate!)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.white24 : Colors.black26,
                                    ),
                                  ),
                                const Spacer(),
                                TextButton(
                                  onPressed: _isLoadingRates
                                      ? null
                                      : () {
                                          HapticService.mediumImpact(context).then((_) => _fetchLiveRates());
                                        },
                                  child: Text(
                                    'Retry rates',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.white38 : Colors.black45,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    
                    if (_history.isNotEmpty)
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _pulseAnimation.value,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.keyboard_arrow_up_rounded,
                                  size: 20,
                                  color: isDark ? Colors.white38 : Colors.black45,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'history',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white38 : Colors.black45,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    
                    const Spacer(flex: 1),
                  ],
                ),
              ),
            ),
          ),
          if (_historyOpen) _buildHistoryOverlay(context),
        ],
      ),
    );
  }
}