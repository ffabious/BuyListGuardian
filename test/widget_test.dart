// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:buylistguard/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('User can add, toggle, and persist buy items', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storage = await BuyListStorage.create();

    await tester.pumpWidget(BuyListApp(storage: storage));
    await tester.pumpAndSettle();

    expect(find.textContaining('Your list is empty'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Milk');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Milk'), findsOneWidget);
    expect(_checkboxValue(tester), isTrue);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect(_checkboxValue(tester), isFalse);

    final reloadedStorage = await BuyListStorage.create();
    final items = await reloadedStorage.loadItems();
    expect(items, hasLength(1));
    final firstItem = items.first;
    expect(firstItem.name, 'Milk');
    expect(firstItem.needed, isFalse);
  });
}

bool _checkboxValue(WidgetTester tester) {
  final checkbox = tester.widget<Checkbox>(find.byType(Checkbox).first);
  return checkbox.value ?? false;
}
