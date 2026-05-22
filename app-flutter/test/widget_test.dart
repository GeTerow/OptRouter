import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rotaotimizada/main.dart';

void main() {
  testWidgets('App should build without errors', (WidgetTester tester) async {
    await tester.pumpWidget(
      RotaOtimizadaApp(
        firebaseInitialization: Completer<FirebaseApp>().future,
      ),
    );
  });
}
