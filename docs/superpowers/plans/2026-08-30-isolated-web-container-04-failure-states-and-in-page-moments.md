# Isolated Web Container — Plan 4: In-Page Moments and Failure States

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The eight screens that happen *while a site is open, or when its route breaks* — a permission ask, reader mode, the site sheet, the row long-press menu, a held download, the Today log, and the two tunnel-failure screens — built as pure widgets over plain view models, testable without a WebView or a live proxy.

**Architecture:** Every screen in this plan is a modal layer or a leaf screen rendered over content this plan does not own. Four are bottom sheets, so Task 1 builds the sheet primitives once and the rest consume them. Each screen is a pure widget fed a plain view model (Plan 1's `DashboardBody` pattern), with no provider or async plumbing inside it — that keeps all of them testable with `pumpWidget` and no fakes. The live page behind an overlay belongs to Plan 3; this plan renders a `PageSkeleton` stand-in in its place, exactly as the spec cards draw it. The two failure screens (`8b`, `8c`) are the one exception to this plan's independence: they render Plan 3's `RouteFailure` and reuse its `refusalMessage()`, because a screen explaining why a tunnel failed has to speak the router's vocabulary. Everything else stays independent of Plans 2 and 3.

**Tech Stack:** Flutter (stable), Dart 3, `flutter_riverpod`, `flutter_test`. No new dependencies. No WebView — Plan 3 owns that.

**Spec:**
- `Sandbox Container -canvas-.dc.html` — authoritative. Read the block whose `id` matches the screen you are building (`id="6a"`, `id="6b"`, `id="6c"`, `id="7b"`, `id="7c"`, `id="5c"`, `id="8b"`, `id="8c"`). Exact copy, colours and sizes come from there, not from this plan's prose.
- `docs/superpowers/plans/2026-08-30-isolated-web-container-01-foundation.md` — Plan 1. Supplies every token, type and widget this plan consumes.
- `docs/superpowers/plans/2026-08-30-isolated-web-container-02-entry-and-identity.md` — Plan 2. Task 5's `AppToggle` (spec 6c's two switches) is the one widget Task 6 borrows from it.
- `docs/superpowers/plans/2026-08-30-isolated-web-container-03-container.md` — Plan 3. Tasks 8 and 9 consume its Task 2: `RouteDecision`, `RouteFailure`, `refusalMessage()` from `lib/domain/models/route_decision.dart`.

**Depends on:** Plan 1 (Tasks 1–4 at minimum: tokens, typography, shared primitives, domain model) for every task in this plan. Task 6 (site sheet, `6c`) additionally depends on Plan 2 Task 5 for `AppToggle`. Tasks 8 and 9 (`8b`, `8c`) additionally depend on Plan 3 Task 2 for `RouteFailure` and `refusalMessage()`. Tasks 1–5 and 7 depend on none of that and can be built in parallel with Plans 2 and 3.

---

## Global Constraints

Every task's requirements implicitly include this section. The first ten are inherited from Plan 1 verbatim and are repeated because a task's implementer may never open Plan 1.

- **Android only. Dark theme only.** Turn 7: "Dark only, as decided." No light theme, no toggle, no `Brightness.light`.
- **User-facing copy is verbatim from the spec.** Never paraphrase, re-capitalise or improve a string. If a string is not in the spec, it is a design question — stop and ask.
- **Jade `#7FC8A9` means live state or the single affirmative action on a screen.** Never decorative. At most one jade action per screen.
- **Hairline dividers, not cards.** Rows are separated by 1px white-alpha lines.
- **IBM Plex Mono for anything technical**, Figtree for everything else.
- **Base background is `#0F1113`**, except `6b` reader mode which is `#12100D`.
- **Reference device is 428 × 908 logical pixels.** All spec sizes are logical pixels — use them as-is.
- **Danger is `#D66A5A`.** Never a filled button background; text, a 1px border at 28% alpha, or the `#241C1D` surface.
- **The app makes no network requests of its own.** No analytics, no telemetry, no crash reporting.
- **No code generation.** No `build_runner`, no `freezed`, no `drift`. Hand-written only.

Added by this plan:

- **The Today log is memory-only and must never be persisted.** Spec `5c`: "Counts are kept in memory only and reset when the app closes." No table, no shared-preferences key, no file. `BlockedTally` is a plain object held by a provider and lost on process death. This is a privacy property, not a performance choice — a log that survives a restart is a record of browsing that the product promises not to keep.
- **No aggregate in this plan counts across vaults.** Inherited from Plan 1's two-store rule. Every count in `5c` is computed from the open vault's data only. There is no code path where a tally is constructed from more than one `AppDatabase`.
- **Permission grants are never remembered silently.** Spec `6a` title: "one time by default, never remembered silently". `allowOnce` and `allowWhileOpen` both expire — one after a single use, one when the session closes. Neither writes to the database. A persistent grant would need its own UI that the spec does not draw, so it does not exist.
- **Wipe is always visually separated from everything else.** Spec `7b`: "wipe sits apart from the rest". Destructive rows live in their own group with their own border, never in the same group as ordinary actions.
- **No screen in this plan may claim a container is fully tunnelled.** WebRTC never reaches the request interceptor and leaks over UDP regardless of route; Safe Browsing pings Google directly. Plan 3 disables both at the WebView level. Until then, `6c`'s proxy row states what the route *is*, never that traffic is fully covered.

---

## File Structure

```
lib/ui/core/widgets/sheet.dart                                BottomSheetSurface, SheetGroup, SheetRow (MODIFY: Task 6 adds an optional drag handle)
lib/ui/core/widgets/page_skeleton.dart                        dimmed stand-in for the live page (Plan 3 replaces)

lib/domain/models/permissions.dart                            PermissionKind, PermissionDecision
lib/domain/models/reader_article.dart                         ReaderArticle
lib/domain/models/held_download.dart                          HeldDownload, DownloadDecision + formatBytes
lib/domain/models/blocked_tally.dart                          BlockedTally, BlockedCategory, CategoryTally, SiteTally + categoryFraction
lib/domain/models/route_failure_copy.dart                     proxyFailureHeadline, proxyFailureDetail (extends Plan 3's RouteFailure)

lib/ui/features/in_page/views/permission_request_sheet.dart   spec 6a
lib/ui/features/in_page/views/reader_screen.dart              spec 6b
lib/ui/features/in_page/views/site_sheet.dart                 spec 6c
lib/ui/features/in_page/views/held_download_sheet.dart        spec 7c
lib/ui/features/in_page/views/proxy_unreachable_screen.dart   spec 8b
lib/ui/features/in_page/views/tunnel_dropped_screen.dart      spec 8c
lib/ui/features/dashboard/views/site_row_menu.dart            spec 7b
lib/ui/features/report/views/today_screen.dart                spec 5c

test/ui/core/sheet_test.dart
test/domain/permissions_test.dart
test/domain/reader_article_test.dart
test/domain/held_download_test.dart
test/domain/blocked_tally_test.dart
test/domain/route_failure_copy_test.dart
test/ui/features/in_page/permission_request_sheet_test.dart
test/ui/features/in_page/reader_screen_test.dart
test/ui/features/in_page/site_sheet_test.dart
test/ui/features/in_page/held_download_sheet_test.dart
test/ui/features/in_page/proxy_unreachable_screen_test.dart
test/ui/features/in_page/tunnel_dropped_screen_test.dart
test/ui/features/dashboard/site_row_menu_test.dart
test/ui/features/report/today_screen_test.dart
```

Split by responsibility: `domain/models/` holds pure data and formatting with no Flutter import beyond `meta`; `ui/features/in_page/` holds things that appear over an open site; `ui/features/report/` holds the one screen that talks about the app's own work.

These are Plan 1's directories, not this plan's own. An earlier draft put domain files flat in `lib/domain/` and screens in `lib/ui/in_page/`, `lib/ui/dashboard/`, `lib/ui/report/`, which collided with the layout Plan 1 shipped — and contradicted itself, since Task 8 imported `domain/models/route_decision.dart` while creating `domain/route_failure_copy.dart`. Two layouts in one app is worse than either, so this plan conforms: pure functions live in `domain/models/` beside the values they format (as Plan 1's own `relative_age.dart` and `site_descriptor.dart` do), and every screen lives under `lib/ui/features/<feature>/views/`. `site_row_menu.dart` is a dashboard screen, so it sits *inside* `lib/ui/features/dashboard/views/`, not beside it.

---

## Task 1: Sheet primitives

Four of this plan's six screens are bottom sheets with identical chrome. Building it once here is the difference between one surface to get right and four to keep in sync.

**Files:**
- Create: `lib/ui/core/widgets/sheet.dart`
- Create: `lib/ui/core/widgets/page_skeleton.dart`
- Test: `test/ui/core/sheet_test.dart`

**Interfaces:**
- Consumes: `C` (colours) and `ui()`/`T` (typography) from Plan 1 Task 1; `Hairline` from Plan 1 Task 2.
- Produces:
  - `class BottomSheetSurface extends StatelessWidget` — `const BottomSheetSurface({required List<Widget> children, EdgeInsets padding})`
  - `class SheetGroup extends StatelessWidget` — `const SheetGroup({required List<Widget> children})`
  - `class SheetRow extends StatelessWidget` — `const SheetRow({required String label, required VoidCallback? onTap, Color? labelColor, Widget? trailing})`
  - `class PageSkeleton extends StatelessWidget` — `const PageSkeleton({double opacity = 0.28})`

- [ ] **Step 1: Write the failing test**

Create `test/ui/core/sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/core/widgets/hairline.dart';
import 'package:container/ui/core/widgets/sheet.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('BottomSheetSurface uses the sheet colour and a 22px top radius',
      (tester) async {
    await tester.pumpWidget(host(
      const BottomSheetSurface(children: [Text('body')]),
    ));

    final container = tester.widget<Container>(
      find.byKey(const Key('sheet-surface')),
    );
    final decoration = container.decoration! as BoxDecoration;

    expect(decoration.color, C.sheet);
    expect(
      decoration.borderRadius,
      const BorderRadius.vertical(top: Radius.circular(22)),
    );
    expect(find.text('body'), findsOneWidget);
  });

  testWidgets('SheetRow renders its label and reports taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(
      SheetRow(label: 'Edit settings', onTap: () => taps++),
    ));

    await tester.tap(find.text('Edit settings'));
    expect(taps, 1);
  });

  testWidgets('SheetRow honours an explicit label colour', (tester) async {
    await tester.pumpWidget(host(
      SheetRow(label: 'Remove site', labelColor: C.danger, onTap: () {}),
    ));

    final text = tester.widget<Text>(find.text('Remove site'));
    expect(text.style!.color, C.danger);
  });

  testWidgets('SheetGroup puts a hairline between rows but not after the last',
      (tester) async {
    await tester.pumpWidget(host(
      SheetGroup(children: [
        SheetRow(label: 'One', onTap: () {}),
        SheetRow(label: 'Two', onTap: () {}),
        SheetRow(label: 'Three', onTap: () {}),
      ]),
    ));

    expect(find.byType(Hairline), findsNWidgets(2));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/core/sheet_test.dart`
Expected: FAIL — "Error: Couldn't resolve the package 'container' ... sheet.dart" or "BottomSheetSurface isn't defined".

- [ ] **Step 3: Write minimal implementation**

Create `lib/ui/core/widgets/sheet.dart`:

```dart
import 'package:flutter/material.dart';

import '../tokens.dart';
import '../typography.dart';
import 'hairline.dart';

/// The bottom-sheet chrome shared by specs `6a`, `6c`, `7b` and `7c`.
///
/// Spec values, identical in all four blocks: background `#141719`, a 1px top
/// border at 9% white, a 22px radius on the top corners only, and a soft
/// upward shadow so the sheet reads as lifted off the page behind it.
class BottomSheetSurface extends StatelessWidget {
  const BottomSheetSurface({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(20, 22, 20, 20),
  });

  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('sheet-surface'),
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: C.sheet,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.09)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 40,
            offset: const Offset(0, -20),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// A rounded, bordered group of rows separated by hairlines.
///
/// Groups are how the design keeps destructive actions apart: spec `7b` puts
/// "Wipe this site's data" and "Remove site" in their own [SheetGroup] rather
/// than at the bottom of the first one. Never mix the two.
class SheetGroup extends StatelessWidget {
  const SheetGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) {
        rows.add(Hairline(color: Colors.white.withValues(alpha: 0.05)));
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        ),
      ),
    );
  }
}

/// One tappable row inside a [SheetGroup]. Spec `7b`: 15px vertical padding,
/// 16px horizontal, `#15181B` fill, 14.5px label.
class SheetRow extends StatelessWidget {
  const SheetRow({
    super.key,
    required this.label,
    required this.onTap,
    this.labelColor,
    this.trailing,
  });

  final String label;
  final VoidCallback? onTap;
  final Color? labelColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        color: C.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: ui(size: 14.5, color: labelColor ?? C.textPrimary),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
```

Create `lib/ui/core/widgets/page_skeleton.dart`:

```dart
import 'package:flutter/material.dart';

import '../tokens.dart';

/// The dimmed placeholder the spec draws behind every in-page overlay.
///
/// Plan 3 replaces this with the live WebView. It exists so this plan's
/// screens can be built and tested with no WebView present, and so the
/// overlays are reviewed against the same background the spec cards show.
/// Spec `6a` uses opacity .28, spec `7b` uses .3.
class PageSkeleton extends StatelessWidget {
  const PageSkeleton({super.key, this.opacity = 0.28});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    Widget bar({required double height, double? widthFactor}) {
      final box = Container(
        height: height,
        decoration: BoxDecoration(
          color: C.skeleton,
          borderRadius: BorderRadius.circular(4),
        ),
      );
      return widthFactor == null
          ? box
          : FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: widthFactor,
              child: box,
            );
    }

    return Opacity(
      opacity: opacity,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            bar(height: 14, widthFactor: 0.45),
            const SizedBox(height: 14),
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: C.surface,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 14),
            bar(height: 10),
            const SizedBox(height: 14),
            bar(height: 10, widthFactor: 0.7),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ui/core/sheet_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/core/widgets/sheet.dart lib/ui/core/widgets/page_skeleton.dart test/ui/core/sheet_test.dart
git commit -m "feat: add bottom sheet primitives and page skeleton stand-in"
```

---

## Task 2: Permission request (spec `6a`)

**Files:**
- Create: `lib/domain/models/permissions.dart`
- Create: `lib/ui/features/in_page/views/permission_request_sheet.dart`
- Test: `test/domain/permissions_test.dart`
- Test: `test/ui/features/in_page/permission_request_sheet_test.dart`

**Interfaces:**
- Consumes: `BottomSheetSurface` (Task 1); `PillButton`, `PillTone` (Plan 1 Task 2); `C`, `ui`, `T` (Plan 1 Task 1).
- Produces:
  - `enum PermissionKind { camera, microphone, location, clipboard }` with `String get phrase`
  - `enum PermissionDecision { allowOnce, allowWhileOpen, keepBlocked }`
  - `class PermissionRequestSheet extends StatelessWidget` — `const PermissionRequestSheet({required String host, required PermissionKind kind, required ValueChanged<PermissionDecision> onDecision})`

The four kinds come from spec `2a`'s "HARDWARE · ALL OFF BY DEFAULT" list: Camera, Microphone, Location, Clipboard. The spec draws only the microphone case, so `phrase` supplies the possessive fragment that completes the one sentence it does show.

- [ ] **Step 1: Write the failing test**

Create `test/domain/permissions_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/permissions.dart';

void main() {
  test('microphone phrase completes the spec sentence exactly', () {
    expect(
      'meet.example.com wants ${PermissionKind.microphone.phrase}',
      'meet.example.com wants your microphone',
    );
  });

  test('every kind has a possessive phrase', () {
    expect(PermissionKind.camera.phrase, 'your camera');
    expect(PermissionKind.microphone.phrase, 'your microphone');
    expect(PermissionKind.location.phrase, 'your location');
    expect(PermissionKind.clipboard.phrase, 'your clipboard');
  });

  test('there are exactly three decisions and none of them persists', () {
    expect(PermissionDecision.values, [
      PermissionDecision.allowOnce,
      PermissionDecision.allowWhileOpen,
      PermissionDecision.keepBlocked,
    ]);
  });
}
```

Create `test/ui/features/in_page/permission_request_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/permissions.dart';
import 'package:container/ui/features/in_page/views/permission_request_sheet.dart';

void main() {
  Widget host({required ValueChanged<PermissionDecision> onDecision}) {
    return MaterialApp(
      home: Scaffold(
        body: PermissionRequestSheet(
          host: 'meet.example.com',
          kind: PermissionKind.microphone,
          onDecision: onDecision,
        ),
      ),
    );
  }

  testWidgets('renders the spec copy verbatim', (tester) async {
    await tester.pumpWidget(host(onDecision: (_) {}));

    expect(find.text('meet.example.com wants your microphone'), findsOneWidget);
    expect(
      find.text(
        'It is blocked right now. Allowing it applies to this site only, '
        'inside this container.',
      ),
      findsOneWidget,
    );
    expect(find.text('Allow once'), findsOneWidget);
    expect(find.text('Allow while this site is open'), findsOneWidget);
    expect(find.text('Keep blocked'), findsOneWidget);
  });

  testWidgets('each action reports its own decision', (tester) async {
    final seen = <PermissionDecision>[];
    await tester.pumpWidget(host(onDecision: seen.add));

    await tester.tap(find.text('Allow once'));
    await tester.tap(find.text('Allow while this site is open'));
    await tester.tap(find.text('Keep blocked'));

    expect(seen, [
      PermissionDecision.allowOnce,
      PermissionDecision.allowWhileOpen,
      PermissionDecision.keepBlocked,
    ]);
  });

  testWidgets('offers no way to remember the grant permanently',
      (tester) async {
    await tester.pumpWidget(host(onDecision: (_) {}));

    expect(find.text('Always allow'), findsNothing);
    expect(find.text('Remember'), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byType(Switch), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/permissions_test.dart test/ui/features/in_page/permission_request_sheet_test.dart`
Expected: FAIL — "Couldn't resolve the package" or "PermissionKind isn't defined".

- [ ] **Step 3: Write minimal implementation**

Create `lib/domain/models/permissions.dart`:

```dart
/// Hardware a site can ask for. The list is spec `2a`'s
/// "HARDWARE · ALL OFF BY DEFAULT" block, in its order.
enum PermissionKind {
  camera('your camera'),
  microphone('your microphone'),
  location('your location'),
  clipboard('your clipboard');

  const PermissionKind(this.phrase);

  /// The possessive fragment that completes spec `6a`'s title:
  /// "meet.example.com wants your microphone".
  final String phrase;
}

/// What the user chose. Spec `6a` is titled "one time by default, never
/// remembered silently", and these are the only three outcomes it draws.
///
/// Neither allow option is persisted. [allowOnce] covers a single use and
/// [allowWhileOpen] expires when the session closes, so a restart always
/// returns to blocked. There is deliberately no "always allow" — a permanent
/// grant would need UI the spec does not draw, and a grant the user cannot
/// see is exactly what "never remembered silently" forbids.
enum PermissionDecision { allowOnce, allowWhileOpen, keepBlocked }
```

Create `lib/ui/features/in_page/views/permission_request_sheet.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../domain/models/permissions.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/sheet.dart';

/// Spec `6a` — a site asks for hardware.
///
/// "Allow once" is the sheet's single jade action. The other two are neutral,
/// which is the design saying that keeping it blocked is not a failure state.
class PermissionRequestSheet extends StatelessWidget {
  const PermissionRequestSheet({
    super.key,
    required this.host,
    required this.kind,
    required this.onDecision,
  });

  final String host;
  final PermissionKind kind;
  final ValueChanged<PermissionDecision> onDecision;

  @override
  Widget build(BuildContext context) {
    return BottomSheetSurface(
      children: [
        Text('$host wants ${kind.phrase}',
            style: ui(size: 17, weight: 600, letterSpacing: -0.17)),
        const SizedBox(height: 8),
        Text(
          'It is blocked right now. Allowing it applies to this site only, '
          'inside this container.',
          style: T.bodyMuted,
        ),
        const SizedBox(height: 16),
        PillButton(
          label: 'Allow once',
          tone: PillTone.primary,
          onTap: () => onDecision(PermissionDecision.allowOnce),
        ),
        const SizedBox(height: 10),
        PillButton(
          label: 'Allow while this site is open',
          onTap: () => onDecision(PermissionDecision.allowWhileOpen),
        ),
        const SizedBox(height: 10),
        PillButton(
          label: 'Keep blocked',
          onTap: () => onDecision(PermissionDecision.keepBlocked),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/domain/permissions_test.dart test/ui/features/in_page/permission_request_sheet_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/models/permissions.dart lib/ui/features/in_page/views/permission_request_sheet.dart test/domain/permissions_test.dart test/ui/features/in_page/permission_request_sheet_test.dart
git commit -m "feat: add permission request sheet (spec 6a)"
```

---

## Task 3: Row long-press menu (spec `7b`)

**Files:**
- Create: `lib/ui/features/dashboard/views/site_row_menu.dart`
- Test: `test/ui/features/dashboard/site_row_menu_test.dart`

**Interfaces:**
- Consumes: `SheetGroup`, `SheetRow` (Task 1); `Monogram`, `PillButton` (Plan 1 Task 2); `C`, `ui`, `T` (Plan 1 Task 1).
- Produces:
  - `enum SiteRowAction { open, openEphemeral, editSettings, duplicate, requirePin, wipeData, removeSite }`
  - `class SiteRowMenu extends StatelessWidget` — `const SiteRowMenu({required String monogram, required String name, required String subtitle, required String ephemeralWorkspaceName, required String duplicateTargetName, required ValueChanged<SiteRowAction> onAction, required VoidCallback onCancel})`

The two workspace names are parameters because the spec's labels name real workspaces — "Open in Ephemeral" and "Duplicate into Work" — and those are user-created, not fixed strings.

- [ ] **Step 1: Write the failing test**

Create `test/ui/features/dashboard/site_row_menu_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/core/widgets/sheet.dart';
import 'package:container/ui/features/dashboard/views/site_row_menu.dart';

void main() {
  Widget host({
    ValueChanged<SiteRowAction>? onAction,
    VoidCallback? onCancel,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SiteRowMenu(
          monogram: 'Fr',
          name: 'Forum',
          subtitle: 'forum.example.com · ephemeral',
          ephemeralWorkspaceName: 'Ephemeral',
          duplicateTargetName: 'Work',
          onAction: onAction ?? (_) {},
          onCancel: onCancel ?? () {},
        ),
      ),
    );
  }

  testWidgets('renders the spec copy verbatim', (tester) async {
    await tester.pumpWidget(host());

    expect(find.text('Forum'), findsOneWidget);
    expect(find.text('forum.example.com · ephemeral'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Open in Ephemeral'), findsOneWidget);
    expect(find.text('Edit settings'), findsOneWidget);
    expect(find.text('Duplicate into Work'), findsOneWidget);
    expect(find.text('Require PIN to open'), findsOneWidget);
    expect(find.text("Wipe this site's data"), findsOneWidget);
    expect(find.text('Remove site'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('destructive actions sit in their own group', (tester) async {
    await tester.pumpWidget(host());

    // Spec 7b: "wipe sits apart from the rest". Two groups, never one.
    expect(find.byType(SheetGroup), findsNWidgets(2));

    final wipeGroup = tester.widget<SheetGroup>(find.ancestor(
      of: find.text("Wipe this site's data"),
      matching: find.byType(SheetGroup),
    ));
    final openGroup = tester.widget<SheetGroup>(find.ancestor(
      of: find.text('Open'),
      matching: find.byType(SheetGroup),
    ));

    expect(identical(wipeGroup, openGroup), isFalse);
    expect(wipeGroup.children.length, 2);
    expect(openGroup.children.length, 5);
  });

  testWidgets('Remove site is the only row drawn in danger colour',
      (tester) async {
    await tester.pumpWidget(host());

    expect(
      tester.widget<Text>(find.text('Remove site')).style!.color,
      C.danger,
    );
    expect(
      tester.widget<Text>(find.text("Wipe this site's data")).style!.color,
      C.textSecondary,
    );
    expect(
      tester.widget<Text>(find.text('Edit settings')).style!.color,
      C.textPrimary,
    );
  });

  testWidgets('workspace names come from the parameters, not hardcoded',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SiteRowMenu(
          monogram: 'Rd',
          name: 'Reader',
          subtitle: 'reader.example.com · Personal',
          ephemeralWorkspaceName: 'Throwaway',
          duplicateTargetName: 'Research',
          onAction: (_) {},
          onCancel: () {},
        ),
      ),
    ));

    expect(find.text('Open in Throwaway'), findsOneWidget);
    expect(find.text('Duplicate into Research'), findsOneWidget);
  });

  testWidgets('every row reports its action and Cancel is separate',
      (tester) async {
    final seen = <SiteRowAction>[];
    var cancelled = 0;
    await tester.pumpWidget(
      host(onAction: seen.add, onCancel: () => cancelled++),
    );

    await tester.tap(find.text('Open'));
    await tester.tap(find.text('Open in Ephemeral'));
    await tester.tap(find.text('Edit settings'));
    await tester.tap(find.text('Duplicate into Work'));
    await tester.tap(find.text('Require PIN to open'));
    await tester.tap(find.text("Wipe this site's data"));
    await tester.tap(find.text('Remove site'));
    await tester.tap(find.text('Cancel'));

    expect(seen, [
      SiteRowAction.open,
      SiteRowAction.openEphemeral,
      SiteRowAction.editSettings,
      SiteRowAction.duplicate,
      SiteRowAction.requirePin,
      SiteRowAction.wipeData,
      SiteRowAction.removeSite,
    ]);
    expect(cancelled, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/features/dashboard/site_row_menu_test.dart`
Expected: FAIL — "SiteRowMenu isn't defined".

- [ ] **Step 3: Write minimal implementation**

Create `lib/ui/features/dashboard/views/site_row_menu.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/monogram.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/sheet.dart';

/// What a long-press on a dashboard row can do. Spec `7b`.
enum SiteRowAction {
  open,
  openEphemeral,
  editSettings,
  duplicate,
  requirePin,
  wipeData,
  removeSite,
}

/// Spec `7b` — long-press on a dashboard row.
///
/// The two groups are load-bearing, not decorative. The spec's own title is
/// "wipe sits apart from the rest": a destructive row must never be one
/// mis-tap away from an ordinary one, so [SiteRowAction.wipeData] and
/// [SiteRowAction.removeSite] live in a second [SheetGroup] with its own
/// border. Do not merge them into the first group to save a few pixels.
class SiteRowMenu extends StatelessWidget {
  const SiteRowMenu({
    super.key,
    required this.monogram,
    required this.name,
    required this.subtitle,
    required this.ephemeralWorkspaceName,
    required this.duplicateTargetName,
    required this.onAction,
    required this.onCancel,
  });

  final String monogram;
  final String name;
  final String subtitle;

  /// Named workspaces, not fixed strings — the spec shows "Open in Ephemeral"
  /// and "Duplicate into Work" because those are what the user called them.
  final String ephemeralWorkspaceName;
  final String duplicateTargetName;

  final ValueChanged<SiteRowAction> onAction;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: C.barTrack,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
            ),
            child: Row(
              children: [
                Monogram(monogram),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: T.rowTitle),
                      const SizedBox(height: 3),
                      Text(subtitle, style: ui(size: 11, color: C.textFaint)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetGroup(children: [
                SheetRow(
                  label: 'Open',
                  onTap: () => onAction(SiteRowAction.open),
                ),
                SheetRow(
                  label: 'Open in $ephemeralWorkspaceName',
                  onTap: () => onAction(SiteRowAction.openEphemeral),
                ),
                SheetRow(
                  label: 'Edit settings',
                  onTap: () => onAction(SiteRowAction.editSettings),
                ),
                SheetRow(
                  label: 'Duplicate into $duplicateTargetName',
                  onTap: () => onAction(SiteRowAction.duplicate),
                ),
                SheetRow(
                  label: 'Require PIN to open',
                  onTap: () => onAction(SiteRowAction.requirePin),
                ),
              ]),
              const SizedBox(height: 10),
              SheetGroup(children: [
                SheetRow(
                  label: "Wipe this site's data",
                  labelColor: C.textSecondary,
                  onTap: () => onAction(SiteRowAction.wipeData),
                ),
                SheetRow(
                  label: 'Remove site',
                  labelColor: C.danger,
                  onTap: () => onAction(SiteRowAction.removeSite),
                ),
              ]),
              const SizedBox(height: 10),
              PillButton(label: 'Cancel', height: 50, onTap: onCancel),
            ],
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ui/features/dashboard/site_row_menu_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/features/dashboard/views/site_row_menu.dart test/ui/features/dashboard/site_row_menu_test.dart
git commit -m "feat: add site row long-press menu (spec 7b)"
```

---

## Task 4: Reader mode (spec `6b`)

**Files:**
- Modify: `lib/ui/core/tokens.dart` (adds reader mode's own warm palette)
- Create: `lib/domain/models/reader_article.dart`
- Create: `lib/ui/features/in_page/views/reader_screen.dart`
- Test: `test/domain/reader_article_test.dart`
- Test: `test/ui/features/in_page/reader_screen_test.dart`

**Interfaces:**
- Consumes: `ui()` (Plan 1 Task 1).
- Produces:
  - `class ReaderArticle { const ReaderArticle({required String host, required String title, required List<String> paragraphs, required int minutesToRead}); String get readingLabel; }` — a plain value, not a widget
  - `class ReaderScreen extends StatelessWidget` — `const ReaderScreen({required ReaderArticle article, required VoidCallback onClose, required VoidCallback onTextSize, required VoidCallback onTheme})`

- [ ] **Step 1: Write the failing tests**

Create `test/domain/reader_article_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/reader_article.dart';

void main() {
  test('the reading label matches the spec\'s "READER · 6 MIN"', () {
    const article = ReaderArticle(
      host: 'forum.example.com',
      title: 'What a container actually isolates, and what it cannot',
      paragraphs: ['One.', 'Two.', 'Three.'],
      minutesToRead: 6,
    );
    expect(article.readingLabel, 'READER · 6 MIN');
  });

  test('the label tracks whatever minute count it is given', () {
    const article = ReaderArticle(
      host: 'reader.example.com',
      title: 'Title',
      paragraphs: ['One.'],
      minutesToRead: 1,
    );
    expect(article.readingLabel, 'READER · 1 MIN');
  });
}
```

Create `test/ui/features/in_page/reader_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/reader_article.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/features/in_page/views/reader_screen.dart';

void main() {
  const article = ReaderArticle(
    host: 'forum.example.com',
    title: 'What a container actually isolates, and what it cannot',
    paragraphs: [
      'Separate storage stops one site from reading another\'s cookies. It '
          'does not hide the fact that a request came from this device, '
          'which is what the proxy layer is for.',
      'The two protections are often confused. Keeping them separate in '
          'your head makes it easier to decide which sites need which.',
      'A site that needs a login and a site you want to read anonymously '
          'are different problems, and they belong in different workspaces.',
    ],
    minutesToRead: 6,
  );

  Widget host({VoidCallback? onClose, VoidCallback? onTextSize, VoidCallback? onTheme}) {
    return MaterialApp(
      home: ReaderScreen(
        article: article,
        onClose: onClose ?? () {},
        onTextSize: onTextSize ?? () {},
        onTheme: onTheme ?? () {},
      ),
    );
  }

  testWidgets('renders the spec copy verbatim, on the reader background', (tester) async {
    await tester.pumpWidget(host());

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, C.bgReader);

    expect(find.text('READER · 6 MIN'), findsOneWidget);
    expect(find.text('forum.example.com'), findsOneWidget);
    expect(find.text('What a container actually isolates, and what it cannot'),
        findsOneWidget);
    expect(find.textContaining('The two protections are often confused'),
        findsOneWidget);
  });

  testWidgets('every paragraph in the article renders, in order', (tester) async {
    await tester.pumpWidget(host());
    for (final paragraph in article.paragraphs) {
      expect(find.textContaining(paragraph.substring(0, 20)), findsOneWidget);
    }
  });

  testWidgets('the three header controls report their own callback', (tester) async {
    var closed = 0;
    var textSized = 0;
    var themed = 0;
    await tester.pumpWidget(host(
      onClose: () => closed++,
      onTextSize: () => textSized++,
      onTheme: () => themed++,
    ));

    await tester.tap(find.text('‹'));
    await tester.tap(find.text('Aa'));
    await tester.tap(find.text('◑'));

    expect(closed, 1);
    expect(textSized, 1);
    expect(themed, 1);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/domain/reader_article_test.dart test/ui/features/in_page/reader_screen_test.dart`
Expected: FAIL — "Couldn't resolve the package" or "ReaderArticle isn't defined".

- [ ] **Step 3: Add reader mode's palette to the shared tokens**

Reader mode is the one screen with its own warm-toned background (`#12100D`, already in `C.bgReader` from Plan 1) and its own text colours, which appear nowhere else in the set. Add these four to `lib/ui/core/tokens.dart`, inside the `C` class, near the other text tokens:

```dart
  // Reader mode — its own warm palette, spec `6b` only.
  static const readerMuted = Color(0xFF8A857C);
  static const readerTitle = Color(0xFFEDE7DC);
  static const readerBody = Color(0xFFCFC8BC);
  static const readerHost = Color(0xFF7C776E);
```

- [ ] **Step 4: Write `ReaderArticle`**

Create `lib/domain/models/reader_article.dart`:

```dart
/// The content of one reader-mode page. Plan 3's `Site.openInReader` decides
/// *whether* a site opens here; producing an [ReaderArticle] from a live page
/// (readability extraction) is not this plan's job and is not attempted —
/// this plan only renders one, however it was built.
class ReaderArticle {
  const ReaderArticle({
    required this.host,
    required this.title,
    required this.paragraphs,
    required this.minutesToRead,
  });

  final String host;
  final String title;
  final List<String> paragraphs;
  final int minutesToRead;

  /// Spec `6b`'s header label: "READER · 6 MIN".
  String get readingLabel => 'READER · $minutesToRead MIN';
}
```

- [ ] **Step 5: Run the domain test to verify it passes**

Run: `flutter test test/domain/reader_article_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 6: Write `ReaderScreen`**

Create `lib/ui/features/in_page/views/reader_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../domain/models/reader_article.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';

/// Spec `6b` — text only, controls out of the way. The header is the only
/// chrome; everything below it is the article, full width, no card.
class ReaderScreen extends StatelessWidget {
  const ReaderScreen({
    super.key,
    required this.article,
    required this.onClose,
    required this.onTextSize,
    required this.onTheme,
  });

  final ReaderArticle article;
  final VoidCallback onClose;
  final VoidCallback onTextSize;
  final VoidCallback onTheme;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bgReader,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: C.line06)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: onClose,
                    child: const Text('‹', style: TextStyle(fontSize: 16, color: C.readerMuted)),
                  ),
                  Text(
                    article.readingLabel,
                    style: ui(size: 11.5, weight: 500, letterSpacing: 0.69, color: C.readerMuted),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: onTextSize,
                        child: Text('Aa', style: ui(size: 13, color: C.readerMuted)),
                      ),
                      const SizedBox(width: 14),
                      GestureDetector(
                        onTap: onTheme,
                        child: Text('◑', style: ui(size: 14, color: C.readerMuted)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(26, 26, 26, 40),
                children: [
                  Text(article.host, style: ui(size: 12, color: C.readerHost)),
                  const SizedBox(height: 18),
                  Text(
                    article.title,
                    style: ui(
                      size: 25,
                      weight: 600,
                      height: 1.25,
                      letterSpacing: -0.375,
                      color: C.readerTitle,
                    ),
                  ),
                  const SizedBox(height: 18),
                  for (var i = 0; i < article.paragraphs.length; i++) ...[
                    if (i != 0) const SizedBox(height: 14),
                    Text(
                      article.paragraphs[i],
                      style: ui(size: 15.5, height: 1.75, color: C.readerBody),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 7: Run the widget test to verify it passes**

Run: `flutter test test/ui/features/in_page/reader_screen_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 8: Run the analyzer**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 9: Commit**

```bash
git add lib/ui/core/tokens.dart lib/domain/models/reader_article.dart lib/ui/features/in_page/views/reader_screen.dart test/domain/reader_article_test.dart test/ui/features/in_page/reader_screen_test.dart
git commit -m "feat: add reader mode (spec 6b)"
```

---

## Task 5: Site sheet (spec `6c`)

**Files:**
- Modify: `lib/ui/core/widgets/sheet.dart` (adds an optional drag handle to `BottomSheetSurface`)
- Create: `lib/ui/features/in_page/views/site_sheet.dart`
- Test: `test/ui/core/sheet_test.dart` (extended)
- Test: `test/ui/features/in_page/site_sheet_test.dart`

**Interfaces:**
- Consumes: `BottomSheetSurface` (Task 1, extended below); `Monogram` (Plan 1 Task 2); `AppToggle` (Plan 2 Task 5, `lib/ui/core/widgets/app_toggle.dart`); `PillButton`, `PillTone` (Plan 1 Task 2); `C`, `ui`, `T` (Plan 1 Task 1).
- Produces:
  - `BottomSheetSurface` gains `bool showHandle` (default `false`)
  - `class SiteSheet extends StatelessWidget` — `const SiteSheet({required String monogram, required String name, required String subtitle, required String proxyDescriptor, required String cookiesDescriptor, required int blockedCount, required bool forceDark, required bool desktopView, required VoidCallback onEdit, required ValueChanged<bool> onForceDarkChanged, required ValueChanged<bool> onDesktopViewChanged, required VoidCallback onCloseAndWipe})`

`proxyDescriptor` and `cookiesDescriptor` arrive pre-composed (`"SOCKS5 · 127.0.0.1:9050"`, `"Wipe on exit"`) — the same convention `SiteRowMenu` used for its `subtitle`, so this widget stays free of formatting logic and testable with plain strings.

- [ ] **Step 1: Write the failing tests**

Add to `test/ui/core/sheet_test.dart`, inside `main()`, after the existing four tests:

```dart
  testWidgets('BottomSheetSurface renders no handle by default', (tester) async {
    await tester.pumpWidget(host(
      const BottomSheetSurface(children: [Text('body')]),
    ));
    expect(find.byKey(const Key('sheet-handle')), findsNothing);
  });

  testWidgets('BottomSheetSurface renders the drag handle when asked', (tester) async {
    await tester.pumpWidget(host(
      const BottomSheetSurface(showHandle: true, children: [Text('body')]),
    ));
    expect(find.byKey(const Key('sheet-handle')), findsOneWidget);
  });
```

Create `test/ui/features/in_page/site_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/ui/core/widgets/app_toggle.dart';
import 'package:container/ui/features/in_page/views/site_sheet.dart';

void main() {
  Widget host({
    bool forceDark = true,
    bool desktopView = false,
    VoidCallback? onEdit,
    ValueChanged<bool>? onForceDarkChanged,
    ValueChanged<bool>? onDesktopViewChanged,
    VoidCallback? onCloseAndWipe,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SiteSheet(
          monogram: 'Fr',
          name: 'Forum',
          subtitle: 'forum.example.com · Personal',
          proxyDescriptor: 'SOCKS5 · 127.0.0.1:9050',
          cookiesDescriptor: 'Wipe on exit',
          blockedCount: 164,
          forceDark: forceDark,
          desktopView: desktopView,
          onEdit: onEdit ?? () {},
          onForceDarkChanged: onForceDarkChanged ?? (_) {},
          onDesktopViewChanged: onDesktopViewChanged ?? (_) {},
          onCloseAndWipe: onCloseAndWipe ?? () {},
        ),
      ),
    );
  }

  testWidgets('renders the spec copy and values verbatim', (tester) async {
    await tester.pumpWidget(host());

    expect(find.byKey(const Key('sheet-handle')), findsOneWidget);
    expect(find.text('Forum'), findsOneWidget);
    expect(find.text('forum.example.com · Personal'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Proxy'), findsOneWidget);
    expect(find.text('SOCKS5 · 127.0.0.1:9050'), findsOneWidget);
    expect(find.text('Cookies'), findsOneWidget);
    expect(find.text('Wipe on exit'), findsOneWidget);
    expect(find.text('Blocked here'), findsOneWidget);
    expect(find.text('164 requests'), findsOneWidget);
    expect(find.text('Force dark mode'), findsOneWidget);
    expect(find.text('Desktop view'), findsOneWidget);
    expect(find.text('Close and wipe this session'), findsOneWidget);
  });

  testWidgets('Edit reports a tap', (tester) async {
    var edits = 0;
    await tester.pumpWidget(host(onEdit: () => edits++));
    await tester.tap(find.text('Edit'));
    expect(edits, 1);
  });

  testWidgets('each toggle reports its new value, not just that it changed', (tester) async {
    bool? forceDarkSeen;
    bool? desktopViewSeen;
    await tester.pumpWidget(host(
      forceDark: true,
      desktopView: false,
      onForceDarkChanged: (v) => forceDarkSeen = v,
      onDesktopViewChanged: (v) => desktopViewSeen = v,
    ));

    final forceDarkRow = find.ancestor(
      of: find.text('Force dark mode'),
      matching: find.byType(Row),
    ).first;
    final desktopViewRow = find.ancestor(
      of: find.text('Desktop view'),
      matching: find.byType(Row),
    ).first;

    // Tap the toggle by its own type, never by whatever it happens to be
    // built from. `AppToggle` is Plan 2's widget; a test reaching for its
    // inner `GestureDetector` passes today and breaks the moment Plan 2
    // rebuilds it on an `InkWell` — failing here, looking like a bug here.
    await tester.tap(find.descendant(of: forceDarkRow, matching: find.byType(AppToggle)));
    await tester.tap(find.descendant(of: desktopViewRow, matching: find.byType(AppToggle)));

    expect(forceDarkSeen, isFalse); // was on, tapped once -> off
    expect(desktopViewSeen, isTrue); // was off, tapped once -> on
  });

  testWidgets('Close and wipe reports a tap', (tester) async {
    var wiped = 0;
    await tester.pumpWidget(host(onCloseAndWipe: () => wiped++));
    await tester.tap(find.text('Close and wipe this session'));
    expect(wiped, 1);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/ui/core/sheet_test.dart test/ui/features/in_page/site_sheet_test.dart`
Expected: FAIL — the two new `sheet_test.dart` cases fail on the missing `showHandle` parameter; `site_sheet_test.dart` fails on the missing `SiteSheet` file.

- [ ] **Step 3: Add the drag handle to `BottomSheetSurface`**

In `lib/ui/core/widgets/sheet.dart`, change the constructor and `build` method:

```dart
class BottomSheetSurface extends StatelessWidget {
  const BottomSheetSurface({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(20, 22, 20, 20),
    this.showHandle = false,
  });

  final List<Widget> children;
  final EdgeInsets padding;

  /// Spec `6c` draws a 36×4 handle above its header row; the other three
  /// sheets in this plan do not. Off by default so every existing call site
  /// is unaffected.
  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('sheet-surface'),
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: C.sheet,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.09)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 40,
            offset: const Offset(0, -20),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHandle)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Center(
                child: Container(
                  key: const Key('sheet-handle'),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C3134),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ...children,
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Write `SiteSheet`**

Create `lib/ui/features/in_page/views/site_sheet.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/app_toggle.dart';
import '../../../core/widgets/monogram.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/sheet.dart';

/// Spec `6c` — what this container is running under, editable in place.
/// Every row here is read-only except the two switches; "Edit" is the one
/// escape hatch into the full Add site form for everything else.
class SiteSheet extends StatelessWidget {
  const SiteSheet({
    super.key,
    required this.monogram,
    required this.name,
    required this.subtitle,
    required this.proxyDescriptor,
    required this.cookiesDescriptor,
    required this.blockedCount,
    required this.forceDark,
    required this.desktopView,
    required this.onEdit,
    required this.onForceDarkChanged,
    required this.onDesktopViewChanged,
    required this.onCloseAndWipe,
  });

  final String monogram;
  final String name;
  final String subtitle;
  final String proxyDescriptor;
  final String cookiesDescriptor;
  final int blockedCount;
  final bool forceDark;
  final bool desktopView;
  final VoidCallback onEdit;
  final ValueChanged<bool> onForceDarkChanged;
  final ValueChanged<bool> onDesktopViewChanged;
  final VoidCallback onCloseAndWipe;

  @override
  Widget build(BuildContext context) {
    return BottomSheetSurface(
      showHandle: true,
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 18),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
          child: Container(
            padding: const EdgeInsets.only(bottom: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: C.line06)),
            ),
            child: Row(
              children: [
                Monogram(monogram, size: 40, radius: 11, fontSize: 15),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: ui(size: 15.5, weight: 600)),
                      const SizedBox(height: 3),
                      Text(subtitle, style: ui(size: 11.5, color: C.textFaint)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onEdit,
                  child: Text('Edit', style: ui(size: 13, weight: 500, color: C.jade)),
                ),
              ],
            ),
          ),
        ),
        _SheetInfoRow(label: 'Proxy', value: proxyDescriptor),
        _SheetInfoRow(label: 'Cookies', value: cookiesDescriptor),
        _SheetInfoRow(label: 'Blocked here', value: '$blockedCount requests'),
        _SheetInfoRow(
          label: 'Force dark mode',
          trailing: AppToggle(value: forceDark, onChanged: onForceDarkChanged),
        ),
        _SheetInfoRow(
          label: 'Desktop view',
          trailing: AppToggle(value: desktopView, onChanged: onDesktopViewChanged),
          showDivider: false,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
          child: PillButton(
            label: 'Close and wipe this session',
            height: 46,
            radius: 14,
            onTap: onCloseAndWipe,
          ),
        ),
      ],
    );
  }
}

class _SheetInfoRow extends StatelessWidget {
  const _SheetInfoRow({
    required this.label,
    this.value,
    this.trailing,
    this.showDivider = true,
  });

  final String label;
  final String? value;
  final Widget? trailing;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        border: showDivider ? const Border(bottom: BorderSide(color: C.line05)) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: ui(size: 14, color: C.textPrimary)),
          trailing ?? Text(value!, style: ui(size: 12.5, color: C.textMuted)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/ui/core/sheet_test.dart test/ui/features/in_page/site_sheet_test.dart`
Expected: PASS, 6 + 4 tests.

- [ ] **Step 6: Run the analyzer**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/ui/core/widgets/sheet.dart lib/ui/features/in_page/views/site_sheet.dart test/ui/core/sheet_test.dart test/ui/features/in_page/site_sheet_test.dart
git commit -m "feat: add site sheet (spec 6c)"
```

---

## Task 6: Held download (spec `7c`)

**Files:**
- Create: `lib/domain/models/held_download.dart`
- Create: `lib/ui/features/in_page/views/held_download_sheet.dart`
- Test: `test/domain/held_download_test.dart`
- Test: `test/ui/features/in_page/held_download_sheet_test.dart`

**Interfaces:**
- Consumes: `BottomSheetSurface` (Task 1); `PillButton`, `PillTone` (Plan 1 Task 2); `C`, `ui`, `T` (Plan 1 Task 1).
- Produces:
  - `enum DownloadDecision { keepInContainer, saveToDevice, discard }`
  - `class HeldDownload { const HeldDownload({required String fileName, required int sizeBytes, required String sourceHost, required String kindLabel}); }`
  - `String formatBytes(int bytes)`
  - `class HeldDownloadSheet extends StatelessWidget` — `const HeldDownloadSheet({required HeldDownload download, required ValueChanged<DownloadDecision> onDecision})`

- [ ] **Step 1: Write the failing tests**

Create `test/domain/held_download_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/held_download.dart';

void main() {
  test('formats megabytes at one decimal, matching the spec\'s "1.4 MB"', () {
    expect(formatBytes(1468006), '1.4 MB');
  });

  test('formats kilobytes at one decimal', () {
    expect(formatBytes(2048), '2.0 KB');
  });

  test('formats sub-kilobyte sizes as whole bytes', () {
    expect(formatBytes(512), '512 B');
  });
}
```

Create `test/ui/features/in_page/held_download_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/held_download.dart';
import 'package:container/ui/features/in_page/views/held_download_sheet.dart';

void main() {
  const download = HeldDownload(
    fileName: 'statement-june.pdf',
    sizeBytes: 1468006,
    sourceHost: 'forum.example.com',
    kindLabel: 'PDF',
  );

  Widget host(ValueChanged<DownloadDecision> onDecision) {
    return MaterialApp(
      home: Scaffold(
        body: HeldDownloadSheet(download: download, onDecision: onDecision),
      ),
    );
  }

  testWidgets('renders the spec copy verbatim', (tester) async {
    await tester.pumpWidget(host((_) {}));

    expect(find.text('Download held'), findsOneWidget);
    expect(
      find.text(
        'Files leave the container when they are saved. This one would go to '
        'your device storage where other apps can read it.',
      ),
      findsOneWidget,
    );
    expect(find.text('PDF'), findsOneWidget);
    expect(find.text('statement-june.pdf'), findsOneWidget);
    expect(find.text('1.4 MB · from forum.example.com'), findsOneWidget);
    expect(find.text('Keep inside this container'), findsOneWidget);
    expect(find.text('Save to device storage'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);
  });

  testWidgets('each action reports its own decision', (tester) async {
    final seen = <DownloadDecision>[];
    await tester.pumpWidget(host(seen.add));

    await tester.tap(find.text('Keep inside this container'));
    await tester.tap(find.text('Save to device storage'));
    await tester.tap(find.text('Discard'));

    expect(seen, [
      DownloadDecision.keepInContainer,
      DownloadDecision.saveToDevice,
      DownloadDecision.discard,
    ]);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/domain/held_download_test.dart test/ui/features/in_page/held_download_sheet_test.dart`
Expected: FAIL — missing files.

- [ ] **Step 3: Write `HeldDownload` and `formatBytes`**

Create `lib/domain/models/held_download.dart`:

```dart
/// What the user can do with a file a site tried to save. Spec `7c`.
enum DownloadDecision { keepInContainer, saveToDevice, discard }

class HeldDownload {
  const HeldDownload({
    required this.fileName,
    required this.sizeBytes,
    required this.sourceHost,
    required this.kindLabel,
  });

  final String fileName;
  final int sizeBytes;
  final String sourceHost;

  /// The short badge on the file icon — "PDF" in the spec's example.
  final String kindLabel;
}

/// The compact size string the sheet's meta line uses: "1.4 MB", "2.0 KB",
/// "512 B".
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
```

- [ ] **Step 4: Run the domain test to verify it passes**

Run: `flutter test test/domain/held_download_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 5: Write `HeldDownloadSheet`**

Create `lib/ui/features/in_page/views/held_download_sheet.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../domain/models/held_download.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/monogram.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/sheet.dart';

/// Spec `7c` — says what a held download is and where it would land.
///
/// "Discard" is this sheet's jade action, not "Keep" or "Save" — in an app
/// whose whole premise is that data does not leave the container, throwing
/// the file away is the affirmative, privacy-preserving choice. This is not
/// a mistake carried over from a generic "primary button" convention; the
/// spec draws it filled jade on purpose.
class HeldDownloadSheet extends StatelessWidget {
  const HeldDownloadSheet({super.key, required this.download, required this.onDecision});

  final HeldDownload download;
  final ValueChanged<DownloadDecision> onDecision;

  @override
  Widget build(BuildContext context) {
    return BottomSheetSurface(
      children: [
        Text('Download held', style: ui(size: 17, weight: 600, letterSpacing: -0.17)),
        const SizedBox(height: 8),
        Text(
          'Files leave the container when they are saved. This one would go to '
          'your device storage where other apps can read it.',
          style: T.bodyMuted,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: C.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: C.line08),
          ),
          child: Row(
            children: [
              // Plan 1's Monogram, parameterised — its open branch is already
              // `C.monogramOpen` on `C.monogramText` at weight 600, which is
              // exactly what the spec draws for this badge.
              Monogram(download.kindLabel, size: 38, radius: 10, fontSize: 11),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(download.fileName, style: ui(size: 13.5, color: C.textPrimary)),
                    const SizedBox(height: 3),
                    Text(
                      '${formatBytes(download.sizeBytes)} · from ${download.sourceHost}',
                      style: ui(size: 11.5, color: C.textFaint),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PillButton(
          label: 'Keep inside this container',
          onTap: () => onDecision(DownloadDecision.keepInContainer),
        ),
        const SizedBox(height: 9),
        PillButton(
          label: 'Save to device storage',
          onTap: () => onDecision(DownloadDecision.saveToDevice),
        ),
        const SizedBox(height: 9),
        PillButton(
          label: 'Discard',
          tone: PillTone.primary,
          onTap: () => onDecision(DownloadDecision.discard),
        ),
      ],
    );
  }
}
```

- [ ] **Step 6: Run the widget test to verify it passes**

Run: `flutter test test/ui/features/in_page/held_download_sheet_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 7: Run the analyzer**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/domain/models/held_download.dart lib/ui/features/in_page/views/held_download_sheet.dart test/domain/held_download_test.dart test/ui/features/in_page/held_download_sheet_test.dart
git commit -m "feat: add held download sheet (spec 7c)"
```

---

## Task 7: Today log (spec `5c`)

**Files:**
- Create: `lib/domain/models/blocked_tally.dart`
- Create: `lib/ui/features/report/views/today_screen.dart`
- Test: `test/domain/blocked_tally_test.dart`
- Test: `test/ui/features/report/today_screen_test.dart`

**Interfaces:**
- Consumes: `C`, `ui`, `T` (Plan 1 Task 1).
- Produces:
  - `enum BlockedCategory { trackers, ads, fingerprinting, permissionAsks }` with `String get label`
  - `class CategoryTally { const CategoryTally({required BlockedCategory category, required int count}); }`
  - `class SiteTally { const SiteTally({required String monogram, required String name, required int count}); }`
  - `class BlockedTally { const BlockedTally({required List<CategoryTally> categories, required List<SiteTally> sites}); int get total; int get siteCount; }`
  - `double categoryFraction(BlockedTally tally, BlockedCategory category)`
  - `class TodayScreen extends StatelessWidget` — `const TodayScreen({required BlockedTally tally, required VoidCallback onBack})`

- [ ] **Step 1: Write the failing domain test**

Create `test/domain/blocked_tally_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/blocked_tally.dart';

BlockedTally _tally() => const BlockedTally(
      categories: [
        CategoryTally(category: BlockedCategory.trackers, count: 198),
        CategoryTally(category: BlockedCategory.ads, count: 88),
        CategoryTally(category: BlockedCategory.fingerprinting, count: 24),
        CategoryTally(category: BlockedCategory.permissionAsks, count: 2),
      ],
      sites: [
        SiteTally(monogram: 'Fr', name: 'Forum', count: 164),
        SiteTally(monogram: 'Mk', name: 'Marketplace', count: 97),
        SiteTally(monogram: 'Rd', name: 'Reader', count: 39),
        SiteTally(monogram: 'Wm', name: 'Webmail', count: 12),
      ],
    );

void main() {
  test('total sums every category, matching the spec\'s 312', () {
    expect(_tally().total, 312);
  });

  test('site count is the number of sites tallied, matching the spec\'s 4', () {
    expect(_tally().siteCount, 4);
  });

  test('the largest category gets the full-width bar', () {
    expect(categoryFraction(_tally(), BlockedCategory.trackers), 1.0);
  });

  test('smaller categories scale relative to the largest, not to the total', () {
    final tally = _tally();
    expect(categoryFraction(tally, BlockedCategory.ads), closeTo(88 / 198, 0.0001));
    expect(categoryFraction(tally, BlockedCategory.fingerprinting), closeTo(24 / 198, 0.0001));
    expect(categoryFraction(tally, BlockedCategory.permissionAsks), closeTo(2 / 198, 0.0001));
  });

  test('a category missing from a non-empty tally reads as zero, not a crash', () {
    const partial = BlockedTally(
      categories: [CategoryTally(category: BlockedCategory.trackers, count: 9)],
      sites: [],
    );
    expect(categoryFraction(partial, BlockedCategory.ads), 0);
  });

  test('an empty tally has no total and does not divide by zero', () {
    const empty = BlockedTally(categories: [], sites: []);
    expect(empty.total, 0);
    expect(empty.siteCount, 0);
    expect(categoryFraction(empty, BlockedCategory.trackers), 0);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/domain/blocked_tally_test.dart`
Expected: FAIL — missing file.

- [ ] **Step 3: Write `BlockedTally`**

Create `lib/domain/models/blocked_tally.dart`:

```dart
/// What a category of request was blocked for. Order matches spec `5c`.
enum BlockedCategory {
  trackers('Trackers'),
  ads('Ads'),
  fingerprinting('Fingerprinting'),
  permissionAsks('Permission asks');

  const BlockedCategory(this.label);
  final String label;
}

class CategoryTally {
  const CategoryTally({required this.category, required this.count});
  final BlockedCategory category;
  final int count;
}

class SiteTally {
  const SiteTally({required this.monogram, required this.name, required this.count});
  final String monogram;
  final String name;
  final int count;
}

/// Everything the Today screen shows. Spec `5c`: "Counts are kept in memory
/// only and reset when the app closes." This class carries that promise by
/// construction — it is a plain immutable value with no `toMap`, no
/// `fromMap`, and no repository anywhere in this plan. A table for it would
/// be exactly the persistence the spec forbids, so none is written.
class BlockedTally {
  const BlockedTally({required this.categories, required this.sites});

  final List<CategoryTally> categories;
  final List<SiteTally> sites;

  int get total => categories.fold(0, (sum, c) => sum + c.count);
  int get siteCount => sites.length;
}

/// The bar width for [category], relative to the largest category in
/// [tally]. The spec's own mock draws 74% / 33% / 9% / 3% for counts of
/// 198 / 88 / 24 / 2 — percentages that do not correspond to any ratio of
/// those numbers, so they read as presentation-only. This computes a real
/// one instead: the largest category always fills the track.
double categoryFraction(BlockedTally tally, BlockedCategory category) {
  if (tally.categories.isEmpty) return 0;
  final max = tally.categories.map((c) => c.count).reduce((a, b) => a > b ? a : b);
  if (max == 0) return 0;
  // A category simply absent from a non-empty tally is not an error. The
  // first real feed for this screen is Plan 3's `FilterEngine`, which counts
  // total blocks and does not yet tag them by reason (CLAUDE.md carries
  // "FilterEngine category tagging" as unassigned work) — so a partial list
  // is what it will hand over, and an unguarded `firstWhere` would throw on
  // the day it does.
  final entry = tally.categories.firstWhere(
    (c) => c.category == category,
    orElse: () => CategoryTally(category: category, count: 0),
  );
  return entry.count / max;
}
```

- [ ] **Step 4: Run it to verify it passes**

Run: `flutter test test/domain/blocked_tally_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 5: Write the failing widget test**

Create `test/ui/features/report/today_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/blocked_tally.dart';
import 'package:container/ui/features/report/views/today_screen.dart';

void main() {
  const tally = BlockedTally(
    categories: [
      CategoryTally(category: BlockedCategory.trackers, count: 198),
      CategoryTally(category: BlockedCategory.ads, count: 88),
      CategoryTally(category: BlockedCategory.fingerprinting, count: 24),
      CategoryTally(category: BlockedCategory.permissionAsks, count: 2),
    ],
    sites: [
      SiteTally(monogram: 'Fr', name: 'Forum', count: 164),
      SiteTally(monogram: 'Mk', name: 'Marketplace', count: 97),
      SiteTally(monogram: 'Rd', name: 'Reader', count: 39),
      SiteTally(monogram: 'Wm', name: 'Webmail', count: 12),
    ],
  );

  testWidgets('renders the spec copy and numbers verbatim', (tester) async {
    // The default 800x600 test surface is shorter than four category rows
    // plus four site rows plus the total block, so the last few rows never
    // enter the sliver list's build range and find.text can't see them.
    // Widen the surface rather than scroll, since every assertion below
    // needs simultaneous visibility.
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;

    var backs = 0;
    await tester.pumpWidget(MaterialApp(
      home: TodayScreen(tally: tally, onBack: () => backs++),
    ));

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('312'), findsOneWidget);
    expect(find.text('requests blocked across 4 sites'), findsOneWidget);

    expect(find.text('Trackers'), findsOneWidget);
    expect(find.text('198'), findsOneWidget);
    expect(find.text('Ads'), findsOneWidget);
    expect(find.text('88'), findsOneWidget);
    expect(find.text('Fingerprinting'), findsOneWidget);
    expect(find.text('24'), findsOneWidget);
    expect(find.text('Permission asks'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    expect(find.text('BY SITE'), findsOneWidget);
    expect(find.text('Forum'), findsOneWidget);
    expect(find.text('164'), findsOneWidget);
    expect(find.text('Marketplace'), findsOneWidget);
    expect(find.text('Reader'), findsOneWidget);
    expect(find.text('Webmail'), findsOneWidget);

    expect(
      find.text('Counts are kept in memory only and reset when the app closes.'),
      findsOneWidget,
    );

    await tester.tap(find.text('‹'));
    expect(backs, 1);
  });
}
```

- [ ] **Step 6: Run it to verify it fails**

Run: `flutter test test/ui/features/report/today_screen_test.dart`
Expected: FAIL — missing file.

- [ ] **Step 7: Write `TodayScreen`**

Create `lib/ui/features/report/views/today_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../domain/models/blocked_tally.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/monogram.dart';

/// Spec `5c` — a quiet log, not a dashboard of scary numbers. Reachable
/// from the dashboard menu, never pushed as a notification (turn 5's note).
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key, required this.tally, required this.onBack});

  final BlockedTally tally;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: C.line06)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onBack,
                    child: const Text('‹', style: TextStyle(fontSize: 16, color: C.icon)),
                  ),
                  const SizedBox(width: 10),
                  Text('Today', style: T.screenTitle),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                children: [
                  Container(
                    padding: const EdgeInsets.only(bottom: 22),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: C.line06)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${tally.total}', style: ui(size: 34, weight: 600, letterSpacing: -0.68)),
                        const SizedBox(height: 8),
                        Text('requests blocked across ${tally.siteCount} sites',
                            style: ui(size: 13.5, color: C.textMuted)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: C.line06)),
                    ),
                    child: Column(
                      children: [
                        for (final category in tally.categories)
                          _CategoryBar(tally: tally, entry: category),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 20, 0, 4),
                    child: Text(
                      'BY SITE',
                      style: ui(size: 10.5, weight: 500, letterSpacing: 1.05, color: C.textFaint),
                    ),
                  ),
                  for (final site in tally.sites) _SiteRow(site: site),
                  const SizedBox(height: 20),
                  Text(
                    'Counts are kept in memory only and reset when the app closes.',
                    style: ui(size: 12, height: 1.6, color: C.textDim),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.tally, required this.entry});

  final BlockedTally tally;
  final CategoryTally entry;

  @override
  Widget build(BuildContext context) {
    final fillColor = entry.category == BlockedCategory.permissionAsks ? C.warning : C.jade;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(entry.category.label, style: ui(size: 13, color: C.textTertiary)),
          ),
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(color: C.barTrack, borderRadius: BorderRadius.circular(3)),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: categoryFraction(tally, entry.category),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: fillColor, borderRadius: BorderRadius.circular(3)),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 34,
            child: Text(
              '${entry.count}',
              textAlign: TextAlign.right,
              style: ui(size: 12.5, weight: 500, color: C.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _SiteRow extends StatelessWidget {
  const _SiteRow({required this.site});

  final SiteTally site;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: C.line05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // `open: false` is Monogram's idle treatment — `C.raised` on
              // `C.textMuted` — which is what `5c` draws for a site that is
              // being reported on rather than running.
              Monogram(site.monogram, size: 32, radius: 9, fontSize: 12.5, open: false),
              const SizedBox(width: 11),
              Text(site.name, style: ui(size: 14, color: C.textSecondary)),
            ],
          ),
          Text('${site.count}', style: ui(size: 12.5, weight: 500, color: C.textMuted)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 8: Run it to verify it passes**

Run: `flutter test test/ui/features/report/today_screen_test.dart`
Expected: PASS, 1 test.

- [ ] **Step 9: Run the analyzer**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 10: Commit**

```bash
git add lib/domain/models/blocked_tally.dart lib/ui/features/report/views/today_screen.dart test/domain/blocked_tally_test.dart test/ui/features/report/today_screen_test.dart
git commit -m "feat: add Today log (spec 5c)"
```

---

## Task 8: Proxy unreachable (spec `8b`)

This task and Task 9 are the "failure states" half of this plan's title. They consume Plan 3 Task 2's `RouteFailure` and `refusalMessage()` — build Plan 3 through at least that task before starting here, or stub `lib/domain/models/route_decision.dart` locally with the signatures Plan 3's Task 2 defines.

**Files:**
- Create: `lib/domain/models/route_failure_copy.dart`
- Create: `lib/ui/features/in_page/views/proxy_unreachable_screen.dart`
- Test: `test/domain/route_failure_copy_test.dart`
- Test: `test/ui/features/in_page/proxy_unreachable_screen_test.dart`

**Interfaces:**
- Consumes: `RouteFailure`, `refusalMessage()` from Plan 3 Task 2 (`lib/domain/models/route_decision.dart`); `PillButton`, `PillTone` (Plan 1 Task 2); `C`, `ui` (Plan 1 Task 1).
- Produces:
  - `String proxyFailureHeadline(RouteFailure failure)`
  - `String proxyFailureDetail(RouteFailure failure, {required String siteName, required String tunnelDescriptor})`
  - `class ProxyUnreachableScreen extends StatelessWidget` — `const ProxyUnreachableScreen({required String host, required String siteName, required RouteFailure failure, required String tunnelDescriptor, required String lastWorkedLabel, required VoidCallback onTryAgain, required VoidCallback onChangeProxySettings, required VoidCallback onOpenWithoutTunnel})`

Spec `8b` draws exactly one of Plan 3's five `RouteFailure` values — `proxyUnreachable` — with copy pinned verbatim: headline "Proxy did not answer", body naming the site and its tunnel. Plan 3's own doc comment on `refusalMessage()` says the `8b` copy is "Plan 4's to settle"; this task settles the drawn case exactly as designed, and covers the other four kinds by reusing `refusalMessage()` — the terse string Plan 3 wrote for precisely this purpose — as the headline, with a generic second sentence. That is a judgement call, not a spec requirement, and it is called out again in this plan's Known gaps below.

- [ ] **Step 1: Write the failing tests**

Create `test/domain/route_failure_copy_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/route_decision.dart';
import 'package:container/domain/models/route_failure_copy.dart';

void main() {
  test('the one failure the spec draws gets its exact pinned headline', () {
    expect(proxyFailureHeadline(RouteFailure.proxyUnreachable), 'Proxy did not answer');
  });

  test('every other failure headlines with Plan 3\'s refusalMessage', () {
    for (final failure in RouteFailure.values) {
      if (failure == RouteFailure.proxyUnreachable) continue;
      expect(proxyFailureHeadline(failure), refusalMessage(failure));
    }
  });

  test('the pinned detail sentence matches the spec\'s Forum example verbatim', () {
    expect(
      proxyFailureDetail(
        RouteFailure.proxyUnreachable,
        siteName: 'Forum',
        tunnelDescriptor: 'SOCKS5 at 127.0.0.1:9050',
      ),
      'Forum is set to go through SOCKS5 at 127.0.0.1:9050 and nothing is '
      'listening there. The page was not loaded, so no request left your device.',
    );
  });

  test('every failure with a tunnel names the site and ends on the same reassurance', () {
    for (final failure in RouteFailure.values) {
      if (failure == RouteFailure.misconfigured) continue;
      final detail = proxyFailureDetail(failure, siteName: 'Forum', tunnelDescriptor: 'the tunnel');
      expect(detail, contains('Forum'));
      expect(detail, endsWith('The page was not loaded, so no request left your device.'));
    }
  });

  test('misconfigured has no detail sentence, because the spec writes none', () {
    // Its headline already says there is no proxy configured; the generic
    // sentence would then name the tunnel the site goes through. Rather than
    // invent copy the spec never wrote, the screen shows the headline alone.
    expect(
      proxyFailureDetail(
        RouteFailure.misconfigured,
        siteName: 'Forum',
        tunnelDescriptor: 'the tunnel',
      ),
      isNull,
    );
  });
}
```

Create `test/ui/features/in_page/proxy_unreachable_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/route_decision.dart';
import 'package:container/ui/features/in_page/views/proxy_unreachable_screen.dart';

void main() {
  Widget host({
    RouteFailure failure = RouteFailure.proxyUnreachable,
    VoidCallback? onTryAgain,
    VoidCallback? onChangeProxySettings,
    VoidCallback? onOpenWithoutTunnel,
  }) {
    return MaterialApp(
      home: ProxyUnreachableScreen(
        host: 'forum.example.com',
        siteName: 'Forum',
        failure: failure,
        tunnelDescriptor: 'socks5 · 127.0.0.1:9050',
        lastWorkedLabel: '2 hours ago',
        onTryAgain: onTryAgain ?? () {},
        onChangeProxySettings: onChangeProxySettings ?? () {},
        onOpenWithoutTunnel: onOpenWithoutTunnel ?? () {},
      ),
    );
  }

  testWidgets('renders the spec copy verbatim for the drawn failure', (tester) async {
    await tester.pumpWidget(host());

    expect(find.text('forum.example.com'), findsOneWidget);
    expect(find.text('Proxy did not answer'), findsOneWidget);
    expect(
      find.text(
        'Forum is set to go through socks5 · 127.0.0.1:9050 and nothing is '
        'listening there. The page was not loaded, so no request left your device.',
      ),
      findsOneWidget,
    );
    expect(find.text('Tunnel'), findsOneWidget);
    expect(find.text('socks5 · 127.0.0.1:9050'), findsOneWidget);
    expect(find.text('Last worked'), findsOneWidget);
    expect(find.text('2 hours ago'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Change proxy settings'), findsOneWidget);
    expect(find.text('Open without the tunnel'), findsOneWidget);
    expect(find.text('This site will see your real IP'), findsOneWidget);
  });

  testWidgets('a different failure headlines with its own refusal message', (tester) async {
    await tester.pumpWidget(host(failure: RouteFailure.proxyRefused));
    // Assert against Plan 3's function, not a copy of the string it returns.
    // A duplicated string keeps passing when Plan 3 rewords the message, then
    // fails here looking like a Plan 4 bug.
    expect(find.text(refusalMessage(RouteFailure.proxyRefused)), findsOneWidget);
  });

  testWidgets('each button reports its own callback', (tester) async {
    var tried = 0;
    var changed = 0;
    var opened = 0;
    await tester.pumpWidget(host(
      onTryAgain: () => tried++,
      onChangeProxySettings: () => changed++,
      onOpenWithoutTunnel: () => opened++,
    ));

    await tester.tap(find.text('Try again'));
    await tester.tap(find.text('Change proxy settings'));
    await tester.tap(find.text('Open without the tunnel'));

    expect(tried, 1);
    expect(changed, 1);
    expect(opened, 1);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/domain/route_failure_copy_test.dart test/ui/features/in_page/proxy_unreachable_screen_test.dart`
Expected: FAIL — missing files (or, if Plan 3 is not yet built, a missing `route_decision.dart`; build Plan 3 Task 2 first).

- [ ] **Step 3: Write `route_failure_copy.dart`**

Create `lib/domain/models/route_failure_copy.dart`:

```dart
import 'route_decision.dart';

export 'route_decision.dart' show RouteFailure;

/// Screen `8b` draws only [RouteFailure.proxyUnreachable]; its headline is
/// pinned verbatim from the spec card. The other four kinds reuse Plan 3's
/// `refusalMessage()` — written, by its own doc comment, for exactly this
/// screen. Extending the spec's one drawn case to the four kinds Plan 3
/// defined is this plan's call, not the spec's; see Known gaps.
String proxyFailureHeadline(RouteFailure failure) {
  if (failure == RouteFailure.proxyUnreachable) return 'Proxy did not answer';
  return refusalMessage(failure);
}

/// The explanatory sentence under the headline, or `null` when the spec gives
/// us nothing to say.
///
/// Only [RouteFailure.proxyUnreachable] is drawn, so only its wording is
/// pinned. [RouteFailure.proxyRefused], [RouteFailure.upstreamTimeout] and
/// [RouteFailure.tlsFailure] share a generic first half: all three describe a
/// tunnel that exists and did not work, so naming it is accurate.
///
/// [RouteFailure.misconfigured] returns `null`. Its headline is "This site
/// has no proxy configured", and the generic sentence would say the site "is
/// set to go through" a tunnel — denying a proxy exists and naming one in
/// consecutive sentences. The spec draws no copy for that state (a grep of
/// the canvas file finds none), and a string that is not in the spec is a
/// design question rather than something to invent here, so the screen shows
/// the headline alone.
///
/// The cost is real and is recorded in this plan's Known gaps: the closing
/// reassurance — no request left your device — is the sentence a user most
/// wants on a failure screen, and `misconfigured` is the one kind that now
/// does not get it.
String? proxyFailureDetail(
  RouteFailure failure, {
  required String siteName,
  required String tunnelDescriptor,
}) {
  if (failure == RouteFailure.misconfigured) return null;

  final cause = failure == RouteFailure.proxyUnreachable
      ? '$siteName is set to go through $tunnelDescriptor and nothing is listening there.'
      : '$siteName is set to go through $tunnelDescriptor, which did not complete the connection.';
  return '$cause The page was not loaded, so no request left your device.';
}
```

Note: `lib/domain/models/route_decision.dart` is Plan 3 Task 2's file, not this task's — do not recreate it. If you are building this task before Plan 3 exists, add the file with exactly the `RouteFailure` enum and `refusalMessage()` function from Plan 3's Task 2 (five values: `proxyUnreachable`, `proxyRefused`, `upstreamTimeout`, `tlsFailure`, `misconfigured`), and remove the stand-in once Plan 3's real file lands.

- [ ] **Step 4: Run the domain test to verify it passes**

Run: `flutter test test/domain/route_failure_copy_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Write `ProxyUnreachableScreen`**

Create `lib/ui/features/in_page/views/proxy_unreachable_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../domain/models/route_failure_copy.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/pill_button.dart';

/// Spec `8b` — no silent fallback, the risky option spelled out. This is the
/// screen the interceptor's refusal (Plan 3) surfaces to: a route that could
/// not be established, never a page that quietly loaded unproxied.
class ProxyUnreachableScreen extends StatelessWidget {
  const ProxyUnreachableScreen({
    super.key,
    required this.host,
    required this.siteName,
    required this.failure,
    required this.tunnelDescriptor,
    required this.lastWorkedLabel,
    required this.onTryAgain,
    required this.onChangeProxySettings,
    required this.onOpenWithoutTunnel,
  });

  final String host;
  final String siteName;
  final RouteFailure failure;
  final String tunnelDescriptor;
  final String lastWorkedLabel;
  final VoidCallback onTryAgain;
  final VoidCallback onChangeProxySettings;
  final VoidCallback onOpenWithoutTunnel;

  @override
  Widget build(BuildContext context) {
    // Null for `misconfigured` — see `proxyFailureDetail`. The headline then
    // stands alone rather than carrying invented copy.
    final detail = proxyFailureDetail(
      failure,
      siteName: siteName,
      tunnelDescriptor: tunnelDescriptor,
    );

    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            _TunnelHeader(host: host),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: C.danger.withValues(alpha: 0.3)),
                      ),
                      child: const Text('⛌', style: TextStyle(fontSize: 16, color: C.danger)),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      proxyFailureHeadline(failure),
                      style: ui(size: 19, weight: 600, letterSpacing: -0.19),
                    ),
                    if (detail != null) ...[
                      const SizedBox(height: 18),
                      Text(
                        detail,
                        style: ui(size: 13.5, height: 1.7, color: C.textMuted),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        color: C.sheet,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: C.line08),
                      ),
                      child: Column(
                        children: [
                          _InfoRow(label: 'Tunnel', value: tunnelDescriptor),
                          const SizedBox(height: 7),
                          _InfoRow(label: 'Last worked', value: lastWorkedLabel),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    PillButton(label: 'Try again', tone: PillTone.primary, onTap: onTryAgain),
                    const SizedBox(height: 9),
                    PillButton(label: 'Change proxy settings', onTap: onChangeProxySettings),
                    const SizedBox(height: 9),
                    PillButton(
                      label: 'Open without the tunnel',
                      sublabel: 'This site will see your real IP',
                      tone: PillTone.dangerOutline,
                      onTap: onOpenWithoutTunnel,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The site pill in a danger tint, shared by `8b` and `8c` — both show a
/// tunnel that is not currently working.
class _TunnelHeader extends StatelessWidget {
  const _TunnelHeader({required this.host});

  final String host;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.line07))),
      child: Row(
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: Center(child: Text('‹', style: TextStyle(fontSize: 16, color: C.icon))),
          ),
          Expanded(
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: C.surface,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: C.danger.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(color: C.danger, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 7),
                  Text(host, style: ui(size: 11.5, color: C.textTertiary)),
                ],
              ),
            ),
          ),
          const SizedBox(
            width: 32,
            height: 32,
            child: Center(child: Text('⟳', style: TextStyle(fontSize: 14, color: C.icon))),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: ui(size: 12, color: C.textFaint)),
        Text(value, style: ui(size: 12, color: C.textSecondary)),
      ],
    );
  }
}
```

- [ ] **Step 6: Run the widget test to verify it passes**

Run: `flutter test test/ui/features/in_page/proxy_unreachable_screen_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 7: Run the analyzer**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/domain/models/route_failure_copy.dart lib/ui/features/in_page/views/proxy_unreachable_screen.dart test/domain/route_failure_copy_test.dart test/ui/features/in_page/proxy_unreachable_screen_test.dart
git commit -m "feat: add proxy unreachable screen (spec 8b)"
```

---

## Task 9: Tunnel dropped mid-session (spec `8c`)

**Files:**
- Create: `lib/ui/features/in_page/views/tunnel_dropped_screen.dart`
- Test: `test/ui/features/in_page/tunnel_dropped_screen_test.dart`

**Interfaces:**
- Consumes: `PageSkeleton` (Task 1); `C`, `ui` (Plan 1 Task 1). Does **not** import `RouteFailure` — spec `8c` is a single fixed state ("Tunnel dropped"), not one branching per failure kind, so it needs no copy table.
- Produces:
  - `class TunnelDroppedScreen extends StatelessWidget` — `const TunnelDroppedScreen({required String host, required String droppedAgoLabel, required VoidCallback onReconnect, required VoidCallback onCloseAndWipe})`

`droppedAgoLabel` arrives pre-composed ("4 seconds ago") — the elapsed time keeps changing while the banner is on screen, and a widget that reformats a live `Duration` on every rebuild is not what "pure widget, plain view model" means here. The caller (Plan 3's session layer) owns the clock.

- [ ] **Step 1: Write the failing test**

Create `test/ui/features/in_page/tunnel_dropped_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/ui/features/in_page/views/tunnel_dropped_screen.dart';

void main() {
  Widget host({VoidCallback? onReconnect, VoidCallback? onCloseAndWipe}) {
    return MaterialApp(
      home: TunnelDroppedScreen(
        host: 'forum.example.com',
        droppedAgoLabel: '4 seconds ago',
        onReconnect: onReconnect ?? () {},
        onCloseAndWipe: onCloseAndWipe ?? () {},
      ),
    );
  }

  testWidgets('renders the spec copy verbatim', (tester) async {
    await tester.pumpWidget(host());

    expect(find.text('forum.example.com'), findsOneWidget);
    expect(find.text('Tunnel dropped'), findsOneWidget);
    expect(
      find.text(
        'The page is paused. Nothing further has been requested since the '
        'connection failed 4 seconds ago.',
      ),
      findsOneWidget,
    );
    expect(find.text('Reconnect'), findsOneWidget);
    expect(find.text('Close and wipe'), findsOneWidget);
  });

  testWidgets('each button reports its own callback', (tester) async {
    var reconnected = 0;
    var wiped = 0;
    await tester.pumpWidget(host(
      onReconnect: () => reconnected++,
      onCloseAndWipe: () => wiped++,
    ));

    await tester.tap(find.text('Reconnect'));
    await tester.tap(find.text('Close and wipe'));

    expect(reconnected, 1);
    expect(wiped, 1);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/ui/features/in_page/tunnel_dropped_screen_test.dart`
Expected: FAIL — missing file.

- [ ] **Step 3: Write `TunnelDroppedScreen`**

Create `lib/ui/features/in_page/views/tunnel_dropped_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/page_skeleton.dart';

/// Spec `8c` — the page freezes and the decision surfaces at the top,
/// instead of a dialog stealing focus from a page the user was reading.
class TunnelDroppedScreen extends StatelessWidget {
  const TunnelDroppedScreen({
    super.key,
    required this.host,
    required this.droppedAgoLabel,
    required this.onReconnect,
    required this.onCloseAndWipe,
  });

  final String host;
  final String droppedAgoLabel;
  final VoidCallback onReconnect;
  final VoidCallback onCloseAndWipe;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: Center(child: Text('‹', style: TextStyle(fontSize: 16, color: C.icon))),
                  ),
                  Expanded(
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: C.surface,
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(color: C.danger.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(color: C.danger, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 7),
                          Text(host, style: ui(size: 11.5, color: C.textTertiary)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: Center(child: Text('⟳', style: TextStyle(fontSize: 14, color: C.icon))),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1517),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: C.danger.withValues(alpha: 0.28)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('⛌', style: TextStyle(fontSize: 13, color: C.danger)),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Tunnel dropped', style: ui(size: 14.5, weight: 600)),
                              const SizedBox(height: 5),
                              Text(
                                'The page is paused. Nothing further has been requested '
                                'since the connection failed $droppedAgoLabel.',
                                style: ui(size: 12.5, height: 1.6, color: C.dangerMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _TunnelActionButton(
                            label: 'Reconnect',
                            background: C.jade,
                            labelColor: C.bg,
                            weight: 600,
                            onTap: onReconnect,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: _TunnelActionButton(
                            label: 'Close and wipe',
                            background: C.dangerSurface,
                            labelColor: C.textSecondary,
                            weight: 500,
                            onTap: onCloseAndWipe,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ColorFiltered(
                colorFilter: const ColorFilter.matrix(<double>[
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0, 0, 0, 1, 0,
                ]),
                child: const PageSkeleton(opacity: 0.34),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The two-button row's fills (`#7FC8A9` jade, `#241C1D` danger surface with
/// plain secondary text) match neither existing [PillTone] exactly, so this
/// is a small local button rather than a third bespoke tone added to a
/// shared primitive for one screen.
class _TunnelActionButton extends StatelessWidget {
  const _TunnelActionButton({
    required this.label,
    required this.background,
    required this.labelColor,
    required this.weight,
    required this.onTap,
  });

  final String label;
  final Color background;
  final Color labelColor;
  final int weight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(21),
        child: Container(
          height: 42,
          alignment: Alignment.center,
          child: Text(label, style: ui(size: 13.5, weight: weight, color: labelColor)),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the widget test to verify it passes**

Run: `flutter test test/ui/features/in_page/tunnel_dropped_screen_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 5: Run the whole plan's suite and the analyzer**

Run: `flutter test test/domain/ test/ui/ && flutter analyze`
Expected: all passing, `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/ui/features/in_page/views/tunnel_dropped_screen.dart test/ui/features/in_page/tunnel_dropped_screen_test.dart
git commit -m "feat: add tunnel dropped mid-session banner (spec 8c)"
```

---

## Known gaps this plan deliberately leaves

- **Nothing in this plan is wired to a live event.** Every screen here is pure and reachable only by a caller that already has its data — a `PermissionRequestSheet` shown because a WebView actually asked, a `TunnelDroppedScreen` shown because a connection actually failed. Plan 3 owns firing them at the right moment; this plan owns what appears once it does.
- **Three of the five `RouteFailure` copy pairs are this plan's invention, and a fourth has no copy at all.** `proxyFailureHeadline`/`proxyFailureDetail` pin `proxyUnreachable` exactly as drawn and generalise `proxyRefused`, `upstreamTimeout` and `tlsFailure` from Plan 3's technical `refusalMessage()` strings. **`misconfigured` renders a headline with no detail sentence.** The generic sentence contradicted its own headline — it names a tunnel for the one state that means no tunnel is set — and the spec writes nothing for it, so nothing was invented in its place. The visible cost is that `misconfigured` is now the only failure that does not tell the user no request left their device, which is the most reassuring sentence on the screen. **That is an open design question, not a settled decision:** `8b` needs either a drawn `misconfigured` variant or an explicit ruling that the headline stands alone. If the design ever draws `8b` for the other kinds, that copy should be checked against this plan's guess and corrected here rather than treated as already settled.
- **The Today log has no live data source.** `BlockedTally` is a plain value; nothing in this plan builds one from `FilterEngine`'s `blockedCount` or a per-category breakdown. Plan 3's `FilterEngine` counts total blocks only, not by category — a real `BlockedTally` needs the filter engine to tag *why* it blocked something, which is new work for whichever plan wires this screen up.
- **The category bar's proportions are computed, not copied.** `categoryFraction` scales every bar to the largest category, which is a defensible rule but not the spec's own (non-derivable) mock percentages. Flagged once above in `blocked_tally.dart`'s doc comment; repeated here because it is a visible, judged deviation.
- **Reader mode never extracts an article.** `ReaderArticle` is rendered, not produced. Turning a live page into `host` / `title` / `paragraphs` / `minutesToRead` (a readability pass) is unbuilt and unassigned to any plan so far.
- **`SiteSheet`'s "Blocked here" count and both toggle values are inputs, not live state.** This screen renders whatever `blockedCount`, `forceDark` and `desktopView` it is given; persisting a toggle change back to `Site` (through `SiteRepository.upsert`) is the caller's job, not this widget's.
- **Held downloads are never actually intercepted.** `HeldDownloadSheet` renders a `HeldDownload` value; nothing in this plan hooks Android's `DownloadListener` or writes a file for `saveToDevice`. That is platform work for whichever plan wires this screen up — likely alongside Plan 3's WebView layer, since a `DownloadListener` is per-`WebView`.
- **`TunnelDroppedScreen`'s countdown is frozen text.** `droppedAgoLabel` is passed once; a real session needs its caller to keep re-supplying it (a `Timer` outside this widget, or a stream the provider layer folds into a rebuilding value model) for the "N seconds ago" to actually tick.

## Handoff

- **From Plan 3:** this plan's Tasks 8 and 9 consume `RouteDecision`, `RouteFailure` and `refusalMessage()` from Plan 3 Task 2 verbatim; nothing here modifies that file. Plan 3's own Known-gaps entry ("`8b` and `8c` are Plan 4's... it does not render them") is closed by this plan.
- **From Plan 2:** this plan's Task 5 (`SiteSheet`) consumes `AppToggle` from Plan 2 Task 5 (`lib/ui/core/widgets/app_toggle.dart`) rather than building a second switch widget. If Plan 2's `AppToggle` signature ever changes, `SiteSheet`'s two toggle rows are the call sites to check.
- **To whichever plan wires live data:** the six "Known gaps" above name every seam a real integration needs — a readability extractor for `6b`, a `FilterEngine` extended to tag block reasons for `5c`, a `DownloadListener` for `7c`, a persistence call for `6c`'s toggles, and a repeating clock for `8c`'s countdown. None of them is assigned to Plan 5 (workspaces and scripts) by Plan 1's roadmap; whoever picks this up next should confirm where they land before starting.
