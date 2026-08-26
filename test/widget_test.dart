import 'package:flutter_test/flutter_test.dart';
import 'package:deneme1/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
  });
}