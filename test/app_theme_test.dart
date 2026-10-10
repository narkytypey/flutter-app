import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/app.dart';
import 'package:container/ui/core/tokens.dart';

void main() {
  testWidgets('the app boots on the container dark theme', (tester) async {
    await tester.pumpWidget(const ContainerApp());

    final theme = Theme.of(tester.element(find.byType(Scaffold)));
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, const Color(0xFF0B0D12));
    expect(theme.colorScheme.primary, const Color(0xFF3DF5D0));
    expect(theme.textTheme.bodyMedium!.fontFamily, 'IBMPlexSans');
  });

  test('the restyle names four canvas colours without changing them', () {
    expect(C.handle, const Color(0xFF7A87A0));
    expect(C.pillText, const Color(0xFFE6EDF7));
    expect(C.dangerSurface, const Color(0xFF2A1520));
    expect(C.pinError, const Color(0xFFFF7AA6));
  });
}
