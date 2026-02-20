import 'package:flutter/material.dart';
import 'calculator_screen.dart';
import 'currency_screen.dart';
import '../screens/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final bool isDarkMode;

  const HomeScreen({
    super.key,
    required this.onThemeToggle,
    required this.isDarkMode,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int get _selectedIndex => _tabController.index;

  @override
  Widget build(BuildContext context) {
    // Use actual theme instead of passed bool
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color selectedPillColor = isDark
        ? const Color(0x26FFFFFF) // 15% white
        : const Color(0x14000000); // 8% black

    final Color segmentBg = isDark
        ? const Color(0x0FFFFFFF) // subtle
        : const Color(0x08000000); // subtle

    final Color selectedTextColor = isDark ? Colors.white : Colors.black;
    final Color unselectedTextColor = isDark ? Colors.white38 : Colors.black45;

    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: segmentBg,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Stack(
                        children: [
                          AnimatedAlign(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                            alignment: _selectedIndex == 0
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                            child: FractionallySizedBox(
                              widthFactor: 0.5,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: selectedPillColor,
                                  borderRadius: BorderRadius.circular(26),
                                ),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _tabController.animateTo(0),
                                  child: Center(
                                    child: Text(
                                      'calculator',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: _selectedIndex == 0
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: _selectedIndex == 0
                                            ? selectedTextColor
                                            : unselectedTextColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _tabController.animateTo(1),
                                  child: Center(
                                    child: Text(
                                      'converter',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: _selectedIndex == 1
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: _selectedIndex == 1
                                            ? selectedTextColor
                                            : unselectedTextColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(left: 10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? const Color(0x1AFFFFFF) // 10% white
                          : const Color(0x0F000000), // 6% black
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.settings, size: 22),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        );
                      },
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                CalculatorScreen(),
                CurrencyScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}