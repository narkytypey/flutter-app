import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/app.dart';

void main() {
  testWidgets('the app boots on the container dark theme', (tester) async {
    await tester.pumpWidget(const ContainerApp());

    final theme = Theme.of(tester.element(find.byType(Scaffold)));
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, const Color(0xFF0F1113));
    expect(theme.colorScheme.primary, const Color(0xFF7FC8A9));
    expect(theme.textTheme.bodyMedium!.fontFamily, 'Figtree');
  });
}
