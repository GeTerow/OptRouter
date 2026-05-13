import 'package:flutter_test/flutter_test.dart';

import 'package:rotaotimizada/main.dart';

void main() {
  testWidgets('App should build without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const RotaOtimizadaApp());
  });
}
