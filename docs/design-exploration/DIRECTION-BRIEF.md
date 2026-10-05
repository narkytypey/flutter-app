# Brief for building one design direction (phase 3)

Written by fire-cd6e6b for the subagents that build the three directions, and
for any later fire that has to finish one. Read this whole file first.

## Context to read (in this order, skim the long ones)

1. `CLAUDE.md` — only the top paragraph and "Global constraints".
2. `docs/design-exploration/RESEARCH.md` — especially **"What this means for
   Container"** (15 implications). Your direction is judged against them.
3. `docs/design-exploration/AUDIT.md` — the current design measured.
4. `docs/design-exploration/inventory/screens-1-5.md` and `screens-6-10.md` —
   the current structure and **every user-facing string, verbatim**, per
   screen block. This is your copy source.
5. `docs/design-exploration/DECISIONS.md` — D2 (mock the app as built) and D3
   (the three axes).

## Frozen — never change

- **Copy.** Every string is verbatim from the inventory (which is the code's
  copy, itself transcribed from the canvas file and approved specs). You may
  change how copy is *set* — size, weight, colour, and letter case through
  CSS `text-transform` only: the HTML text node is exactly the inventory's
  string, never retyped. (So an uppercase stored string such as a section
  label can be *shown* in small caps via `font-variant`, but its text node
  stays uppercase.) Never invent a
  string. If a screen seems to need one, write the question into your
  `BRIEF.md` under "Copy questions" and use the nearest existing string.
- **Structure and flow.** Same screens, same elements in the same order, same
  journeys. You may restyle a screen beyond recognition (bars, cards, grouping,
  placement within the screen) but not remove, add or reorder its elements'
  meaning. No new screens, toggles or settings.
- **Privacy model.** Nothing may depend on which vault (real or decoy) is
  open: no per-vault colour, theme or mark; Settings look identical in both.
  No leak count anywhere, under any name. The blocked-request tally (Today
  `5c`, `6c`) stays and must not become a score or grade.
- **Danger is never a full-screen fill** (Tor removed a red screen that
  frightened people; RESEARCH §3). Danger as text, outline or a small tinted
  panel.

## Deliverables (all in `docs/design-exploration/direction-<x>-<name>/`)

Write them in this order, saving each file as soon as it is done (a session
can be cut off at any time; whole files survive, half-written thoughts do
not). **Do not run git** — the orchestrator commits. Exception: after
finishing each numbered step below, run
`bash /home/user/flutter-app/docs/design-exploration/tools/push.sh "docs(restyle): direction <x> <what>"`
(it is lock-serialised and safe to call in parallel).

1. **`BRIEF.md`** — the thesis in one paragraph; who it is for (name the
   reader concretely); 3–5 named references from RESEARCH.md and exactly what
   is taken from each; what it deliberately sacrifices; what the logo means;
   how it handles the global constraints it touches (dark-only, jade rule)
   with an explicit argument if it breaks one; light-mode / WebView note (the
   Android theme must stay dark — `values/styles.xml`, guarded by
   `test/android_theme_test.dart` — because WebView only force-darkens under a
   dark theme; a light Flutter UI is possible without touching it but pages
   will still be told `prefers-color-scheme: dark`; say how the direction
   lives with that); "Copy questions" (may be empty).
2. **`TOKENS.md` + `tokens.css`** — the complete system:
   - Named colour roles (not swatches), each with hex, purpose, and its
     **measured** contrast against every surface it sits on. Measure with
     `python3 docs/design-exploration/tools/contrast.py FG BG` or
     `--table pairs.txt` (format `label|#fg|#bg|min`); keep your pairs file as
     `contrast-pairs.txt` in your folder and paste the table into TOKENS.md.
     Every text pairing ≥ 4.5:1 (all app text is small); every meaningful
     non-text mark (switch track and knob, PIN dots, live/idle indicators,
     input borders, focus) ≥ 3:1 against what it sits on. State ratios; do
     not assert passes. If the direction has light and dark, measure both.
   - Type: name the typefaces concretely, licence (must be OFL/Apache — the
     app bundles fonts and never fetches one at runtime), bundled size
     estimate (sizes measured in RESEARCH §4: Figtree 61 KB, Atkinson
     Hyperlegible Next 112 KB, IBM Plex Sans 525 KB variable / ~3 static
     weights, Plex Mono Regular+Medium 272 KB already bundled, Geist 165 KB,
     Geist Mono 168 KB, JetBrains Mono 183 KB, Inter 857 KB). A full scale:
     role, family, size (sp), weight, line height, letter-spacing. **Map every
     role onto the existing `T.*` names** in `lib/ui/core/typography.dart`
     (screenTitle, sheetTitle, stepTitle, appBarTitle, rowTitle, rowTitleIdle,
     body, bodyMuted, meta, metaIdle, sectionLabel, sectionLabelLive,
     barSummary, barBadge, code) and say which new roles you add.
   - Colour roles mapped onto existing `C.*` names where they correspond
     (see AUDIT §1.1), saying which are retired / renamed / added.
   - Spacing scale, corner radii scale, border treatment, elevation, motion
     (durations, easings / springs, and the one or two moments that move).
   - Touch targets: 48 dp minimum for every tappable thing.
   - `tokens.css`: the same values as CSS custom properties (both themes if
     two), used by your `screens.html`.
3. **Logo set** — hand-authored SVG only (no raster, no generators, no
   external refs, no text elements that rely on an installed font for the
   *mark*; a wordmark may use a font if it is also outlined or if you note the
   font):
   - `logo.svg` — primary mark. Must survive 24 px: verify by rendering it at
     24, 48 and 128 px with `tools/shot.mjs` and looking at the PNG with the
     Read tool.
   - `logo-wordmark.svg` — mark + the word "Container".
   - `logo-monochrome.svg` — single colour (works as Android 13 themed icon).
   - `app-icon.svg` — Android adaptive launcher icon: `viewBox="0 0 108 108"`,
     full-bleed background layer, foreground mark inside the central 72×72
     safe zone (and ideally within the 66 dp circle that survives every mask).
   Say in BRIEF what the mark means.
4. **`screens.html`** — one self-contained file, inline CSS (it may
   `<link>` your `tokens.css` sibling, and a Google Fonts stylesheet for the
   typefaces — that is the only external request allowed). Each block is a
   phone frame **390×844**, labelled with its spec id and canvas title, laid
   out in a wrapping grid so several are visible at once. Mark each block with
   `<section data-block="1b">` and the frame with `class="phone"` (the
   overflow checker relies on both).
   - The page must honour two URL params via a tiny inline script:
     `?w=320` sets every phone's width (height 568 when w=320), and
     `?scale=1.3` multiplies every font size (use `calc(var(--fs) * Npx)` or
     `rem` with `html{font-size:calc(16px*var(--scale))}` — your choice, but
     every text size must scale and nothing else should). Also add a small
     fixed toolbar with links for 390/320 × 1.0/1.3/2.0.
   - **Mandatory blocks, in this order:** `1b` dashboard · `2b` container
     chrome · `2a` add site · `2c` tabs · `2d` settings · `3a` lock screen ·
     `4a` setup PIN · `5c` today · `6c` shield panel · `8b` proxy refused.
   - Then, as budget allows, in this order: `9b` `9c` `6b` `6a` `7c` `10a`
     `10b` `10d` `10e` `3c` `5a` `5b` `8a` `8c` `7b` `4b` `4c` `1a` `1c` `3b`.
     (`1a`/`1c` were never built as app screens; mock them from the canvas
     file `Sandbox Container -canvas-.dc.html` and say so in the block label.)
   - Write the file after **each** block (append, don't hold it all in
     memory), and push after the mandatory ten and after every five more.
   - Copy verbatim from the inventory. Use the canvas's sample data (sites
     like Forum / Notes / Webmail / Bank, hosts, counts) as the inventory
     lists them. Pages behind chrome are placeholder blocks (no real sites'
     logos, no imitation of real brands).
   - Icons: draw them as inline SVG line icons consistent with your
     direction (the app draws its own `AppIcon`s; no icon fonts, no emoji).
5. **Accessibility pass** — run
   `node docs/design-exploration/tools/shot.mjs <your>/screens.html /tmp/x.png "w=320&scale=1.0"`
   and the same with `w=390&scale=1.3`, `w=390&scale=2.0`, `w=320&scale=1.3`.
   It prints every element spilling out of a phone frame or clipped. Fix
   what it reports until each run says `no overflow` (text may wrap, rows
   may grow, frames may scroll vertically — `overflow-y:auto` on the phone
   is fine; horizontal spill is not). Look at at least two screenshots with
   the Read tool to check the result *looks* right, not just measures right.
   Record each run's result in `A11Y.md` in your folder (the four commands
   and their output, what you changed), plus: the smallest text size used,
   the smallest touch target, and any pairing below 4.5:1 / 3:1 (should be
   none).

## Quality bar

- Three genuinely different answers. Do not drift toward the other two
  directions' theses (in `PROGRESS.md` "Directions").
- Every number is measured, not asserted. "Passes AA" without a ratio is
  not acceptable.
- It must look *designed*: a real hierarchy, rhythm, and conviction. A
  mainstream Android user from Chrome is the reader to win.
- When done, reply with: which files exist, which blocks are in
  screens.html, the four accessibility-run results, and anything unfinished.
