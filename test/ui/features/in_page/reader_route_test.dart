import 'package:container/domain/models/reader_article.dart';
import 'package:container/domain/models/reader_style.dart';
import 'package:container/domain/repositories/repositories.dart';
import 'package:container/ui/features/in_page/views/reader_route.dart';
import 'package:container/ui/features/in_page/views/reader_screen.dart';
import 'package:container/ui/features/settings/view_models/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemorySettings implements SettingsRepository {
  final values = <String, String>{};

  @override
  Future<bool> getBool(String key, {bool fallback = false}) async =>
      values.containsKey(key) ? values[key] == 'true' : fallback;

  @override
  Future<void> setBool(String key, bool value) async => values[key] = '$value';

  @override
  Future<String?> getString(String key, {String? fallback}) async => values[key] ?? fallback;

  @override
  Future<void> setString(String key, String value) async => values[key] = value;
}

/// User's ruling, 2026-09-30: Aa and ◑ are remembered per vault.
void main() {
  const article = ReaderArticle(
    host: 'forum.example.com',
    title: 'What a container actually isolates, and what it cannot',
    paragraphs: ['Separate storage stops one site from reading another\'s cookies.'],
    minutesToRead: 6,
  );

  Future<void> pump(WidgetTester tester, _MemorySettings settings) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [settingsRepositoryProvider.overrideWithValue(settings)],
      child: MaterialApp(home: ReaderRoute(article: article, onClose: () {})),
    ));
    await tester.pumpAndSettle();
  }

  ReaderStyle styleShown(WidgetTester tester) =>
      tester.widget<ReaderScreen>(find.byType(ReaderScreen)).style;

  testWidgets('opens with the vault\'s saved style', (tester) async {
    final settings = _MemorySettings()
      ..values['reader_text_size'] = ReaderTextSize.largest.name
      ..values['reader_contrast'] = 'soft';
    await pump(tester, settings);

    expect(styleShown(tester).size, ReaderTextSize.largest);
    expect(styleShown(tester).soft, isTrue);
  });

  testWidgets('Aa and ◑ change the page and are saved', (tester) async {
    final settings = _MemorySettings();
    await pump(tester, settings);
    expect(styleShown(tester).size, ReaderTextSize.standard);

    await tester.tap(find.text('Aa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('◑'));
    await tester.pumpAndSettle();

    expect(styleShown(tester).size, ReaderTextSize.larger);
    expect(styleShown(tester).soft, isTrue);
    expect(settings.values['reader_text_size'], ReaderTextSize.larger.name);
    expect(settings.values['reader_contrast'], 'soft');
  });
}
