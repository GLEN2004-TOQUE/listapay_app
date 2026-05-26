import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ListaPay/core/widgets/simple_loading.dart';

void main() {
  testWidgets('SimpleLoading shows message', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SimpleLoading(message: 'Loading store...'),
        ),
      ),
    );
    expect(find.text('Loading store...'), findsOneWidget);
    expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
  });
}
