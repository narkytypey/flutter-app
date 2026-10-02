import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/app.dart';
import 'package:container/ui/core/tokens.dart';

void main() {
  testWidgets('the app boots on the container dark theme', (tester) async {
    await tester.pumpWidget(const ContainerApp());

    final theme = Theme.of(tester.element(find.byType(Scaffold)));
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, const Color(0xFF0F1113));
    expect(theme.colorScheme.primary, const Color(0xFF7FC8A9));
    expect(theme.textTheme.bodyMedium!.fontFamily, 'Figtree');
  });

  test('the restyle names four canvas colours without changing them', () {
    expect(C.handle, const Color(0xFF2C3134));
    expect(C.pillText, const Color(0xFFA9B0AE));
    expect(C.dangerPanel, const Color(0xFF1A1517));
    expect(C.pinError, const Color(0xFF4A3634));
  });
}
