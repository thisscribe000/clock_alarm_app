import 'package:flutter_test/flutter_test.dart';
import 'package:clock_alarm_app/main.dart';

void main() {
  testWidgets('app starts without errors', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp(initialDarkMode: false));

    // Verify that our app displays calculator and converter tabs
    expect(find.text('calculator'), findsOneWidget);
    expect(find.text('converter'), findsOneWidget);
  });
}