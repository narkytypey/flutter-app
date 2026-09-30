export const meta = {
  name: 'plan-12-browser-chrome',
  description: 'Write the implementation plan for the approved browser-chrome spec (1 agent)',
  phases: [{ title: 'Plan', detail: 'writing-plans against current main' }],
}

phase('Plan')
const result = await agent(`You are writing the implementation plan for an approved design spec in this Flutter + Kotlin Android repo (C:\\Users\\Metin\\Desktop\\flutter-app, branch main @ b95b6e0, clean tree).

FIRST invoke the Skill tool with skill "superpowers:writing-plans" and follow it exactly. Do not execute the plan — only write it.

SPEC: docs/superpowers/specs/2026-09-28-browser-chrome-design.md ("Browser chrome and navigation", project 1 of 4; supersedes canvas screen 2b). Read it in full. Read CLAUDE.md's plan table and at least one recent plan (docs/superpowers/plans/2026-09-28-filter-lists-and-scripts.md) to match the house format, including the "Known gaps" and "Handoff" sections every plan ends with.

OUTPUT FILE: docs/superpowers/plans/2026-09-29-browser-chrome.md — this is "Plan 12". Do NOT commit it and do not touch any other file; the orchestrator reviews and commits it.

FACTS ALREADY ESTABLISHED (do not re-investigate, just use):
- Spec §1's prerequisite (commit 6a5f013, the nested _OpenVault navigator in AppGate) IS merged into main.
- Spec §10's coordination note is resolved: the peer work (Plan 11, filter lists and scripts) is merged into main. Write against the tree as it is now.
- Spec §4.2 verification: Mullvad Leta was shut down on 2025-11-27 (https://mullvad.net/en/blog/2025/11/6/shutting-down-our-search-proxy-leta; leta.mullvad.net now says it has been shut down). Per the spec's own rule ("Any engine that no longer works is dropped from the enum rather than shipped broken") the enum is { duckDuckGo, startpage, braveSearch } and the picker lists three names. Record this as a deliberate deviation in the plan header. Brave Search's template answered HTTP 200 from this machine. Startpage's GET template https://www.startpage.com/sp/search?query= could not be reached from this machine (network restriction, not evidence it is wrong); keep it and add an on-emulator check of it to the device-verification step.
- Only one agent will execute this plan, inline, with superpowers:executing-plans, in a git worktree on branch plan-12-browser-chrome. Order tasks so that EVERY task ends with a green tree: flutter analyze clean, flutter test all passing, and — for any task touching Kotlin — the Kotlin JVM unit tests passing and flutter build apk --debug succeeding with zero "e:" lines. flutter analyze/test never compile android/…/engine/, so Kotlin tasks MUST include the APK build. Find the repo's actual Kotlin test command (read how earlier plans ran it) and tell the executor to read counts from the JUnit XML, not from BUILD SUCCESSFUL. One commit per task, conventional "feat:/fix:/test:/docs:" style matching git log.
- Aim for roughly 10–14 tasks. Suggested grouping (adjust if the code says otherwise): pure-Dart domain (parseAddressInput, SearchEngine, resolveDestination, suggestionsFor, throwaway Site builder); SettingsRepository getString/setString + search-engine setting and picker in 2d; AppIcon CustomPainter set; Kotlin navigation/find events + goBack/goForward/stop/loadUrl(scheme refusal)/find/findNext/clearFind/navigationState; Kotlin throwaway journal + open(throwaway) + keep + sweep-on-start + wipeAll clearing it; Dart ContainerEngine/ChannelContainerEngine/FakeContainerEngine + NavigationState/FindResult models + the shared subscribe-then-snapshot helper extracted from sessionForSiteProvider; layout C top bar/load line/bottom bar + PopScope; address editing + AddressSuggestions + destination routing (ThisContainer loadUrl / push ContainerRoute with initialUrl / throwaway); throwawaySitesProvider cleared on leaving SessionOpen + save bar + save flow (upsert then keep, skip keep if wipe-on-exit chosen); BrowserMenuSheet; FindBar; final verification + CLAUDE.md/plan docs task.

HARD CONSTRAINTS the plan must respect (all come from CLAUDE.md and recent fixes; cite them where relevant):
- Copy: only strings in spec §7 or the canvas file ("Sandbox Container -canvas-.dc.html"). Never invent, paraphrase or re-capitalise user-facing text. If a step genuinely needs a string that exists in neither, do NOT invent it: list it in a "Design questions" section near the top of the plan and design the step so it does not need it.
- Jade #7FC8A9 (C.jade) only for live state or the single affirmative action — the load line is C.textMuted, the cursor C.textPrimary, the save bar neutral.
- No network requests of the app's own; suggestions are vault-local only.
- Two-vault model: nothing asks which vault is open; throwaways cleared on every transition out of SessionOpen.
- The interceptor never falls back to direct; a throwaway inherits the current container's route exactly (mode, host, port).
- loadUrl refuses every scheme except http/https on the Kotlin side too.
- Every ContainerRoute push must land on the nested _OpenVault navigator: never rootNavigator, never useRootNavigator: true on a sheet or dialog (see CLAUDE.md Device verification, 6a5f013).
- ContainerRoute must not build the page view off a session it did not open itself (_openReturned, commit 5b53462); a pushed saved-site container and a throwaway must keep that property.
- ProfileManager.wipe journals in-use profiles (PendingDeletions.kt) instead of deleting them; the throwaway journal must interoperate with that, not replace it. Don't "simplify" wipe back to a bare deleteProfile.
- androidx.webkit ProfileStore calls are UI-thread-only; proxy probing must not run on the main thread (a42896d).
- ContainerView.dispose's wipeOnExit path is how a popped throwaway is wiped; verify it actually runs for a pushed-then-popped route.
- Existing tests must keep passing; where a test pins removed 2b chrome (the ◑ ≡ ⋯ buttons, top-bar ‹ and ⟳), the plan says exactly which test changes and why.

QUALITY BAR: every step has exact file paths and complete code (no "similar to above", no TODO placeholders, no prose-only steps); tests written first; each code block consistent with the real APIs in the tree — read the actual files (ContainerRoute, ContainerScreen, ContainerTopBar, ContainerToolbar, SwitcherSheet, container providers, ContainerEngine/ChannelContainerEngine/FakeContainerEngine, SiteSheet, SettingsScreen/SettingsRepository/app_settings, AppGate/_OpenVault, session_controller, search_results, AddSiteScreen, EngineChannel.kt, ContainerView.kt, ContainerViewFactory.kt, RequestInterceptor.kt, Shields.kt, ProfileManager.kt, PendingDeletions.kt, MainActivity.kt, tokens.dart, typography.dart, the Sheet/PillButton widgets) before writing code that calls them. After writing, self-review the whole plan once against the spec section by section and fix gaps.

The plan's final task must end with: the four gate commands with counts, and a list of on-emulator checks (spec §8 Device, plus the Startpage check) marked as to be done by the orchestrator, not the executor.`, {
  label: 'write Plan 12',
  phase: 'Plan',
  schema: {
    type: 'object',
    properties: {
      planPath: { type: 'string' },
      taskCount: { type: 'number' },
      tasks: { type: 'array', items: { type: 'string' }, description: 'one line per task: number, title, files touched' },
      designQuestions: { type: 'array', items: { type: 'string' }, description: 'strings or behaviours the spec leaves undecided that the plan refused to invent' },
      deviationsFromSpec: { type: 'array', items: { type: 'string' } },
      risks: { type: 'array', items: { type: 'string' }, description: 'places where the tree fights the spec, or steps the executor is most likely to get wrong' },
      kotlinTestCommand: { type: 'string' },
    },
    required: ['planPath', 'taskCount', 'tasks', 'designQuestions', 'deviationsFromSpec', 'risks', 'kotlinTestCommand'],
  },
})
return result
