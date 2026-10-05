# 02 — Privacy-browser peers

Research for the Container redesign (mainstream users). Compiled 2026-10-05.
Every claim carries its source inline. **[unverified]** marks values I could
not confirm from a primary or reputable secondary source (usually observed
from memory of the apps, or from colour-aggregator sites only). Corner radii,
list density and launcher-icon legibility are almost never published; where
given they are marked as observation, not fact.

Scope note: two of the seven targets have **no Android app**. Mullvad Browser
is desktop-only and the Android request was closed as not planned
(https://browsers.to/mullvad-browser, https://github.com/mullvad/mullvad-browser/issues/338).
Kagi says Orion for Android is "not planned yet"
(https://piunikaweb.com/2026/06/30/kagi-no-plans-for-orion-browser-android/),
and in October 2026 it ended Orion for Linux/Windows to focus on macOS/iOS
(https://alternativeto.net/news/2026/10/kagi-ends-development-of-orion-for-linux-and-windows-open-sources-code-to-community/).
They are included for philosophy and voice, not Android patterns.

---

## Brave (Android)

**Colour.** Primary orange `#FB542B`; dark grey `#343546`, light grey
`#A0A1B2`, off-white `#F0F0F0`, purple `#A3278F`, deep purple `#4F30AB`
(https://brave.com/brave-branding-assets/).

**Type.** The official brand-assets page specifies Poppins for headline and
body (https://brave.com/brave-branding-assets/). The live site pairs Poppins
heads with Inter Variable body (https://design.withfudge.com/share/brave.com-design),
and the browser's Leo design-token system moves UI type to `--leo-font-*`
tokens, with settings pages moving to system fonts
(https://github.com/brave/leo, https://github.com/brave/brave-browser/issues/41559).
Takeaway: the brand face lives in marketing; the product chrome uses system
or neutral UI fonts.

**Address bar.** Top by default; a bottom address bar rolled out to all
Android users in August 2025, toggled by long-pressing the bar or via
Settings → Appearance (https://x.com/brave/status/1958217092370665915,
https://x.com/brave/status/1954968686772535665).

**How protection is visualised.** The lion icon in the address bar *is* the
Shields control; tapping it shows how many trackers are blocked on this page
(https://github.com/brave/brave-browser/wiki/Shields-Debugging-Guide). The
number next to "Block ads & trackers" lists everything blocked on the domain
when tapped (https://support.brave.app/hc/en-us/articles/360022806212-How-do-I-use-Shields-while-browsing).
The panel has a simple view and an "Advanced controls" expansion
(https://github.com/brave/brave-browser/issues/6831). Shields is a single
per-site up/down toggle — the whole protection model collapses into one
binary that a novice can understand.

**Counter.** A badge on the Shields icon counts blocked items per page, and
the new-tab page shows lifetime "Trackers & ads blocked / Bandwidth saved /
Time saved" (https://news.ycombinator.com/item?id=30548838,
https://community.brave.app/t/stats-trackers-ads-blocked-etc-on-android/469867).
Users asked to hide the badge because the incrementing number was
distracting: "The color of the icon is enough for me to know whether it's
enabled or not, and if it's enabled I trust that it's working." Brave added a
setting, "Indicate the number of blocked items on the Shields icon"
(https://github.com/brave/brave-browser/issues/3121). This is direct evidence
that a *state colour* reassures more durably than a *running number*.

**Voice.** Shields copy is plain and causal: "Sites often have cookies and
scripts lurking in the background, trying to identify you and your device.
Why? So you can be followed around the web… Brave Shields block cookies and
scripts, which means better privacy online." Breakage copy: "If this site
seems broken, try Shields down. Note: this may reduce Brave privacy
protections." (https://github.com/brave/brave-ios/issues/3910). It names a
villain, answers "why?", and gives a single escape hatch.

**Intimidates vs reassures.** Reassures: one toggle, one icon colour, an
honest "this may break the site" escape. Intimidates: bloat. Reviews call out
"AI, crypto wallets, rewards, and news feeds that users never asked for"
(https://www.howtogeek.com/could-cost-60-dollars-to-fix-brave-bloat-problem/);
a GitHub issue says default crypto features make a clean install look like "a
bloated 'scam' browser" (https://github.com/brave/brave-browser/issues/43030).

**Launcher icon.** Orange-gradient lion head; at 48 px it reads as a warm
orange blob with a white face — recognisable by colour more than by shape
**[unverified, observation]**.

## DuckDuckGo (Android)

**Colour.** Brand orange-red `#DE5833` ("Flame Pea"), per aggregators
(https://brandpalettes.com/duckduckgo-logo-colors/) **[unverified against an
official DDG guide]**.

**Type.** Was Proxima Nova; in 2025 DDG commissioned **Duck Sans** (a
semi-custom Pangea by Fontwerk), with Display and Product cuts, rounder
distinctiveness on `G`, redesigned numerals and heavier i-dots
(https://fontwerk.com/en/text/semi-custom-font-for-duckduckgo). A
privacy brand investing in one friendly, characterful sans — not a mono.

**Address bar.** Top by default; Settings → Appearance offers Top or Bottom
(and on some versions a split layout)
(https://thedroidguy.com/customize-duckduckgo-appearance-or-settings-step-by-step-guide-1263128,
https://github.com/duckduckgo/Android/issues/1082). A reviewer liked that
"all the essential buttons are at the screen's bottom-right corner alongside
the address bar" (https://www.androidauthority.com/duckduckgo-vs-chrome-incognito-mode-3590389/).

**How protection is visualised.** A shield in the address bar opens the
Privacy Dashboard, which "report[s] trackers found and blocked… display[s]
connection details, change[s] permissions, and send[s] breakage reports",
including a "Website not working as expected?" link
(https://github.com/duckduckgo/privacy-dashboard/). Since 2022 it shows
"which third-party requests have been blocked from loading and which other
third-party requests have loaded, with reasons for both"
(https://spreadprivacy.com/more-privacy-and-transparency/). The old **A–F
Privacy Grade** has been retired: its repo was archived 10 March 2023
(https://github.com/duckduckgo/privacy-grade); the app now shows blocked
trackers rather than a score
(https://kinsta.com/blog/duckduckgo-privacy/) **[the exact retirement date of
grades in the UI is unverified]**. Lesson: a letter grade judged *the site*,
which users read as judging *their safety*; DDG moved to factual lists.

**Fire Button (burn).** A flame icon that clears tabs, cookies, history and
site data, with a full-screen fire animation (alternatives: Whirlpool,
Inferno, Airstream, none)
(https://www.hardreset.info/devices/apps/apps-duckduckgo-privacy-browser/change-fire-button-animation/).
DDG's designers say they turned "this really mundane and boring technical
thing in a really satisfying experience"; surveys showed delight up, and
angry all-caps feedback about accidental deletion went down after they made
the confirmation dialog larger and moved its buttons away from the thumb,
and added single-tab burning
(https://insideduckduckgo.substack.com/p/duck-tales-the-fire-button-a-delightful).
"Fireproof" sites keep their first-party cookies through a burn
(https://factually.co/fact-checks/technology/how-duckduckgo-fire-button-works-what-it-doesnt-clear-757617)
— the exact analogue of Container's "Keep for this site".

**Intimidates vs reassures.** Reassures: playful metaphor, one obvious
destructive action, a confirmation tuned against accidents. Mild critique:
"pretty barebones in design" for a primary browser
(https://www.androidauthority.com/duckduckgo-vs-chrome-incognito-mode-3590389/).
A reviewer described the Fire Button as "a big red nuke button" (same
source) — the destructive control is visually loud, intentionally.

**Launcher icon.** Duck head on an orange-red circle; strong silhouette, reads
at 48 px **[unverified, observation]**.

## Tor Browser (Android)

**Colour.** Purple `#7D4698`, dark purple `#59316B`, green `#68B030`, grey
`#F8F9FA`, dark grey `#333A41` (https://styleguide.torproject.org/visuals/).

**Type.** Source Sans Pro for Latin, Noto for other scripts; headers about
twice body size, in Tor purple (https://simplysecure.org/resources/tor-style-guide-v1.3.pdf,
https://styleguide.torproject.org/visuals/). Tor Browser 14 inherited
Firefox's "heavier headings and changes to line heights intended to improve
font compatibility and accessibility" (https://blog.torproject.org/new-release-tor-browser-140/).

**Security level.** Three named levels — **Standard / Safer / Safest** —
reached on Android via ⋮ → Privacy and security → Security Level → "Save and
restart" (https://support.torproject.org/tor-browser/features/security-levels/).
Copy: Standard — "all Tor Browser and website features are enabled"; Safer —
"disables website features that are often dangerous"; Safest — "only allows
website features required for static sites and basic services" (same source).
On desktop the level lives behind a shield next to the URL bar
(https://manual-f04e0b.pages.torproject.net/security-settings/). Container's
Plan 16 already copies these exact names. Warning from Privacy Guides: the
slider gave "no visible indicator that anything is different" and "no prompt
to restart" even though protections only fully applied after restart
(https://www.privacyguides.org/articles/2025/05/02/tor-security-slider-flaw/).
Container reopens the container in place; that change should be *visible*.

**Circuit / new identity.** Android long exposed "New identity" only via a
persistent notification, and it actually just refreshed circuits; Tor 14.0
replaced it with an in-app "New circuit for this site" in the overflow menu,
because most users used it to fix a broken site
(https://blog.torproject.org/new-release-tor-browser-140/). Tor 14.5 says the
new backend enables a future circuit display on Android
(https://blog.torproject.org/new-release-tor-browser-145/) — i.e. **no
circuit display on Android yet** **[as of 14.5; later versions unverified]**.

**Talking to novices.** Connection screens were rebuilt in 13.5 with
"Configure connection", auto-connect, and the explicit goal that "a user who
can successfully circumvent censorship on desktop will be able to pick
Android up without needing to relearn how it works"
(https://blog.torproject.org/new-release-tor-browser-135/). 14.5's Connection
Assist framed the problem in one human question: "But what happens if the Tor
network itself is blocked in your country, by your ISP, or on your local
network?" and then "will offer to find and try bridges for you"
(https://blog.torproject.org/new-release-tor-browser-145/). Tor 13.0 removed
the "red screen of death" connectivity check that frightened users whose
connection was fine, replacing it with "a simple status banner"
(https://blog.torproject.org/new-release-tor-browser-130/).

**Launcher icon.** The onion mark, refined (not replaced) in 13.0 for Android
adaptive icons and "enhanced legibility at smaller sizes", because
"discernible application and installer icons help prevent user error"
(https://blog.torproject.org/new-release-tor-browser-130/).

**Intimidates vs reassures.** Intimidates: false alarms (the old red screen),
settings that need a restart, jargon (bridges, pluggable transports).
Reassures: one-question explanations, auto-connect.

## Mullvad Browser (desktop only)

**Colour.** Blue `#294D73`, dark blue `#192E45`, green `#44AD4D`, red
`#E34039`, yellow (helmet) `#FFD524`, brown `#D2943B`, beige `#FFCD86`
(https://mullvad.net/en/press).

**Type.** Open Sans for body, Source Sans Pro for headlines and buttons
(https://mullvad.net/en/press).

**Approach.** No counters, no dashboard: "Hide in the crowd" — every user
should look the same, so it ships uBlock Origin and NoScript, private mode on
by default, and discourages changes because "any change makes your
fingerprint unique" (https://mullvad.net/en/browser,
https://privacytools.io/app/mullvad-browser). Letterboxing's grey bars are
*explained as a protective feature* rather than hidden
(https://mullvad.net/en/browser). Headline: "Free the internet with Mullvad
Browser"; framing like "A VPN is not enough for privacy" (same source). It
shares Tor's Standard/Safer/Safest slider, and its restart flaw
(https://www.privacyguides.org/articles/2025/05/02/tor-security-slider-flaw/).

**Launcher icon.** **[unverified]** — not documented in sources found.

## Cromite (Android)

Chromium fork succeeding Bromite: built-in ad blocking (Adblock Plus engine
with EasyList), DoH, optional always-incognito
(https://privacytools.io/app/cromite). Looks "enough like Chrome that users can
start browsing within minutes"
(https://www.makeuseof.com/i-found-a-chrome-like-android-browser-that-actually-feels-cleaner/),
and its settings expose a dedicated adblock page with master switch and
filter lists (same source). The README is candid to the point of
discouraging novices: anti-fingerprinting mitigations "are not to be
considered useful for high-risk users", recommending Tor Browser instead
(https://github.com/uazo/cromite). No brand palette, no protection
visualisation of note; **no published colours or type [unverified]**. Its
lesson: familiarity (Chrome's layout) is itself reassuring; honesty about
limits builds trust with experts but offers novices nothing to hold.

## Vivaldi (Android)

**Colour.** Brand red `#EF3939`; a darker UI red `#C83838` is reported by the
community (https://forum.vivaldi.net/topic/7113/what-color-is-vivaldi-red)
**[#C83838 unverified officially]**.

**Type.** Logo "V" is a custom mark; vivaldi.com uses Roboto headlines over
system-ui body (https://logosandtypes.com/alphabet/letter-v/vivaldi-browser/)
**[secondary source]**.

**Address bar.** Top by default, bottom optional (long-press → "Move Address
Bar to the bottom"), and the optional tab bar follows it
(https://vivaldi.com/blog/vivaldi-on-android-configurable-address-bar-tab-bar/,
https://help.vivaldi.com/android/android-browse/address-field-in-vivaldi-on-android/).
Rationale: "Our aim is to put all the navigation bars at the bottom so that
the key functionality is just a thumb away"
(https://vivaldi.com/blog/teamblog/vivaldi-browser-android-improves-tabs-tracker-ad-blocker/).

**Protection.** A shield at the left end of the address field; tap to choose
**No Blocking / Block Trackers / Block Trackers and Ads** per site, with a
per-site count that opens a detailed list
(https://help.vivaldi.com/android/android-privacy/android-tracker-and-ad-blocker/).
A three-step named ladder, like Tor's, but about blocking rather than
features.

**Theming.** By default (light theme) the address and tab bars adopt the
page's main colour; some users find "the vivid colors are very disturbing,
especially when the address bar is at the bottom"
(https://help.vivaldi.com/android/android-appearance/themes-on-android/,
https://forum.vivaldi.net/topic/40240/option-to-disable-accent-colors-from-active-site).
Settings density is the classic complaint ("overwhelming"), addressed by a
6.9 settings redesign (https://deepakness.com/blog/vivaldi-browser/,
https://alternativeto.net/news/2024/9/vivaldi-6-9-launches-on-ios-and-android-with-enhanced-settings-and-tab-management).

**Launcher icon.** White "V" on a red rounded square, flattened in 2017
(https://logosandtypes.com/alphabet/letter-v/vivaldi-browser/); reads at
48 px as a red tile **[legibility is observation]**.

## Orion (Kagi; no Android)

Voice: "Zero-telemetry browsing", "No data collection. No telemetry. No
sponsored junk", "Software made to work for the people funding it", tagline
"Browse beyond ✴︎"; purple/lavender gradient accents (https://orionbrowser.com/).
Tracker blocking is presented as one part of a "Zero Compromise Privacy"
pillar, not a counter (same source). Its voice is *confident about what it
doesn't do* — the closest match to Container's "no requests of its own".

---

## Cross-cutting observations

- **Light vs dark default.** Every Android peer follows the system theme or
  defaults to light; none is dark-only **[unverified per app; based on settings
  pages showing System/Light/Dark choices]**. Vivaldi's adaptive colour only
  applies in light theme (https://help.vivaldi.com/android/android-appearance/themes-on-android/).
  Container's dark-only rule is the outlier.
- **Address bar.** All three Android incumbents (Brave, DDG, Vivaldi) default
  to top with a bottom option; Chrome only added bottom in 2025
  (https://9to5google.com/2025/07/15/chrome-android-bottom-address-bar-2/).
  Container's layout C already has a bottom bar.
- **Type.** Nobody uses a monospace in product chrome. Brave, Tor, Mullvad
  and DDG all use humanist/geometric sans (Poppins/Inter, Source Sans, Open
  Sans, Duck Sans).
- **Protection = one icon at the address bar.** Brave lion, DDG shield,
  Vivaldi shield, Tor shield (desktop). Colour state first, number second.
- **Corner radii / list density.** Not published by any peer. Observed: all
  use Material-style rounded sheets and pill address bars, with full-width
  list rows separated by whitespace rather than rules **[observation,
  unverified]**.

## Transferable takeaways

1. **Put the shield in the pill and make its colour the message.** Brave's
   users said icon colour alone tells them protection is on
   (https://github.com/brave/brave-browser/issues/3121). Container's `6c`
   shield should carry state (jade = protected/live) before any number.
2. **Keep the blocked tally factual, page-scoped and secondary.** Brave lets
   users hide the badge; DDG replaced a judgmental A–F grade with lists of
   what was blocked and why. Container's per-site blocked count fits this.
   Never present a grade or score; that also respects the no-leak-count rule.
3. **Name levels in plain words, three steps, with one-line consequences.**
   Tor's "Standard / Safer / Safest" and Vivaldi's "No Blocking / Block
   Trackers / Block Trackers and Ads" both work. Container already uses Tor's
   names. Each needs a one-line effect ("some sites may break").
4. **Make protective changes visibly take effect.** Tor's silent
   restart-needed slider is a cautionary tale
   (https://www.privacyguides.org/articles/2025/05/02/tor-security-slider-flaw/).
   When Container reopens in place, briefly show it.
5. **Give "burn" a memorable, safe metaphor.** DDG's Fire Button shows that
   delight drives use of a destructive action, provided the confirm is big and
   placed away from the thumb, and there is a per-tab version
   (https://insideduckduckgo.substack.com/p/duck-tales-the-fire-button-a-delightful).
   That maps to Container's panic, close-and-wipe and New identity.
   "Fireproof" is the model for "Keep for this site".
6. **Explain with one human question, then offer to fix it.** Tor's "what
   happens if the Tor network itself is blocked…?" plus "will offer to find
   and try bridges for you", and Brave's "Why? So you can be followed around
   the web". This is the right register for `8b` failures and Tor connecting.
7. **Never show false alarms.** Tor removed its "red screen of death"
   because it frightened users whose connection was fine
   (https://blog.torproject.org/new-release-tor-browser-130/). Container's
   failure screens should appear only when something is actually wrong.
8. **Cut the feature count before you add polish.** Brave's bloat makes it
   read as a "scam" browser to newcomers, and Vivaldi's settings feel
   "overwhelming". Container should hide advanced controls (proxy fields,
   scripts, filter lists) behind one "Advanced" fold, as Brave does with
   "Advanced controls".
9. **Use a friendly sans and a warm, saturated brand colour.** Every peer uses
   one: orange, orange-red, purple, red or yellow. None uses mono in its UI.
   Keep IBM Plex Mono for addresses and technical values only, and let
   Figtree carry the voice.
10. **Pick a launcher icon with a single strong silhouette on a solid colour
    field.** The duck, the lion, the onion and the V all read at 48 px. Tor
    refined its icon specifically for adaptive icons and small-size legibility.
