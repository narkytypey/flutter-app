# Isolated Web Container — Plan 1: Foundation, Design System and Dashboard

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A running Android app that boots into the session-list dashboard (design option `1b`), backed by a real local database, with the design system it and every later screen are built from.

**Architecture:** Flutter UI over a local SQLite store, Riverpod for state. The dashboard is a pure widget (`DashboardBody`) fed a plain view model, with a thin provider-wired wrapper (`DashboardScreen`) around it — so every screen in this and later plans is testable without async plumbing. Session open/idle state is deliberately **runtime-only** and never persisted, because the product promise is that sessions do not survive the app closing. No WebView, no proxy, no PIN in this plan; those are Plans 2 and 3, and this plan leaves named seams for them.

**Tech Stack:** Flutter (stable channel), Dart 3, `flutter_riverpod`, `sqflite` (+ `sqflite_common_ffi` for host tests), `path`, `path_provider`. Fonts Figtree and IBM Plex Mono, **bundled as assets** — never fetched at runtime.

**Spec:**
- `Sandbox Container -canvas-.dc.html` — the authoritative source: exact copy, colours, sizes and layout for all 32 screens. Read the block whose `id` matches the option you are building (e.g. `id="1b"`).
- `Sandbox Container.dc.html` — same screens, print layout.
- `app-design.pdf` — rendered version of the above; the HTML wins on any disagreement.

**Assumption stated up front:** the product is being built for real, with a native Android layer later (androidx WebView profiles for true per-site storage isolation, an in-app local proxy for filtering and SOCKS5 forwarding). Plan 1 contains none of that, but the domain model here is shaped for it. If the project is instead a UI-only prototype, this plan is unchanged; only Plan 3 changes.

---

## Global Constraints

Every task's requirements implicitly include this section.

- **Android only. Dark theme only.** The design note on turn 7 is explicit: "Dark only, as decided." Do not add a light theme, a theme toggle, or `Brightness.light` anywhere.
- **English UI.** No localisation layer in this plan.
- **The app makes no network requests of its own.** From setup step 3 (`5a`): "Nothing is sent anywhere — No account, no sync, no analytics." This is why fonts are bundled assets and why `google_fonts` (which fetches at runtime) must not be used.
- **User-facing copy is verbatim from the spec.** Never paraphrase, re-capitalise or "improve" a string. If a string is not in the spec, it is a design question — stop and ask.
- **Jade `#7FC8A9` means live state or the single affirmative action on a screen.** Turn 2: "jade only for live state". Never decorative, never a background tint, never a brand accent on idle content.
- **Hairline dividers, not cards.** Turn 2: "hairline dividers instead of cards". Rows are separated by 1px white-alpha lines; they do not sit in elevated containers.
- **IBM Plex Mono for anything technical**, Figtree for everything else. Turn 2: "mono for anything technical".
- **Base background is `#0F1113`** on every screen except the three that state otherwise (`3c` panic `#0C0E10`, `9a` recents `#0A0B0C`, `6b` reader `#12100D`).
- **Reference device is 428 × 908 logical pixels** (`hint-size` in every spec block). All spec sizes are logical pixels — use them as-is, do not rescale.
- **Danger is `#D66A5A`, warning is `#D6A45B`.** Danger is never a filled button background; it appears as text, a 1px border at 28% alpha, or the `#241C1D` surface.
- **App label is "Container"** (from `9a`, "Recents — neutral name"). `applicationId` is `com.mono.container`.
- `minSdk 26`, `targetSdk 36`. Plan 3 may raise `minSdk`; do not raise it here.
- **Threat model: coerced unlock, not forensic disk imaging.** The adversary is a person holding the phone who can compel an unlock. The decoy board must be convincing on screen, and the real vault must be unreachable with the decoy PIN. Explicitly out of scope, and acceptable: someone who images the disk can see that two encrypted stores exist. They cannot read the second one.
- **The decoy is a second store, not a filter.** Two vaults, two data keys, selected by which PIN successfully unwraps. One database with a "hide this row" boolean fails at the only moment it is tested — the attacker has the PIN you handed them, and the rows they were not meant to see are decrypted and flagged. Plan 1 therefore never assumes a single store, and never names a store file for its role.
- **No query in this app filters rows for privacy, and no aggregate counts across vaults.** This follows from the constraint above and is the practical reason for it. A filter model would put the whole promise on every query in the codebase remembering to exclude hidden rows — including aggregates that count before they filter, like this plan's own `2 SESSIONS · 0 LEAKS`, and later the Today log, cross-workspace search and the quick switcher. That is a discipline with a large surface, not a boundary. With two stores the open vault is the only data that exists at runtime, so counting everything you can see is automatically correct.
- **No code generation.** No `build_runner`, no `freezed`, no `drift`. Hand-written mappers only — this keeps the execution loop fast and the diffs readable.

---

## File Structure

```
pubspec.yaml
assets/fonts/Figtree.ttf                 variable weight axis, bundled
assets/fonts/IBMPlexMono-Regular.ttf
assets/fonts/IBMPlexMono-Medium.ttf
android/app/src/main/AndroidManifest.xml label "Container"

lib/main.dart                            opens the database, runs the app
lib/app.dart                             MaterialApp + theme, home = DashboardScreen

lib/ui/core/tokens.dart                  every colour and marker, copied from spec
lib/ui/core/typography.dart              ui()/mono() builders + named styles
lib/ui/core/theme.dart                   ThemeData assembled from the tokens
lib/ui/core/widgets/hairline.dart        1px divider
lib/ui/core/widgets/section_label.dart   10px .1em caps label
lib/ui/core/widgets/monogram.dart        rounded monogram square
lib/ui/core/widgets/status_rail.dart     3px live/idle rail
lib/ui/core/widgets/pill_button.dart     the rounded action buttons
lib/ui/core/widgets/dashed_box.dart      dashed rounded border (empty state)

lib/domain/models/workspace.dart         Workspace + StorageRule
lib/domain/models/site.dart              Site + CookiePolicy + ProxyMode
lib/domain/models/monogram_suggestion.dart  suggestMonogram()
lib/domain/models/relative_age.dart      relativeAge()
lib/domain/models/site_descriptor.dart   siteDescriptor()
lib/domain/repositories/repositories.dart   WorkspaceRepository, SiteRepository

lib/data/services/app_database.dart      Vault, sqflite open + schema v1 + seed
lib/data/repositories/workspace_repository_sqlite.dart
lib/data/repositories/site_repository_sqlite.dart

lib/ui/features/dashboard/view_models/dashboard_view.dart   DashboardView, SessionEntry
lib/ui/features/dashboard/view_models/providers.dart        the provider graph
lib/ui/features/dashboard/views/dashboard_body.dart         pure widget, no providers
lib/ui/features/dashboard/views/dashboard_screen.dart       provider-wired wrapper
lib/ui/features/dashboard/views/workspace_bar.dart
lib/ui/features/dashboard/views/session_row.dart
lib/ui/features/dashboard/views/dashboard_footer.dart
lib/ui/features/dashboard/views/empty_workspace.dart
lib/ui/features/dashboard/views/workspace_menu.dart

test/ui/core/primitives_test.dart
test/domain/relative_age_test.dart
test/domain/monogram_suggestion_test.dart
test/domain/site_descriptor_test.dart
test/data/repositories_test.dart
test/ui/features/dashboard_body_test.dart
test/ui/features/workspace_menu_test.dart
test/app_theme_test.dart
```

This is the layered structure the `dart-flutter:flutter-apply-architecture-best-practices` skill prescribes: UI grouped by feature under `ui/`, data and domain grouped by type. Two deliberate deviations from that skill, both worth stating rather than leaving as silent drift:

- **No `freezed`/`built_value` for the domain models.** The skill suggests them; this plan forbids code generation outright (see Global Constraints), so `Workspace` and `Site` are hand-written immutables with explicit `copyWith` and `==`. The models are small and stable enough that the generator earns nothing, and every task in this plan stays a single `flutter test` away from feedback.
- **Riverpod providers instead of `ChangeNotifier` view models.** The skill allows any `Listenable`; `dashboardProvider` and `workspaceOptionsProvider` in `view_models/` are the ViewModel layer, and they expose exactly what MVVM asks for — an immutable `DashboardView` snapshot to a View that holds no logic.

Each file has one job. `dashboard_body.dart` never imports `package:flutter_riverpod` — that separation is what makes the widget tests trivial, and later plans follow the same rule.

---

## Task 1: Project scaffold, bundled fonts, dark theme

**Files:**
- Create: `pubspec.yaml` (generated, then edited), `lib/main.dart`, `lib/app.dart`
- Create: `assets/fonts/Figtree.ttf`, `assets/fonts/IBMPlexMono-Regular.ttf`, `assets/fonts/IBMPlexMono-Medium.ttf`
- Modify: `android/app/src/main/AndroidManifest.xml`, `android/app/build.gradle.kts`
- Test: `test/app_theme_test.dart`

**Interfaces:**
- Consumes: nothing (first task).
- Produces: `ContainerApp` (a `StatelessWidget` with a const constructor) and `containerTheme()` returning `ThemeData`. Every later task builds inside `ContainerApp`.

- [ ] **Step 1: Install the Flutter SDK and confirm the Android toolchain**

Flutter is not currently on this machine; the Android SDK already is, at `C:\Users\Metin\AppData\Local\Android\Sdk`. In PowerShell:

```powershell
git clone --depth 1 -b stable https://github.com/flutter/flutter.git C:\src\flutter
[Environment]::SetEnvironmentVariable('Path', "C:\src\flutter\bin;" + [Environment]::GetEnvironmentVariable('Path','User'), 'User')
$env:Path = "C:\src\flutter\bin;$env:Path"
flutter --version
flutter doctor
```

Expected: `flutter --version` prints a stable release. `flutter doctor` shows Flutter and "Android toolchain" with checkmarks. If Android licences are unaccepted, run `flutter doctor --android-licenses` and accept.

- [ ] **Step 2: Create the Flutter project in the existing directory**

The directory already holds the design files; `flutter create .` works in a non-empty directory and leaves them alone.

```powershell
cd C:\Users\Metin\Desktop\flutter-app
flutter create --org com.mono --project-name container --platforms=android .
flutter run --debug
```

Expected: the counter app builds and launches on a device or emulator. Stop it once you have seen it run.

- [ ] **Step 3: Initialise git and make the first commit**

```bash
git init
printf '%s\n' 'build/' '.dart_tool/' '.idea/' '*.iml' 'android/.gradle/' 'android/local.properties' '.flutter-plugins*' > .gitignore
git add -A
git commit -m "chore: scaffold Flutter Android project"
```

- [ ] **Step 4: Download the two bundled font families**

```powershell
New-Item -ItemType Directory -Force assets\fonts | Out-Null
curl.exe -fL -o assets\fonts\Figtree.ttf            "https://github.com/google/fonts/raw/main/ofl/figtree/Figtree%5Bwght%5D.ttf"
curl.exe -fL -o assets\fonts\IBMPlexMono-Regular.ttf "https://github.com/google/fonts/raw/main/ofl/ibmplexmono/IBMPlexMono-Regular.ttf"
curl.exe -fL -o assets\fonts\IBMPlexMono-Medium.ttf  "https://github.com/google/fonts/raw/main/ofl/ibmplexmono/IBMPlexMono-Medium.ttf"
Get-ChildItem assets\fonts | Select-Object Name, Length
```

Expected: three files, each well over 20 KB. `curl.exe -f` fails loudly on a 404 rather than writing an HTML error page.

If the Figtree variable-font URL 404s (upstream repo layouts do move), use the static instances instead and declare four separate `asset:` entries with explicit `weight:` in Step 5:
`https://github.com/google/fonts/raw/main/ofl/figtree/static/Figtree-Regular.ttf`, `-Medium.ttf`, `-SemiBold.ttf`, `-Bold.ttf`.

- [ ] **Step 5: Declare dependencies and fonts in `pubspec.yaml`**

Replace the `dependencies`, `dev_dependencies` and `flutter` sections:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1
  sqflite: ^2.3.3
  path: ^1.9.0
  path_provider: ^2.1.4

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  sqflite_common_ffi: ^2.3.3

flutter:
  uses-material-design: true
  fonts:
    - family: Figtree
      fonts:
        - asset: assets/fonts/Figtree.ttf
    - family: IBMPlexMono
      fonts:
        - asset: assets/fonts/IBMPlexMono-Regular.ttf
        - asset: assets/fonts/IBMPlexMono-Medium.ttf
          weight: 500
```

Then:

```bash
flutter pub get
```

- [ ] **Step 6: Set the neutral app label and SDK levels**

In `android/app/src/main/AndroidManifest.xml`, change the `<application>` label:

```xml
    <application
        android:label="Container"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
```

In `android/app/build.gradle.kts`, inside `defaultConfig`:

```kotlin
        applicationId = "com.mono.container"
        minSdk = 26
        targetSdk = 36
```

- [ ] **Step 7: Write the failing theme test**

Create `test/app_theme_test.dart`:

```dart
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
```

- [ ] **Step 8: Run the test to verify it fails**

Run: `flutter test test/app_theme_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:container/app.dart'`.

- [ ] **Step 9: Write the tokens the theme needs**

Create `lib/ui/core/tokens.dart`. This is the complete palette for the whole screen set, transcribed from the spec — later tasks and later plans read from it rather than adding new values.

```dart
import 'dart:ui';

/// Colour tokens for the Isolated Web Container.
///
/// Every value is copied verbatim from the design source
/// (`Sandbox Container -canvas-.dc.html`). If a screen needs a colour that is
/// not here, that is a design question, not an implementation one.
abstract final class C {
  // Surfaces
  static const bg = Color(0xFF0F1113);
  static const bgPanic = Color(0xFF0C0E10);
  static const bgRecents = Color(0xFF0A0B0C);
  static const bgReader = Color(0xFF12100D);
  static const surface = Color(0xFF15181B);
  static const sheet = Color(0xFF141719);
  static const raised = Color(0xFF181B1E);
  static const button = Color(0xFF1C2124);
  static const selected = Color(0xFF20262A);
  static const monogramOpen = Color(0xFF20252A);
  static const footer = Color(0xFF111417);
  static const trackOff = Color(0xFF232729);
  static const knobOff = Color(0xFF4A5150);
  static const skeleton = Color(0xFF1B1F22);
  static const barTrack = Color(0xFF1A1E21);

  // Hairlines — white at the alphas the spec uses. The number is the
  // percentage: line06 is rgba(255,255,255,.06).
  static const line05 = Color(0x0DFFFFFF);
  static const line06 = Color(0x0FFFFFFF);
  static const line07 = Color(0x12FFFFFF);
  static const line08 = Color(0x14FFFFFF);
  static const line09 = Color(0x17FFFFFF);
  static const line10 = Color(0x1AFFFFFF);
  static const line12 = Color(0x1FFFFFFF);
  static const line13 = Color(0x21FFFFFF);
  static const line16 = Color(0x29FFFFFF);

  // Text
  static const textPrimary = Color(0xFFE8E9E7);
  static const textSecondary = Color(0xFFD7DCDA);
  static const textTertiary = Color(0xFFB9BFBD);
  static const textMuted = Color(0xFF8A918F);
  static const textFaint = Color(0xFF6E7573);
  static const textDim = Color(0xFF5F6664);
  static const textDisabled = Color(0xFF4A5150);
  static const monogramText = Color(0xFFC7CECC);
  static const icon = Color(0xFF9AA1A0);
  static const chevron = Color(0xFF7E8583);
  static const tabInactive = Color(0xFF767D7B);

  // State
  static const jade = Color(0xFF7FC8A9);
  static const jadeCode = Color(0xFF9FD8C0);
  static const idleDot = Color(0xFF3E4644);
  static const pinEmpty = Color(0xFF3A403E);
  static const danger = Color(0xFFD66A5A);
  static const dangerSurface = Color(0xFF241C1D);
  static const dangerMuted = Color(0xFF8A6A62);
  static const warning = Color(0xFFD6A45B);

  /// Workspace markers, in the order the picker shows them (spec `10b`).
  static const markers = <Color>[
    Color(0xFF7FC8A9),
    Color(0xFF8FA5C8),
    Color(0xFFD6A45B),
    Color(0xFFC89BB4),
    Color(0xFF8A918F),
  ];
}
```

- [ ] **Step 10: Write the typography builders**

Create `lib/ui/core/typography.dart`:

```dart
import 'package:flutter/widgets.dart';

import 'tokens.dart';

const _figtree = 'Figtree';
const _plexMono = 'IBMPlexMono';

/// Figtree is bundled as a variable font, so every style sets both
/// [TextStyle.fontWeight] and an explicit `wght` variation. Setting only one
/// of the two renders at the wrong weight on some engine versions.
TextStyle ui({
  required double size,
  int weight = 400,
  Color color = C.textPrimary,
  double? height,
  double? letterSpacing,
}) {
  return TextStyle(
    fontFamily: _figtree,
    fontSize: size,
    height: height,
    letterSpacing: letterSpacing,
    color: color,
    fontWeight: FontWeight.values[(weight ~/ 100) - 1],
    fontVariations: [FontVariation('wght', weight.toDouble())],
  );
}

TextStyle mono({
  required double size,
  int weight = 400,
  Color color = C.textSecondary,
  double? height,
}) {
  return TextStyle(
    fontFamily: _plexMono,
    fontSize: size,
    height: height,
    color: color,
    fontWeight: FontWeight.values[(weight ~/ 100) - 1],
  );
}

/// Named styles that recur across the screen set.
abstract final class T {
  static TextStyle get screenTitle => ui(size: 16, weight: 600);
  static TextStyle get sheetTitle => ui(size: 17, weight: 600, letterSpacing: -0.17);
  static TextStyle get stepTitle => ui(size: 22, weight: 600, letterSpacing: -0.22);
  static TextStyle get appBarTitle => ui(size: 15, weight: 600);

  static TextStyle get rowTitle => ui(size: 14.5, weight: 500);
  static TextStyle get rowTitleIdle => ui(size: 14.5, weight: 500, color: C.textTertiary);

  static TextStyle get body => ui(size: 14);
  static TextStyle get bodyMuted => ui(size: 13, color: C.textMuted, height: 1.65);

  static TextStyle get meta => ui(size: 10.5, color: C.textFaint);
  static TextStyle get metaIdle => ui(size: 10.5, color: C.textDim);

  /// 10px / 500 / .1em uppercase — the section label used across the set.
  static TextStyle get sectionLabel =>
      ui(size: 10, weight: 500, letterSpacing: 1.0, color: C.textFaint);
  static TextStyle get sectionLabelLive =>
      ui(size: 10, weight: 500, letterSpacing: 1.0, color: C.jade);

  /// The workspace summary on the right of the dashboard bar (spec `1b`).
  static TextStyle get barSummary => ui(size: 10, color: C.textFaint);

  /// The storage-rule badge that replaces it (spec `5b`).
  static TextStyle get barBadge =>
      ui(size: 10.5, weight: 500, letterSpacing: 0.63, color: C.textFaint);

  static TextStyle get code => mono(size: 11.5, height: 1.9, color: C.jadeCode);
}
```

- [ ] **Step 11: Assemble the theme and the app shell**

Create `lib/ui/core/theme.dart`:

```dart
import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

ThemeData containerTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Figtree',
    scaffoldBackgroundColor: C.bg,
    canvasColor: C.bg,
    colorScheme: const ColorScheme.dark(
      surface: C.bg,
      onSurface: C.textPrimary,
      primary: C.jade,
      onPrimary: C.bg,
      secondary: C.jade,
      error: C.danger,
    ),
    dividerColor: C.line06,
    splashColor: C.line05,
    highlightColor: C.line05,
    textTheme: TextTheme(
      titleLarge: T.stepTitle,
      titleMedium: T.screenTitle,
      bodyLarge: T.rowTitle,
      bodyMedium: T.body,
      bodySmall: T.meta,
      labelSmall: T.sectionLabel,
    ),
  );
}
```

Create `lib/app.dart`:

```dart
import 'package:flutter/material.dart';

import 'ui/core/theme.dart';
import 'ui/core/tokens.dart';

class ContainerApp extends StatelessWidget {
  const ContainerApp({super.key, this.home});

  /// Overridden by [main]; defaults to a bare surface so widget tests can
  /// pump the app without a database.
  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Container',
      debugShowCheckedModeBanner: false,
      theme: containerTheme(),
      home: home ?? const Scaffold(backgroundColor: C.bg),
    );
  }
}
```

Create `lib/main.dart`:

```dart
import 'package:flutter/material.dart';

import 'app.dart';

void main() {
  runApp(const ContainerApp());
}
```

- [ ] **Step 12: Run the test to verify it passes**

Run: `flutter test test/app_theme_test.dart`
Expected: PASS, 1 test.

- [ ] **Step 13: Commit**

```bash
git add -A
git commit -m "feat: dark theme, bundled fonts and design tokens"
```

---

## Task 2: Shared design primitives

Build only the five primitives the dashboard and its empty state need. Later plans add more as their screens require them — do not build a speculative widget library.

**Files:**
- Create: `lib/ui/core/widgets/hairline.dart`, `section_label.dart`, `monogram.dart`, `status_rail.dart`, `pill_button.dart`, `dashed_box.dart`
- Test: `test/ui/core/primitives_test.dart`

**Interfaces:**
- Consumes: `C` and `T` from Task 1.
- Produces:
  - `Hairline({Color color = C.line06})`
  - `SectionLabel(String text, {bool live = false})`
  - `Monogram(String text, {double size = 36, double radius = 10, double fontSize = 14, bool open = true})`
  - `StatusRail({required bool live})`
  - `PillButton({required String label, required VoidCallback? onTap, String? sublabel, PillTone tone = PillTone.neutral, double height = 48, double? radius})` with `enum PillTone { primary, neutral, dangerOutline }`
  - `DashedBox({required double size, required double radius, Color color = C.line16})`

- [ ] **Step 1: Write the failing primitives test**

Create `test/ui/core/primitives_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/core/widgets/monogram.dart';
import 'package:container/ui/core/widgets/pill_button.dart';
import 'package:container/ui/core/widgets/section_label.dart';
import 'package:container/ui/core/widgets/status_rail.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(home: Scaffold(body: Center(child: child))),
  );
}

void main() {
  testWidgets('a live rail is jade, an idle rail is a hairline', (tester) async {
    await _pump(tester, const Row(children: [StatusRail(live: true), StatusRail(live: false)]));

    final rails = tester.widgetList<Container>(find.byType(Container)).toList();
    final live = rails.first.decoration! as BoxDecoration;
    final idle = rails.last.decoration! as BoxDecoration;
    expect(live.color, C.jade);
    expect(idle.color, C.line09);
    expect(tester.getSize(find.byType(StatusRail).first).width, 3);
  });

  testWidgets('an open monogram is brighter than an idle one', (tester) async {
    await _pump(tester, const Monogram('Nt'));
    expect(find.text('Nt'), findsOneWidget);
    expect(tester.getSize(find.byType(Monogram)), const Size(36, 36));

    final open = tester.widget<Text>(find.text('Nt')).style!.color;
    expect(open, C.monogramText);

    await _pump(tester, const Monogram('Fr', open: false));
    expect(tester.widget<Text>(find.text('Fr')).style!.color, C.textMuted);
  });

  testWidgets('a section label is uppercase-styled and jade only when live', (tester) async {
    await _pump(tester, const Column(children: [
      SectionLabel('OPEN NOW', live: true),
      SectionLabel('IDLE'),
    ]));

    expect(tester.widget<Text>(find.text('OPEN NOW')).style!.color, C.jade);
    expect(tester.widget<Text>(find.text('IDLE')).style!.color, C.textFaint);
    expect(tester.widget<Text>(find.text('IDLE')).style!.letterSpacing, 1.0);
  });

  testWidgets('a primary pill is jade with dark text and reports taps', (tester) async {
    var taps = 0;
    await _pump(tester, PillButton(
      label: '+ Add site',
      tone: PillTone.primary,
      height: 46,
      radius: 14,
      onTap: () => taps++,
    ));

    expect(tester.widget<Text>(find.text('+ Add site')).style!.color, C.bg);
    await tester.tap(find.byType(PillButton));
    expect(taps, 1);
  });

  testWidgets('a disabled pill does not report taps', (tester) async {
    await _pump(tester, const PillButton(label: 'Continue', onTap: null));
    await tester.tap(find.byType(PillButton));
    // Nothing to assert beyond "did not throw"; the callback is null.
    expect(find.text('Continue'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/ui/core/primitives_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:container/ui/core/widgets/status_rail.dart'`.

- [ ] **Step 3: Write the primitives**

`lib/ui/core/widgets/hairline.dart`:

```dart
import 'package:flutter/widgets.dart';

import '../tokens.dart';

/// A 1 logical-pixel divider. The design uses hairlines instead of cards, so
/// this is the main structural element of the whole set.
class Hairline extends StatelessWidget {
  const Hairline({super.key, this.color = C.line06});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(height: 1, color: color);
}
```

`lib/ui/core/widgets/section_label.dart`:

```dart
import 'package:flutter/widgets.dart';

import '../typography.dart';

/// The 10px letterspaced caps label. [text] must already be uppercase — copy
/// is verbatim from the spec, so casing is not this widget's decision.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.live = false});

  final String text;
  final bool live;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: live ? T.sectionLabelLive : T.sectionLabel);
}
```

`lib/ui/core/widgets/monogram.dart`:

```dart
import 'package:flutter/widgets.dart';

import '../tokens.dart';
import '../typography.dart';

/// The rounded two-letter square that stands in for a site. [open] switches it
/// between the live and idle treatments.
class Monogram extends StatelessWidget {
  const Monogram(
    this.text, {
    super.key,
    this.size = 36,
    this.radius = 10,
    this.fontSize = 14,
    this.open = true,
  });

  final String text;
  final double size;
  final double radius;
  final double fontSize;
  final bool open;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: open ? C.monogramOpen : C.raised,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        text,
        style: ui(
          size: fontSize,
          weight: 600,
          color: open ? C.monogramText : C.textMuted,
        ),
      ),
    );
  }
}
```

`lib/ui/core/widgets/status_rail.dart`:

```dart
import 'package:flutter/widgets.dart';

import '../tokens.dart';

/// The 3px rail on the left of a session row. Jade means the session is live;
/// this is one of the few places jade is allowed.
class StatusRail extends StatelessWidget {
  const StatusRail({super.key, required this.live});

  final bool live;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      decoration: BoxDecoration(
        color: live ? C.jade : C.line09,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
```

`lib/ui/core/widgets/pill_button.dart`:

```dart
import 'package:flutter/material.dart';

import '../tokens.dart';
import '../typography.dart';

enum PillTone {
  /// Jade fill, dark label. At most one per screen.
  primary,

  /// The `#1C2124` fill used for everything else.
  neutral,

  /// A 28%-alpha danger border with danger text. Danger is never a fill.
  dangerOutline,
}

/// The rounded action button. Heights and radii differ per screen, so both are
/// parameters; the spec value is always passed explicitly at the call site.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.sublabel,
    this.tone = PillTone.neutral,
    this.height = 48,
    this.radius,
  });

  final String label;
  final String? sublabel;
  final VoidCallback? onTap;
  final PillTone tone;
  final double height;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius ?? height / 2);
    final enabled = onTap != null;

    final (Color? fill, Border? border, Color labelColor, int weight) = switch (tone) {
      PillTone.primary => (C.jade, null, C.bg, 600),
      PillTone.neutral => (C.button, null, enabled ? C.textSecondary : C.textDim, 500),
      PillTone.dangerOutline => (
          null,
          Border.all(color: C.danger.withValues(alpha: 0.28)),
          C.danger,
          500,
        ),
    };

    return Material(
      color: fill ?? const Color(0x00000000),
      borderRadius: r,
      child: InkWell(
        onTap: onTap,
        borderRadius: r,
        child: Container(
          height: height,
          decoration: BoxDecoration(borderRadius: r, border: border),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: ui(size: 14.5, weight: weight, color: labelColor)),
              if (sublabel != null) ...[
                const SizedBox(height: 1),
                Text(sublabel!, style: ui(size: 10.5, color: C.dangerMuted)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

`lib/ui/core/widgets/dashed_box.dart`:

```dart
import 'package:flutter/widgets.dart';

import '../tokens.dart';

/// A dashed rounded square. Flutter has no dashed border, so the empty state's
/// placeholder is painted.
class DashedBox extends StatelessWidget {
  const DashedBox({
    super.key,
    required this.size,
    required this.radius,
    this.color = C.line16,
  });

  final double size;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(size, size),
        painter: _DashedPainter(radius: radius, color: color),
      );
}

class _DashedPainter extends CustomPainter {
  const _DashedPainter({required this.radius, required this.color});

  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(radius),
      ));

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + 4).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += 8;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPainter old) =>
      old.radius != radius || old.color != color;
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/ui/core/primitives_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Run the analyzer**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: shared design primitives"
```

---

## Task 3: Domain model and the three pure functions the dashboard needs

**Files:**
- Create: `lib/domain/models/workspace.dart`, `lib/domain/models/site.dart`, `lib/domain/models/relative_age.dart`, `lib/domain/models/monogram_suggestion.dart`, `lib/domain/models/site_descriptor.dart`, `lib/domain/repositories/repositories.dart`
- Test: `test/domain/relative_age_test.dart`, `test/domain/monogram_suggestion_test.dart`, `test/domain/site_descriptor_test.dart`

**Interfaces:**
- Consumes: nothing outside `dart:core`.
- Produces:
  - `enum StorageRule { keep, wipeOnExit }`
  - `enum CookiePolicy { keep, wipeOnExit }`
  - `enum ProxyMode { direct, socks5, http }`
  - `class Workspace { String id; String name; int markerIndex; StorageRule storageRule; bool requirePin; bool showInDecoy; int sortIndex; }` — immutable, with `copyWith`
  - `class Site { String id; String workspaceId; String name; String monogram; String url; CookiePolicy cookiePolicy; ProxyMode proxyMode; String? proxyHost; int? proxyPort; bool requirePin; bool showInDecoy; DateTime? lastVisitedAt; int sortIndex; }` — immutable, with `copyWith` and a `String get host` derived from `url`
  - `String relativeAge(DateTime now, DateTime? then)`
  - `String suggestMonogram(String name)`
  - `String siteDescriptor(Site site)`
  - `abstract interface class WorkspaceRepository { Future<List<Workspace>> all(); Future<Workspace?> byId(String id); Future<void> upsert(Workspace w); Future<void> delete(String id); }`
  - `abstract interface class SiteRepository { Future<List<Site>> inWorkspace(String workspaceId); Future<void> upsert(Site s); Future<void> delete(String id); Future<void> touch(String id, DateTime at); }`

- [ ] **Step 1: Write the failing `relativeAge` test**

Create `test/domain/relative_age_test.dart`. The expected strings come straight from the seed data in the spec's `<script type="text/x-dc">` block: `now`, `14m`, `2h`, `1d`, `3d`, `5d`, and the decoy board's `2d`, `4d`, `1w`, `2w`.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/relative_age.dart';

void main() {
  final now = DateTime(2026, 8, 30, 9, 10);

  String ago(Duration d) => relativeAge(now, now.subtract(d));

  test('anything under a minute reads as now', () {
    expect(ago(Duration.zero), 'now');
    expect(ago(const Duration(seconds: 59)), 'now');
  });

  test('minutes, hours, days and weeks each get their own unit', () {
    expect(ago(const Duration(minutes: 1)), '1m');
    expect(ago(const Duration(minutes: 14)), '14m');
    expect(ago(const Duration(minutes: 59)), '59m');
    expect(ago(const Duration(hours: 2)), '2h');
    expect(ago(const Duration(hours: 23)), '23h');
    expect(ago(const Duration(days: 1)), '1d');
    expect(ago(const Duration(days: 5)), '5d');
    expect(ago(const Duration(days: 6)), '6d');
    expect(ago(const Duration(days: 7)), '1w');
    expect(ago(const Duration(days: 14)), '2w');
  });

  test('a site that has never been opened has no age', () {
    expect(relativeAge(now, null), '');
  });

  test('a clock that has gone backwards does not produce a negative age', () {
    expect(relativeAge(now, now.add(const Duration(hours: 3))), 'now');
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/domain/relative_age_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:container/domain/models/relative_age.dart'`.

- [ ] **Step 3: Write `relativeAge`**

Create `lib/domain/models/relative_age.dart`:

```dart
/// Formats how long ago a site was last opened, in the compact form the
/// dashboard uses: `now`, `14m`, `2h`, `3d`, `2w`.
///
/// Returns an empty string when the site has never been opened. A [then] in
/// the future (a clock change) reads as `now` rather than a negative age.
String relativeAge(DateTime now, DateTime? then) {
  if (then == null) return '';

  final elapsed = now.difference(then);
  if (elapsed.isNegative || elapsed.inMinutes < 1) return 'now';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes}m';
  if (elapsed.inDays < 1) return '${elapsed.inHours}h';
  if (elapsed.inDays < 7) return '${elapsed.inDays}d';
  return '${elapsed.inDays ~/ 7}w';
}
```

- [ ] **Step 4: Run it to verify it passes**

Run: `flutter test test/domain/relative_age_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Write the failing `suggestMonogram` test**

The monograms in the spec's seed data are hand-picked (`Webmail` → `Wm`, `Marketplace` → `Mk`), so no rule reproduces all of them. `suggestMonogram` is a *starting suggestion* that the user overrides in the Add site screen; the seed rows carry the spec's exact values as stored data. This test pins the rule and the override.

Create `test/domain/monogram_suggestion_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/monogram_suggestion.dart';

void main() {
  test('the suggestion is the first letter plus the next consonant', () {
    expect(suggestMonogram('Notes'), 'Nt');
    expect(suggestMonogram('Forum'), 'Fr');
    expect(suggestMonogram('Reader'), 'Rd');
    expect(suggestMonogram('Wiki'), 'Wk');
    expect(suggestMonogram('News'), 'Nw');
    expect(suggestMonogram('Weather'), 'Wt');
    expect(suggestMonogram('Recipes'), 'Rc');
  });

  test('a name with no second consonant falls back to its first two letters', () {
    expect(suggestMonogram('Idea'), 'Id');
    expect(suggestMonogram('Ai'), 'Ai');
  });

  test('a single-letter name doubles nothing', () {
    expect(suggestMonogram('X'), 'X');
  });

  test('leading whitespace and empty names are handled', () {
    expect(suggestMonogram('  scratch tab'), 'Sc');
    expect(suggestMonogram(''), '');
    expect(suggestMonogram('   '), '');
  });
}
```

- [ ] **Step 6: Run it to verify it fails**

Run: `flutter test test/domain/monogram_suggestion_test.dart`
Expected: FAIL — missing file.

- [ ] **Step 7: Write `suggestMonogram`**

Create `lib/domain/models/monogram_suggestion.dart`:

```dart
const _vowels = {'a', 'e', 'i', 'o', 'u'};

/// Suggests the two-letter monogram for a newly added site: the first letter,
/// then the next consonant after it.
///
/// This is only a suggestion. `Site.monogram` is stored, and the Add site
/// screen lets the user replace it — which is why the seeded sites can carry
/// the design's hand-picked values (`Webmail` → `Wm`) that no rule produces.
String suggestMonogram(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '';

  final first = trimmed[0].toUpperCase();
  if (trimmed.length == 1) return first;

  for (var i = 1; i < trimmed.length; i++) {
    final ch = trimmed[i].toLowerCase();
    if (!_isLetter(ch)) continue;
    if (!_vowels.contains(ch)) return '$first$ch';
  }

  return '$first${trimmed[1].toLowerCase()}';
}

bool _isLetter(String ch) {
  final c = ch.codeUnitAt(0);
  return c >= 0x61 && c <= 0x7A;
}
```

- [ ] **Step 8: Run it to verify it passes**

Run: `flutter test test/domain/monogram_suggestion_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 9: Write the entities**

Create `lib/domain/models/workspace.dart`:

```dart
/// Whether a workspace keeps its storage between runs of the app.
enum StorageRule { keep, wipeOnExit }

class Workspace {
  const Workspace({
    required this.id,
    required this.name,
    required this.markerIndex,
    required this.storageRule,
    this.requirePin = false,
    this.showInDecoy = false,
    this.sortIndex = 0,
  });

  final String id;
  final String name;

  /// Index into `C.markers` — the five swatches in the picker (spec `10b`).
  final int markerIndex;
  final StorageRule storageRule;

  /// "Ask for PIN to enter · Applies to the whole workspace" (spec `10b`).
  final bool requirePin;

  /// "Show in decoy vault · Off keeps it invisible behind the second PIN".
  final bool showInDecoy;
  final int sortIndex;

  Workspace copyWith({
    String? name,
    int? markerIndex,
    StorageRule? storageRule,
    bool? requirePin,
    bool? showInDecoy,
    int? sortIndex,
  }) {
    return Workspace(
      id: id,
      name: name ?? this.name,
      markerIndex: markerIndex ?? this.markerIndex,
      storageRule: storageRule ?? this.storageRule,
      requirePin: requirePin ?? this.requirePin,
      showInDecoy: showInDecoy ?? this.showInDecoy,
      sortIndex: sortIndex ?? this.sortIndex,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Workspace &&
      other.id == id &&
      other.name == name &&
      other.markerIndex == markerIndex &&
      other.storageRule == storageRule &&
      other.requirePin == requirePin &&
      other.showInDecoy == showInDecoy &&
      other.sortIndex == sortIndex;

  @override
  int get hashCode => Object.hash(
      id, name, markerIndex, storageRule, requirePin, showInDecoy, sortIndex);
}
```

Create `lib/domain/models/site.dart`:

```dart
/// Whether a site's cookies survive closing it.
enum CookiePolicy { keep, wipeOnExit }

/// How a site's traffic is routed. The design's rule (turn 8) is that a site
/// set to a proxy never silently falls back to [direct].
enum ProxyMode { direct, socks5, http }

class Site {
  const Site({
    required this.id,
    required this.workspaceId,
    required this.name,
    required this.monogram,
    required this.url,
    this.cookiePolicy = CookiePolicy.keep,
    this.proxyMode = ProxyMode.direct,
    this.proxyHost,
    this.proxyPort,
    this.requirePin = false,
    this.showInDecoy = false,
    this.lastVisitedAt,
    this.sortIndex = 0,
  });

  final String id;
  final String workspaceId;
  final String name;
  final String monogram;
  final String url;
  final CookiePolicy cookiePolicy;
  final ProxyMode proxyMode;
  final String? proxyHost;
  final int? proxyPort;
  final bool requirePin;
  final bool showInDecoy;
  final DateTime? lastVisitedAt;
  final int sortIndex;

  /// The bare host shown in the dashboard's meta line — `forum.example.com`
  /// from `https://forum.example.com/threads`.
  String get host => Uri.tryParse(url)?.host ?? url;

  Site copyWith({
    String? name,
    String? monogram,
    String? url,
    CookiePolicy? cookiePolicy,
    ProxyMode? proxyMode,
    String? proxyHost,
    int? proxyPort,
    bool? requirePin,
    bool? showInDecoy,
    DateTime? lastVisitedAt,
    int? sortIndex,
  }) {
    return Site(
      id: id,
      workspaceId: workspaceId,
      name: name ?? this.name,
      monogram: monogram ?? this.monogram,
      url: url ?? this.url,
      cookiePolicy: cookiePolicy ?? this.cookiePolicy,
      proxyMode: proxyMode ?? this.proxyMode,
      proxyHost: proxyHost ?? this.proxyHost,
      proxyPort: proxyPort ?? this.proxyPort,
      requirePin: requirePin ?? this.requirePin,
      showInDecoy: showInDecoy ?? this.showInDecoy,
      lastVisitedAt: lastVisitedAt ?? this.lastVisitedAt,
      sortIndex: sortIndex ?? this.sortIndex,
    );
  }

  @override
  bool operator ==(Object other) => other is Site && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
```

- [ ] **Step 10: Write the failing `siteDescriptor` test**

The dashboard meta line is `host · descriptor`. The spec's Personal rows give the four descriptors and their precedence.

Create `test/domain/site_descriptor_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/site_descriptor.dart';

Site _site({
  CookiePolicy cookies = CookiePolicy.keep,
  ProxyMode proxy = ProxyMode.direct,
  bool requirePin = false,
}) {
  return Site(
    id: 's',
    workspaceId: 'w',
    name: 'Site',
    monogram: 'St',
    url: 'https://example.com',
    cookiePolicy: cookies,
    proxyMode: proxy,
    requirePin: requirePin,
  );
}

void main() {
  test('a plain site reads as direct', () {
    expect(siteDescriptor(_site()), 'direct');
  });

  test('a proxied site names its scheme', () {
    expect(siteDescriptor(_site(proxy: ProxyMode.socks5)), 'socks5');
    expect(siteDescriptor(_site(proxy: ProxyMode.http)), 'http');
  });

  test('wiping cookies reads as ephemeral and outranks the proxy', () {
    expect(siteDescriptor(_site(cookies: CookiePolicy.wipeOnExit)), 'ephemeral');
    expect(
      siteDescriptor(_site(cookies: CookiePolicy.wipeOnExit, proxy: ProxyMode.socks5)),
      'ephemeral',
    );
  });

  test('a PIN requirement outranks everything', () {
    expect(
      siteDescriptor(_site(
        requirePin: true,
        cookies: CookiePolicy.wipeOnExit,
        proxy: ProxyMode.socks5,
      )),
      'pin required',
    );
  });
}
```

- [ ] **Step 11: Run it to verify it fails**

Run: `flutter test test/domain/site_descriptor_test.dart`
Expected: FAIL — missing file.

- [ ] **Step 12: Write `siteDescriptor`**

Create `lib/domain/models/site_descriptor.dart`:

```dart
import 'site.dart';

/// The second half of a dashboard row's meta line — `forum.example.com ·
/// ephemeral`. One descriptor wins; the order below is the order the design's
/// Personal workspace shows (spec `1b`).
///
/// Note: the spec's `Scratch tab` mock row reads `wipes on exit` where this
/// rule yields `ephemeral`. That is an inconsistency in the mock data, not two
/// different states, and it is resolved here in favour of the rule.
String siteDescriptor(Site site) {
  if (site.requirePin) return 'pin required';
  if (site.cookiePolicy == CookiePolicy.wipeOnExit) return 'ephemeral';
  return switch (site.proxyMode) {
    ProxyMode.socks5 => 'socks5',
    ProxyMode.http => 'http',
    ProxyMode.direct => 'direct',
  };
}
```

- [ ] **Step 13: Write the repository interfaces**

Create `lib/domain/repositories/repositories.dart`:

```dart
import '../models/site.dart';
import '../models/workspace.dart';

abstract interface class WorkspaceRepository {
  Future<List<Workspace>> all();
  Future<Workspace?> byId(String id);
  Future<void> upsert(Workspace workspace);
  Future<void> delete(String id);
}

abstract interface class SiteRepository {
  Future<List<Site>> inWorkspace(String workspaceId);
  Future<void> upsert(Site site);
  Future<void> delete(String id);

  /// Records that a site was just opened, which drives its dashboard age.
  Future<void> touch(String id, DateTime at);
}
```

- [ ] **Step 14: Run the whole domain suite and the analyzer**

Run: `flutter test test/domain/ && flutter analyze`
Expected: PASS, 12 tests. `No issues found!`

- [ ] **Step 15: Commit**

```bash
git add -A
git commit -m "feat: domain model, relative age, monogram and descriptor rules"
```

---

## Task 4: SQLite persistence

**Files:**
- Create: `lib/data/services/app_database.dart`, `lib/data/repositories/workspace_repository_sqlite.dart`, `lib/data/repositories/site_repository_sqlite.dart`
- Modify: `lib/main.dart`
- Test: `test/data/repositories_test.dart`

**Interfaces:**
- Consumes: `Workspace`, `Site`, the enums, and both repository interfaces from Task 3.
- Produces:
  - `enum Vault { a, b }` and `String vaultFileName(Vault vault)`
  - `class AppDatabase { static Future<AppDatabase> open({required String path, DatabaseFactory? factory}); Database get db; Future<void> close(); }`
  - `class SqliteWorkspaceRepository implements WorkspaceRepository { SqliteWorkspaceRepository(AppDatabase); }`
  - `class SqliteSiteRepository implements SiteRepository { SqliteSiteRepository(AppDatabase); }`
  - `Future<void> seedIfEmpty(AppDatabase db)` — inserts the spec's Personal / Work / Ephemeral workspaces and their sites, with the design's exact hand-picked monograms.

`open` takes a path and an optional factory rather than a fixed filename, because Plan 2 opens **two** of these — one per vault, each with its own key. A vault is chosen by which PIN successfully unwraps its data key; there is no runtime "which rows may I see" decision anywhere, and no code path in which one key opens both stores.

Plan 1 opens only `Vault.a` and does not encrypt it. What Plan 1 owes Plan 2 is a shape that a second vault fits into, which is why the filename comes from `vaultFileName` rather than a literal.

- [ ] **Step 1: Write the failing repository test**

Create `test/data/repositories_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/data/repositories/site_repository_sqlite.dart';
import 'package:container/data/repositories/workspace_repository_sqlite.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/workspace.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;

  setUp(() async {
    database = await AppDatabase.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
  });

  tearDown(() => database.close());

  test('a fresh database seeds the three workspaces from the spec', () async {
    await seedIfEmpty(database);
    final workspaces = await SqliteWorkspaceRepository(database).all();

    expect(workspaces.map((w) => w.name), ['Personal', 'Work', 'Ephemeral']);
    expect(workspaces.last.storageRule, StorageRule.wipeOnExit);
  });

  test('seeding twice does not duplicate anything', () async {
    await seedIfEmpty(database);
    await seedIfEmpty(database);

    expect((await SqliteWorkspaceRepository(database).all()).length, 3);
  });

  test('the seeded Personal sites keep the design\'s hand-picked monograms', () async {
    await seedIfEmpty(database);
    final personal = (await SqliteWorkspaceRepository(database).all()).first;
    final sites = await SqliteSiteRepository(database).inWorkspace(personal.id);

    expect(sites.map((s) => s.name),
        ['Notes', 'Webmail', 'Forum', 'Reader', 'Bank', 'Marketplace']);
    expect(sites.map((s) => s.monogram),
        ['Nt', 'Wm', 'Fr', 'Rd', 'Bk', 'Mk']);
  });

  test('a site round-trips every field through the database', () async {
    final workspaces = SqliteWorkspaceRepository(database);
    final sites = SqliteSiteRepository(database);

    await workspaces.upsert(const Workspace(
      id: 'w1',
      name: 'Research',
      markerIndex: 1,
      storageRule: StorageRule.keep,
      requirePin: true,
    ));

    final visited = DateTime.utc(2026, 8, 30, 9, 10);
    await sites.upsert(Site(
      id: 's1',
      workspaceId: 'w1',
      name: 'Forum',
      monogram: 'Fr',
      url: 'https://forum.example.com',
      cookiePolicy: CookiePolicy.wipeOnExit,
      proxyMode: ProxyMode.socks5,
      proxyHost: '127.0.0.1',
      proxyPort: 9050,
      showInDecoy: true,
      lastVisitedAt: visited,
      sortIndex: 3,
    ));

    final loaded = (await sites.inWorkspace('w1')).single;
    expect(loaded.name, 'Forum');
    expect(loaded.cookiePolicy, CookiePolicy.wipeOnExit);
    expect(loaded.proxyMode, ProxyMode.socks5);
    expect(loaded.proxyHost, '127.0.0.1');
    expect(loaded.proxyPort, 9050);
    expect(loaded.showInDecoy, isTrue);
    expect(loaded.lastVisitedAt, visited);
    expect(loaded.sortIndex, 3);
    expect(loaded.host, 'forum.example.com');
  });

  test('touch updates only the last-visited time', () async {
    final sites = SqliteSiteRepository(database);
    await SqliteWorkspaceRepository(database).upsert(const Workspace(
      id: 'w1', name: 'W', markerIndex: 0, storageRule: StorageRule.keep));
    await sites.upsert(const Site(
      id: 's1', workspaceId: 'w1', name: 'N', monogram: 'Nt',
      url: 'https://n.example.com'));

    final at = DateTime.utc(2026, 8, 30, 12);
    await sites.touch('s1', at);

    final loaded = (await sites.inWorkspace('w1')).single;
    expect(loaded.lastVisitedAt, at);
    expect(loaded.name, 'N');
  });

  test('neither vault file is named for its role', () {
    // Under the coerced-unlock threat model the attacker is looking at the
    // device, so a file called `decoy.db` would give away the whole scheme.
    final names = {vaultFileName(Vault.a), vaultFileName(Vault.b)};

    expect(names.length, 2, reason: 'the two vaults must not share a file');
    for (final name in names) {
      expect(name.toLowerCase(), isNot(contains('decoy')));
      expect(name.toLowerCase(), isNot(contains('real')));
      expect(name.toLowerCase(), isNot(contains('hidden')));
    }
  });

  test('deleting a workspace removes its sites', () async {
    await seedIfEmpty(database);
    final workspaces = SqliteWorkspaceRepository(database);
    final personal = (await workspaces.all()).first;

    await workspaces.delete(personal.id);

    expect(await SqliteSiteRepository(database).inWorkspace(personal.id), isEmpty);
    expect((await workspaces.all()).length, 2);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/data/repositories_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:container/data/services/app_database.dart'`.

- [ ] **Step 3: Write the database, schema and seed**

Create `lib/data/services/app_database.dart`:

```dart
import 'package:sqflite/sqflite.dart';

import '../../domain/models/site.dart';
import '../../domain/models/workspace.dart';

/// Which of the two stores is open.
///
/// The vaults are peers. Neither is named for its role on disk, because a file
/// called `decoy.db` leaks precisely what the decoy exists to hide — and under
/// the coerced-unlock threat model the attacker is looking at the device.
enum Vault { a, b }

String vaultFileName(Vault vault) => switch (vault) {
      Vault.a => 'store-1.db',
      Vault.b => 'store-2.db',
    };

/// One vault's store. Nothing here leaves the device.
///
/// [open] takes a path and an optional factory so tests can run in-memory on
/// the host, and so Plan 2 can open each vault through a factory keyed from
/// the data key that vault's PIN unwrapped. Two vaults means two live
/// [AppDatabase] instances with two different keys — never one store with a
/// visibility flag over it.
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static const schemaVersion = 1;

  static Future<AppDatabase> open({
    required String path,
    DatabaseFactory? factory,
  }) async {
    final open = factory?.openDatabase ?? databaseFactory.openDatabase;
    final db = await open(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE workspaces (
              id            TEXT PRIMARY KEY,
              name          TEXT    NOT NULL,
              marker_index  INTEGER NOT NULL,
              storage_rule  TEXT    NOT NULL,
              require_pin   INTEGER NOT NULL DEFAULT 0,
              show_in_decoy INTEGER NOT NULL DEFAULT 0,
              sort_index    INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE sites (
              id              TEXT PRIMARY KEY,
              workspace_id    TEXT    NOT NULL
                                REFERENCES workspaces(id) ON DELETE CASCADE,
              name            TEXT    NOT NULL,
              monogram        TEXT    NOT NULL,
              url             TEXT    NOT NULL,
              cookie_policy   TEXT    NOT NULL,
              proxy_mode      TEXT    NOT NULL,
              proxy_host      TEXT,
              proxy_port      INTEGER,
              require_pin     INTEGER NOT NULL DEFAULT 0,
              -- Provisioning only: "copy this row into the other vault when
              -- the decoy is set up". It is never read as a runtime filter,
              -- and rows in the decoy's own store do not use it.
              show_in_decoy   INTEGER NOT NULL DEFAULT 0,
              last_visited_at INTEGER,
              sort_index      INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await db.execute(
              'CREATE INDEX idx_sites_workspace ON sites(workspace_id)');
        },
      ),
    );
    return AppDatabase._(db);
  }

  Future<void> close() => db.close();
}

/// Inserts the workspaces and sites the design shows, so the dashboard has
/// something real to render on a fresh install. Does nothing if any workspace
/// already exists.
Future<void> seedIfEmpty(AppDatabase database) async {
  final existing = Sqflite.firstIntValue(
      await database.db.rawQuery('SELECT COUNT(*) FROM workspaces'));
  if (existing != null && existing > 0) return;

  final now = DateTime.now();
  DateTime ago(Duration d) => now.subtract(d);

  const workspaces = [
    Workspace(
        id: 'ws-personal', name: 'Personal', markerIndex: 0,
        storageRule: StorageRule.keep, sortIndex: 0),
    Workspace(
        id: 'ws-work', name: 'Work', markerIndex: 1,
        storageRule: StorageRule.keep, sortIndex: 1),
    Workspace(
        id: 'ws-ephemeral', name: 'Ephemeral', markerIndex: 4,
        storageRule: StorageRule.wipeOnExit, sortIndex: 2),
  ];

  // Monograms are the design's hand-picked values, not suggestMonogram output.
  final sites = <Site>[
    Site(
        id: 'st-notes', workspaceId: 'ws-personal', name: 'Notes',
        monogram: 'Nt', url: 'https://notes.example.org',
        proxyMode: ProxyMode.socks5, proxyHost: '127.0.0.1', proxyPort: 9050,
        lastVisitedAt: ago(const Duration(seconds: 20)), sortIndex: 0),
    Site(
        id: 'st-webmail', workspaceId: 'ws-personal', name: 'Webmail',
        monogram: 'Wm', url: 'https://mail.example.net',
        lastVisitedAt: ago(const Duration(minutes: 14)), sortIndex: 1),
    Site(
        id: 'st-forum', workspaceId: 'ws-personal', name: 'Forum',
        monogram: 'Fr', url: 'https://forum.example.com',
        cookiePolicy: CookiePolicy.wipeOnExit,
        lastVisitedAt: ago(const Duration(hours: 2)), sortIndex: 2),
    Site(
        id: 'st-reader', workspaceId: 'ws-personal', name: 'Reader',
        monogram: 'Rd', url: 'https://read.example.io',
        lastVisitedAt: ago(const Duration(days: 1)), sortIndex: 3),
    Site(
        id: 'st-bank', workspaceId: 'ws-personal', name: 'Bank',
        monogram: 'Bk', url: 'https://bank.example.com', requirePin: true,
        lastVisitedAt: ago(const Duration(days: 3)), sortIndex: 4),
    Site(
        id: 'st-market', workspaceId: 'ws-personal', name: 'Marketplace',
        monogram: 'Mk', url: 'https://shop.example.com',
        lastVisitedAt: ago(const Duration(days: 5)), sortIndex: 5),
    Site(
        id: 'st-wiki', workspaceId: 'ws-work', name: 'Wiki',
        monogram: 'Wk', url: 'https://wiki.internal',
        proxyMode: ProxyMode.socks5, proxyHost: '127.0.0.1', proxyPort: 9050,
        lastVisitedAt: ago(const Duration(minutes: 3)), sortIndex: 0),
    Site(
        id: 'st-tickets', workspaceId: 'ws-work', name: 'Tickets',
        monogram: 'Tk', url: 'https://tickets.internal',
        lastVisitedAt: ago(const Duration(hours: 1)), sortIndex: 1),
  ];

  await database.db.transaction((txn) async {
    for (final w in workspaces) {
      await txn.insert('workspaces', workspaceToRow(w));
    }
    for (final s in sites) {
      await txn.insert('sites', siteToRow(s));
    }
  });
}

// ---------------------------------------------------------------- mapping --

Map<String, Object?> workspaceToRow(Workspace w) => {
      'id': w.id,
      'name': w.name,
      'marker_index': w.markerIndex,
      'storage_rule': w.storageRule.name,
      'require_pin': w.requirePin ? 1 : 0,
      'show_in_decoy': w.showInDecoy ? 1 : 0,
      'sort_index': w.sortIndex,
    };

Workspace workspaceFromRow(Map<String, Object?> r) => Workspace(
      id: r['id']! as String,
      name: r['name']! as String,
      markerIndex: r['marker_index']! as int,
      storageRule: StorageRule.values.byName(r['storage_rule']! as String),
      requirePin: (r['require_pin']! as int) == 1,
      showInDecoy: (r['show_in_decoy']! as int) == 1,
      sortIndex: r['sort_index']! as int,
    );

Map<String, Object?> siteToRow(Site s) => {
      'id': s.id,
      'workspace_id': s.workspaceId,
      'name': s.name,
      'monogram': s.monogram,
      'url': s.url,
      'cookie_policy': s.cookiePolicy.name,
      'proxy_mode': s.proxyMode.name,
      'proxy_host': s.proxyHost,
      'proxy_port': s.proxyPort,
      'require_pin': s.requirePin ? 1 : 0,
      'show_in_decoy': s.showInDecoy ? 1 : 0,
      'last_visited_at': s.lastVisitedAt?.millisecondsSinceEpoch,
      'sort_index': s.sortIndex,
    };

Site siteFromRow(Map<String, Object?> r) {
  final visited = r['last_visited_at'] as int?;
  return Site(
    id: r['id']! as String,
    workspaceId: r['workspace_id']! as String,
    name: r['name']! as String,
    monogram: r['monogram']! as String,
    url: r['url']! as String,
    cookiePolicy: CookiePolicy.values.byName(r['cookie_policy']! as String),
    proxyMode: ProxyMode.values.byName(r['proxy_mode']! as String),
    proxyHost: r['proxy_host'] as String?,
    proxyPort: r['proxy_port'] as int?,
    requirePin: (r['require_pin']! as int) == 1,
    showInDecoy: (r['show_in_decoy']! as int) == 1,
    lastVisitedAt:
        visited == null ? null : DateTime.fromMillisecondsSinceEpoch(visited, isUtc: true),
    sortIndex: r['sort_index']! as int,
  );
}
```

- [ ] **Step 4: Write the two repositories**

Create `lib/data/repositories/workspace_repository_sqlite.dart`:

```dart
import 'package:sqflite/sqflite.dart';

import '../../domain/models/workspace.dart';
import '../../domain/repositories/repositories.dart';
import '../services/app_database.dart';

class SqliteWorkspaceRepository implements WorkspaceRepository {
  const SqliteWorkspaceRepository(this._database);

  final AppDatabase _database;

  @override
  Future<List<Workspace>> all() async {
    final rows = await _database.db.query('workspaces', orderBy: 'sort_index');
    return rows.map(workspaceFromRow).toList();
  }

  @override
  Future<Workspace?> byId(String id) async {
    final rows = await _database.db
        .query('workspaces', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : workspaceFromRow(rows.first);
  }

  @override
  Future<void> upsert(Workspace workspace) async {
    await _database.db.insert(
      'workspaces',
      workspaceToRow(workspace),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> delete(String id) async {
    await _database.db.delete('workspaces', where: 'id = ?', whereArgs: [id]);
  }
}
```


Create `lib/data/repositories/site_repository_sqlite.dart`:

```dart
import 'package:sqflite/sqflite.dart';

import '../../domain/repositories/repositories.dart';
import '../../domain/models/site.dart';
import '../services/app_database.dart';

class SqliteSiteRepository implements SiteRepository {
  const SqliteSiteRepository(this._database);

  final AppDatabase _database;

  @override
  Future<List<Site>> inWorkspace(String workspaceId) async {
    final rows = await _database.db.query(
      'sites',
      where: 'workspace_id = ?',
      whereArgs: [workspaceId],
      orderBy: 'sort_index',
    );
    return rows.map(siteFromRow).toList();
  }

  @override
  Future<void> upsert(Site site) async {
    await _database.db.insert(
      'sites',
      siteToRow(site),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> delete(String id) async {
    await _database.db.delete('sites', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> touch(String id, DateTime at) async {
    await _database.db.update(
      'sites',
      {'last_visited_at': at.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/data/repositories_test.dart`
Expected: PASS, 7 tests.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: sqlite persistence for workspaces and sites"
```

---

## Task 5: The dashboard (spec `1b`)

**Files:**
- Create: `lib/ui/features/dashboard/view_models/dashboard_view.dart`, `dashboard_body.dart`, `widgets/workspace_bar.dart`, `widgets/session_row.dart`, `widgets/dashboard_footer.dart`
- Test: `test/ui/features/dashboard_body_test.dart`

**Interfaces:**
- Consumes: `C`, `T`, `Hairline`, `SectionLabel`, `Monogram`, `StatusRail`, `PillButton`, `Site`, `Workspace`, `relativeAge`, `siteDescriptor`.
- Produces:
  - `class SessionEntry { String siteId; String name; String monogram; String meta; String age; bool live; }`
  - `class DashboardView { String workspaceName; bool wipesOnExit; int sessionCount; int leakCount; List<SessionEntry> open; List<SessionEntry> idle; bool get isEmpty; static DashboardView from({required Workspace workspace, required List<Site> sites, required Set<String> openSiteIds, required int leakCount, required DateTime now}); }`
  - `class DashboardBody extends StatelessWidget { DashboardBody({required DashboardView view, required VoidCallback onWorkspaceTap, required VoidCallback onAddSite, required VoidCallback onSearch, required void Function(String siteId) onOpenSite, required void Function(String siteId) onSiteMenu}) }`

`DashboardBody` takes no providers, so the tests below construct a view directly.

- [ ] **Step 1: Write the failing dashboard test**

Create `test/ui/features/dashboard_body_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/ui/features/dashboard/views/dashboard_body.dart';
import 'package:container/ui/features/dashboard/view_models/dashboard_view.dart';

final _now = DateTime(2026, 8, 30, 9, 10);

Site _site(String id, String name, String mono, String url, Duration ago,
        {CookiePolicy cookies = CookiePolicy.keep,
        ProxyMode proxy = ProxyMode.direct,
        bool pin = false}) =>
    Site(
      id: id, workspaceId: 'ws', name: name, monogram: mono, url: url,
      cookiePolicy: cookies, proxyMode: proxy, requirePin: pin,
      lastVisitedAt: _now.subtract(ago),
    );

DashboardView _personal({Set<String> open = const {'st-notes', 'st-webmail'}}) {
  return DashboardView.from(
    workspace: const Workspace(
        id: 'ws', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep),
    sites: [
      _site('st-notes', 'Notes', 'Nt', 'https://notes.example.org',
          const Duration(seconds: 10), proxy: ProxyMode.socks5),
      _site('st-webmail', 'Webmail', 'Wm', 'https://mail.example.net',
          const Duration(minutes: 14)),
      _site('st-forum', 'Forum', 'Fr', 'https://forum.example.com',
          const Duration(hours: 2), cookies: CookiePolicy.wipeOnExit),
      _site('st-bank', 'Bank', 'Bk', 'https://bank.example.com',
          const Duration(days: 3), pin: true),
    ],
    openSiteIds: open,
    leakCount: 0,
    now: _now,
  );
}

Future<void> _pump(WidgetTester tester, DashboardView view,
    {void Function(String)? onOpenSite, VoidCallback? onAddSite}) {
  return tester.pumpWidget(MaterialApp(
    home: DashboardBody(
      view: view,
      onWorkspaceTap: () {},
      onAddSite: onAddSite ?? () {},
      onSearch: () {},
      onOpenSite: onOpenSite ?? (_) {},
      onSiteMenu: (_) {},
    ),
  ));
}

void main() {
  testWidgets('the bar names the workspace and counts sessions and leaks',
      (tester) async {
    await _pump(tester, _personal());

    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('2 SESSIONS · 0 LEAKS'), findsOneWidget);
  });

  testWidgets('sites are grouped into OPEN NOW and IDLE', (tester) async {
    await _pump(tester, _personal());

    expect(find.text('OPEN NOW'), findsOneWidget);
    expect(find.text('IDLE'), findsOneWidget);

    final openLabel = tester.getTopLeft(find.text('OPEN NOW')).dy;
    final idleLabel = tester.getTopLeft(find.text('IDLE')).dy;
    expect(tester.getTopLeft(find.text('Notes')).dy, greaterThan(openLabel));
    expect(tester.getTopLeft(find.text('Notes')).dy, lessThan(idleLabel));
    expect(tester.getTopLeft(find.text('Forum')).dy, greaterThan(idleLabel));
  });

  testWidgets('each row shows host and descriptor, and its age', (tester) async {
    await _pump(tester, _personal());

    expect(find.text('notes.example.org · socks5'), findsOneWidget);
    expect(find.text('mail.example.net · direct'), findsOneWidget);
    expect(find.text('forum.example.com · ephemeral'), findsOneWidget);
    expect(find.text('bank.example.com · pin required'), findsOneWidget);

    expect(find.text('now'), findsOneWidget);
    expect(find.text('14m'), findsOneWidget);
    expect(find.text('2h'), findsOneWidget);
    expect(find.text('3d'), findsOneWidget);
  });

  testWidgets('an open row is brighter than an idle one', (tester) async {
    await _pump(tester, _personal());

    expect(tester.widget<Text>(find.text('Notes')).style!.color, C.textPrimary);
    expect(tester.widget<Text>(find.text('Forum')).style!.color, C.textTertiary);
  });

  testWidgets('tapping a row opens that site', (tester) async {
    final opened = <String>[];
    await _pump(tester, _personal(), onOpenSite: opened.add);

    await tester.tap(find.text('Forum'));
    expect(opened, ['st-forum']);
  });

  testWidgets('with nothing open the OPEN NOW group is absent', (tester) async {
    await _pump(tester, _personal(open: const {}));

    expect(find.text('OPEN NOW'), findsNothing);
    expect(find.text('IDLE'), findsOneWidget);
    expect(find.text('0 SESSIONS · 0 LEAKS'), findsOneWidget);
  });

  testWidgets('the footer offers Add site and reports taps', (tester) async {
    var added = 0;
    await _pump(tester, _personal(), onAddSite: () => added++);

    expect(find.text('+ Add site'), findsOneWidget);
    await tester.tap(find.text('+ Add site'));
    expect(added, 1);
  });

  testWidgets('a wipe-on-exit workspace shows its rule instead of counts',
      (tester) async {
    await _pump(
      tester,
      DashboardView.from(
        workspace: const Workspace(
            id: 'ws', name: 'Ephemeral', markerIndex: 4,
            storageRule: StorageRule.wipeOnExit),
        sites: const [],
        openSiteIds: const {},
        leakCount: 0,
        now: _now,
      ),
    );

    expect(find.text('WIPES ON EXIT'), findsOneWidget);
    expect(find.textContaining('SESSIONS'), findsNothing);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/ui/features/dashboard_body_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:container/ui/features/dashboard/view_models/dashboard_view.dart'`.

- [ ] **Step 3: Write the view model**

Create `lib/ui/features/dashboard/view_models/dashboard_view.dart`:

```dart
import '../../../../domain/models/relative_age.dart';
import '../../../../domain/models/site.dart';
import '../../../../domain/models/site_descriptor.dart';
import '../../../../domain/models/workspace.dart';

/// One row on the dashboard, already reduced to strings. The widget layer does
/// no formatting of its own.
class SessionEntry {
  const SessionEntry({
    required this.siteId,
    required this.name,
    required this.monogram,
    required this.meta,
    required this.age,
    required this.live,
  });

  final String siteId;
  final String name;
  final String monogram;

  /// `forum.example.com · ephemeral`
  final String meta;

  /// `now`, `14m`, `2h`, `3d`
  final String age;
  final bool live;
}

class DashboardView {
  const DashboardView({
    required this.workspaceName,
    required this.wipesOnExit,
    required this.sessionCount,
    required this.leakCount,
    required this.open,
    required this.idle,
  });

  final String workspaceName;

  /// True for a workspace whose storage rule is wipe-on-exit; the bar shows
  /// `WIPES ON EXIT` instead of the session counts (spec `5b`).
  final bool wipesOnExit;
  final int sessionCount;
  final int leakCount;
  final List<SessionEntry> open;
  final List<SessionEntry> idle;

  bool get isEmpty => open.isEmpty && idle.isEmpty;

  /// Which sites are live is runtime state, not stored state: sessions do not
  /// survive the app closing, so [openSiteIds] comes from a provider rather
  /// than from the database.
  static DashboardView from({
    required Workspace workspace,
    required List<Site> sites,
    required Set<String> openSiteIds,
    required int leakCount,
    required DateTime now,
  }) {
    SessionEntry entry(Site s, bool live) => SessionEntry(
          siteId: s.id,
          name: s.name,
          monogram: s.monogram,
          meta: '${s.host} · ${siteDescriptor(s)}',
          age: relativeAge(now, s.lastVisitedAt),
          live: live,
        );

    final open = <SessionEntry>[];
    final idle = <SessionEntry>[];
    for (final site in sites) {
      final live = openSiteIds.contains(site.id);
      (live ? open : idle).add(entry(site, live));
    }

    return DashboardView(
      workspaceName: workspace.name,
      wipesOnExit: workspace.storageRule == StorageRule.wipeOnExit,
      sessionCount: open.length,
      leakCount: leakCount,
      open: open,
      idle: idle,
    );
  }
}
```

- [ ] **Step 4: Write the three widgets**

Create `lib/ui/features/dashboard/views/workspace_bar.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/hairline.dart';

/// The top bar: workspace name with a dropdown caret on the left, and either
/// the session counts or the workspace's storage rule on the right.
class WorkspaceBar extends StatelessWidget {
  const WorkspaceBar({
    super.key,
    required this.name,
    required this.trailing,
    required this.trailingIsBadge,
    required this.onTap,
  });

  final String name;
  final String trailing;
  final bool trailingIsBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: onTap,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(name, style: T.appBarTitle),
                    const SizedBox(width: 7),
                    const Icon(Icons.keyboard_arrow_down,
                        size: 14, color: C.chevron),
                  ],
                ),
              ),
              Text(
                trailing,
                style: trailingIsBadge ? T.barBadge : T.barSummary,
              ),
            ],
          ),
        ),
        const Hairline(),
      ],
    );
  }
}
```

Create `lib/ui/features/dashboard/views/session_row.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/monogram.dart';
import '../../../core/widgets/status_rail.dart';
import '../view_models/dashboard_view.dart';

/// One site on the dashboard. Hairline-separated, never a card.
class SessionRow extends StatelessWidget {
  const SessionRow({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onLongPress,
  });

  final SessionEntry entry;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final live = entry.live;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: C.line05)),
        ),
        child: IntrinsicHeight(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                StatusRail(live: live),
                const SizedBox(width: 12),
                Monogram(entry.monogram, open: live),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.name,
                          style: live ? T.rowTitle : T.rowTitleIdle),
                      const SizedBox(height: 3),
                      Text(
                        entry.meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: live ? T.meta : T.metaIdle,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  entry.age,
                  style: live
                      ? ui(size: 10.5, color: C.textMuted)
                      : T.metaIdle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

Create `lib/ui/features/dashboard/views/dashboard_footer.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/widgets/hairline.dart';
import '../../../core/widgets/pill_button.dart';

/// The bottom bar: `+ Add site` plus search, within thumb reach.
///
/// [emphasise] turns the primary button jade — the empty state is the one
/// place the design does that (spec `5b`), because it is the only action left.
class DashboardFooter extends StatelessWidget {
  const DashboardFooter({
    super.key,
    required this.onAddSite,
    required this.onSearch,
    this.emphasise = false,
  });

  final VoidCallback onAddSite;
  final VoidCallback onSearch;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Hairline(),
        ColoredBox(
          color: C.footer,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
            child: Row(
              children: [
                Expanded(
                  child: PillButton(
                    label: '+ Add site',
                    tone: emphasise ? PillTone.primary : PillTone.neutral,
                    height: 46,
                    radius: 14,
                    onTap: onAddSite,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 46,
                  height: 46,
                  child: Material(
                    color: C.button,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: onSearch,
                      borderRadius: BorderRadius.circular(14),
                      child: const Icon(Icons.search, size: 20, color: C.icon),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Write `DashboardBody`**

Create `lib/ui/features/dashboard/views/dashboard_body.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/widgets/section_label.dart';
import 'dashboard_view.dart';
import 'dashboard_footer.dart';
import 'session_row.dart';
import 'workspace_bar.dart';

/// The dashboard, spec option `1b`. Takes a finished view model and callbacks,
/// so it can be pumped in a widget test with no providers and no database.
class DashboardBody extends StatelessWidget {
  const DashboardBody({
    super.key,
    required this.view,
    required this.onWorkspaceTap,
    required this.onAddSite,
    required this.onSearch,
    required this.onOpenSite,
    required this.onSiteMenu,
  });

  final DashboardView view;
  final VoidCallback onWorkspaceTap;
  final VoidCallback onAddSite;
  final VoidCallback onSearch;
  final void Function(String siteId) onOpenSite;
  final void Function(String siteId) onSiteMenu;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            WorkspaceBar(
              name: view.workspaceName,
              trailing: view.wipesOnExit
                  ? 'WIPES ON EXIT'
                  : '${view.sessionCount} SESSIONS · ${view.leakCount} LEAKS',
              trailingIsBadge: view.wipesOnExit,
              onTap: onWorkspaceTap,
            ),
            Expanded(child: _list()),
            DashboardFooter(
              onAddSite: onAddSite,
              onSearch: onSearch,
              emphasise: view.isEmpty,
            ),
          ],
        ),
      ),
    );
  }

  Widget _list() {
    final children = <Widget>[];

    if (view.open.isNotEmpty) {
      children.add(const Padding(
        padding: EdgeInsets.fromLTRB(18, 16, 18, 6),
        child: SectionLabel('OPEN NOW', live: true),
      ));
      children.addAll(view.open.map(_row));
    }

    if (view.idle.isNotEmpty) {
      children.add(const Padding(
        padding: EdgeInsets.fromLTRB(18, 20, 18, 6),
        child: SectionLabel('IDLE'),
      ));
      children.addAll(view.idle.map(_row));
    }

    return ListView(padding: EdgeInsets.zero, children: children);
  }

  Widget _row(SessionEntry entry) => SessionRow(
        key: ValueKey(entry.siteId),
        entry: entry,
        onTap: () => onOpenSite(entry.siteId),
        onLongPress: () => onSiteMenu(entry.siteId),
      );
}
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/ui/features/dashboard_body_test.dart`
Expected: PASS, 8 tests.

- [ ] **Step 7: Run the analyzer and the whole suite**

Run: `flutter analyze && flutter test`
Expected: `No issues found!` and all tests passing.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: dashboard session list (spec 1b)"
```

---

## Task 6: Workspace switcher, empty state, and wiring the app to the database

This is the task that makes the app real: launching it shows seeded data, and switching workspaces changes what is on screen.

**Files:**
- Create: `lib/ui/features/dashboard/views/workspace_menu.dart`, `lib/ui/features/dashboard/views/empty_workspace.dart`, `lib/ui/features/dashboard/view_models/providers.dart`, `lib/ui/features/dashboard/views/dashboard_screen.dart`
- Modify: `lib/ui/features/dashboard/views/dashboard_body.dart` (render the empty state), `lib/main.dart`, `lib/app.dart`
- Test: `test/ui/features/workspace_menu_test.dart`, and two additions to `test/ui/features/dashboard_body_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 1–5.
- Produces:
  - `class WorkspaceOption { String id; String name; String meta; bool selected; }`
  - `class WorkspaceMenu extends StatelessWidget { WorkspaceMenu({required List<WorkspaceOption> options, required void Function(String id) onPick}) }`
  - `String workspaceMeta({required Workspace workspace, required int siteCount, required int openCount})`
  - `class EmptyWorkspace extends StatelessWidget` — no parameters; its copy is fixed by the spec
  - Providers: `databaseProvider`, `workspaceRepositoryProvider`, `siteRepositoryProvider`, `activeWorkspaceIdProvider`, `openSiteIdsProvider`, `leakCountProvider`, `workspacesProvider`, `workspaceOptionsProvider`, `dashboardProvider`
  - `class DashboardScreen extends ConsumerStatefulWidget` — stateful because the workspace menu's open/closed flag (`_menuOpen`) is local UI state; a `StateProvider` for it would leak view state into the provider graph

- [ ] **Step 1: Write the failing workspace-menu test**

Create `test/ui/features/workspace_menu_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/ui/features/dashboard/views/workspace_menu.dart';

void main() {
  test('a keeping workspace is summarised by its site and open counts', () {
    const personal = Workspace(
        id: 'ws', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep);

    expect(workspaceMeta(workspace: personal, siteCount: 6, openCount: 2),
        '6 SITES · 2 OPEN');
    expect(workspaceMeta(workspace: personal, siteCount: 1, openCount: 0),
        '1 SITES · 0 OPEN');
  });

  test('a wipe-on-exit workspace is summarised by its rule', () {
    const ephemeral = Workspace(
        id: 'ws', name: 'Ephemeral', markerIndex: 4,
        storageRule: StorageRule.wipeOnExit);

    expect(workspaceMeta(workspace: ephemeral, siteCount: 1, openCount: 1),
        'WIPES ON EXIT');
  });

  testWidgets('the menu lists every workspace and ticks the selected one',
      (tester) async {
    final picked = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WorkspaceMenu(
          options: const [
            WorkspaceOption(
                id: 'a', name: 'Personal', meta: '6 SITES · 2 OPEN', selected: true),
            WorkspaceOption(
                id: 'b', name: 'Work', meta: '2 SITES · 1 OPEN', selected: false),
            WorkspaceOption(
                id: 'c', name: 'Ephemeral', meta: 'WIPES ON EXIT', selected: false),
          ],
          onPick: picked.add,
        ),
      ),
    ));

    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('WIPES ON EXIT'), findsOneWidget);

    final tick = tester.widget<Icon>(find.byIcon(Icons.check));
    expect(tick.color, C.jade);

    await tester.tap(find.text('Work'));
    expect(picked, ['b']);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/ui/features/workspace_menu_test.dart`
Expected: FAIL — missing `workspace_menu.dart`.

- [ ] **Step 3: Write the workspace menu**

Create `lib/ui/features/dashboard/views/workspace_menu.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../../domain/models/workspace.dart';

class WorkspaceOption {
  const WorkspaceOption({
    required this.id,
    required this.name,
    required this.meta,
    required this.selected,
  });

  final String id;
  final String name;
  final String meta;
  final bool selected;
}

/// The one-line summary under a workspace's name in the switcher.
String workspaceMeta({
  required Workspace workspace,
  required int siteCount,
  required int openCount,
}) {
  if (workspace.storageRule == StorageRule.wipeOnExit) return 'WIPES ON EXIT';
  return '$siteCount SITES · $openCount OPEN';
}

/// The dropdown that hangs under the workspace name (spec `1a`). It is reused
/// on the `1b` bar, which is why it lives in its own file.
class WorkspaceMenu extends StatelessWidget {
  const WorkspaceMenu({super.key, required this.options, required this.onPick});

  final List<WorkspaceOption> options;
  final void Function(String id) onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 6),
      decoration: BoxDecoration(
        color: C.surface,
        border: Border.all(color: C.line08),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in options)
            InkWell(
              onTap: () => onPick(option.id),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: option == options.last
                      ? null
                      : const Border(bottom: BorderSide(color: C.line05)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(option.name, style: ui(size: 14, weight: 500)),
                            const SizedBox(height: 2),
                            Text(option.meta,
                                style: ui(size: 10, color: C.textFaint)),
                          ],
                        ),
                      ),
                      if (option.selected)
                        const Icon(Icons.check, size: 15, color: C.jade),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run it to verify it passes**

Run: `flutter test test/ui/features/workspace_menu_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 5: Write the failing empty-state test**

Append to `test/ui/features/dashboard_body_test.dart`, inside `main()`:

```dart
  testWidgets('an empty workspace says so in one sentence with one action',
      (tester) async {
    await _pump(
      tester,
      DashboardView.from(
        workspace: const Workspace(
            id: 'ws', name: 'Ephemeral', markerIndex: 4,
            storageRule: StorageRule.wipeOnExit),
        sites: const [],
        openSiteIds: const {},
        leakCount: 0,
        now: _now,
      ),
    );

    expect(find.text('Nothing here yet'), findsOneWidget);
    expect(
      find.text('Sites you open in this workspace leave nothing behind when '
          'you close the app.'),
      findsOneWidget,
    );
    expect(find.text('+ Add site'), findsOneWidget);
    expect(find.text('OPEN NOW'), findsNothing);
  });

  testWidgets('the empty state promotes Add site to the jade action',
      (tester) async {
    await _pump(
      tester,
      DashboardView.from(
        workspace: const Workspace(
            id: 'ws', name: 'Ephemeral', markerIndex: 4,
            storageRule: StorageRule.wipeOnExit),
        sites: const [],
        openSiteIds: const {},
        leakCount: 0,
        now: _now,
      ),
    );

    expect(tester.widget<Text>(find.text('+ Add site')).style!.color, C.bg);
  });
```

- [ ] **Step 6: Run it to verify it fails**

Run: `flutter test test/ui/features/dashboard_body_test.dart`
Expected: FAIL — `Expected: exactly one matching candidate / Actual: _TextFinder:<zero widgets>` for `Nothing here yet`.

- [ ] **Step 7: Write the empty state and render it**

Create `lib/ui/features/dashboard/views/empty_workspace.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/dashed_box.dart';

/// Spec `5b`: one sentence and one action. The copy is fixed by the design.
class EmptyWorkspace extends StatelessWidget {
  const EmptyWorkspace({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DashedBox(size: 40, radius: 12),
            const SizedBox(height: 16),
            Text('Nothing here yet',
                style: ui(size: 15, weight: 500, color: C.textTertiary)),
            const SizedBox(height: 16),
            Text(
              'Sites you open in this workspace leave nothing behind when you '
              'close the app.',
              textAlign: TextAlign.center,
              style: ui(size: 13, color: C.textFaint, height: 1.65),
            ),
          ],
        ),
      ),
    );
  }
}
```

In `lib/ui/features/dashboard/views/dashboard_body.dart`, add the import and return the empty state from `_list()`:

```dart
import 'empty_workspace.dart';
```

```dart
  Widget _list() {
    if (view.isEmpty) return const EmptyWorkspace();

    final children = <Widget>[];
    // ... unchanged from Task 5
```

- [ ] **Step 8: Run it to verify it passes**

Run: `flutter test test/ui/features/dashboard_body_test.dart`
Expected: PASS, 10 tests.

- [ ] **Step 9: Write the provider graph**

Create `lib/ui/features/dashboard/view_models/providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/services/app_database.dart';
import '../../../../data/repositories/site_repository_sqlite.dart';
import '../../../../data/repositories/workspace_repository_sqlite.dart';
import '../../../../domain/repositories/repositories.dart';
import '../../../../domain/models/workspace.dart';
import 'dashboard_view.dart';
import '../views/workspace_menu.dart';

/// Overridden in [main] with the opened database.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw StateError('databaseProvider must be overridden in main()'),
);

final workspaceRepositoryProvider = Provider<WorkspaceRepository>(
  (ref) => SqliteWorkspaceRepository(ref.watch(databaseProvider)),
);

final siteRepositoryProvider = Provider<SiteRepository>(
  (ref) => SqliteSiteRepository(ref.watch(databaseProvider)),
);

final workspacesProvider = FutureProvider<List<Workspace>>(
  (ref) => ref.watch(workspaceRepositoryProvider).all(),
);

/// Null means "the first workspace"; set when the user picks one.
final activeWorkspaceIdProvider = StateProvider<String?>((ref) => null);

/// Which sites are live. Runtime only — sessions never survive the app
/// closing, so this is deliberately not persisted.
final openSiteIdsProvider = StateProvider<Set<String>>((ref) => <String>{});

/// Seam for Plan 3: the filtering proxy will supply the real count. Until then
/// the dashboard honestly reports zero rather than inventing a number.
final leakCountProvider = Provider<int>((ref) => 0);

final dashboardProvider = FutureProvider<DashboardView>((ref) async {
  final workspaces = await ref.watch(workspacesProvider.future);
  if (workspaces.isEmpty) {
    return const DashboardView(
      workspaceName: '',
      wipesOnExit: false,
      sessionCount: 0,
      leakCount: 0,
      open: [],
      idle: [],
    );
  }

  final activeId = ref.watch(activeWorkspaceIdProvider);
  final workspace = workspaces.firstWhere(
    (w) => w.id == activeId,
    orElse: () => workspaces.first,
  );

  final sites = await ref.watch(siteRepositoryProvider).inWorkspace(workspace.id);

  return DashboardView.from(
    workspace: workspace,
    sites: sites,
    openSiteIds: ref.watch(openSiteIdsProvider),
    leakCount: ref.watch(leakCountProvider),
    now: DateTime.now(),
  );
});

/// The switcher's rows, with each workspace's site and open counts.
final workspaceOptionsProvider = FutureProvider<List<WorkspaceOption>>((ref) async {
  final workspaces = await ref.watch(workspacesProvider.future);
  final sites = ref.watch(siteRepositoryProvider);
  final openIds = ref.watch(openSiteIdsProvider);
  final activeId = ref.watch(activeWorkspaceIdProvider) ??
      (workspaces.isEmpty ? null : workspaces.first.id);

  final options = <WorkspaceOption>[];
  for (final workspace in workspaces) {
    final inWorkspace = await sites.inWorkspace(workspace.id);
    options.add(WorkspaceOption(
      id: workspace.id,
      name: workspace.name,
      meta: workspaceMeta(
        workspace: workspace,
        siteCount: inWorkspace.length,
        openCount: inWorkspace.where((s) => openIds.contains(s.id)).length,
      ),
      selected: workspace.id == activeId,
    ));
  }
  return options;
});
```

- [ ] **Step 10: Write the screen that wires the body to the providers**

Create `lib/ui/features/dashboard/views/dashboard_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tokens.dart';
import '../view_models/providers.dart';
import 'dashboard_body.dart';
import '../views/workspace_menu.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _menuOpen = false;

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(dashboardProvider);

    return dashboard.when(
      loading: () => const Scaffold(backgroundColor: C.bg),
      error: (error, _) => Scaffold(
        backgroundColor: C.bg,
        body: Center(child: Text('$error')),
      ),
      data: (view) => Stack(
        children: [
          DashboardBody(
            view: view,
            onWorkspaceTap: () => setState(() => _menuOpen = !_menuOpen),
            // The screens behind these callbacks arrive in later plans.
            onAddSite: () {},
            onSearch: () {},
            onOpenSite: (siteId) {
              ref.read(openSiteIdsProvider.notifier).update((ids) => {...ids, siteId});
              ref.read(siteRepositoryProvider).touch(siteId, DateTime.now());
              ref.invalidate(dashboardProvider);
            },
            onSiteMenu: (_) {},
          ),
          if (_menuOpen) _menu(),
        ],
      ),
    );
  }

  Widget _menu() {
    final options = ref.watch(workspaceOptionsProvider);
    return SafeArea(
      child: Padding(
        // Sits directly under the 47px-tall workspace bar.
        padding: const EdgeInsets.only(top: 47),
        child: Align(
          alignment: Alignment.topCenter,
          child: options.maybeWhen(
            data: (options) => WorkspaceMenu(
              options: options,
              onPick: (id) {
                ref.read(activeWorkspaceIdProvider.notifier).state = id;
                setState(() => _menuOpen = false);
              },
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 11: Open the database at startup and show the dashboard**

Replace `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/services/app_database.dart';
import 'ui/features/dashboard/views/dashboard_screen.dart';
import 'ui/features/dashboard/view_models/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final directory = await getApplicationDocumentsDirectory();
  // Plan 1 always opens Vault.a. Plan 2 picks the vault from which PIN
  // unwrapped, and opens it with that vault's key.
  final database = await AppDatabase.open(
    path: p.join(directory.path, vaultFileName(Vault.a)),
  );
  await seedIfEmpty(database);

  runApp(ProviderScope(
    overrides: [databaseProvider.overrideWithValue(database)],
    child: const ContainerApp(home: DashboardScreen()),
  ));
}
```

- [ ] **Step 12: Run the full suite and the analyzer**

Run: `flutter test && flutter analyze`
Expected: all tests passing (34 total), `No issues found!`

- [ ] **Step 13: Run the app and confirm it against the spec**

Run: `flutter run --debug`

Check by eye against the `1b` block in `Sandbox Container -canvas-.dc.html`:
- The bar reads `Personal` with a caret, and `0 SESSIONS · 0 LEAKS` on the right.
- Six rows under an `IDLE` label, hairline-separated, each `host · descriptor` with an age on the right.
- Tapping `Notes` moves it under a jade `OPEN NOW` label and the bar becomes `1 SESSIONS · 0 LEAKS`.
- Tapping the workspace name drops the switcher; picking `Ephemeral` shows the empty state with a jade `+ Add site`.

- [ ] **Step 14: Commit**

```bash
git add -A
git commit -m "feat: workspace switcher, empty state, and live dashboard wiring"
```

---

## Known gaps this plan deliberately leaves

State them in the handoff rather than papering over them:

- `0 SESSIONS · 0 LEAKS` shows a real session count and a hardcoded zero leak count. `leakCountProvider` is the seam; Plan 3's filtering proxy fills it.
- `onAddSite`, `onSearch` and `onSiteMenu` are wired to empty callbacks. Their screens are `2a`, a search screen not yet designed, and `7b`, in Plans 3 and 4.
- No lock screen: the app opens straight to the dashboard. Plan 2 puts `3a` in front of it and re-keys the database from the PIN.
- The database is unencrypted, and only `Vault.a` is ever opened. Plan 2 adds the key hierarchy — PIN through Argon2id to a key-encrypting key, the KEK unwrapping a per-vault data key, that data key encrypting that vault's store. Neither PIN is stored or hashed: a wrong PIN is detected by the unwrap failing its AEAD tag, which is what makes `4c`'s countdown honest, since the app genuinely cannot tell "wrong PIN" from "PIN for a vault that does not exist". A device-bound Android keystore key wraps both, so the stores are useless lifted off the phone. Panic destroys the data keys first and the files afterwards — killing 32 bytes is the irreversible step, and wiping files is cleanup. (Design contributed by the peer session working the security lane.)
- **Per-site proxy routing is settled, and the model here is correct as written.** Plan 3 routes by intercepting resource loads per WebView (`shouldInterceptRequest`) rather than by pointing the process at a proxy. `ProxyController.setProxyOverride` is process-wide and could not attribute a request to the container that issued it; interception knows the issuing WebView, so `Site.proxyMode`/`proxyHost`/`proxyPort` being per-site is honest, and `2a`'s "Route through proxy · This site only" means what it says. The rule from turn 8 — "never fall back to a direct connection on its own" — is enforced in the transport: when a site's route is unavailable the interceptor refuses, and no code path connects direct. Nothing in Plan 1 changes; this note exists so the next reader knows the per-site fields were checked rather than assumed.
- `1 SITES · 0 OPEN` is grammatically wrong for a single site. The spec never shows that case; leaving it literal is deliberate until the design says otherwise.

## The remaining plans

Written on request, in this order — each ships working software:

2. **Entry and identity** — setup wizard (`4a`, `4b`, `5a`), lock (`3a`), wrong PIN (`4c`), decoy vault (`3b`), panic (`3c`), settings (`2d`), and the PIN-derived database key.
3. **The container** — the Kotlin platform layer, per-site WebView isolation, the local filtering proxy, and the container screen (`2b`), switcher drawer (`2c`), add site (`2a`), opening (`8a`).
4. **When things go wrong, and in-page moments** — tunnel failures (`8b`, `8c`), permission request (`6a`), reader mode (`6b`), site sheet (`6c`), row menu (`7b`), blocked download (`7c`), today (`5c`).
5. **Workspaces and scripts** — workspace management (`10a`, `10b`, `10c`), the script library (`10d`), the script editor (`10e`), and backgrounding (`9a`, `9b`, `9c`).
