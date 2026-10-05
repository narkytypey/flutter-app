# 04 — Human factors: sizes, legibility, and how privacy UI is understood

Research brief for the Container visual redesign (mainstream audience). Compiled
2026-10-05. Every figure has a source next to it. Where a number comes from
platform source code rather than a guideline page, the code is cited, because
the m3.material.io pages render client-side and could not be quoted directly.

---

## 1. Platform metrics: Material 3, M3 Expressive, Apple HIG

### 1.1 Touch targets

- **Material 3: at least 48 × 48dp**, which is about 9 mm physically whatever
  the screen. The visible icon can be 24dp; padding makes up the rest. Targets
  should sit **8dp or more apart**.
  ([M3 accessibility: structure](https://m3.material.io/foundations/designing/structure),
  [M3 icon buttons: accessibility](https://m3.material.io/components/icon-buttons/accessibility))
- **Apple HIG (iOS/iPadOS): default 44 × 44 pt, minimum 28 × 28 pt.** These
  come from the "Minimum control size" table in the HIG Accessibility page,
  read from its data feed
  ([HIG Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)).

### 1.2 Type scale (Material 3 baseline, sp, size / line height)

These are read from Jetpack Compose's generated `TypeScaleTokens.kt`
([androidx source](https://github.com/androidx/androidx/blob/androidx-main/compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/tokens/TypeScaleTokens.kt))
and agree with the
[MDC-Android typography doc](https://github.com/material-components/material-components-android/blob/master/docs/theming/Typography.md)
(baseline "Regular 57sp" down to "Medium 11sp"):

| Role | Large | Medium | Small |
|---|---|---|---|
| Display | 57 / 64 | 45 / 52 | 36 / 44 |
| Headline | 32 / 40 | 28 / 36 | 24 / 32 |
| Title | 22 / 28 | 16 / 24 | 14 / 20 |
| Body | **16 / 24** | 14 / 20 | 12 / 16 |
| Label | 14 / 20 | 12 / 16 | 11 / 16 |

M3 Expressive adds an **emphasized** set with the same sizes at heavier weights
(e.g. Medium 57sp through Bold 11sp)
([MDC-Android Typography.md](https://github.com/material-components/material-components-android/blob/master/docs/theming/Typography.md)).
Body Large's line height is 1.5× its size (24/16), which already meets WCAG
1.4.12's line-height figure (see §2).

**Apple Dynamic Type, "Large (default)"**: Large Title 34/41, Title 1 28/34,
Title 2 22/28, Title 3 20/25, Headline 17/22 semibold, **Body 17/22**, Callout
16/21, Subhead 15/20, Footnote 13/18, Caption 1 12/16. The range runs from
**xSmall (Body 14)** through **xxxLarge (Body 23)**, and up to **AX5 (Body
53 pt)** with the accessibility sizes. The HIG lists **11 pt** as the iOS
minimum and 17 pt as the default
([HIG Typography](https://developer.apple.com/design/human-interface-guidelines/typography),
tables read from its data feed). So iOS body text is 17 pt and Material body is
16sp: both are above the 14sp or smaller that dense "technical" UIs tend to use.

### 1.3 Shape (corner radius) scale

From MDC-Android `Shape.md`
([source](https://github.com/material-components/material-components-android/blob/master/docs/theming/Shape.md)):
None 0dp · Extra small 4dp · Small 8dp · Medium 12dp · Large 16dp ·
**Large increased 20dp** · Extra large 28dp · **Extra large increased 32dp** ·
**Extra extra large 48dp** · Full (pill). The three in bold were added by M3
Expressive.

### 1.4 Motion

- **M3 Expressive moves to spring physics.** A spring is defined by stiffness
  (higher settles faster) and damping (higher stops the bounce sooner). The
  *Expressive* scheme has lower damping and visible overshoot. The *Standard*
  scheme has higher damping and is meant for "utilitarian" apps
  ([M3 motion: how it works](https://m3.material.io/styles/motion/overview/how-it-works),
  [M3 blog: motion physics](https://m3.material.io/blog/m3-expressive-motion-theming)).
- **Spring tokens** ([MDC-Android Motion.md](https://github.com/material-components/material-components-android/blob/master/docs/theming/Motion.md)):
  - Fast spatial: damping 0.9, stiffness 1400 (switches and buttons)
  - Default spatial: 0.9, 700 (bottom sheets and drawers)
  - Slow spatial: 0.9, 300 (full-screen transitions)
  - Effects springs (colour and opacity) use damping 1.0, so they never
    bounce: fast 3800, default 1600, slow 800.
- **Duration tokens:** short1–4 are 50/100/150/200 ms; medium1–4 are
  250/300/350/400 ms; long1–4 are 450–600 ms; extra-long1–4 are 700–1000 ms
  (same source).
- **Easing:** emphasized `cubic-bezier(0.2, 0, 0, 1)`; emphasized-decelerate
  `(0.05, 0.7, 0.1, 1)`; emphasized-accelerate `(0.3, 0, 0.8, 0.15)`; legacy
  standard `(0.4, 0, 0.2, 1)`
  ([Compose MotionTokens.kt](https://github.com/androidx/androidx/blob/androidx-main/compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/tokens/MotionTokens.kt);
  [M3 easing and duration](https://m3.material.io/styles/motion/easing-and-duration/tokens-specs)).

### 1.5 Component heights

- **List items: 56dp for one line, 72dp for two lines, 88dp for three lines**
  ([Compose ListTokens.kt](https://github.com/androidx/androidx/blob/androidx-main/compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/tokens/ListTokens.kt);
  [M3 Lists](https://m3.material.io/components/lists/overview)).
- **Top app bar: small 64dp, medium 112dp, large 152dp**
  (`AppBarSmallTokens`, `AppBarMediumTokens` and `AppBarLargeTokens` in the
  [same tokens directory](https://github.com/androidx/androidx/tree/androidx-main/compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/tokens)).
- **Navigation bar: 80dp in M3 and 64dp in M3 Expressive** ("Height: From 80dp
  to 64dp")
  ([MDC-Android BottomNavigation.md](https://github.com/material-components/material-components-android/blob/master/docs/components/BottomNavigation.md);
  Compose `NavigationBarTokens`: `ContainerHeight` 64dp,
  `TallContainerHeight` 80dp).

### 1.6 Why Expressive matters here

Google calls M3 Expressive its most-researched design update: **46 studies and
more than 18,000 participants**. Participants spotted key UI elements **"up to
4x faster"**, and time-to-tap on key actions fell by seconds. Google credits
colour, shape, size, motion and containment for directing attention
([Google Design: Expressive design research](https://design.google/library/expressive-material-design-google-research);
[Android Authority deep dive](https://www.androidauthority.com/google-material-3-expressive-features-changes-availability-devices-3556392/)).
This is vendor research, but it is the strongest public evidence that bigger,
more contained and more varied UI improves findability over flat hairline
lists.

---

## 2. WCAG 2.x requirements (and APCA)

| SC | Level | Requirement |
|---|---|---|
| [1.4.3 Contrast (Minimum)](https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html) | AA | **4.5:1** for text; **3:1** for large text, meaning **≥18 pt (≈24 CSS px) regular or ≥14 pt (≈18.66 px) bold** |
| [1.4.11 Non-text Contrast](https://www.w3.org/WAI/WCAG21/Understanding/non-text-contrast.html) | AA | **3:1** against adjacent colours for UI component boundaries and states (switch tracks, input borders, focus rings) and meaningful graphics (icons) |
| [1.4.4 Resize Text](https://www.w3.org/WAI/WCAG21/Understanding/resize-text.html) | AA | Text can be resized to **200%** with no loss of content or function |
| [1.4.12 Text Spacing](https://www.w3.org/WAI/WCAG21/Understanding/text-spacing.html) | AA | Nothing breaks when the user sets line height ≥ **1.5×**, paragraph spacing ≥ **2×**, letter spacing ≥ **0.12×** and word spacing ≥ **0.16×** the font size |
| [2.5.8 Target Size (Minimum)](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html) (WCAG 2.2) | AA | Target ≥ **24 × 24 CSS px**, or spaced so that 24px circles centred on adjacent targets do not overlap |
| [2.5.5 Target Size (Enhanced)](https://www.w3.org/WAI/WCAG21/Understanding/target-size.html) | AAA | Target ≥ **44 × 44 CSS px** |

Note that 2.5.8's 24px AA floor is half of Material's 48dp. Platform guidance
is the stricter bar, and the one to design to. Apple's HIG gives the same
4.5:1 for text up to 17 pt
([HIG Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)).

**APCA (context only).** The Accessible Perceptual Contrast Algorithm is the
candidate contrast method for WCAG 3. It scores lightness contrast (Lc, 0–~106)
and weights it by font size, weight and polarity, so light-on-dark and
dark-on-light pairs score differently, unlike the WCAG 2 ratio. Lc 75 is the
usual target for body text. **WCAG 3 is not a standard**, and tool support is
still patchy, so conformance claims must use WCAG 2 ratios
([APCA in a Nutshell](https://git.apcacontrast.com/documentation/APCA_in_a_Nutshell.html);
[Why APCA](https://github.com/Myndex/SAPC-APCA/blob/master/documentation/WhyAPCA.md)).
APCA matters for this app because it penalises thin, small, light-on-dark text
more than WCAG 2 does. That is exactly the current UI's IBM Plex Mono captions
on near-black.

---

## 3. What text size people actually run

- **Netherlands (Appt.org, a panel of ~5 million devices, collected through
  Q42's open-source library).** "More than a fifth of users normally increase
  the text size on iOS and on Android", which is over 3 million Dutch people.
  On Android "the most commonly used setting differs per device type", so
  Appt measured change against each device's modal setting
  ([Appt: font size](https://appt.org/en/stats/font-size),
  [Appt: stats methodology](https://appt.org/en/stats), updated
  2025-12-04). Font size is the most-used accessibility setting in their data.
- **PSPDFKit (PDF Viewer for iOS): about 27% of users set a non-default text
  size**, and a rerun with 50% more data points gave a similar figure. Some of
  those users chose *smaller* text
  ([PSPDFKit blog, 2018](https://pspdfkit.com/blog/2018/improving-dynamic-type-support/)).
- **Immoweb's iOS audience: 29% use a non-default Dynamic Type size**
  (≈107k larger, ≈68k smaller), and adoption differs by country (26% US vs
  18% France). These numbers are second-hand, via a developer write-up
  ([fassko, "Embracing the Dynamic Type"](https://fassko.medium.com/embracing-the-dynamic-type-d8df6701aa19)).
  Treat them as indicative.
- **Android 14 raised the maximum font scale from 130% to 200%** (on Pixel)
  and added **nonlinear scaling**: large text grows less than small text, to
  keep hierarchy and avoid clipping. Google tells developers to test at 200%
  ([Android 14 features](https://developer.android.com/about/versions/14/features)).
  Flutter adopted nonlinear scaling through `TextScaler`
  ([Flutter breaking-change note](https://docs.flutter.dev/release/breaking-changes/android-14-nonlinear-text-scaling-migration)).

**Working assumption:** about 1 in 4 or 5 users run above default size. A
noticeable minority run *below* it. Every screen has to hold at 2.0×. The
project's own 2026-10-05 responsiveness run already tests 1.3× and 2.0×
(CLAUDE.md), which matches this.

---

## 4. Why privacy and security tools feel intimidating, and what fixes it

### 4.1 The evidence base

- **Why Johnny Can't Encrypt** (Whitten & Tygar, USENIX Security 1999).
  Given 90 minutes, **only 4 of 12** participants could sign and encrypt an
  email with PGP 5.0. The authors trace the failure to UI that expected users
  to understand the security model
  ([paper](https://people.eecs.berkeley.edu/~tygar/papers/Why_Johnny_Cant_Encrypt/USENIX.pdf)).
- **Tor Browser.** In Norcie et al. (Why Johnny Can't Blow the Whistle),
  users could not tell Tor Browser apart from their normal browser, and the
  slow launch was a "stop-point". The Tor Project changed both, and stop-points
  fell significantly in a follow-up study
  ([paper](https://www.freehaven.net/anonbib/cache/usableTor.pdf)). Gallagher
  et al. (CCS 2018) had **19 non-experts** use Tor Browser for a week. They
  reported broken sites, latency, missing conveniences, wrong geolocation and
  **"operational opacity"**: they could not see what the tool was doing
  ([NYU record](https://nyuscholars.nyu.edu/en/publications/peeling-the-onions-user-experience-layer-examining-naturalistic-u)).
- **Warning fatigue.**
  - *Crying Wolf* (Sunshine et al., USENIX Sec 2009): better SSL warnings
    helped, but "far too many" participants still clicked through. The
    authors recommend removing benign warnings and blocking the dangerous
    cases outright
    ([paper](https://www.usenix.org/legacy/event/sec09/tech/full_papers/sunshine.pdf)).
  - Krol, Moroz & Sasse (2012): all 120 participants noticed a download
    warning, and **81.7% downloaded anyway**. A short generic warning and a
    long specific one made no difference, and the stated cause was
    desensitisation from false alarms
    ([ResearchGate](https://researchgate.net/publication/261487657_Don't_work_Can't_work_Why_it's_time_to_rethink_security_warnings)).
  - Anderson, Vance, Kirwan et al. used fMRI and found that visual
    processing of a warning drops sharply **after the second exposure**, and
    keeps falling over a workweek. *Polymorphic* warnings (varied appearance)
    resisted this
    ([CHI 2017](https://dl.acm.org/doi/10.1145/3025453.3025896)).
- **Security fatigue** (Stanton et al., NIST, 2016). Users described
  "resignation, loss of control, fatalism, risk minimization, and decision
  avoidance", and more than half felt "overwhelmed and bombarded"
  ([NIST](https://www.nist.gov/publications/security-fatigue)).
- **Fear appeals backfire without efficacy.** Under Witte's EPPM, fear
  without a clear, doable action leads to fear-control (denial, avoidance)
  rather than danger-control. In security studies, efficacy predicts
  behaviour roughly three times more strongly than threat
  ([Renaud & Dupuis, "Cyber Security Fear Appeals"](http://faculty.washington.edu/marcjd/articles/fear-appeals.pdf);
  [JMIS 2023 meta-analysis](https://www.tandfonline.com/doi/abs/10.1080/07421222.2023.2267318);
  [Tannenbaum et al. 2015, APA](https://www.apa.org/pubs/journals/releases/bul-a0039729.pdf)).

### 4.2 What works

- **Opinionated design.** Felt et al. (CHI 2015) made "Back to safety" the
  prominent action on Chrome's SSL warning and moved "proceed" under
  Advanced. Adherence rose **from 31% to 58%** in a controlled experiment and
  **from 37% to 62%** in the field. Comprehension stayed low (<50% could name
  the threat source), so the visual hierarchy did the work and the copy did
  not ([paper](https://adrifelt.github.io/sslinterstitial-chi.pdf)).
- **Safe by default, quiet when fine.** Chrome removed its green "Secure"
  label in 2018 because "users should expect that the web is safe by default"
  and are warned "only when there's an issue"
  ([Chromium blog](https://blog.chromium.org/2018/05/evolving-chromes-security-indicators.html)).
- **Notify, don't block.** Signal moved key changes to an advisory mode after
  users said they wanted "to know when this occurs, but not necessarily be
  blocked by it" ([Signal, 2016](https://signal.org/blog/safety-number-updates/)).
  Key verification in messengers is still a cautionary tale. In
  Vaziripour et al.'s 2017 comparison of WhatsApp, Viber and Facebook
  Messenger, only **14%** verified keys without extra explanation. Their 2018
  follow-up added an explicit "Action needed" prompt to Signal, which
  significantly cut the time to find and complete verification
  ([SOUPS 2018](https://www.usenix.org/system/files/conference/soups2018/soups2018-vaziripour.pdf)).
- **Positive, progress-shaped framing.** 1Password presents Watchtower as a
  score that "climbs" as you fix issues and offers "peace of mind … bragging
  rights", not as a list of failures
  ([1Password blog, 2022](https://1password.com/blog/improve-watchtower-score-1password)).
- **Progressive disclosure.** Show the few important options and leave the
  rest for a request (NN/g, Nielsen 2006)
  ([NN/g](https://www.nngroup.com/articles/progressive-disclosure/)). For
  Container, that means route, proxy credentials and filter categories belong
  a layer down, not on the first screen.

---

## 5. How people misunderstand "private" browsing

Users bring an *incognito* mental model to anything that says "private" or
"container". The data shows that model over-promises.

**Wu et al., "Your Secrets Are Safe" (WWW 2018)** tested 460 participants
across 13 browser disclosures
([paper PDF](https://www.blaseur.com/papers/www18privatebrowsing.pdf)).
Participants who saw the disclosure still believed:

- **56.3%**: that searches are not saved by Google while logged in
- **46.5%**: that bookmarks saved in private mode disappear (inflated by a
  survey typo)
- **40.2%**: that websites cannot estimate their location
- **37.0% / 22.6% / 22.0%**: that their **employer / government / ISP** cannot
  track them
- **27.1%**: that private mode protects better against **viruses and malware**
- **25.2%**: that sites cannot see their **IP address**

Some reasoning ran "nothing is stored, so nothing can be seen", and some
assumed **built-in VPN** behaviour. Only Chrome desktop's disclosure improved
accuracy over the control. Loaded names (Opera's "protection") appeared to
*add* misconceptions.

**DuckDuckGo (Jan 2017, n = 5,710 US adults).**
**76%** of private-mode users could not identify what it protects, and
**66.5%** of those overestimated it. **41%** believed it "prevents websites
from tracking me", and **36%** that it stops search engines knowing their
searches. **65.9%** of those with misconceptions felt "surprised, misled,
confused or vulnerable" when told
([DuckDuckGo study PDF](https://duckduckgo.com/download/Private_Browsing.pdf)).

**Habib et al., "Away From Prying Eyes" (SOUPS 2018).**
Observed browsing from 451 SBO participants plus a survey. Private mode did
meet the *local* need (other users of the device), but participants
overestimated protection from tracking and ads:

- **39%** thought it lets you browse **anonymously**
- **22%** thought it stops cookies being sent
- **12% (SBO) and 5% (MTurk)** expected protection from malware or hacking
- **20–24%** of private-mode shoppers thought it protected their card details

([paper](https://www.andrew.cmu.edu/user/nicolasc/publications/H+-SOUPS18b.pdf))

**Brown v. Google (settled April 2024).** Google agreed to delete or
de-identify billions of private-browsing records, keep third-party cookies
blocked by default in Incognito, and rewrite its disclosure. Class members got
no payout
([Washington Post](https://www.washingtonpost.com/technology/2024/04/01/google-incognito-data-lawsuit-settlement/);
[Dark Reading](https://www.darkreading.com/cyber-risk/google-settles-lawsuit-tracking-private-browsing-users)).
The new Chrome text (Canary 122) reads: *"Others who use this device won't see
your activity, so you can browse more privately. This won't change how data is
collected by websites you visit and the services they use, including Google.
Downloads, bookmarks and reading list items will be saved."*
([Android Authority](https://www.androidauthority.com/incognito-mode-disclaimer-3403968/);
[The Register](https://www.theregister.com/2024/01/17/google_updates_chrome_incognito_disclaimer/)).
The pattern to borrow is **one sentence on what it protects against and one on
what it does not**, in plain words, naming the actors.

Relevance to Container: a "Direct" site in its own container hides nothing
from the ISP or employer network, and "Wipe on exit" does not stop a site
recognising the IP. The redesign's friendlier tone must not widen the gap
between what users believe and what the tool does. Plain "who can see this"
statements per route (Direct / proxy / Tor) are the evidence-backed remedy.

---

## 6. Dark mode vs light mode

- **Light mode is easier to read for people with normal vision.** NN/g
  (Budiu, 2020) summarises the evidence: positive polarity (dark text on
  light) wins on acuity and proofreading for young (18–33) and older (60–85)
  adults, and **the advantage grows as font size shrinks**. People with
  cataracts or cloudy ocular media can do better in dark mode. NN/g recommends
  light by default with a dark option for general audiences
  ([NN/g](https://www.nngroup.com/articles/dark-mode/);
  [Piepenbrock et al., Ergonomics 2013](https://www.researchgate.net/publication/236662424_Positive_display_polarity_is_advantageous_for_both_younger_and_older_adults);
  [Piepenbrock et al., Human Factors 2014: "particularly advantageous for
  small character sizes"](https://journals.sagepub.com/doi/abs/10.1177/0018720813515509)).
  The mechanism: brighter screens contract the pupil and sharpen the retinal
  image.
- **What users prefer.** NN/g's 2023 survey of 115 mobile users found about
  one-third dark, one-third light and one-third switching. Users think of
  dark mode as a *system* setting, not a per-app one
  ([NN/g: Dark mode — how users think about it](https://www.nngroup.com/articles/dark-mode-users-issues/)).
  An Android Authority reader poll (2020, 2,514 votes) found **81.9%** use dark
  mode and 9.9% switch, but that audience is enthusiasts
  ([Android Authority](https://www.androidauthority.com/dark-mode-poll-results-1090716/)).
- **Implication.** CLAUDE.md currently says "dark theme only". The evidence
  supports *following the system setting*, light and dark, for a mainstream
  audience. If dark stays the only theme, then small mono captions are where
  it hurts most, and body text must grow (≥16sp) and avoid thin weights. That
  is a product decision for the user, not something this research can settle.

---

## Transferable takeaways

1. **Every tappable thing is ≥ 48 × 48dp with ≥ 8dp between targets.** That
   includes ×, ⋯, chips and row icons. The WCAG 2.5.8 floor of 24px is not
   the bar.
2. **Body text is 16sp/24 (M3 Body Large); nothing users must read is below
   12sp.** Mono or "technical" text is ≥ 14sp, or hidden behind disclosure.
3. **Text contrast is ≥ 4.5:1, and every icon, switch track, field border and
   divider that carries meaning is ≥ 3:1.** Hairlines that separate rows and
   carry information fail 1.4.11 if they are 1px white at low alpha. Check
   with APCA as well: Lc ≥ 75 for body text on dark.
4. **Test every screen at 2.0× font scale (Android 14 maximum) and 320dp
   wide.** Expect 20–30% of users above default. Nothing clips; rows grow
   (56/72/88dp minimums, no fixed heights).
5. **Use the M3 shape scale.** 12–16dp for cards and sheets, 28dp for dialogs
   and bottom sheets, full radius for pills and chips. No sharp 0–4dp
   containers on primary surfaces.
6. **Use spring motion.** Standard (damped, ~0.9 / 700) for navigation and
   sheets. Effects springs never bounce. Keep bounce for one or two
   moments of delight. Respect reduced-motion.
7. **Default to calm. Show state only when it is abnormal** (Chrome's "safe by
   default" rule). A healthy route needs no badge; a refused one gets a single
   clear, opinionated primary action. That fits the existing jade rule.
8. **Every warning names one concrete action the user can take** (efficacy
   beats threat by ~3×). No warning without a button that resolves it.
9. **Make the safe choice visually dominant and push the risky one into a
   secondary "More options" layer.** Opinionated design took adherence from
   31% to 58%.
10. **Each privacy mode gets a two-sentence, actor-named disclosure:** "Hidden
    from: … / Still visible to: …" (ISP, employer Wi-Fi, the site itself).
    This targets the measured misconceptions about ISP (22%), employer (37%),
    malware (27%) and IP (25%).
11. **Keep repeated warnings rare and varied.** Habituation sets in by the
    second exposure. Do not show the same banner on every open.
12. **Follow the system light/dark setting if the product allows it**
    (positive polarity is more legible, especially for small text). If dark
    stays the only theme, compensate with larger text and medium weights,
    never thin light-on-dark mono.
