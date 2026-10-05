# Research — who Container's user is, and what they expect

Compiled 2026-10-05 by fire-cd6e6b from four research notes, each with every
source inline and uncertain values marked:

- `research/01-market-and-majors.md` — market share; Chrome, Safari, Samsung
  Internet, Edge, Firefox, Opera
- `research/02-privacy-peers.md` — Brave, DuckDuckGo, Tor Browser, Mullvad
  Browser, Cromite, Vivaldi, Orion
- `research/03-craft-outliers.md` — Arc/Dia, Zen, Proton, Mullvad VPN,
  Signal, Tailscale, 1Password, Obsidian; open-licence typefaces
- `research/04-human-factors.md` — Material 3 / Expressive, HIG, WCAG, font
  scale data, intimidating security UI, incognito misconceptions, polarity

This file is the synthesis. Claims carry their primary source; the notes
carry the rest.

## 1. Where the user is arriving from

| Source | Chrome | Safari | Samsung Internet | Firefox |
|---|---|---|---|---|
| StatCounter, mobile, worldwide, Sept 2026 ([link](https://gs.statcounter.com/browser-market-share/mobile/worldwide)) | 67.6 % | 24.7 % | 3.5 % | 0.7 % |
| Cloudflare Radar 2025, **Android only** ([link](https://blog.cloudflare.com/radar-2025-year-in-review/)) | **85 %** | — | **6.6 %** | — |
| StatCounter, mobile, Europe ([link](https://gs.statcounter.com/browser-market-share/mobile/europe)) | 62.8 % | 28.0 % | 5.5 % | 1.1 % |
| W3Counter, all platforms (outlier sample) ([link](https://www.w3counter.com/globalstats.php)) | 83.8 % | 5.0 % | — | 1.0 % |

Android is 69.2 % of mobile ([StatCounter OS](https://gs.statcounter.com/os-market-share/mobile/worldwide)).
**An Android user bouncing off Container came, roughly 17 times in 18, from
Chrome**; the remainder mostly from Samsung Internet (Galaxy default), and in
North America (Safari 45.9 % of mobile) a meaningful minority carry iPhone
habits. Firefox, Opera and Edge users are each ~1 % and already
privacy-literate — they are not the brief.

## 2. What those browsers taught the user

- **Chrome's toolbar is 56 dp with a 40 dp pill (20 dp corners), 48 dp
  minimum touch targets, 24 dp icons** — read from Chromium's own resource
  files ([omnibox dimens](https://chromium.googlesource.com/chromium/src/+/refs/heads/main/chrome/browser/ui/android/omnibox/java/res/values/dimens.xml),
  [browser_ui dimens](https://chromium.googlesource.com/chromium/src/+/refs/heads/main/components/browser_ui/styles/android/java/res/values/dimens.xml)).
  Tab-grid cards use a 24 dp radius ([tab_ui dimens](https://chromium.googlesource.com/chromium/src/+/refs/heads/main/chrome/android/features/tab_ui/java/res/values/dimens.xml)).
- **Every major follows the system light/dark setting by default; none is
  dark-only** ([Chrome help](https://support.google.com/chrome/answer/9275525?hl=en&co=GENIE.Platform%3DAndroid); note 01 §3).
- **Every major now offers the address bar at the bottom** (Chrome since June
  2025: [9to5Google](https://9to5google.com/2025/06/24/chrome-bottom-address-bar-android/));
  Safari 26 and Samsung One UI 8.5 float it as a translucent pill.
- **Private mode is a whole-UI shift plus one icon**: Chrome forces dark with
  the hat-and-glasses; Firefox goes purple with a mask ([Mozilla
  Connect](https://connect.mozilla.org/t5/ideas/purple-background-for-private-tabs-tray-firefox-for-android/idi-p/63790));
  Samsung greys out with a mask ([Samsung](https://www.samsung.com/us/support/answer/ANS10010475/));
  Safari blacks the bar and locks behind Face ID ([Apple](https://support.apple.com/en-us/105030)).
  The user has learned "dark = private". Container is dark everywhere, so
  that signal is spent before the user does anything.
- **Protection is shown as one icon in the address bar that opens a panel**:
  Firefox's shield ([Mozilla](https://support.mozilla.org/en-US/kb/enhanced-tracking-protection-firefox-android)),
  Brave's lion, DuckDuckGo's shield, Vivaldi's shield (note 02). Container's
  shield-in-the-pill → `6c` is already on-pattern; it is just too small (28 dp).
- **Chrome's tint is Material You dynamic colour, not brand colour**
  ([9to5Google, Chrome 141](https://9to5google.com/2025/10/26/chrome-141-android-m3-expressive-redesign/)).
  The user's browser looks like their wallpaper; their privacy app should not
  look like nobody's.

## 3. Privacy peers: what reassures, what intimidates

- **Colour before numbers.** Brave users report that the shield's colour
  alone tells them protection is on ([brave-browser#3121](https://github.com/brave/brave-browser/issues/3121)),
  and Brave added a setting to *hide* its blocked count because the rising
  number distracted ([note 02](research/02-privacy-peers.md)).
- **Scores were abandoned.** DuckDuckGo retired its A–F privacy grade and
  shows what was blocked instead (repo archived 2023; note 02). That supports
  Container's existing rule: a factual tally, never a score, no leak count.
- **Plain three-step levels work.** Tor's Standard / Safer / Safest (which
  Container's Plan 16 already uses) — but Tor's slider gave no sign a change
  had not applied ([Privacy Guides, 2025](https://www.privacyguides.org/articles/2025/05/02/tor-security-slider-flaw/)).
- **Burn actions can be friendly.** DuckDuckGo's Fire Button makes
  destruction delightful while keeping the confirm big and away from the
  thumb (note 02) — the model for panic, wipe and New identity.
- **What intimidates:** Brave's extra features read as a "scam" to some
  newcomers; Vivaldi's settings are called "overwhelming"; Tor removed a red
  error screen that frightened users whose connection was fine (note 02).
- **Nobody uses monospace in the chrome** (note 02). Container's mono is a
  differentiator for experts and a barrier for everyone else; it has to be
  kept for facts (hosts, proxy addresses) and taken off labels.

## 4. Craft outliers: how calm products look

- **One rare hue over warm neutrals.** Tailscale's ink `#181717` rather than
  black, one accent used rarely ([refero, unverified](https://styles.refero.design/style/5b679fb6-8d53-402d-a77b-c88bfb397623));
  Mullvad's navy field with green/red reserved for connection state
  ([mullvad.net/press](https://mullvad.net/en/press)); 1Password desaturated
  its blue "so it feels more tactile" ([1Password](https://1password.com/blog/1password-brand-refresh)).
- **A mark built on one physical object survives 16 px** (1Password's
  keyhole, Obsidian's rock, Mullvad's mole); **thin concentric strokes do
  not** (Zen's logo, criticised at small sizes: [havn.blog](https://havn.blog/2024/12/12/i-tried-to.html)).
- **Novelty budget.** Dia keeps the browser boring and spends colour and
  motion only on what is new (note 03). Container's new things are isolation
  and the shield.
- **Identity per context.** Zen gives each workspace its own colour and
  gradient; Proton fades its master purple into each product's colour
  (note 03). Users tell isolated contexts apart by colour.
- **Typefaces available to us (OFL, bundleable):** Figtree 61 KB variable
  (already bundled), Atkinson Hyperlegible Next 112 KB with a Mono companion
  ([Braille Institute](https://www.brailleinstitute.org/freefont/)), Public
  Sans 101 KB, Manrope 161 KB, Geist / Geist Mono 165 / 168 KB, IBM Plex Sans
  525 KB variable (Plex Mono already bundled), Inter 857 KB. Proprietary and
  ruled out: ABC Arizona (Proton), ABC Oracle (Dia), Agile Sans (1Password),
  MDIO (Tailscale). Sizes measured from `google/fonts` on 2026-10-05 (note 03 §9).

## 5. Human factors

- **Targets: 48 × 48 dp, 8 dp apart** ([M3](https://m3.material.io/foundations/designing/structure));
  Apple 44 pt ([HIG](https://developer.apple.com/design/human-interface-guidelines/accessibility)).
  WCAG 2.2's 24 px AA floor is half that and is not the bar.
- **Body text: Material Body Large 16/24 sp; iOS Body 17/22 pt**; Material's
  smallest role (Label Small) is 11 sp ([Compose TypeScaleTokens](https://github.com/androidx/androidx/blob/androidx-main/compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/tokens/TypeScaleTokens.kt);
  [HIG Typography](https://developer.apple.com/design/human-interface-guidelines/typography)).
- **List items 56 / 72 / 88 dp** for one / two / three lines
  ([ListTokens](https://github.com/androidx/androidx/blob/androidx-main/compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/tokens/ListTokens.kt)).
- **Shape scale** 4 / 8 / 12 / 16 / 20 / 28 / 32 / 48 dp / full
  ([MDC Shape.md](https://github.com/material-components/material-components-android/blob/master/docs/theming/Shape.md)).
  **Springs** damping 0.9, stiffness 1400 / 700 / 300; effects never bounce
  ([MDC Motion.md](https://github.com/material-components/material-components-android/blob/master/docs/theming/Motion.md)).
- **M3 Expressive's research** (46 studies, 18,000+ participants): key
  elements found "up to 4× faster" with more colour, shape, size and
  containment ([Google Design](https://design.google/library/expressive-material-design-google-research)).
  Vendor research, but the best public evidence against flat hairline lists.
- **WCAG 2.1 AA:** 4.5:1 text, 3:1 large text (≥ 24 px, or ≥ 18.66 px bold),
  3:1 for UI components and meaningful graphics (1.4.11), 200 % resize (1.4.4)
  ([W3C](https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html),
  [1.4.11](https://www.w3.org/WAI/WCAG21/Understanding/non-text-contrast.html)).
- **Font scale in the wild: roughly one user in four or five runs larger
  than default** — Appt.org's Dutch panel reports "more than a fifth" on both
  Android and iOS ([Appt](https://appt.org/en/stats/font-size)); two iOS apps
  measured 27 % and 29 % (second-hand; note 04 §3). Android 14 scales
  non-linearly to 200 %.
- **Positive polarity (dark on light) reads better for normal vision,
  especially at small sizes** ([NN/g](https://www.nngroup.com/articles/dark-mode/);
  [Piepenbrock et al. 2013](https://www.researchgate.net/publication/236662424_Positive_display_polarity_is_advantageous_for_both_younger_and_older_adults)).
  Preference splits roughly into thirds (light / dark / follow-system;
  [NN/g 2023](https://www.nngroup.com/articles/dark-mode-users-issues/)).

## 6. Why security UI intimidates, and what makes it trustworthy

- **Opacity and fear without an action** drive users away; warnings that name
  one concrete action work better than threat (efficacy beats threat ~3×;
  note 04 §4 with sources). **Habituation** sets in by the second exposure of
  the same warning.
- **Opinionated defaults**: making the safe choice visually dominant moved
  adherence from 31 % to 58 % in the study cited in note 04 §4.
- **Calm when healthy, loud only when abnormal** — Chrome's "secure by
  default, mark the insecure" logic; Signal's "absence as a trust signal"
  (no status chatter by default; note 03 §5).
- **Plain words.** Signal's verification ("if these numbers match…") never
  says "cryptographic". Proton chose a humanist face because "our font should
  have a more human touch" ([Proton](https://proton.me/blog/new-visual-universe)).

## 7. How people misunderstand "private"

- **Wu et al., "Your Secrets Are Safe", WWW 2018** (n = 460): 37 % believed
  private browsing hides them from their employer, 22 % from their ISP, 27 %
  that it protects against malware, 25 % that it hides their IP
  ([paper](https://dl.acm.org/doi/10.1145/3178876.3186088)).
- **DuckDuckGo, 2017** (n = 5,710): 76 % could not accurately say what
  private browsing protects ([PDF](https://duckduckgo.com/download/Private_Browsing.pdf)).
- **Habib et al., "Away From Prying Eyes", SOUPS 2018**: 39 % believed it
  makes them anonymous ([SOUPS](https://www.usenix.org/conference/soups2018/presentation/habib-prying)).
- **Google's 2024 Incognito settlement** rewrote the disclosure to name what
  it does and does not protect against (note 04 §5).

The relevance: Container's isolation is *stronger* than incognito (separate
storage per site, per-site routing) but its UI gives the user no picture of
it. A user who thinks "private = dark screen" will read Container's
always-dark UI as "everything is incognito", which is exactly the
misconception the research measures — and wrong in a new way (Keep sites stay
signed in).

## What this means for Container

Each is specific enough to be checked against a mockup or a build. They are
the input to phase 3.

1. **Nothing the user reads is under 12 sp, body is 16 sp, and the address
   is 15–16 sp.** Today 43 % of literal text sizes are ≤ 12.5 px, meta is
   10.5 px and the pill's host is 11.5 px (AUDIT §1.2, §1.4). Falsifiable:
   grep `size:` under `lib/ui` after the restyle; no value under 12 except
   decorative glyph sizes.
2. **Every tappable icon is a 48 × 48 dp target.** Today 28 of 29 `IconTap`
   call sites are smaller; the pill's shield — the only door to `6c` — is
   28 dp. Falsifiable: `IconTap`'s default and minimum size become 48.
3. **Every text pairing is ≥ 4.5:1 and every meaningful non-text mark
   (switch track, PIN dot, live/idle indicator) ≥ 3:1.** Today `textFaint`
   (the most-used text colour, 52 refs) is 4.01:1 and an off switch's track
   is 1.26:1 (AUDIT §2). Falsifiable: `tools/contrast.py` on each direction's
   token table.
4. **At most four surface tones, each ≥ 1.15:1 from its neighbour, and
   containment (grouped, rounded surfaces) instead of hairline-only
   structure.** Today eleven darks sit within 1.26:1 and a sheet differs from
   the page by 1.05:1. M3 Expressive's containment research (§5) is the
   argument.
5. **The address bar matches Chrome's grammar: a ≥ 48 dp pill in a ≥ 56 dp
   bar, host in the UI face at ≥ 15 sp, shield and reload as ≥ 40 dp
   in-pill targets.** Today: 34 dp pill, 11.5 px host, 28 dp buttons.
6. **"Private" must not be signalled by darkness alone.** The user has
   learned dark = incognito (§2). Whatever a direction's base polarity, the
   *difference* between a saved Keep site, a wipe-on-exit site, a throwaway
   and a Tor route must be visible in the chrome itself, not only in a 9.5 px
   label.
7. **Section labels stop being 10 px tracked uppercase.** At a 1.3 scale
   they are still 13 px caps in a 4.01:1 grey. Labels become sentence-case
   or small caps at ≥ 12 sp in a ≥ 4.5:1 tone; copy is unchanged, only its
   setting (`text-transform` is styling — the stored string stays).
8. **Monospace is for values, never labels.** Hosts, proxy addresses, rule
   counts stay mono (a real trust signal, AUDIT §3.4); route labels like
   `SOCKS5` / `TOR` become UI-face badges with an icon, ≥ 12 sp.
9. **The shield's colour states protection before any number**, and no
   screen shows a score or leak count (§3, CLAUDE.md). The blocked tally
   stays a secondary line in `6c` and Today.
10. **There is a real launcher icon** that reads by silhouette and one colour
    at 48 px and as an Android 13 themed (monochrome) icon. Today it is
    Flutter's default (AUDIT §1.6). The mark is one physical object — a box
    / container — not thin concentric strokes.
11. **Light or dark is a stated decision with its cost**: following the
    system wins on legibility (§5) and familiarity (§2) but changes the
    "dark only" constraint and interacts with WebView's force-dark (the
    Android theme must stay dark; `test/android_theme_test.dart`). A dark
    direction compensates with ≥ 16 sp body and medium weights.
12. **Destructive actions get space, not alarm.** Panic, wipe and New
    identity keep danger red as text/outline (never a full-screen red), the
    confirm is the largest target on its sheet, and it sits ≥ 24 dp from the
    cancel. (DuckDuckGo's Fire Button; Tor's removed red screen.)
13. **Every layout survives 320 × 568 at 1.0, 360 × 640 at 1.3, and
    412 × 915 at 2.0** — the sizes this repo's own responsiveness run used.
    Rows grow with text; nothing has a fixed height.
14. **Spend motion on two moments only**: unlock (the vault opening) and a
    protective change taking effect (reopen-in-place). Everything else uses
    effects springs that never bounce, and respects reduced motion.
15. **The decoy cannot be told apart.** No visual element may depend on
    which vault is open — no per-vault theme, accent or icon. (Threat model;
    any per-site colour must come from the site's own data, which both vaults
    have.)
