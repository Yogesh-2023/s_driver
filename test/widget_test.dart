import 'package:flutter_test/flutter_test.dart';

import 'package:driver_flutter/main.dart';

void main() {
  testWidgets('driver app opens login after splash', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DriverApp());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('Join as Driver Partner'), findsOneWidget);
  });
}
