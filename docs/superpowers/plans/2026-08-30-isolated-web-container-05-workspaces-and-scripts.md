# Isolated Web Container — Plan 5: Workspaces and Scripts

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The workspace-management surface (`10a`–`10c`: list, create/edit, delete-with-typed-confirmation) and the scripts-and-filters surface (`10d`, `10e`: filter-list toggles, a reusable script library, the script editor) — the last screens in the design's 32-screen set.

**Architecture:** Two independent feature areas sharing one screen family (`lib/ui/features/workspaces/` and `lib/ui/features/scripts/`), each a thin stateful shell over SQLite-backed repositories, following Plan 1's split of pure domain logic from Flutter widgets. Workspace deletion relies on the `ON DELETE CASCADE` Plan 1 already put on `sites.workspace_id` — deleting a workspace row cascades to its sites for free; nothing here re-implements that. Scripts are workspace-independent by design (spec `10c`: "Custom scripts kept ... In the script library"), so they get their own tables and a many-to-many join to sites, never a workspace foreign key.

**Tech Stack:** Everything from Plan 1 (Flutter, `flutter_riverpod`, `sqflite`). No new dependencies — rule-count formatting and the script editor's line gutter are hand-rolled rather than pulling in `intl` or a code-editor package.

**Spec:**
- `Sandbox Container -canvas-.dc.html` — read blocks `id="10a"` through `id="10e"`.
- `docs/superpowers/plans/2026-08-30-isolated-web-container-01-foundation.md` — Plan 1. Supplies tokens, typography, primitives, `Workspace`, `StorageRule`, `WorkspaceRepository`, `AppDatabase`.
- `docs/superpowers/plans/2026-08-30-isolated-web-container-02-entry-and-identity.md` — Plan 2. Task 6's `AppToggle` and Task 8's `SettingRow`/`SettingsScreen`, which Task 1 extends with an entry point.
- `docs/superpowers/plans/2026-08-30-isolated-web-container-03-container.md` — Plan 3. Task 1 bumped the schema to version 2; this plan continues that sequence. Its Handoff names `addDocumentStartJavaScript` in `Shields.apply` as where this plan's scripts inject — this plan produces the value, Plan 3's engine consumes it.

**Note on scope — turn 9 is not in this plan.** Plan 1's own roadmap assigned "backgrounding (`9a`, `9b`, `9c`)" to this plan, but Plan 2 built all three as part of its PIN/lock state machine: `9a` is `SecureWindowPlugin` + `FLAG_SECURE` (Plan 2 Task 8), and `9b`/`9c` are `LockBody`'s `LockMood.welcomeBack` and `LockMood.afterTimeout` (Plan 2 Task 5 — see its `Welcome back` / `3 sessions still open · locks in 40s` / `Locked after 1 minute in the background` copy, verbatim from these spec blocks). They were pulled forward because they are inseparable from the lock timer. Nothing in this plan touches turn 9 again.

**Depends on:** Plan 1 (all tasks) and Plan 2 Task 6 (`AppToggle`) and Task 8 (`SettingsScreen`, which Task 1 modifies).

---

## Global Constraints

The first eight are inherited from Plan 1 verbatim, repeated because a task's implementer may never open Plan 1.

- **Android only. Dark theme only.**
- **User-facing copy is verbatim from the spec.** Never paraphrase or invent a string; if it's not in the spec, flag the judgement call rather than pretending it's pinned.
- **Jade `#7FC8A9`** means live state or the single affirmative action on a screen — never more than one per screen.
- **Hairline dividers, not cards.**
- **IBM Plex Mono for anything technical**, Figtree for everything else.
- **Base background is `#0F1113`.**
- **The app makes no network requests of its own.**
- **No code generation.**

Added by this plan:

- **A workspace's deletion never touches the script library.** Spec `10c`: "Custom scripts kept ... In the script library." Scripts have no `workspace_id` column anywhere, by construction — a script's only relationship is to the sites it is applied to, through a join table whose rows disappear when a site is deleted, never when a workspace is.
- **"Update over the proxy" (`10d`) is rendered, not implemented.** It is a real button with a real callback, but nothing in this plan performs a network fetch — that would contradict the "no network requests of its own" constraint above, and resolving that tension (an explicit, scoped exception for filter-list updates) is a product decision for whoever builds it, not an implementation detail to slip past silently. See Known gaps.
- **Filter-list rule counts and "updated" timestamps are seeded static values**, not the output of a real filter-list fetch or a live rule-count from Plan 3's `FilterEngine`. Plan 3's own Known Gaps already flag that `FilterEngine` "will need a real matcher" for a multi-list library — this plan builds the Dart-side model and UI that a real matcher will eventually read `enabled` from; it does not build the matcher.
- **The two-vault rule from Plan 1 still applies**: nothing in this plan counts or lists across both vaults. Every repository here reads the one open `AppDatabase`.

---

## File Structure

```
lib/data/services/app_database.dart          MODIFY: schema v3 (Task 4), then v4 (Task 5)

lib/domain/models/filter_list.dart           FilterList
lib/domain/repositories/filter_list_repository.dart   FilterListRepository
lib/data/repositories/filter_list_repository_sqlite.dart

lib/domain/models/user_script.dart           UserScript, ScriptKind
lib/domain/repositories/script_repository.dart        ScriptRepository
lib/data/repositories/script_repository_sqlite.dart

lib/domain/workspace_stats.dart              workspaceStatsLine, wholeMegabytes
lib/domain/workspace_deletion.dart           confirmsDeletion
lib/domain/services/workspace_storage_service.dart     WorkspaceStorageService, FakeWorkspaceStorageService

lib/ui/features/workspaces/views/workspaces_screen.dart       spec 10a
lib/ui/features/workspaces/views/workspace_form_screen.dart   spec 10b
lib/ui/features/workspaces/views/delete_workspace_sheet.dart  spec 10c

lib/ui/features/scripts/views/filter_list_section.dart        spec 10d (filter half)
lib/ui/features/scripts/views/scripts_and_filters_screen.dart spec 10d (whole screen)
lib/ui/features/scripts/views/script_editor_screen.dart       spec 10e

lib/ui/features/settings/views/settings_screen.dart  MODIFY: adds the MANAGE section (Task 1)

test/domain/workspace_stats_test.dart
test/domain/workspace_deletion_test.dart
test/data/filter_list_repository_test.dart
test/data/script_repository_test.dart
test/ui/features/workspaces_screen_test.dart
test/ui/features/workspace_form_screen_test.dart
test/ui/features/delete_workspace_sheet_test.dart
test/ui/features/filter_list_section_test.dart
test/ui/features/scripts_and_filters_screen_test.dart
test/ui/features/script_editor_screen_test.dart
test/ui/features/settings_test.dart            MODIFY (Task 1)
```

---

## Task 1: Workspace stats and the Workspaces list (spec `10a`)

**Files:**
- Create: `lib/domain/workspace_stats.dart`
- Create: `lib/domain/services/workspace_storage_service.dart`
- Create: `lib/ui/features/workspaces/views/workspaces_screen.dart`
- Modify: `lib/ui/features/settings/views/settings_screen.dart`
- Test: `test/domain/workspace_stats_test.dart`
- Test: `test/ui/features/workspaces_screen_test.dart`
- Test: `test/ui/features/settings_test.dart` (extended)

**Interfaces:**
- Consumes: `Workspace`, `StorageRule` (Plan 1); `C`, `ui`, `T` (Plan 1 Task 1); `SettingRow`, `SettingsScreen` (Plan 2 Task 8).
- Produces:
  - `String wholeMegabytes(int bytes)`
  - `String workspaceStatsLine({required StorageRule storageRule, required int siteCount, required int storageBytes})`
  - `abstract interface class WorkspaceStorageService { Future<int> bytesFor(String workspaceId); }`
  - `class FakeWorkspaceStorageService implements WorkspaceStorageService`
  - `class WorkspaceListItem { const WorkspaceListItem({required String id, required String name, required int markerIndex, required String statsLine}); }`
  - `class WorkspacesScreen extends StatelessWidget` — `const WorkspacesScreen({required List<WorkspaceListItem> items, required void Function(String id) onOpen, required VoidCallback onNewWorkspace, required VoidCallback onBack})`
  - `SettingsScreen` gains a `void Function(String key) onTap` case for two new keys: `'workspaces'`, `'scripts'` (the callback signature is unchanged — these are new call sites, not a new parameter)

`storageBytes` comes from `WorkspaceStorageService`, a seam this task defines and does not implement for real: computing a WebView profile directory's on-disk size is platform code that depends on Plan 3's `ProfileManager`, which this plan does not touch. `FakeWorkspaceStorageService` is what tests use; production wiring is a Known Gap.

- [ ] **Step 1: Write the failing domain test**

Create `test/domain/workspace_stats_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/domain/workspace_stats.dart';

void main() {
  test('whole-number megabytes, matching the spec\'s "12 MB"', () {
    expect(wholeMegabytes(12 * 1024 * 1024), '12 MB');
    expect(wholeMegabytes(3 * 1024 * 1024), '3 MB');
  });

  test('a kept workspace states sites, cookie policy and size', () {
    expect(
      workspaceStatsLine(
        storageRule: StorageRule.keep,
        siteCount: 6,
        storageBytes: 12 * 1024 * 1024,
      ),
      '6 sites · cookies kept · 12 MB',
    );
    expect(
      workspaceStatsLine(
        storageRule: StorageRule.keep,
        siteCount: 2,
        storageBytes: 3 * 1024 * 1024,
      ),
      '2 sites · cookies kept · 3 MB',
    );
  });

  test('a single site reads as singular, matching the spec\'s "1 site"', () {
    expect(
      workspaceStatsLine(storageRule: StorageRule.keep, siteCount: 1, storageBytes: 0),
      '1 site · cookies kept · 0 MB',
    );
  });

  test('an ephemeral workspace never reports a size', () {
    expect(
      workspaceStatsLine(
        storageRule: StorageRule.wipeOnExit,
        siteCount: 1,
        storageBytes: 999999999,
      ),
      '1 site · wipes on exit · nothing stored',
    );
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/domain/workspace_stats_test.dart`
Expected: FAIL — missing file.

- [ ] **Step 3: Write `workspace_stats.dart`**

Create `lib/domain/workspace_stats.dart`:

```dart
import 'models/workspace.dart';

/// Rounded to the nearest whole megabyte — spec `10a` shows "12 MB", never
/// "12.0 MB". A dedicated rounder rather than reusing Plan 4's `formatBytes`,
/// which always keeps one decimal; the two screens want different precision
/// for the same underlying byte count.
String wholeMegabytes(int bytes) => '${(bytes / (1024 * 1024)).round()} MB';

/// The stats line under a workspace's name in `10a`'s list.
String workspaceStatsLine({
  required StorageRule storageRule,
  required int siteCount,
  required int storageBytes,
}) {
  final siteWord = siteCount == 1 ? 'site' : 'sites';
  final ruleClause = storageRule == StorageRule.wipeOnExit ? 'wipes on exit' : 'cookies kept';
  final storageClause =
      storageRule == StorageRule.wipeOnExit ? 'nothing stored' : wholeMegabytes(storageBytes);
  return '$siteCount $siteWord · $ruleClause · $storageClause';
}
```

- [ ] **Step 4: Run it to verify it passes**

Run: `flutter test test/domain/workspace_stats_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Write `WorkspaceStorageService`**

Create `lib/domain/services/workspace_storage_service.dart`:

```dart
/// How many bytes a workspace's sites have stored on disk. Real answers need
/// a platform call into Plan 3's per-site `ProfileManager` directories, which
/// this plan does not build — see this plan's Known gaps.
abstract interface class WorkspaceStorageService {
  Future<int> bytesFor(String workspaceId);
}

/// Test and pre-native-wiring stand-in. Returns 0 for any workspace not given
/// an explicit value, never throws.
class FakeWorkspaceStorageService implements WorkspaceStorageService {
  FakeWorkspaceStorageService([this._bytes = const {}]);

  final Map<String, int> _bytes;

  @override
  Future<int> bytesFor(String workspaceId) async => _bytes[workspaceId] ?? 0;
}
```

- [ ] **Step 6: Write the failing widget test**

Create `test/ui/features/workspaces_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/ui/features/workspaces/views/workspaces_screen.dart';

void main() {
  const items = [
    WorkspaceListItem(id: 'ws-personal', name: 'Personal', markerIndex: 0,
        statsLine: '6 sites · cookies kept · 12 MB'),
    WorkspaceListItem(id: 'ws-work', name: 'Work', markerIndex: 1,
        statsLine: '2 sites · cookies kept · 3 MB'),
    WorkspaceListItem(id: 'ws-ephemeral', name: 'Ephemeral', markerIndex: 4,
        statsLine: '1 site · wipes on exit · nothing stored'),
  ];

  Widget host({
    void Function(String id)? onOpen,
    VoidCallback? onNewWorkspace,
    VoidCallback? onBack,
  }) {
    return MaterialApp(
      home: WorkspacesScreen(
        items: items,
        onOpen: onOpen ?? (_) {},
        onNewWorkspace: onNewWorkspace ?? () {},
        onBack: onBack ?? () {},
      ),
    );
  }

  testWidgets('renders every workspace and the spec copy verbatim', (tester) async {
    await tester.pumpWidget(host());

    expect(find.text('Workspaces'), findsOneWidget);
    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('6 sites · cookies kept · 12 MB'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('2 sites · cookies kept · 3 MB'), findsOneWidget);
    expect(find.text('Ephemeral'), findsOneWidget);
    expect(find.text('1 site · wipes on exit · nothing stored'), findsOneWidget);
    expect(find.text('New workspace'), findsOneWidget);
    expect(
      find.text(
        'The same site can live in more than one workspace. Each copy has '
        'its own login and its own history.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping a row reports its id, and New workspace is separate', (tester) async {
    final opened = <String>[];
    var newTaps = 0;
    await tester.pumpWidget(host(onOpen: opened.add, onNewWorkspace: () => newTaps++));

    await tester.tap(find.text('Work'));
    await tester.tap(find.text('New workspace'));

    expect(opened, ['ws-work']);
    expect(newTaps, 1);
  });
}
```

- [ ] **Step 7: Run it to verify it fails**

Run: `flutter test test/ui/features/workspaces_screen_test.dart`
Expected: FAIL — missing file.

- [ ] **Step 8: Write `WorkspacesScreen`**

Create `lib/ui/features/workspaces/views/workspaces_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/typography.dart';

class WorkspaceListItem {
  const WorkspaceListItem({
    required this.id,
    required this.name,
    required this.markerIndex,
    required this.statsLine,
  });

  final String id;
  final String name;
  final int markerIndex;
  final String statsLine;
}

/// Spec `10a` — what each workspace keeps.
class WorkspacesScreen extends StatelessWidget {
  const WorkspacesScreen({
    super.key,
    required this.items,
    required this.onOpen,
    required this.onNewWorkspace,
    required this.onBack,
  });

  final List<WorkspaceListItem> items;
  final void Function(String id) onOpen;
  final VoidCallback onNewWorkspace;
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
                  Text('Workspaces', style: T.screenTitle),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                children: [
                  for (final item in items) _WorkspaceRow(item: item, onTap: () => onOpen(item.id)),
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: GestureDetector(
                      onTap: onNewWorkspace,
                      child: Row(
                        children: [
                          Text('+', style: ui(size: 17, weight: 300, color: C.jade)),
                          const SizedBox(width: 11),
                          Text('New workspace', style: ui(size: 14.5, weight: 500, color: C.jade)),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 22),
                    child: Text(
                      'The same site can live in more than one workspace. Each copy has '
                      'its own login and its own history.',
                      style: ui(size: 12, height: 1.6, color: C.textDim),
                    ),
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

class _WorkspaceRow extends StatelessWidget {
  const _WorkspaceRow({required this.item, required this.onTap});

  final WorkspaceListItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: C.line06)),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: C.markers[item.markerIndex],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: ui(size: 15, weight: 500)),
                  const SizedBox(height: 4),
                  Text(item.statsLine, style: ui(size: 11.5, color: C.textFaint)),
                ],
              ),
            ),
            Text('›', style: ui(size: 14, color: C.textFaint)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 9: Run it to verify it passes**

Run: `flutter test test/ui/features/workspaces_screen_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 10: Add the entry point in Settings**

The spec draws no explicit link from Settings to `10a`/`10d` — this plan puts one there, since Settings is the app's one general-purpose navigation surface and both destinations are management screens, not day-to-day actions. The row labels reuse each destination screen's own header text rather than inventing new copy.

Extend `test/ui/features/settings_test.dart` — add inside `main()`, after the existing tests:

```dart
  testWidgets('a MANAGE section links to workspaces and scripts', (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(
        biometrics: true,
        autoLockLabel: 'After 1 min',
        decoyEnabled: false,
        decoySiteCount: 0,
        hideFromSwitcher: true,
        panicOnFlip: false,
        onPanicLabel: 'Wipe + lock',
        onChanged: (_, __) {},
        onTap: tapped.add,
      ),
    ));

    expect(find.text('MANAGE'), findsOneWidget);
    expect(find.text('Workspaces'), findsOneWidget);
    expect(find.text('Scripts and filters'), findsOneWidget);

    await tester.tap(find.text('Workspaces'));
    await tester.tap(find.text('Scripts and filters'));
    expect(tapped, ['workspaces', 'scripts']);
  });
```

In `lib/ui/features/settings/views/settings_screen.dart`, insert a new section between the `LOCK` rows and the `if (decoyEnabled)` block:

```dart
                  SettingRow(
                      title: 'Change main PIN', onTap: () => onTap('changePin')),
                  const SizedBox(height: 24),
                  Text('MANAGE', style: T.sectionLabel),
                  SettingRow(title: 'Workspaces', onTap: () => onTap('workspaces')),
                  SettingRow(title: 'Scripts and filters', onTap: () => onTap('scripts')),
                  if (decoyEnabled) ...[
```

(This replaces the two lines `SettingRow(title: 'Change main PIN', onTap: () => onTap('changePin')), if (decoyEnabled) ...[` with the block above — the `Change main PIN` row's own line is unchanged, everything from `const SizedBox(height: 24)` down is new.)

- [ ] **Step 11: Run the settings tests to verify they pass**

Run: `flutter test test/ui/features/settings_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 12: Run the analyzer**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 13: Commit**

```bash
git add lib/domain/workspace_stats.dart lib/domain/services/workspace_storage_service.dart lib/ui/features/workspaces/views/workspaces_screen.dart lib/ui/features/settings/views/settings_screen.dart test/domain/workspace_stats_test.dart test/ui/features/workspaces_screen_test.dart test/ui/features/settings_test.dart
git commit -m "feat: add Workspaces list screen and its Settings entry point (spec 10a)"
```

---

## Task 2: New / edit workspace (spec `10b`)

**Files:**
- Create: `lib/ui/features/workspaces/views/workspace_form_screen.dart`
- Test: `test/ui/features/workspace_form_screen_test.dart`

**Interfaces:**
- Consumes: `StorageRule` (Plan 1); `C.markers` (Plan 1 Task 1); `AppToggle` (Plan 2 Task 6).
- Produces:
  - `class WorkspaceFormResult { const WorkspaceFormResult({required String name, required int markerIndex, required StorageRule storageRule, required bool requirePin, required bool showInDecoy}); }`
  - `class WorkspaceFormScreen extends StatefulWidget` — `const WorkspaceFormScreen({required String title, required String initialName, required int initialMarkerIndex, required StorageRule initialStorageRule, required bool initialRequirePin, required bool initialShowInDecoy, required ValueChanged<WorkspaceFormResult> onSave, required VoidCallback onClose})`

One screen for both create and edit — `title` and the five `initial*` values are the only difference the caller supplies. Spec `10b` only draws the create case ("New workspace"); an edit caller passes the workspace's own name as `title` and its current field values as the `initial*` args, matching the pattern Plan 3's Add Site screen already established for reusing one form both ways.

- [ ] **Step 1: Write the failing test**

Create `test/ui/features/workspace_form_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/ui/features/workspaces/views/workspace_form_screen.dart';

void main() {
  Widget host({
    ValueChanged<WorkspaceFormResult>? onSave,
    VoidCallback? onClose,
    String initialName = '',
    int initialMarkerIndex = 0,
    StorageRule initialStorageRule = StorageRule.keep,
    bool initialRequirePin = false,
    bool initialShowInDecoy = false,
  }) {
    return MaterialApp(
      home: WorkspaceFormScreen(
        title: 'New workspace',
        initialName: initialName,
        initialMarkerIndex: initialMarkerIndex,
        initialStorageRule: initialStorageRule,
        initialRequirePin: initialRequirePin,
        initialShowInDecoy: initialShowInDecoy,
        onSave: onSave ?? (_) {},
        onClose: onClose ?? () {},
      ),
    );
  }

  testWidgets('renders the spec copy verbatim', (tester) async {
    await tester.pumpWidget(host());

    expect(find.text('New workspace'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('×'), findsOneWidget);
    expect(find.text('NAME'), findsOneWidget);
    expect(find.text('MARKER'), findsOneWidget);
    expect(find.text('STORAGE'), findsOneWidget);
    expect(find.text('Keep between sessions'), findsOneWidget);
    expect(find.text('Stays signed in'), findsOneWidget);
    expect(find.text('Wipe when the app closes'), findsOneWidget);
    expect(find.text('Nothing survives a restart'), findsOneWidget);
    expect(find.text('Ask for PIN to enter'), findsOneWidget);
    expect(find.text('Applies to the whole workspace'), findsOneWidget);
    expect(find.text('Show in decoy vault'), findsOneWidget);
    expect(find.text('Off keeps it invisible behind the second PIN'), findsOneWidget);
  });

  testWidgets('Save reports the typed name and the defaults untouched', (tester) async {
    WorkspaceFormResult? result;
    await tester.pumpWidget(host(onSave: (r) => result = r));

    await tester.enterText(find.byType(TextField), 'Research');
    await tester.tap(find.text('Save'));

    expect(result!.name, 'Research');
    expect(result!.markerIndex, 0);
    expect(result!.storageRule, StorageRule.keep);
    expect(result!.requirePin, isFalse);
    expect(result!.showInDecoy, isFalse);
  });

  testWidgets('picking a marker and the wipe rule changes what Save reports', (tester) async {
    WorkspaceFormResult? result;
    await tester.pumpWidget(host(onSave: (r) => result = r, initialName: 'Ephemeral'));

    await tester.tap(find.byKey(const Key('marker-2')));
    await tester.tap(find.text('Wipe when the app closes'));
    await tester.tap(find.text('Save'));

    expect(result!.markerIndex, 2);
    expect(result!.storageRule, StorageRule.wipeOnExit);
  });

  testWidgets('both toggles report their new value', (tester) async {
    WorkspaceFormResult? result;
    await tester.pumpWidget(host(onSave: (r) => result = r, initialName: 'X'));

    final pinRow = find.ancestor(
      of: find.text('Ask for PIN to enter'),
      matching: find.byType(Row),
    ).first;
    final decoyRow = find.ancestor(
      of: find.text('Show in decoy vault'),
      matching: find.byType(Row),
    ).first;
    await tester.tap(find.descendant(of: pinRow, matching: find.byType(GestureDetector)));
    await tester.tap(find.descendant(of: decoyRow, matching: find.byType(GestureDetector)));
    await tester.tap(find.text('Save'));

    expect(result!.requirePin, isTrue);
    expect(result!.showInDecoy, isTrue);
  });

  testWidgets('the × closes without saving', (tester) async {
    var saves = 0;
    var closes = 0;
    await tester.pumpWidget(host(onSave: (_) => saves++, onClose: () => closes++));

    await tester.tap(find.text('×'));

    expect(closes, 1);
    expect(saves, 0);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/ui/features/workspace_form_screen_test.dart`
Expected: FAIL — missing file.

- [ ] **Step 3: Write `WorkspaceFormScreen`**

Create `lib/ui/features/workspaces/views/workspace_form_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../domain/models/workspace.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/app_toggle.dart';

class WorkspaceFormResult {
  const WorkspaceFormResult({
    required this.name,
    required this.markerIndex,
    required this.storageRule,
    required this.requirePin,
    required this.showInDecoy,
  });

  final String name;
  final int markerIndex;
  final StorageRule storageRule;
  final bool requirePin;
  final bool showInDecoy;
}

/// Spec `10b` — used both to create a workspace and, with the caller passing
/// its current values as `initial*`, to edit one. The spec draws only the
/// create case; [title] is the one thing that visibly changes between them.
class WorkspaceFormScreen extends StatefulWidget {
  const WorkspaceFormScreen({
    super.key,
    required this.title,
    required this.initialName,
    required this.initialMarkerIndex,
    required this.initialStorageRule,
    required this.initialRequirePin,
    required this.initialShowInDecoy,
    required this.onSave,
    required this.onClose,
  });

  final String title;
  final String initialName;
  final int initialMarkerIndex;
  final StorageRule initialStorageRule;
  final bool initialRequirePin;
  final bool initialShowInDecoy;
  final ValueChanged<WorkspaceFormResult> onSave;
  final VoidCallback onClose;

  @override
  State<WorkspaceFormScreen> createState() => _WorkspaceFormScreenState();
}

class _WorkspaceFormScreenState extends State<WorkspaceFormScreen> {
  late final _nameController = TextEditingController(text: widget.initialName);
  late int _markerIndex = widget.initialMarkerIndex;
  late StorageRule _storageRule = widget.initialStorageRule;
  late bool _requirePin = widget.initialRequirePin;
  late bool _showInDecoy = widget.initialShowInDecoy;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    widget.onSave(WorkspaceFormResult(
      name: _nameController.text,
      markerIndex: _markerIndex,
      storageRule: _storageRule,
      requirePin: _requirePin,
      showInDecoy: _showInDecoy,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: widget.onClose,
                    child: const Text('×', style: TextStyle(fontSize: 20, color: C.icon)),
                  ),
                  Text(widget.title, style: ui(size: 15, weight: 600)),
                  GestureDetector(
                    onTap: _save,
                    child: Text('Save', style: ui(size: 14, weight: 500, color: C.jade)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                children: [
                  _fieldLabel('NAME'),
                  const SizedBox(height: 8),
                  Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: C.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: C.jade.withValues(alpha: 0.35)),
                    ),
                    child: TextField(
                      controller: _nameController,
                      style: ui(size: 14, color: C.textSecondary),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _fieldLabel('MARKER'),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      for (var i = 0; i < C.markers.length; i++) ...[
                        if (i != 0) const SizedBox(width: 12),
                        GestureDetector(
                          key: Key('marker-$i'),
                          onTap: () => setState(() => _markerIndex = i),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: C.markers[i],
                              borderRadius: BorderRadius.circular(8),
                              border: i == _markerIndex
                                  ? Border.all(color: C.textPrimary, width: 2)
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  _fieldLabel('STORAGE'),
                  const SizedBox(height: 9),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: DecoratedBox(
                      decoration: BoxDecoration(border: Border.all(color: C.line08)),
                      child: Column(
                        children: [
                          _storageOption(
                            title: 'Keep between sessions',
                            subtitle: 'Stays signed in',
                            selected: _storageRule == StorageRule.keep,
                            onTap: () => setState(() => _storageRule = StorageRule.keep),
                          ),
                          Container(height: 1, color: C.bg),
                          _storageOption(
                            title: 'Wipe when the app closes',
                            subtitle: 'Nothing survives a restart',
                            selected: _storageRule == StorageRule.wipeOnExit,
                            onTap: () => setState(() => _storageRule = StorageRule.wipeOnExit),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _toggleRow(
                    title: 'Ask for PIN to enter',
                    subtitle: 'Applies to the whole workspace',
                    value: _requirePin,
                    onChanged: (v) => setState(() => _requirePin = v),
                  ),
                  _toggleRow(
                    title: 'Show in decoy vault',
                    subtitle: 'Off keeps it invisible behind the second PIN',
                    value: _showInDecoy,
                    onChanged: (v) => setState(() => _showInDecoy = v),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) =>
      Text(text, style: ui(size: 10.5, weight: 600, letterSpacing: 1.05, color: C.textFaint));

  Widget _storageOption({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: C.surface,
        padding: const EdgeInsets.all(13),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: ui(size: 13.5, color: selected ? C.textPrimary : C.textTertiary)),
                const SizedBox(height: 3),
                Text(subtitle, style: ui(size: 11, color: C.textFaint)),
              ],
            ),
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: C.bg,
                border: Border.all(color: selected ? C.jade : C.idleDot, width: selected ? 5 : 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ui(size: 14, color: C.textPrimary)),
                const SizedBox(height: 3),
                Text(subtitle, style: ui(size: 11, color: C.textFaint)),
              ],
            ),
          ),
          AppToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run it to verify it passes**

Run: `flutter test test/ui/features/workspace_form_screen_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Run the analyzer**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/ui/features/workspaces/views/workspace_form_screen.dart test/ui/features/workspace_form_screen_test.dart
git commit -m "feat: add new/edit workspace form (spec 10b)"
```

---

## Task 3: Deleting a workspace (spec `10c`)

**Files:**
- Create: `lib/domain/workspace_deletion.dart`
- Create: `lib/ui/features/workspaces/views/delete_workspace_sheet.dart`
- Test: `test/domain/workspace_deletion_test.dart`
- Test: `test/ui/features/delete_workspace_sheet_test.dart`

**Interfaces:**
- Consumes: `BottomSheetSurface` (Plan 4 Task 1); `PillButton`, `PillTone` (Plan 1 Task 2); `wholeMegabytes` (Task 1); `C`, `ui` (Plan 1 Task 1).
- Produces:
  - `bool confirmsDeletion(String typed, String workspaceName)`
  - `class DeleteWorkspaceSheet extends StatefulWidget` — `const DeleteWorkspaceSheet({required String workspaceName, required int sitesRemoved, required int storageBytesWiped, required VoidCallback onCancel, required VoidCallback onDelete})`

`WorkspaceRepository.delete(id)` (Plan 1) already cascades to the workspace's sites through the `ON DELETE CASCADE` on `sites.workspace_id` — this task calls it, it does not re-implement it. `sitesRemoved` and `storageBytesWiped` are gathered by the caller (`SiteRepository.inWorkspace(id).length` and `WorkspaceStorageService.bytesFor(id)`) before showing this sheet, so "logins destroyed" — which spec `10c` always shows equal to sites removed, one login per site — is `sitesRemoved` again, not a second count this plan invents a source for.

- [ ] **Step 1: Write the failing domain test**

Create `test/domain/workspace_deletion_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/workspace_deletion.dart';

void main() {
  test('the typed name must match exactly', () {
    expect(confirmsDeletion('Work', 'Work'), isTrue);
  });

  test('a partial or wrong name does not confirm', () {
    expect(confirmsDeletion('Wor', 'Work'), isFalse);
    expect(confirmsDeletion('work', 'Work'), isFalse);
    expect(confirmsDeletion('', 'Work'), isFalse);
  });

  test('surrounding whitespace is trimmed, but internal case is not', () {
    expect(confirmsDeletion('  Work  ', 'Work'), isTrue);
    expect(confirmsDeletion('WORK', 'Work'), isFalse);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/domain/workspace_deletion_test.dart`
Expected: FAIL — missing file.

- [ ] **Step 3: Write `confirmsDeletion`**

Create `lib/domain/workspace_deletion.dart`:

```dart
/// Whether [typed] matches [workspaceName] closely enough to arm the delete
/// button in spec `10c`'s "Type the name to confirm" field. Exact match
/// after trimming outer whitespace — no case-insensitivity, so a workspace
/// named "work" and one named "Work" are never confused by a careless typo.
bool confirmsDeletion(String typed, String workspaceName) => typed.trim() == workspaceName;
```

- [ ] **Step 4: Run it to verify it passes**

Run: `flutter test test/domain/workspace_deletion_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 5: Write the failing widget test**

Create `test/ui/features/delete_workspace_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/ui/features/workspaces/views/delete_workspace_sheet.dart';

void main() {
  Widget host({VoidCallback? onCancel, VoidCallback? onDelete}) {
    return MaterialApp(
      home: Scaffold(
        body: DeleteWorkspaceSheet(
          workspaceName: 'Work',
          sitesRemoved: 2,
          storageBytesWiped: 3 * 1024 * 1024,
          onCancel: onCancel ?? () {},
          onDelete: onDelete ?? () {},
        ),
      ),
    );
  }

  testWidgets('renders the spec copy and computed stats verbatim', (tester) async {
    await tester.pumpWidget(host());

    // Curly quotes, not straight ones — the canvas writes this title as
    // `Delete “Work”?`, the only curly-quoted string in the whole spec.
    expect(find.text('Delete “Work”?'), findsOneWidget);
    expect(find.text('Sites removed'), findsOneWidget);
    expect(find.text('Logins destroyed'), findsOneWidget);
    expect(find.text('2'), findsNWidgets(2));
    expect(find.text('Stored data wiped'), findsOneWidget);
    expect(find.text('3 MB'), findsOneWidget);
    expect(find.text('Custom scripts kept'), findsOneWidget);
    expect(find.text('In the script library'), findsOneWidget);
    expect(
      find.text('This cannot be undone and there is no backup unless you made one yourself.'),
      findsOneWidget,
    );
    expect(find.text('Type the name to confirm'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('Delete is inert until the typed name matches', (tester) async {
    var deletes = 0;
    await tester.pumpWidget(host(onDelete: () => deletes++));

    await tester.tap(find.text('Delete'));
    expect(deletes, 0);

    // `enterText` does not pump a frame, so without these pumps the tap
    // below lands on the previously-built, still-disabled Delete button and
    // the matching name looks like it did nothing.
    await tester.enterText(find.byType(TextField), 'Wor');
    await tester.pump();
    await tester.tap(find.text('Delete'));
    expect(deletes, 0);

    await tester.enterText(find.byType(TextField), 'Work');
    await tester.pump();
    await tester.tap(find.text('Delete'));
    expect(deletes, 1);
  });

  testWidgets('Cancel reports a tap regardless of the typed text', (tester) async {
    var cancels = 0;
    await tester.pumpWidget(host(onCancel: () => cancels++));
    await tester.tap(find.text('Cancel'));
    expect(cancels, 1);
  });
}
```

- [ ] **Step 6: Run it to verify it fails**

Run: `flutter test test/ui/features/delete_workspace_sheet_test.dart`
Expected: FAIL — missing file.

- [ ] **Step 7: Write `DeleteWorkspaceSheet`**

Create `lib/ui/features/workspaces/views/delete_workspace_sheet.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../domain/workspace_deletion.dart';
import '../../../../domain/workspace_stats.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/sheet.dart';

/// Spec `10c` — an itemised list of what goes, typed confirmation.
class DeleteWorkspaceSheet extends StatefulWidget {
  const DeleteWorkspaceSheet({
    super.key,
    required this.workspaceName,
    required this.sitesRemoved,
    required this.storageBytesWiped,
    required this.onCancel,
    required this.onDelete,
  });

  final String workspaceName;
  final int sitesRemoved;
  final int storageBytesWiped;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  @override
  State<DeleteWorkspaceSheet> createState() => _DeleteWorkspaceSheetState();
}

class _DeleteWorkspaceSheetState extends State<DeleteWorkspaceSheet> {
  final _controller = TextEditingController();
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final now = confirmsDeletion(_controller.text, widget.workspaceName);
      if (now != _confirmed) setState(() => _confirmed = now);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BottomSheetSurface(
      children: [
        // Curly quotes are what the spec draws: `Delete “Work”?`. The canvas
        // is authoritative over this plan file. Do not "normalise" them.
        Text('Delete “${widget.workspaceName}”?',
            style: ui(size: 17, weight: 600, letterSpacing: -0.17)),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: DecoratedBox(
            decoration: BoxDecoration(border: Border.all(color: C.line08)),
            child: Column(
              children: [
                _statRow('Sites removed', '${widget.sitesRemoved}'),
                _statRow('Logins destroyed', '${widget.sitesRemoved}'),
                _statRow('Stored data wiped', wholeMegabytes(widget.storageBytesWiped)),
                _statRow('Custom scripts kept', 'In the script library', muted: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'This cannot be undone and there is no backup unless you made one yourself.',
          style: ui(size: 12.5, height: 1.6, color: C.textMuted),
        ),
        const SizedBox(height: 16),
        Text('Type the name to confirm', style: ui(size: 11.5, color: C.textFaint)),
        const SizedBox(height: 8),
        Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: C.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: C.line10),
          ),
          child: TextField(
            controller: _controller,
            style: ui(size: 14, color: C.textSecondary),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              hintText: widget.workspaceName,
              hintStyle: ui(size: 14, color: C.textDisabled),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: PillButton(label: 'Cancel', onTap: widget.onCancel)),
            const SizedBox(width: 9),
            Expanded(
              child: _DeleteButton(enabled: _confirmed, onTap: widget.onDelete),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statRow(String label, String value, {bool muted = false}) {
    return Container(
      color: C.surface,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: ui(size: 13, color: C.textTertiary)),
          Text(value, style: ui(size: 13, color: muted ? C.textMuted : C.textPrimary)),
        ],
      ),
    );
  }
}

/// Spec `10c`'s Delete button fills `#241C1D` (danger surface) with a
/// `#8A6A62` (danger-muted) label and a 28%-alpha danger border — a
/// combination none of Plan 1's [PillTone] values produce, so it is a small
/// local button rather than a fourth bespoke tone added for one screen.
class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: C.dangerSurface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: C.danger.withValues(alpha: enabled ? 0.28 : 0.1)),
          ),
          child: Text(
            'Delete',
            style: ui(size: 14.5, weight: 500, color: enabled ? C.dangerMuted : C.textDisabled),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 8: Run it to verify it passes**

Run: `flutter test test/ui/features/delete_workspace_sheet_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 9: Run the analyzer**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 10: Commit**

```bash
git add lib/domain/workspace_deletion.dart lib/ui/features/workspaces/views/delete_workspace_sheet.dart test/domain/workspace_deletion_test.dart test/ui/features/delete_workspace_sheet_test.dart
git commit -m "feat: add typed-confirmation workspace deletion (spec 10c)"
```

---

## Task 4: Filter lists (spec `10d`, filter half)

**Files:**
- Modify: `lib/data/services/app_database.dart` (schema version 2 → 3)
- Create: `lib/domain/models/filter_list.dart`
- Create: `lib/domain/repositories/filter_list_repository.dart`
- Create: `lib/data/repositories/filter_list_repository_sqlite.dart`
- Create: `lib/ui/features/scripts/views/filter_list_section.dart`
- Test: `test/data/filter_list_repository_test.dart`
- Test: `test/ui/features/filter_list_section_test.dart`

**Interfaces:**
- Consumes: `AppDatabase` (Plan 1, extended by Plan 3 to schema 2).
- Produces:
  - `class FilterList { const FilterList({required String id, required String name, required int ruleCount, required DateTime updatedAt, required bool enabled}); }`
  - `abstract interface class FilterListRepository { Future<List<FilterList>> all(); Future<void> setEnabled(String id, bool enabled); }`
  - `class SqliteFilterListRepository implements FilterListRepository { SqliteFilterListRepository(AppDatabase database); }`
  - `Future<void> seedFilterListsIfEmpty(AppDatabase database, {DateTime Function() now = DateTime.now})`
  - `String formatRuleCount(int n)`
  - `String updatedAgoLabel(DateTime now, DateTime updatedAt)`
  - `class FilterListSection extends StatelessWidget` — `const FilterListSection({required List<FilterList> lists, required DateTime now, required int nextUpdateInDays, required ValueChanged<String> onToggle, required VoidCallback onUpdateNow})`

- [ ] **Step 1: Write the failing repository test**

Create `test/data/filter_list_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:container/data/repositories/filter_list_repository_sqlite.dart';
import 'package:container/data/services/app_database.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
  });

  tearDown(() => database.close());

  DateTime fixedNow() => DateTime.utc(2026, 8, 30, 9);

  test('a fresh database seeds the three lists from the spec', () async {
    await seedFilterListsIfEmpty(database, now: fixedNow);
    final lists = await SqliteFilterListRepository(database).all();

    expect(lists.map((l) => l.name), ['Trackers and ads', 'Cookie notices', 'Social embeds']);
    expect(lists.map((l) => l.ruleCount), [84102, 11430, 2908]);
    expect(lists.map((l) => l.enabled), [true, true, false]);
  });

  test('seeding twice does not duplicate anything', () async {
    await seedFilterListsIfEmpty(database, now: fixedNow);
    await seedFilterListsIfEmpty(database, now: fixedNow);

    expect((await SqliteFilterListRepository(database).all()).length, 3);
  });

  test('toggling persists the enabled bit without touching anything else', () async {
    await seedFilterListsIfEmpty(database, now: fixedNow);
    final repo = SqliteFilterListRepository(database);
    final socialEmbeds = (await repo.all()).firstWhere((l) => l.name == 'Social embeds');

    await repo.setEnabled(socialEmbeds.id, true);
    final reloaded = (await repo.all()).firstWhere((l) => l.id == socialEmbeds.id);

    expect(reloaded.enabled, isTrue);
    expect(reloaded.ruleCount, socialEmbeds.ruleCount);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/data/filter_list_repository_test.dart`
Expected: FAIL — missing files.

- [ ] **Step 3: Bump the schema and add the table**

In `lib/data/services/app_database.dart`, change `static const schemaVersion = 2;` to `static const schemaVersion = 3;`, add the table to `onCreate` (after the `sites` table's `CREATE INDEX`), and extend `onUpgrade`:

```dart
          await db.execute('''
            CREATE TABLE filter_lists (
              id          TEXT PRIMARY KEY,
              name        TEXT    NOT NULL,
              rule_count  INTEGER NOT NULL,
              updated_at  INTEGER NOT NULL,
              enabled     INTEGER NOT NULL DEFAULT 1
            )
          ''');
```

```dart
        onUpgrade: (db, from, to) async {
          if (from < 2) {
            // ... Plan 3's existing block, unchanged ...
          }
          if (from < 3) {
            await db.execute('''
              CREATE TABLE filter_lists (
                id          TEXT PRIMARY KEY,
                name        TEXT    NOT NULL,
                rule_count  INTEGER NOT NULL,
                updated_at  INTEGER NOT NULL,
                enabled     INTEGER NOT NULL DEFAULT 1
              )
            ''');
          }
        },
```

- [ ] **Step 4: Write `FilterList` and the repository**

Create `lib/domain/models/filter_list.dart`:

```dart
class FilterList {
  const FilterList({
    required this.id,
    required this.name,
    required this.ruleCount,
    required this.updatedAt,
    required this.enabled,
  });

  final String id;
  final String name;
  final int ruleCount;
  final DateTime updatedAt;
  final bool enabled;
}
```

Create `lib/domain/repositories/filter_list_repository.dart`:

```dart
import '../models/filter_list.dart';

abstract interface class FilterListRepository {
  Future<List<FilterList>> all();
  Future<void> setEnabled(String id, bool enabled);
}
```

Create `lib/data/repositories/filter_list_repository_sqlite.dart`:

```dart
import '../../domain/models/filter_list.dart';
import '../../domain/repositories/filter_list_repository.dart';
import '../services/app_database.dart';

class SqliteFilterListRepository implements FilterListRepository {
  SqliteFilterListRepository(this._database);

  final AppDatabase _database;

  @override
  Future<List<FilterList>> all() async {
    final rows = await _database.db.query('filter_lists', orderBy: 'rowid');
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> setEnabled(String id, bool enabled) async {
    await _database.db.update(
      'filter_lists',
      {'enabled': enabled ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  FilterList _fromRow(Map<String, Object?> row) => FilterList(
        id: row['id']! as String,
        name: row['name']! as String,
        ruleCount: row['rule_count']! as int,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at']! as int, isUtc: true),
        enabled: (row['enabled']! as int) == 1,
      );
}

/// Seeds the three lists spec `10d` shows. Real values need a downloaded
/// filter list this app does not yet fetch (see this plan's Global
/// Constraints on "no network requests"); these are the spec's own numbers.
Future<void> seedFilterListsIfEmpty(
  AppDatabase database, {
  DateTime Function() now = DateTime.now,
}) async {
  final db = database.db;
  final existing = await db.query('filter_lists', limit: 1);
  if (existing.isNotEmpty) return;

  final updatedAt = now().toUtc().subtract(const Duration(days: 2)).millisecondsSinceEpoch;
  final rows = <Map<String, Object?>>[
    {'id': 'fl-trackers', 'name': 'Trackers and ads', 'rule_count': 84102, 'updated_at': updatedAt, 'enabled': 1},
    {'id': 'fl-cookies', 'name': 'Cookie notices', 'rule_count': 11430, 'updated_at': updatedAt, 'enabled': 1},
    {'id': 'fl-social', 'name': 'Social embeds', 'rule_count': 2908, 'updated_at': updatedAt, 'enabled': 0},
  ];
  for (final row in rows) {
    await db.insert('filter_lists', row);
  }
}
```

- [ ] **Step 5: Run the repository test to verify it passes**

Run: `flutter test test/data/filter_list_repository_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 6: Run Plan 1's and Plan 3's suites to confirm the migration didn't break anything**

Run: `flutter test`
Expected: PASS, everything green.

- [ ] **Step 7: Write the failing widget test**

Create `test/ui/features/filter_list_section_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/filter_list.dart';
import 'package:container/ui/features/scripts/views/filter_list_section.dart';

void main() {
  final now = DateTime.utc(2026, 8, 30, 9);
  final updatedTwoDaysAgo = now.subtract(const Duration(days: 2));

  final lists = [
    FilterList(id: 'fl-trackers', name: 'Trackers and ads', ruleCount: 84102, updatedAt: updatedTwoDaysAgo, enabled: true),
    FilterList(id: 'fl-cookies', name: 'Cookie notices', ruleCount: 11430, updatedAt: updatedTwoDaysAgo, enabled: true),
    FilterList(id: 'fl-social', name: 'Social embeds', ruleCount: 2908, updatedAt: updatedTwoDaysAgo, enabled: false),
  ];

  Widget host({ValueChanged<String>? onToggle, VoidCallback? onUpdateNow}) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: FilterListSection(
            lists: lists,
            now: now,
            nextUpdateInDays: 5,
            onToggle: onToggle ?? (_) {},
            onUpdateNow: onUpdateNow ?? () {},
          ),
        ),
      ),
    );
  }

  testWidgets('renders every list with the spec\'s exact rule counts', (tester) async {
    await tester.pumpWidget(host());

    expect(find.text('FILTER LISTS'), findsOneWidget);
    expect(find.text('Trackers and ads'), findsOneWidget);
    expect(find.text('84,102 rules · updated 2 days ago'), findsOneWidget);
    expect(find.text('Cookie notices'), findsOneWidget);
    expect(find.text('11,430 rules · updated 2 days ago'), findsOneWidget);
    expect(find.text('Social embeds'), findsOneWidget);
    expect(find.text('2,908 rules · off'), findsOneWidget);
    expect(find.text('Update over the proxy'), findsOneWidget);
    expect(find.text('Next check in 5 days'), findsOneWidget);
    expect(find.text('Update now'), findsOneWidget);
  });

  testWidgets('each toggle reports its own id, Update now reports a tap', (tester) async {
    final toggled = <String>[];
    var updates = 0;
    await tester.pumpWidget(host(onToggle: toggled.add, onUpdateNow: () => updates++));

    await tester.tap(find.text('Trackers and ads'));
    await tester.tap(find.text('Update now'));

    expect(toggled, ['fl-trackers']);
    expect(updates, 1);
  });
}
```

- [ ] **Step 8: Run it to verify it fails**

Run: `flutter test test/ui/features/filter_list_section_test.dart`
Expected: FAIL — missing file.

- [ ] **Step 9: Write `FilterListSection`**

Create `lib/ui/features/scripts/views/filter_list_section.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../domain/models/filter_list.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/app_toggle.dart';

/// Digit-group commas, hand-rolled — no `intl` dependency for one format.
String formatRuleCount(int n) {
  final digits = n.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i != 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

String updatedAgoLabel(DateTime now, DateTime updatedAt) {
  final days = now.difference(updatedAt).inDays;
  final unit = days == 1 ? 'day' : 'days';
  return 'updated $days $unit ago';
}

/// The `FILTER LISTS` half of spec `10d`. Each row's tap toggles the whole
/// row — there is no separate hit target for the switch, matching how the
/// dashboard treats a session row.
class FilterListSection extends StatelessWidget {
  const FilterListSection({
    super.key,
    required this.lists,
    required this.now,
    required this.nextUpdateInDays,
    required this.onToggle,
    required this.onUpdateNow,
  });

  final List<FilterList> lists;
  final DateTime now;
  final int nextUpdateInDays;
  final ValueChanged<String> onToggle;
  final VoidCallback onUpdateNow;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text('FILTER LISTS',
              style: ui(size: 10.5, weight: 600, letterSpacing: 1.05, color: C.textFaint)),
        ),
        for (final list in lists)
          GestureDetector(
            onTap: () => onToggle(list.id),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: C.line06)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(list.name, style: ui(size: 14, color: C.textPrimary)),
                      const SizedBox(height: 3),
                      Text(
                        list.enabled
                            ? '${formatRuleCount(list.ruleCount)} rules · ${updatedAgoLabel(now, list.updatedAt)}'
                            : '${formatRuleCount(list.ruleCount)} rules · off',
                        style: ui(size: 11.5, color: C.textFaint),
                      ),
                    ],
                  ),
                  AppToggle(value: list.enabled, onChanged: (_) => onToggle(list.id)),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Update over the proxy', style: ui(size: 13.5, color: C.textSecondary)),
                  const SizedBox(height: 4),
                  Text('Next check in $nextUpdateInDays days',
                      style: ui(size: 11.5, color: C.textFaint)),
                ],
              ),
              GestureDetector(
                onTap: onUpdateNow,
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: C.button,
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: Text('Update now', style: ui(size: 13, weight: 500, color: C.textSecondary)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 10: Run it to verify it passes**

Run: `flutter test test/ui/features/filter_list_section_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 11: Run the analyzer**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 12: Commit**

```bash
git add lib/data/services/app_database.dart lib/domain/models/filter_list.dart lib/domain/repositories/filter_list_repository.dart lib/data/repositories/filter_list_repository_sqlite.dart lib/ui/features/scripts/views/filter_list_section.dart test/data/filter_list_repository_test.dart test/ui/features/filter_list_section_test.dart
git commit -m "feat: add filter lists, seeded and toggleable (spec 10d)"
```

---

## Task 5: The script library (spec `10d`, scripts half)

**Files:**
- Modify: `lib/data/services/app_database.dart` (schema version 3 → 4)
- Create: `lib/domain/models/user_script.dart`
- Create: `lib/domain/repositories/script_repository.dart`
- Create: `lib/data/repositories/script_repository_sqlite.dart`
- Create: `lib/ui/features/scripts/views/scripts_and_filters_screen.dart`
- Test: `test/data/script_repository_test.dart`
- Test: `test/ui/features/scripts_and_filters_screen_test.dart`

**Interfaces:**
- Consumes: `AppDatabase` (extended by Task 4 to schema 3); `FilterListSection` (Task 4).
- Produces:
  - `enum ScriptKind { css, js }` with `String get badge` and `Color get badgeColor`
  - `class UserScript { const UserScript({required String id, required String name, required ScriptKind kind, required String code, required bool runAtDocumentStart, required bool enabled, required List<String> appliedSiteIds}); }`
  - `abstract interface class ScriptRepository { Future<List<UserScript>> all(); Future<UserScript?> byId(String id); Future<void> upsert(UserScript script); Future<void> delete(String id); }`
  - `class SqliteScriptRepository implements ScriptRepository { SqliteScriptRepository(AppDatabase database); }`
  - `String scriptSubtitle(UserScript script, {required Map<String, String> siteNamesById})`
  - `class ScriptsAndFiltersScreen extends StatelessWidget` — `const ScriptsAndFiltersScreen({required List<FilterList> filterLists, required DateTime now, required int nextUpdateInDays, required List<UserScript> scripts, required Map<String, String> siteNamesById, required ValueChanged<String> onToggleFilterList, required VoidCallback onUpdateFilterListsNow, required ValueChanged<String> onToggleScript, required void Function(String id) onOpenScript, required VoidCallback onNewScript, required VoidCallback onBack})`

`scriptSubtitle` only appends a "runs at ..." clause for `ScriptKind.js` — spec `10d`'s CSS rows never show one, only its one JS row does.

- [ ] **Step 1: Write the failing repository test**

Create `test/data/script_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:container/data/repositories/script_repository_sqlite.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/domain/models/user_script.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
  });

  tearDown(() => database.close());

  test('a script round-trips its fields and its site associations', () async {
    final repo = SqliteScriptRepository(database);

    await repo.upsert(const UserScript(
      id: 'sc-1',
      name: 'Hide sticky headers',
      kind: ScriptKind.css,
      code: 'header { position: static !important; }',
      runAtDocumentStart: true,
      enabled: true,
      appliedSiteIds: ['st-forum', 'st-reader'],
    ));

    final loaded = await repo.byId('sc-1');
    expect(loaded!.name, 'Hide sticky headers');
    expect(loaded.kind, ScriptKind.css);
    expect(loaded.code, 'header { position: static !important; }');
    expect(loaded.runAtDocumentStart, isTrue);
    expect(loaded.enabled, isTrue);
    expect(loaded.appliedSiteIds, unorderedEquals(['st-forum', 'st-reader']));
  });

  test('re-saving replaces the site associations rather than appending', () async {
    final repo = SqliteScriptRepository(database);
    await repo.upsert(const UserScript(
      id: 'sc-1', name: 'S', kind: ScriptKind.js, code: '', runAtDocumentStart: false,
      enabled: true, appliedSiteIds: ['a', 'b'],
    ));
    await repo.upsert(const UserScript(
      id: 'sc-1', name: 'S', kind: ScriptKind.js, code: '', runAtDocumentStart: false,
      enabled: true, appliedSiteIds: ['c'],
    ));

    final loaded = await repo.byId('sc-1');
    expect(loaded!.appliedSiteIds, ['c']);
  });

  test('all() lists every script, deleting removes it and its associations', () async {
    final repo = SqliteScriptRepository(database);
    await repo.upsert(const UserScript(
      id: 'sc-1', name: 'One', kind: ScriptKind.css, code: '', runAtDocumentStart: false,
      enabled: true, appliedSiteIds: ['a'],
    ));
    await repo.upsert(const UserScript(
      id: 'sc-2', name: 'Two', kind: ScriptKind.js, code: '', runAtDocumentStart: false,
      enabled: false, appliedSiteIds: [],
    ));

    expect((await repo.all()).map((s) => s.name), ['One', 'Two']);

    await repo.delete('sc-1');
    expect((await repo.all()).map((s) => s.id), ['sc-2']);
    expect(await repo.byId('sc-1'), isNull);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/data/script_repository_test.dart`
Expected: FAIL — missing files.

- [ ] **Step 3: Bump the schema and add the tables**

In `lib/data/services/app_database.dart`, change `static const schemaVersion = 3;` to `static const schemaVersion = 4;`, add both tables to `onCreate` (after `filter_lists`), and extend `onUpgrade`'s `if (from < 4)` branch:

```dart
          await db.execute('''
            CREATE TABLE scripts (
              id                   TEXT PRIMARY KEY,
              name                 TEXT    NOT NULL,
              kind                 TEXT    NOT NULL,
              code                 TEXT    NOT NULL DEFAULT '',
              run_at_document_start INTEGER NOT NULL DEFAULT 0,
              enabled              INTEGER NOT NULL DEFAULT 1
            )
          ''');
          await db.execute('''
            CREATE TABLE script_sites (
              script_id TEXT NOT NULL REFERENCES scripts(id) ON DELETE CASCADE,
              site_id   TEXT NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
              PRIMARY KEY (script_id, site_id)
            )
          ''');
```

```dart
          if (from < 4) {
            await db.execute('''
              CREATE TABLE scripts (
                id                   TEXT PRIMARY KEY,
                name                 TEXT    NOT NULL,
                kind                 TEXT    NOT NULL,
                code                 TEXT    NOT NULL DEFAULT '',
                run_at_document_start INTEGER NOT NULL DEFAULT 0,
                enabled              INTEGER NOT NULL DEFAULT 1
              )
            ''');
            await db.execute('''
              CREATE TABLE script_sites (
                script_id TEXT NOT NULL REFERENCES scripts(id) ON DELETE CASCADE,
                site_id   TEXT NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
                PRIMARY KEY (script_id, site_id)
              )
            ''');
          }
```

- [ ] **Step 4: Write `UserScript` and the repository**

Create `lib/domain/models/user_script.dart`:

```dart
import 'package:flutter/material.dart' show Color;

/// Spec `10d`'s badge colours: CSS reads `#9FD8C0` (the jade-code tone code
/// blocks use elsewhere), JS reads `#D6A45B` (warning).
enum ScriptKind {
  css('CSS'),
  js('JS');

  const ScriptKind(this.badge);
  final String badge;

  Color get badgeColor => switch (this) {
        ScriptKind.css => const Color(0xFF9FD8C0),
        ScriptKind.js => const Color(0xFFD6A45B),
      };
}

class UserScript {
  const UserScript({
    required this.id,
    required this.name,
    required this.kind,
    required this.code,
    required this.runAtDocumentStart,
    required this.enabled,
    required this.appliedSiteIds,
  });

  final String id;
  final String name;
  final ScriptKind kind;
  final String code;

  /// Feeds Plan 3's `Shields.apply` → `addDocumentStartJavaScript` seam.
  final bool runAtDocumentStart;
  final bool enabled;
  final List<String> appliedSiteIds;

  UserScript copyWith({
    String? name,
    ScriptKind? kind,
    String? code,
    bool? runAtDocumentStart,
    bool? enabled,
    List<String>? appliedSiteIds,
  }) {
    return UserScript(
      id: id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      code: code ?? this.code,
      runAtDocumentStart: runAtDocumentStart ?? this.runAtDocumentStart,
      enabled: enabled ?? this.enabled,
      appliedSiteIds: appliedSiteIds ?? this.appliedSiteIds,
    );
  }
}
```

Create `lib/domain/repositories/script_repository.dart`:

```dart
import '../models/user_script.dart';

abstract interface class ScriptRepository {
  Future<List<UserScript>> all();
  Future<UserScript?> byId(String id);
  Future<void> upsert(UserScript script);
  Future<void> delete(String id);
}
```

Create `lib/data/repositories/script_repository_sqlite.dart`:

```dart
import 'package:sqflite/sqflite.dart';

import '../../domain/models/user_script.dart';
import '../../domain/repositories/script_repository.dart';
import '../services/app_database.dart';

class SqliteScriptRepository implements ScriptRepository {
  SqliteScriptRepository(this._database);

  final AppDatabase _database;

  @override
  Future<List<UserScript>> all() async {
    final rows = await _database.db.query('scripts', orderBy: 'rowid');
    final scripts = <UserScript>[];
    for (final row in rows) {
      scripts.add(await _fromRow(row));
    }
    return scripts;
  }

  @override
  Future<UserScript?> byId(String id) async {
    final rows = await _database.db.query('scripts', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _fromRow(rows.single);
  }

  @override
  Future<void> upsert(UserScript script) async {
    await _database.db.transaction((txn) async {
      await txn.insert(
        'scripts',
        {
          'id': script.id,
          'name': script.name,
          'kind': script.kind.name,
          'code': script.code,
          'run_at_document_start': script.runAtDocumentStart ? 1 : 0,
          'enabled': script.enabled ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete('script_sites', where: 'script_id = ?', whereArgs: [script.id]);
      for (final siteId in script.appliedSiteIds) {
        await txn.insert('script_sites', {'script_id': script.id, 'site_id': siteId});
      }
    });
  }

  @override
  Future<void> delete(String id) async {
    await _database.db.delete('scripts', where: 'id = ?', whereArgs: [id]);
  }

  Future<UserScript> _fromRow(Map<String, Object?> row) async {
    final siteRows = await _database.db.query(
      'script_sites',
      columns: ['site_id'],
      where: 'script_id = ?',
      whereArgs: [row['id']],
    );
    return UserScript(
      id: row['id']! as String,
      name: row['name']! as String,
      kind: ScriptKind.values.byName(row['kind']! as String),
      code: row['code']! as String,
      runAtDocumentStart: (row['run_at_document_start']! as int) == 1,
      enabled: (row['enabled']! as int) == 1,
      appliedSiteIds: siteRows.map((r) => r['site_id']! as String).toList(),
    );
  }
}
```

- [ ] **Step 5: Run the repository test to verify it passes**

Run: `flutter test test/data/script_repository_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 6: Run the whole suite to confirm the migration chain still holds**

Run: `flutter test`
Expected: PASS, everything green.

- [ ] **Step 7: Write the failing widget test**

Create `test/ui/features/scripts_and_filters_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/filter_list.dart';
import 'package:container/domain/models/user_script.dart';
import 'package:container/ui/features/scripts/views/scripts_and_filters_screen.dart';

void main() {
  final now = DateTime.utc(2026, 8, 30, 9);

  final filterLists = [
    FilterList(id: 'fl-1', name: 'Trackers and ads', ruleCount: 84102,
        updatedAt: now.subtract(const Duration(days: 2)), enabled: true),
  ];

  final scripts = [
    const UserScript(id: 'sc-1', name: 'Hide sticky headers', kind: ScriptKind.css, code: '',
        runAtDocumentStart: true, enabled: true, appliedSiteIds: ['s1', 's2', 's3', 's4']),
    const UserScript(id: 'sc-2', name: 'Auto-expand comments', kind: ScriptKind.js, code: '',
        runAtDocumentStart: false, enabled: false, appliedSiteIds: ['s1']),
  ];

  Widget host({
    ValueChanged<String>? onToggleScript,
    void Function(String id)? onOpenScript,
    VoidCallback? onNewScript,
  }) {
    return MaterialApp(
      home: ScriptsAndFiltersScreen(
        filterLists: filterLists,
        now: now,
        nextUpdateInDays: 5,
        scripts: scripts,
        siteNamesById: const {},
        onToggleFilterList: (_) {},
        onUpdateFilterListsNow: () {},
        onToggleScript: onToggleScript ?? (_) {},
        onOpenScript: onOpenScript ?? (_) {},
        onNewScript: onNewScript ?? () {},
        onBack: () {},
      ),
    );
  }

  testWidgets('renders filter lists and scripts together, verbatim', (tester) async {
    await tester.pumpWidget(host());

    expect(find.text('Scripts and filters'), findsOneWidget);
    expect(find.text('Trackers and ads'), findsOneWidget);
    expect(find.text('MY SCRIPTS'), findsOneWidget);
    expect(find.text('CSS'), findsOneWidget);
    expect(find.text('Hide sticky headers'), findsOneWidget);
    expect(find.text('Applied to 4 sites'), findsOneWidget);
    expect(find.text('JS'), findsOneWidget);
    expect(find.text('Auto-expand comments'), findsOneWidget);
    expect(find.text('Applied to 1 site · runs at load'), findsOneWidget);
    expect(find.text('New script'), findsOneWidget);
  });

  testWidgets('tapping a script row opens it, New script is separate', (tester) async {
    final opened = <String>[];
    var newTaps = 0;
    await tester.pumpWidget(host(onOpenScript: opened.add, onNewScript: () => newTaps++));

    await tester.tap(find.text('Hide sticky headers'));
    await tester.tap(find.text('New script'));

    expect(opened, ['sc-1']);
    expect(newTaps, 1);
  });
}
```

- [ ] **Step 8: Run it to verify it fails**

Run: `flutter test test/ui/features/scripts_and_filters_screen_test.dart`
Expected: FAIL — missing file.

- [ ] **Step 9: Write `scriptSubtitle` and `ScriptsAndFiltersScreen`**

Create `lib/ui/features/scripts/views/scripts_and_filters_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../domain/models/filter_list.dart';
import '../../../../domain/models/user_script.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/app_toggle.dart';
import 'filter_list_section.dart';

/// The `MY SCRIPTS` row subtitle. Only `ScriptKind.js` rows in spec `10d`
/// show a "runs at ..." clause; the CSS rows never do.
String scriptSubtitle(UserScript script, {required Map<String, String> siteNamesById}) {
  final count = script.appliedSiteIds.length;
  final siteWord = count == 1 ? 'site' : 'sites';
  final base = 'Applied to $count $siteWord';
  if (script.kind != ScriptKind.js) return base;
  return script.runAtDocumentStart ? '$base · runs at start' : '$base · runs at load';
}

/// Spec `10d` — one library, reused across sites.
class ScriptsAndFiltersScreen extends StatelessWidget {
  const ScriptsAndFiltersScreen({
    super.key,
    required this.filterLists,
    required this.now,
    required this.nextUpdateInDays,
    required this.scripts,
    required this.siteNamesById,
    required this.onToggleFilterList,
    required this.onUpdateFilterListsNow,
    required this.onToggleScript,
    required this.onOpenScript,
    required this.onNewScript,
    required this.onBack,
  });

  final List<FilterList> filterLists;
  final DateTime now;
  final int nextUpdateInDays;
  final List<UserScript> scripts;
  final Map<String, String> siteNamesById;
  final ValueChanged<String> onToggleFilterList;
  final VoidCallback onUpdateFilterListsNow;
  final ValueChanged<String> onToggleScript;
  final void Function(String id) onOpenScript;
  final VoidCallback onNewScript;
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
                  Text('Scripts and filters', style: T.screenTitle),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  FilterListSection(
                    lists: filterLists,
                    now: now,
                    nextUpdateInDays: nextUpdateInDays,
                    onToggle: onToggleFilterList,
                    onUpdateNow: onUpdateFilterListsNow,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 24, 0, 4),
                    child: Text('MY SCRIPTS',
                        style: ui(size: 10.5, weight: 600, letterSpacing: 1.05, color: C.textFaint)),
                  ),
                  for (final script in scripts)
                    GestureDetector(
                      onTap: () => onOpenScript(script.id),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: C.line06)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: C.raised,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text(script.kind.badge,
                                  style: ui(size: 12, color: script.kind.badgeColor)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(script.name, style: ui(size: 14, color: C.textPrimary)),
                                  const SizedBox(height: 3),
                                  Text(
                                    scriptSubtitle(script, siteNamesById: siteNamesById),
                                    style: ui(size: 11.5, color: C.textFaint),
                                  ),
                                ],
                              ),
                            ),
                            AppToggle(
                              value: script.enabled,
                              onChanged: (_) => onToggleScript(script.id),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: GestureDetector(
                      onTap: onNewScript,
                      child: Row(
                        children: [
                          Text('+', style: ui(size: 17, weight: 300, color: C.jade)),
                          const SizedBox(width: 11),
                          Text('New script', style: ui(size: 14.5, weight: 500, color: C.jade)),
                        ],
                      ),
                    ),
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
```

- [ ] **Step 10: Run it to verify it passes**

Run: `flutter test test/ui/features/scripts_and_filters_screen_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 11: Run the analyzer**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 12: Commit**

```bash
git add lib/data/services/app_database.dart lib/domain/models/user_script.dart lib/domain/repositories/script_repository.dart lib/data/repositories/script_repository_sqlite.dart lib/ui/features/scripts/views/scripts_and_filters_screen.dart test/data/script_repository_test.dart test/ui/features/scripts_and_filters_screen_test.dart
git commit -m "feat: add the script library, backed by SQLite (spec 10d)"
```

---

## Task 6: Script editor (spec `10e`)

**Files:**
- Create: `lib/ui/features/scripts/views/script_editor_screen.dart`
- Test: `test/ui/features/script_editor_screen_test.dart`

**Interfaces:**
- Consumes: `ScriptKind`, `UserScript` (Task 5); `C`, `ui`, `mono` (Plan 1 Task 1); `AppToggle` (Plan 2 Task 6).
- Produces:
  - `class ScriptSiteChip { const ScriptSiteChip({required String id, required String name}); }`
  - `class ScriptEditorResult { const ScriptEditorResult({required ScriptKind kind, required String code, required bool runAtDocumentStart}); }`
  - `class ScriptEditorScreen extends StatefulWidget` — `const ScriptEditorScreen({required String title, required ScriptKind initialKind, required String initialCode, required bool initialRunAtDocumentStart, required List<ScriptSiteChip> appliedSites, required ValueChanged<ScriptEditorResult> onSave, required void Function(String siteId) onRemoveSite, required VoidCallback onAddSite, required VoidCallback onClose})`

The header shows the script's name as a static title, not an editable field — spec `10e` draws no rename control, so renaming a script is out of this screen's scope (see Known gaps). Site removal and site addition are reported through callbacks rather than mutated locally, because `appliedSites` is the one piece of state this screen does not own — the caller's `ScriptRepository` does.

- [ ] **Step 1: Write the failing test**

Create `test/ui/features/script_editor_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/user_script.dart';
import 'package:container/ui/features/scripts/views/script_editor_screen.dart';

void main() {
  const appliedSites = [
    ScriptSiteChip(id: 's1', name: 'Forum'),
    ScriptSiteChip(id: 's2', name: 'Reader'),
  ];

  Widget host({
    ValueChanged<ScriptEditorResult>? onSave,
    void Function(String siteId)? onRemoveSite,
    VoidCallback? onAddSite,
    VoidCallback? onClose,
    String initialCode = '',
    bool initialRunAtDocumentStart = true,
  }) {
    return MaterialApp(
      home: ScriptEditorScreen(
        title: 'Hide sticky headers',
        initialKind: ScriptKind.css,
        initialCode: initialCode,
        initialRunAtDocumentStart: initialRunAtDocumentStart,
        appliedSites: appliedSites,
        onSave: onSave ?? (_) {},
        onRemoveSite: onRemoveSite ?? (_) {},
        onAddSite: onAddSite ?? () {},
        onClose: onClose ?? () {},
      ),
    );
  }

  testWidgets('renders the spec copy and the applied sites verbatim', (tester) async {
    await tester.pumpWidget(host());

    expect(find.text('Hide sticky headers'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('CSS'), findsOneWidget);
    expect(find.text('JavaScript'), findsOneWidget);
    expect(find.text('RUNS ON'), findsOneWidget);
    expect(find.text('Forum ×'), findsOneWidget);
    expect(find.text('Reader ×'), findsOneWidget);
    expect(find.text('+ Add site'), findsOneWidget);
    expect(find.text('Run before the page paints'), findsOneWidget);
    expect(find.text('Prevents a flash of the hidden elements'), findsOneWidget);
  });

  testWidgets('the line gutter tracks the code as it is typed', (tester) async {
    await tester.pumpWidget(host());
    expect(find.text('1'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'a\nb\nc');
    await tester.pump();

    expect(find.text('1\n2\n3'), findsOneWidget);
  });

  testWidgets('Save reports the kind, code and toggle as they stand', (tester) async {
    ScriptEditorResult? result;
    await tester.pumpWidget(host(onSave: (r) => result = r, initialRunAtDocumentStart: false));

    await tester.enterText(find.byType(TextField), 'body { color: red; }');
    await tester.tap(find.text('JavaScript'));
    await tester.tap(find.text('Run before the page paints'));
    await tester.tap(find.text('Save'));

    expect(result!.kind, ScriptKind.js);
    expect(result!.code, 'body { color: red; }');
    expect(result!.runAtDocumentStart, isTrue);
  });

  testWidgets('a site chip\'s × reports its own id, Add site is separate', (tester) async {
    final removed = <String>[];
    var adds = 0;
    await tester.pumpWidget(host(onRemoveSite: removed.add, onAddSite: () => adds++));

    await tester.tap(find.text('Reader ×'));
    await tester.tap(find.text('+ Add site'));

    expect(removed, ['s2']);
    expect(adds, 1);
  });

  testWidgets('the × closes without saving', (tester) async {
    var saves = 0;
    var closes = 0;
    await tester.pumpWidget(host(onSave: (_) => saves++, onClose: () => closes++));

    await tester.tap(find.text('‹'));

    expect(closes, 1);
    expect(saves, 0);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/ui/features/script_editor_screen_test.dart`
Expected: FAIL — missing file.

- [ ] **Step 3: Write `ScriptEditorScreen`**

Create `lib/ui/features/scripts/views/script_editor_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../domain/models/user_script.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/app_toggle.dart';

class ScriptSiteChip {
  const ScriptSiteChip({required this.id, required this.name});
  final String id;
  final String name;
}

class ScriptEditorResult {
  const ScriptEditorResult({
    required this.kind,
    required this.code,
    required this.runAtDocumentStart,
  });

  final ScriptKind kind;
  final String code;
  final bool runAtDocumentStart;
}

/// Spec `10e` — code, then where it runs. Renaming a script is not built
/// here: the header shows [title] as static text, matching what the spec
/// draws (no rename control).
class ScriptEditorScreen extends StatefulWidget {
  const ScriptEditorScreen({
    super.key,
    required this.title,
    required this.initialKind,
    required this.initialCode,
    required this.initialRunAtDocumentStart,
    required this.appliedSites,
    required this.onSave,
    required this.onRemoveSite,
    required this.onAddSite,
    required this.onClose,
  });

  final String title;
  final ScriptKind initialKind;
  final String initialCode;
  final bool initialRunAtDocumentStart;
  final List<ScriptSiteChip> appliedSites;
  final ValueChanged<ScriptEditorResult> onSave;
  final void Function(String siteId) onRemoveSite;
  final VoidCallback onAddSite;
  final VoidCallback onClose;

  @override
  State<ScriptEditorScreen> createState() => _ScriptEditorScreenState();
}

class _ScriptEditorScreenState extends State<ScriptEditorScreen> {
  late final _codeController = TextEditingController(text: widget.initialCode);
  late ScriptKind _kind = widget.initialKind;
  late bool _runAtDocumentStart = widget.initialRunAtDocumentStart;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _save() {
    widget.onSave(ScriptEditorResult(
      kind: _kind,
      code: _codeController.text,
      runAtDocumentStart: _runAtDocumentStart,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: C.line06)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: widget.onClose,
                    child: const Text('‹', style: TextStyle(fontSize: 16, color: C.icon)),
                  ),
                  Text(widget.title, style: ui(size: 15, weight: 600)),
                  GestureDetector(
                    onTap: _save,
                    child: Text('Save', style: ui(size: 14, weight: 500, color: C.jade)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Row(
                    children: [
                      Expanded(child: _kindTab(ScriptKind.css, 'CSS')),
                      const SizedBox(width: 8),
                      Expanded(child: _kindTab(ScriptKind.js, 'JavaScript')),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _CodeEditor(controller: _codeController),
                  const SizedBox(height: 20),
                  Text('RUNS ON',
                      style: ui(size: 10.5, weight: 600, letterSpacing: 1.05, color: C.textFaint)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final site in widget.appliedSites)
                        GestureDetector(
                          onTap: () => widget.onRemoveSite(site.id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: C.button,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('${site.name} ×',
                                style: ui(size: 12.5, color: C.textSecondary)),
                          ),
                        ),
                      GestureDetector(
                        onTap: widget.onAddSite,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: Text('+ Add site', style: ui(size: 12.5, color: C.jade)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.only(top: 14),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: C.line06)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Run before the page paints',
                                  style: ui(size: 14, color: C.textPrimary)),
                              const SizedBox(height: 3),
                              Text('Prevents a flash of the hidden elements',
                                  style: ui(size: 11.5, color: C.textFaint)),
                            ],
                          ),
                        ),
                        AppToggle(
                          value: _runAtDocumentStart,
                          onChanged: (v) => setState(() => _runAtDocumentStart = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kindTab(ScriptKind kind, String label) {
    final selected = _kind == kind;
    return GestureDetector(
      onTap: () => setState(() => _kind = kind),
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? C.selected : null,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: selected ? C.line10 : C.line07),
        ),
        child: Text(label, style: ui(size: 13, color: selected ? C.textPrimary : C.tabInactive)),
      ),
    );
  }
}

/// A monospace textarea with a line-number gutter that scrolls with it. The
/// gutter and the field share one outer scroll view, and the field's own
/// scrolling is disabled — two independently-scrolling columns would drift
/// out of sync the moment either one moved.
class _CodeEditor extends StatelessWidget {
  const _CodeEditor({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.line09),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    final lineCount = '\n'.allMatches(value.text).length + 1;
                    return Text(
                      List.generate(lineCount, (i) => '${i + 1}').join('\n'),
                      textAlign: TextAlign.right,
                      style: mono(size: 11.5, height: 1.9, color: C.textDisabled),
                    );
                  },
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 12, 12),
                  child: TextField(
                    controller: controller,
                    maxLines: null,
                    scrollPhysics: const NeverScrollableScrollPhysics(),
                    style: mono(size: 11.5, height: 1.9, color: C.jadeCode),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run it to verify it passes**

Run: `flutter test test/ui/features/script_editor_screen_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Run the whole suite and the analyzer**

Run: `flutter test && flutter analyze`
Expected: all passing, `No issues found!`

- [ ] **Step 6: Verify on a device against the spec**

Run: `flutter run --debug`

- `Workspaces` (reachable from Settings' new `MANAGE` section) lists Personal / Work / Ephemeral with the seeded stats.
- Tapping `New workspace` opens the create form; picking a marker moves the white ring; picking `Wipe when the app closes` moves the jade ring.
- From a workspace row's context, deleting shows the itemised sheet and the `Delete` button stays inert until the name is typed exactly.
- `Scripts and filters` shows the three seeded filter lists (two on, one off) and the seed's own scripts once seeded there; toggling a filter list or a script persists across an app restart.
- Opening a script shows its code with a correct line gutter, and its applied-site chips.

- [ ] **Step 7: Commit**

```bash
git add lib/ui/features/scripts/views/script_editor_screen.dart test/ui/features/script_editor_screen_test.dart
git commit -m "feat: add the script editor (spec 10e)"
```

---

## Known gaps this plan deliberately leaves

- **`WorkspaceStorageService` has no real implementation.** `FakeWorkspaceStorageService` is what every test uses; a real one needs a platform call that sums a workspace's sites' WebView profile directories, which depends on Plan 3's `ProfileManager` and is not built here. Every "N MB" shown by this plan's screens is fed by whatever the caller supplies — wiring a real byte count is a follow-up.
- **"Update over the proxy" does not fetch anything.** `onUpdateFilterListsNow` and the seeded `updatedAt`/rule counts are display-only. Spec `10d` implies a network fetch this app's own "no network requests of its own" constraint does not currently permit; resolving that tension — an explicit, scoped exception for filter-list updates, or a decision that updates ship with the app instead — is a product call this plan does not make.
- **`FilterList.enabled` is not read by Plan 3's `FilterEngine`.** Toggling a list in this plan's UI persists the bit in SQLite; nothing wires that bit into the native matcher, which (per Plan 3's own Known Gaps) only understands `||host^` rules from one bundled file and has no concept of named, toggleable lists yet. A real multi-list matcher is unbuilt.
- **`UserScript.code`/`runAtDocumentStart` are not injected into any WebView.** They persist correctly. Plan 3's `Shields.apply` names `addDocumentStartJavaScript` as the seam; connecting this plan's scripts to it — and adding the equivalent path for CSS, which needs a different injection point than JS does — is unbuilt.
- **Renaming a script is not supported.** Spec `10e` draws no rename control; `ScriptEditorScreen`'s title is static. If a future design draws one, it is a new field on this screen, not a change to any type this plan defines.
- **The site picker behind "+ Add site" (`10e`) is a callback, not a screen.** No site-search or multi-select UI is built here; `onAddSite` is a seam for whoever builds that picker.
- **A workspace row's tap target in `10a` is not wired to anything concrete.** `WorkspacesScreen.onOpen` fires with an id; whether that opens `WorkspaceFormScreen` in edit mode, a distinct detail screen, or something else is caller-level routing this plan does not decide, because no such destination is drawn in the spec beyond the create form.

## Handoff

- **From Plan 1:** `WorkspaceRepository.delete` is unchanged and is what Task 3 calls; deletion cascades to sites through the `ON DELETE CASCADE` Plan 1 already put on `sites.workspace_id`. No new repository method was needed.
- **From Plan 2:** Task 1 adds two rows to Plan 2's `SettingsScreen` under a new `MANAGE` section. If Plan 2's settings layout changes, check that section survives.
- **From Plan 3:** the schema-version sequence continues from Plan 3's `2` — this plan's Task 4 bumps to `3`, Task 5 to `4`. Any future plan touching `AppDatabase` starts its own migration at `5`.
- **To Plan 3 (or whoever wires live filtering/scripting):** `FilterListRepository.all()`/`setEnabled` and `ScriptRepository.all()` are the contracts a real `FilterEngine` and a real `Shields.apply` extension need to read from. `UserScript.runAtDocumentStart` is named to match Plan 3's `addDocumentStartJavaScript` directly.
- **This closes Plan 1's roadmap.** Plans 1 through 5 now cover every screen in the spec's 32-screen set except the platform-dependent gaps named above and in each plan's own "Known gaps" — those are follow-up work, not missing plan coverage.
