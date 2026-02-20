import 'dart:convert';
import 'dart:math' show sqrt;
import 'dart:ui'; // Added for ImageFilter

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/haptic_service.dart';
import '../services/share_service.dart';
import '../services/widget_service.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  // Big display shows TOTAL only
  String _display = '0';
  String _expression = '';

  // Current number being typed
  String _currentInput = '';

  double _firstNumber = 0;
  String _operation = '';
  bool _isNewOperation = true;

  // History
  final List<String> _history = [];
  static const String _historyKey = 'calc_history_v1';
  bool _historyOpen = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
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
      setState(() {
        _history
          ..clear()
          ..addAll(list.cast<String>());
        if (_history.length > 5) {
          _history.removeRange(5, _history.length);
        }
      });
    } catch (_) {}
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey, jsonEncode(_history));
  }

  void _addToHistory(String entry) {
    setState(() {
      _history.insert(0, entry);
      if (_history.length > 5) _history.removeLast();
    });
    _saveHistory();
  }

  // ---------------------------
  // Helpers
  // ---------------------------
  String _formatNumber(double v) {
    // Use user's decimal places setting to avoid extremely long repeating
    // decimals which cause layout overflow in the display.
    final places = Provider.of<SettingsProvider>(context, listen: false).decimalPlaces;

    // If value is effectively an integer, show without decimals.
    if (v == v.toInt()) return v.toInt().toString();

    // Format with fixed decimal places, then trim trailing zeros.
    var s = v.toStringAsFixed(places);
    s = s.replaceFirst(RegExp(r"\.0+\$"), '');
    s = s.replaceFirst(RegExp(r"(\.[0-9]*[1-9])0+\$"), r"\1");
    return s;
  }

  double _parse(String s) => double.tryParse(s) ?? 0;

  double? _compute(double a, String op, double b) {
    switch (op) {
      case '+':
        return a + b;
      case '-':
        return a - b;
      case '×':
        return a * b;
      case '÷':
        if (b == 0) return null;
        return a / b;
      default:
        return null;
    }
  }

  Color _withOpacity(Color color, double opacity) {
    return color.withValues(alpha: opacity);
  }

  String _chainLine() {
    final expr = _expression.trim();
    final input = _currentInput.trim();
    if (expr.isEmpty) return input;
    if (input.isEmpty) return expr;
    return '$expr $input';
  }

  // ---------------------------
  // Share
  // ---------------------------
  void _shareResult() {
    final expression = _chainLine().isNotEmpty ? _chainLine() : _display;
    ShareService.shareCalculation(
      context,
      expression: expression,
      result: _display,
    ).then((_) {
      if (mounted) HapticService.success(context);
    });
  }

  // ---------------------------
  // Core input
  // ---------------------------
  void _onNumberPressed(String number) {
    setState(() {
      if (_isNewOperation) {
        _currentInput = '';
        _isNewOperation = false;
      }

      if (number == '.') {
        if (_currentInput.isEmpty) {
          _currentInput = '0.';
        } else if (!_currentInput.contains('.')) {
          _currentInput += '.';
        }
        return;
      }

      if (_currentInput == '0') {
        _currentInput = number;
      } else {
        _currentInput += number;
      }
    });
  }

  void _onOperationPressed(String newOp) {
    HapticService.lightTap(context).then((_) {
      if (!mounted) return;
      setState(() {
        if (_isNewOperation && _operation.isNotEmpty) {
          final parts = _expression.trim().split(' ');
          if (parts.isNotEmpty) {
            parts[parts.length - 1] = newOp;
            _expression = parts.join(' ');
          } else {
            _expression = '$_display $newOp';
          }
          _operation = newOp;
          return;
        }

        final hasInput = _currentInput.trim().isNotEmpty;

        if (_operation.isEmpty) {
          final first = hasInput ? _parse(_currentInput) : _parse(_display);
          _firstNumber = first;
          _display = _formatNumber(first);
          _expression = '${_formatNumber(first)} $newOp';
          _operation = newOp;
          _currentInput = '';
          _isNewOperation = true;
          return;
        }

        if (hasInput) {
          final second = _parse(_currentInput);

          final result = _compute(_firstNumber, _operation, second);
          if (result == null) {
            _display = 'error';
            _expression = '';
            _operation = '';
            _currentInput = '';
            _isNewOperation = true;
            return;
          }

          _firstNumber = result;
          _display = _formatNumber(result);

          _expression = '${_expression.trim()} ${_formatNumber(second)} $newOp';
          _operation = newOp;

          _currentInput = '';
          _isNewOperation = true;
          return;
        }

        final parts = _expression.trim().split(' ');
        if (parts.isNotEmpty) {
          parts[parts.length - 1] = newOp;
          _expression = parts.join(' ');
        } else {
          _expression = '$_display $newOp';
        }
        _operation = newOp;
        _isNewOperation = true;
      });
    });
  }

  void _onEqual() {
    HapticService.mediumImpact(context).then((_) {
      if (!mounted) return;
      setState(() {
        if (_operation.isEmpty) return;

        final hasInput = _currentInput.trim().isNotEmpty;
        final second = hasInput ? _parse(_currentInput) : _parse(_display);

        final base = _expression.trim().isEmpty ? '$_display $_operation' : _expression.trim();
        final fullExpr = '$base ${_formatNumber(second)}';

        final result = _compute(_firstNumber, _operation, second);
        if (result == null) {
          _display = 'error';
          _expression = '';
          _operation = '';
          _currentInput = '';
          _isNewOperation = true;
          return;
        }

        final resultText = _formatNumber(result);
        _display = resultText;

        _addToHistory('$fullExpr = $resultText');
        WidgetService.saveLastCalculation('$fullExpr = $resultText'); // Add this

        _firstNumber = result;
        _expression = '';
        _operation = '';
        _currentInput = '';
        _isNewOperation = true;
      });
    });
  }

  void _onClear() {
    HapticService.lightTap(context).then((_) {
      if (!mounted) return;
      setState(() {
        _display = '0';
        _expression = '';
        _currentInput = '';
        _firstNumber = 0;
        _operation = '';
        _isNewOperation = true;
      });
    });
  }

  void _onDelete() {
    HapticService.lightTap(context).then((_) {
      if (!mounted) return;
      setState(() {
        if (_isNewOperation) return;
        if (_currentInput.isEmpty) return;

        if (_currentInput.length > 1) {
          _currentInput = _currentInput.substring(0, _currentInput.length - 1);
          if (_currentInput == '-') _currentInput = '';
        } else {
          _currentInput = '';
        }
      });
    });
  }

  void _onPercentage() {
    HapticService.lightTap(context).then((_) {
      if (!mounted) return;
      setState(() {
        if (_currentInput.isEmpty) {
          final v = _parse(_display) / 100;
          _display = _formatNumber(v);
          _firstNumber = _parse(_display);
        } else {
          final v = _parse(_currentInput) / 100;
          _currentInput = _formatNumber(v);
        }
      });
    });
  }

  void _onPlusMinus() {
    HapticService.lightTap(context).then((_) {
      if (!mounted) return;
      setState(() {
        if (_currentInput.isEmpty) {
          if (_display == '0') return;
          if (_display.startsWith('-')) {
            _display = _display.substring(1);
          } else {
            _display = '-$_display';
          }
          _firstNumber = _parse(_display);
        } else {
          if (_currentInput.startsWith('-')) {
            _currentInput = _currentInput.substring(1);
          } else {
            _currentInput = '-$_currentInput';
          }
        }
      });
    });
  }

  // Utilities
  void _copyResult() {
    HapticService.success(context).then((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('copied: $_display'),
          duration: const Duration(milliseconds: 800),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  void _square() {
    HapticService.lightTap(context).then((_) {
      if (!mounted) return;
      setState(() {
        if (_currentInput.isNotEmpty) {
          final v = _parse(_currentInput);
          _currentInput = _formatNumber(v * v);
        } else {
          final v = _parse(_display);
          _display = _formatNumber(v * v);
          _firstNumber = _parse(_display);
        }
        _isNewOperation = true;
      });
    });
  }

  void _squareRoot() {
    HapticService.lightTap(context).then((_) {
      if (!mounted) return;
      setState(() {
        if (_currentInput.isNotEmpty) {
          final v = _parse(_currentInput);
          _currentInput = v < 0 ? 'error' : _formatNumber(sqrt(v));
        } else {
          final v = _parse(_display);
          _display = v < 0 ? 'error' : _formatNumber(sqrt(v));
          _firstNumber = _parse(_display);
        }
        _isNewOperation = true;
      });
    });
  }

  void _reciprocal() {
    HapticService.lightTap(context).then((_) {
      if (!mounted) return;
      setState(() {
        if (_currentInput.isNotEmpty) {
          final v = _parse(_currentInput);
          _currentInput = v == 0 ? 'error' : _formatNumber(1 / v);
        } else {
          final v = _parse(_display);
          _display = v == 0 ? 'error' : _formatNumber(1 / v);
          _firstNumber = _parse(_display);
        }
        _isNewOperation = true;
      });
    });
  }

  void _useHistoryResult(String line) {
    final parts = line.split('=');
    final result = parts.length > 1 ? parts.last.trim() : line.trim();
    setState(() {
      _display = result;
      _firstNumber = _parse(_display);
      _operation = '';
      _expression = '';
      _currentInput = '';
      _isNewOperation = true;
    });
  }

  // ---------------------------
  // UI
  // ---------------------------
  Widget _buildButton(
    String text, {
    Color? color,
    Color? textColor,
    double fontSize = 24,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Material(
          color: color ??
              (isDark
                  ? _withOpacity(Colors.white, 0.1)
                  : _withOpacity(Colors.black, 0.05)),
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              if (text == 'share') {
                _shareResult();
                return;
              }
              if (text == 'copy') {
                _copyResult();
                return;
              }
              if (text == 'x²') {
                _square();
                return;
              }
              if (text == '√') {
                _squareRoot();
                return;
              }
              if (text == '1/x') {
                _reciprocal();
                return;
              }
              if (text == 'C') {
                _onClear();
                return;
              }
              if (text == '⌫') {
                _onDelete();
                return;
              }
              if (text == '%') {
                _onPercentage();
                return;
              }
              if (text == '±') {
                _onPlusMinus();
                return;
              }
              if (text == '÷' || text == '×' || text == '-' || text == '+') {
                _onOperationPressed(text);
                return;
              }
              if (text == '=') {
                _onEqual();
                return;
              }
              _onNumberPressed(text);
              HapticService.lightTap(context);
            },
            child: Container(
              alignment: Alignment.center,
              child: Text(
                text,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  color: textColor ?? (isDark ? Colors.white : Colors.black),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _displayArea(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final exprColor = isDark ? Colors.white70 : Colors.black54;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragEnd: (details) {
        HapticService.swipe(context).then((_) {
          if (mounted) setState(() => _historyOpen = true);
        });
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.bottomRight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (_chainLine().isNotEmpty)
              Text(
                _chainLine(),
                style: TextStyle(
                  fontSize: 18,
                  color: exprColor,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.right,
              ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'total',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: exprColor,
                  ),
                ),
                const Spacer(),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomRight,
                  child: Text(
                    _display,
                    style: const TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.w300,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyOverlay(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final historyTextColor = isDark ? Colors.white : Colors.black87;
    final dividerColor = isDark
        ? _withOpacity(Colors.white, 0.14)
        : _withOpacity(Colors.black, 0.18);

    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _historyOpen = false),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.10),
            alignment: Alignment.topCenter,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 88, 14, 0),
                child: Material(
                  color: isDark
                      ? _withOpacity(Colors.white, 0.10)
                      : _withOpacity(Colors.white, 0.75),
                  borderRadius: BorderRadius.circular(26),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(26),
                    onTap: () {},
                    child: SizedBox(
                      height: 230,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                        child: Column(
                          children: [
                            Center(
                              child: Icon(
                                Icons.keyboard_arrow_up_rounded,
                                size: 28,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Expanded(
                              child: _history.isEmpty
                                  ? Center(
                                      child: Text(
                                        'No recent calculations',
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black54,
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
                                                alignment: Alignment.centerRight,
                                                child: SelectableText(
                                                  line,
                                                  textAlign: TextAlign.right,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    color: historyTextColor,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            IconButton(
                                              tooltip: 'Use result',
                                              icon: Icon(
                                                Icons.subdirectory_arrow_left_rounded,
                                                color: isDark
                                                    ? Colors.white70
                                                    : Colors.black54,
                                              ),
                                              onPressed: () {
                                                _useHistoryResult(line);
                                                setState(() => _historyOpen = false);
                                              },
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: () {
                                  setState(() => _history.clear());
                                  _saveHistory();
                                },
                                child: Text(
                                  'Clear history',
                                  style: TextStyle(color: historyTextColor),
                                ),
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
    return Stack(
      children: [
        Column(
          children: [
            Expanded(flex: 2, child: _displayArea(context)),
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          _buildButton('share', fontSize: 14),
                          _buildButton('x²', fontSize: 16),
                          _buildButton('√', fontSize: 18),
                          _buildButton('1/x', fontSize: 16),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          _buildButton('C',
                              color: _withOpacity(Colors.red, 0.8),
                              textColor: Colors.white),
                          _buildButton('÷'),
                          _buildButton('×'),
                          _buildButton('⌫', fontSize: 20),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          _buildButton('7'),
                          _buildButton('8'),
                          _buildButton('9'),
                          _buildButton('-'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          _buildButton('4'),
                          _buildButton('5'),
                          _buildButton('6'),
                          _buildButton('+'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          _buildButton('1'),
                          _buildButton('2'),
                          _buildButton('3'),
                          _buildButton('=',
                              color: _withOpacity(Colors.blue, 0.8),
                              textColor: Colors.white),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          _buildButton('%'),
                          _buildButton('±'),
                          _buildButton('0'),
                          _buildButton('.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (_historyOpen) _historyOverlay(context),
      ],
    );
  }
}