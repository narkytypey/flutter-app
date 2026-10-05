# 03 — Craft outliers: what the best-crafted privacy/tool brands do

Research for the Container visual-identity redesign (logo, palette, type, density) aimed at mainstream users. Compiled 2026-10-05. Every claim carries its source inline. Values marked **(unverified)** come from third-party design-token scrapers or aggregators (refero, Brandfetch-style sites, design-analysis blogs), not from the brand owner. Treat them as close, not authoritative.

Constraint to keep in mind throughout: Container can only **bundle** fonts under OFL or Apache, and makes no network requests of its own, so nothing here can be fetched at runtime.

---

## 1. Arc and Dia (The Browser Company)

**Palette.** Arc's marketing canvas is a warm off-white, "Arc Offwhite" `#FFFCEC`, with one saturated blue `#3139FB` used as a full-bleed band ([shadcn.io/design/arc](https://www.shadcn.io/design/arc), [dembrandt.com/explorer/arc](https://www.dembrandt.com/explorer/arc); **unverified**, scraped). The logo is a swooping arc in a purple-to-coral gradient, roughly `#6B4EFF` to `#FF6B4E` ([designyourway.net](https://www.designyourway.net/blog/arc-browser-logo/); **unverified**). Dia's visual language "lives almost entirely in black and white with surgical chromatic accents", and its logo was refreshed in 2025 to a "Sunglow Yellow" ([styles.refero.design, Dia](https://styles.refero.design/style/b458ca1a-70f0-4f85-b745-f879a4d08457); **unverified**).

**Type.** Arc uses Marlin Soft SQ (commercial) for display and Inter for UI. The hero is Marlin Soft SQ 700 with tight negative tracking ([shadcn.io/design/arc](https://www.shadcn.io/design/arc); **unverified**). Dia uses ABC Oracle (commercial, Dinamo) for body at weights 300–400, with an ultra-condensed display face for headlines ([refero, Dia](https://styles.refero.design/style/b458ca1a-70f0-4f85-b745-f879a4d08457); **unverified**). Neither display face can be bundled. Inter is the open-licence part.

**Calm and trust (Dia's design strategy, first-party).** The Browser Company's own write-up is the most useful source here ([browsercompany.substack.com](https://browsercompany.substack.com/p/the-strategy-behind-dias-design)):
- **"10am on a Tuesday" rule:** anyone should be able to switch mid-workday without learning anything new.
- **A "novelty budget":** familiar UI stays plain, and expressive colour and motion are spent only on the genuinely new feature (Chat).
- **Hide secondary controls:** bookmark and site-settings buttons appear only on hover, to keep "a sense of calmness in the core UI".
- **One way to do each task**, so there is no duplicate UI.
- **No update banners:** the app updates in the background.
- **Page colour extended into the active tab** so the chrome and the content read as one surface.
- **Readable titles:** page titles are shown instead of raw URLs, with the full URL on hover.

**Motion.** Dia animates the most-used UI (the Assistant Bar) fluidly, and a brand animation "swells into the view" when Chat opens ([same source](https://browsercompany.substack.com/p/the-strategy-behind-dias-design)). Arc's onboarding is known for its polish ([saasui.design](https://www.saasui.design/pattern/onboarding/arc-browser)), but no first-party motion specs were found.

**Transferable to Container:**
- Spend novelty only on what is new here: per-site isolation and the shield. Keep the address bar, tabs and back button boringly familiar.
- Tint the chrome from the page or the site, which suits a per-site container identity.

## 2. Zen Browser

Zen is an open-source Firefox fork from 2024 that took on Arc's layout ideas ([Wikipedia](https://en.wikipedia.org/wiki/Zen_Browser)).

**Logo.** Three concentric circles that get thinner toward the centre, after the raked patterns of a zen garden. A designer critique notes that "a bunch of circles in a quite minimalistic style" is not distinctive at small sizes ([havn.blog](https://havn.blog/2024/12/12/i-tried-to.html)). That is a cautionary tale for any abstract mark.

**Palette and theming.** The accent is user-set (`zen.theme.accent-color`), and gradient backgrounds are on by default (`zen.theme.gradient`) ([docs.zen-browser.app](https://docs.zen-browser.app/guides/about-config-flags)). Each Workspace gets a name, a colour or emoji, and its own background gradient ([supasidebar.com](https://supasidebar.com/blog/zen-browser-features-guide-2026); [deepwiki theme system](https://deepwiki.com/zen-browser/desktop/3.2-theme-system-and-customization)).

**Transferable to Container:** give each workspace (or site) its own colour or monogram so users can tell at a glance which isolated context they are in. This is an identity cue, not decoration.

## 3. Proton (Mail / VPN / Pass)

**Palette.** Proton Purple is `#6D4AFF` (RGB 109, 74, 255) ([brandcolorcode.com](https://www.brandcolorcode.com/protonmail); [Brandfetch](https://brandfetch.com/proton.me)). Purple has been Proton's colour since 2014, and the rebrand made it "bolder and more vibrant" and "compatible with light and dark backgrounds" ([proton.me/blog/new-visual-universe](https://proton.me/blog/new-visual-universe)). Each product has an accent: green for VPN, blue for Calendar, red for Drive. Each product icon "starts with the Proton purple and then fades into the service color" ([same](https://proton.me/blog/new-visual-universe)).

**Type.** The brand face is **ABC Arizona** by Elias Hanzer (Dinamo, commercial): its Sans style for text and its Flare style for headlines. Proton chose it because "our font should have a more human touch", against tech's usual bold sans ([proton.me blog](https://proton.me/blog/new-visual-universe); [Brandfetch blog](https://brandfetch.com/blog/proton-new-logo-and-brand)). Inside the products, the web apps (Mail, Calendar, Drive, Pass) use **Inter** ([rsms/inter discussion #664](https://github.com/rsms/inter/discussions/664), Dec 2023). So Proton pairs a warm brand face for marketing with Inter for UI.

**Logo.** A stylised "P" with a shadow and a hidden 3D "entrance". The P stands for "the alternative path", and the services are "portals" ([Brandfetch blog](https://brandfetch.com/blog/proton-new-logo-and-brand)). The mark also alludes to encryption keys ([proton.me](https://proton.me/blog/new-visual-universe)). The product icons keep their heritage shapes: VPN stays triangular, and Mail derives from the bottom half of the old padlock ([same](https://proton.me/blog/new-visual-universe)).

**Calm and trust.** Proton presents privacy as human and accessible rather than technical, through its typeface choice, warm gradients and people-first copy ([same](https://proton.me/blog/new-visual-universe)).

**Radii and elevation.** No first-party token documentation was found, so these are left open rather than guessed.

**Transferable to Container:**
- A single master hue, with sub-accents derived from it by gradient, is a proven way to run a family: workspaces, security levels, Tor.
- A warm humanist face can carry trust better than a cold grotesk.

## 4. Mullvad VPN

**Palette (first-party).** Mullvad's press page lists the brand colours ([mullvad.net/en/press](https://mullvad.net/en/press)):
- Blue `#294D73`
- Dark Blue `#192E45`
- Green `#44AD4D`
- Red `#E34039`
- Yellow `#FFD524` (the logo's helmet)
- Brown `#D2943B` (the logo's fur)
- Beige `#FFCD86` (the logo's nose)

**Type.** Open Sans for body copy, and Source Sans Pro (now Source Sans 3) for headlines and buttons. Both are OFL ([mullvad.net/en/press](https://mullvad.net/en/press)).

**Logo.** A mole in a yellow helmet ("mullvad" is Swedish for mole), an illustrated character rather than an abstraction ([Wikipedia](https://en.wikipedia.org/wiki/Mullvad)). It reads at small sizes because of the yellow helmet's silhouette.

**Calm and trust.** A dark navy field, with green and red reserved strictly for connection state. In the app, green means secured and red means unsecured (observed in the app, consistent with the brand palette above; **no first-party UI spec found**). Mullvad's restraint is the brand: there are no accounts and no marketing flourish.

**Transferable to Container:**
- A dark blue-black base with semantic-only green and red maps directly onto Container's existing rule that jade means live state.
- A mascot can be friendlier than an abstract shield, but it is harder to keep crisp at 16 px.

## 5. Signal

**Palette.** Signal Blue is `#3A76F0`, with `#2C6BED` for pressed states ([brandcolorcode.com](https://www.brandcolorcode.com/signal); [blakecrosley.com](https://blakecrosley.com/guides/design/signal)). The neutrals below come from a third-party analysis (**unverified**: [blakecrosley.com](https://blakecrosley.com/guides/design/signal)):
- Dark mode: background `#1B1B1B`, surface `#2B2B2B`, primary text `#E9E9E9`, secondary text `#A5A5A5`.
- Light mode: surface `#F6F6F6`, secondary text `#5E5E5E`.

**Type.** **Inter** is Signal's brand typeface. The marketing site uses weights 400, 600 and 800, with 800 for display ([shadcn.io/design/signal](https://www.shadcn.io/design/signal); [mobbin](https://mobbin.com/colors/brand/signal); **unverified**). The Android app itself uses the system font (Roboto), as far as is known (**unverified**).

**Radii, shadow and sizes.** These are also from [blakecrosley.com](https://blakecrosley.com/guides/design/signal) (**unverified**):
- Message bubbles are asymmetric, `18 18 4 18` px.
- The shadow is barely there: `0 1px 2px rgba(0,0,0,.08)`.
- Meta text is 11–13 px.

**Logo.** A speech bubble ringed by a broken (dashed) circle. Its minimum size is 26×26 px, and it must not be rotated, outlined or given effects ([signal.org/brand](https://signal.org/brand/)).

**Calm and trust.** The theme is "absence as a trust signal": no read receipts, no online status and no typing indicators by default. Verification uses plain language ("if these numbers match…") with no cryptographic terms, and safety numbers are shown in groups of five ([blakecrosley.com](https://blakecrosley.com/guides/design/signal)).

**Icons.** Simple outline icons with no gradients ([same](https://blakecrosley.com/guides/design/signal)).

**Transferable to Container:**
- Explain security in plain words.
- Group technical strings for scanning (Container's mono hosts already do this).
- A ring motif around a core shape reads well at small sizes.

## 6. Tailscale

**Palette.** All values are **unverified**, scraped by [refero](https://styles.refero.design/style/5b679fb6-8d53-402d-a77b-c88bfb397623) and corroborated by [characterquilt](https://www.characterquilt.com/branding/tailscale).
- Neutrals: Ink `#181717` (text; never pure `#000`), Bone `#EEEBEA` (canvas), Linen `#F7F5F4`.
- Greys: Charcoal `#575555`, Ash `#706E6D`.
- Accent: Signal Red `#D04841`, used rarely.
- A Network Blue gradient (`#5A82DE` to `#324994`) appears in product UI only.

**Type.** **Inter** at weights 300–600. Headlines are 48–64 px at weight **300** (light, not bold), body is 16/400 and UI labels are 14/500. A custom mono-ish face, "MDIO", is used for small tracked labels (+0.043–0.05 em). The type scale is 12, 14, 16, 20, 32, 48 and 64 ([refero](https://styles.refero.design/style/5b679fb6-8d53-402d-a77b-c88bfb397623); **unverified**).

**Radii and shadow** (same source):
- Buttons 8 px, cards 16 px, hero cards 32 px, pills 9999 px. The rules say no 0 or 4 px cards.
- Shadows are warm-tinted from the ink colour: `rgba(24,23,23,.02) 0 4px 8px` and `rgba(24,23,23,.16) 0 4px 16px`.
- Spacing scale: 4, 8, 12, 16, 20, 24, 32, 48, 64.

**Icons.** Outline icons in Ink, 16–20 px ([same](https://styles.refero.design/style/5b679fb6-8d53-402d-a77b-c88bfb397623)).

**Logo.** A 3×3 grid of dots, some filled and some outlined ([streamlinehq](https://www.streamlinehq.com/icons/download/tailscale--31088); [Wikimedia](https://commons.wikimedia.org/wiki/File:Tailscale-Logo-Black.svg)). It reads as nodes in a mesh. No official explanation was found; a Tailscale blog post jokes about it in connection with Plan 9 ([tailscale.com](https://tailscale.com/blog/tailscale-enterprise-plan-9-support)). It is crisp at any size because it is built on a grid.

**Calm and trust.** The agency Together describes the original brand as "understated, minimal, and quietly confident", with white space kept central and colour, shape and motion "introduced with greater intention" ([together.agency](https://together.agency/work/tailscale/)). Security is made approachable rather than intimidating through warm paper tones and light-weight headlines.

**Transferable to Container:**
- Warm off-black instead of pure black (Container is dark-only, so read this as a warm near-black and warm greys).
- Light display weights.
- One rare accent colour.
- A grid-built mark that survives 16 px.

## 7. 1Password

**Palette.** The brand refresh names three colours: **Bits Blue**, **Intrepid Blue** (a navy) and **Biscuit** (a neutral beige). The primary blue was "desaturated a bit so it feels more tactile and almost denim-like", and the navy's "richness dialed up" ([1password.com/blog/1password-brand-refresh](https://1password.com/blog/1password-brand-refresh)). Hex values for those names were not published there. Aggregators give the primary blue as `#198CFF` and a Science Blue `#0364D3` ([logotyp.us](https://logotyp.us/logo/1password/); [mobbin](https://mobbin.com/colors/brand/agilebits); **unverified**, and possibly pre-refresh values).

**Type.** The wordmark uses the custom **Agile Sans**, "friendly and trustworthy… a dash of charm and just the right amount of quirkiness" ([1Password blog](https://1password.com/blog/1password-brand-refresh)). It is proprietary.

**Logo.** The refresh took the lock out of the wordmark and made the **keyhole** the logo itself, simplified so it flexes across uses ([same](https://1password.com/blog/1password-brand-refresh)). A keyhole in a circle reads at any size.

**Motion and delight.** The lock icon opens and "a series of multi-colored rings" burst out of it, a "portal into the human side of 1Password" ([same](https://1password.com/blog/1password-brand-refresh)). Illustration runs at four sizes (small, medium, large, extended), with textures, thin-line spot illustrations and "consistent tones of positivity, wonder, and quirkiness" ([same](https://1password.com/blog/1password-brand-refresh)).

**Transferable to Container:**
- Desaturate the hero colour so it feels tactile rather than neon.
- A single meaningful object (a keyhole there; a container or box here) as the whole mark.
- Reserve the burst of delight for the unlock moment.

## 8. Obsidian

**Palette.** Obsidian's purple is `#6C31E3` ([loftlyy](https://www.loftlyy.com/en/obsidian); [brandcolorcode](https://www.brandcolorcode.com/obsidian); **unverified**, since the official brand page publishes no hex: [obsidian.md/brand](https://obsidian.md/brand)).

**Type.** **Inter** only, in Regular, Medium and Semibold ([madegooddesigns](https://madegooddesigns.com/obsidian-font/); [blakecrosley](https://blakecrosley.com/guides/design/obsidian); **unverified**, but consistent with the app's default UI font).

**Logo.** A faceted gem "inspired by its namesake, the volcanic rock… used… to make arrowheads, scrapers, knives". The lockup is the purple mark with black or white text, and single-colour uses are all-black or all-white ([obsidian.md/brand](https://obsidian.md/brand)). The faceting gives it depth with flat fills, and its silhouette holds at icon size.

**Transferable to Container:**
- Three weights of one family (400, 500, 600) are enough for a whole app.
- A mark grounded in a physical object, here a sealed container, reads more warmly than an abstract one.

---

## 9. Open-licence typeface candidates for a mobile browser UI

Sizes below are the **variable TTF** from `google/fonts` `main`, measured by HTTP `Content-Length` on 2026-10-05 at `https://raw.githubusercontent.com/google/fonts/main/ofl/<family>/…`. Every family here lives in Google Fonts' `ofl/` directory, so each is **SIL OFL 1.1** and bundleable. A variable font covers regular, medium and semibold in one file. Three static weights are usually about 1.5–2× one variable file before subsetting. Subsetting to Latin plus Latin Extended typically cuts these sizes 50–80% (an estimate).

| Typeface | Licence | Variable TTF size | Legibility notes | Source |
|---|---|---|---|---|
| **Inter** (v4.1) | OFL | 857 KB (`Inter[opsz,wght]`, includes the Display optical sizes; large) | Tall x-height and open apertures, tuned for screens and small sizes. The `opsz` axis gives a Display cut at 32. Used by Signal, Obsidian, Tailscale and Proton's apps. Ubiquity is its downside: it looks generic. | [Wikipedia](https://en.wikipedia.org/wiki/Inter_(typeface)), [rsms/inter v4](https://github.com/rsms/inter/discussions/463) |
| **Figtree** | OFL | **61 KB** (`Figtree[wght]`) | Geometric but friendly, with clean, fairly large x-height. By far the smallest file. Container already bundles it, so keeping it costs nothing. | [google/fonts ofl/figtree](https://github.com/google/fonts/tree/main/ofl/figtree) |
| **Atkinson Hyperlegible Next** | OFL | 112 KB | Braille Institute, Feb 2025. Seven weights (up from two), 150+ languages, and character shapes deliberately differentiated (I/l/1, O/0) for low vision. A Mono companion exists. Strongest accessibility story for a mainstream audience. | [Braille Institute](https://www.brailleinstitute.org/about-us/news/braille-institute-launches-enhanced-atkinson-hyperlegible-font-to-make-reading-easier/), [prnewswire](https://www.prnewswire.com/news-releases/braille-institute-launches-enhanced-atkinson-hyperlegible-font-to-make-reading-easier-302371657.html) |
| **Public Sans** | OFL | 101 KB | US Web Design System (USWDS). Neutral, strong and sober, with a "government-grade trustworthy" connotation. | [google/fonts ofl/publicsans](https://github.com/google/fonts/tree/main/ofl/publicsans) |
| **Manrope** | OFL | 161 KB | Semi-condensed and geometric, with a large x-height. Feels modern and techy, and is compact for dense lists. | [google/fonts ofl/manrope](https://github.com/google/fonts/tree/main/ofl/manrope) |
| **Geist** / **Geist Mono** | OFL | 165 KB / 168 KB | Vercel's Swiss-style grotesk with a matched mono, so one family covers both UI and technical text. Large x-height. | [google/fonts ofl/geist](https://github.com/google/fonts/tree/main/ofl/geist) |
| **Instrument Sans** | OFL | 190 KB (with a width axis) | Contemporary and slightly warm; the `wdth` axis can tighten dense rows. | [google/fonts ofl/instrumentsans](https://github.com/google/fonts/tree/main/ofl/instrumentsans) |
| **DM Sans** | OFL | 235 KB (opsz + wght) | Low-contrast geometric with optical sizes, soft and friendly. | [google/fonts ofl/dmsans](https://github.com/google/fonts/tree/main/ofl/dmsans) |
| **Source Sans 3** | OFL | 631 KB | Humanist, very readable for long text. Mullvad's headline face. Large file. | [mullvad.net/en/press](https://mullvad.net/en/press), [google/fonts](https://github.com/google/fonts/tree/main/ofl/sourcesans3) |
| **Lexend** | OFL | 172 KB | Designed for reading fluency, with wide spacing. Takes more width per row. | [google/fonts ofl/lexend](https://github.com/google/fonts/tree/main/ofl/lexend) |
| **IBM Plex Sans** | OFL | 525 KB (wdth + wght) | Engineered and corporate. Pairs natively with Plex Mono, which Container already bundles. | [google/fonts ofl/ibmplexsans](https://github.com/google/fonts/tree/main/ofl/ibmplexsans) |
| **Space Grotesk** | OFL | 133 KB | Quirky display grotesk. Too characterful for body text; possible for a wordmark. | [google/fonts ofl/spacegrotesk](https://github.com/google/fonts/tree/main/ofl/spacegrotesk) |

**Monospace options for hosts, routes and PINs:**
- **IBM Plex Mono:** 132 KB for the static Regular alone. It is already bundled.
- **JetBrains Mono:** 183 KB, variable. Tall x-height and clear 0/O and 1/l.
- **Geist Mono:** 168 KB, variable.
- **Atkinson Hyperlegible Mono:** the most legible of the four for low vision.

Sources: [google/fonts ofl/jetbrainsmono](https://github.com/google/fonts/tree/main/ofl/jetbrainsmono) and [Braille Institute](https://www.brailleinstitute.org/freefont/).

**Proprietary faces to rule out:**
- Proton's ABC Arizona, Dia's ABC Oracle and Arc's Marlin Soft SQ (Dinamo and other commercial foundries).
- 1Password's Agile Sans (custom).
- Tailscale's MDIO (custom).

---

## 10. Cross-cutting patterns

- **One hero hue, desaturated or warmed.** Proton made its purple brighter but legible on dark ([source](https://proton.me/blog/new-visual-universe)). 1Password went the other way and "denim-like", desaturated ([source](https://1password.com/blog/1password-brand-refresh)). Tailscale uses its red rarely ([source](https://styles.refero.design/style/5b679fb6-8d53-402d-a77b-c88bfb397623)). None of them floods the UI with the brand colour.
- **Warm neutrals instead of pure black or white.** Tailscale's `#181717`, and Arc's and Dia's cream ([refero](https://styles.refero.design/style/5b679fb6-8d53-402d-a77b-c88bfb397623), [shadcn arc](https://www.shadcn.io/design/arc)).
- **Inter is the default UI face for the whole cohort** (Signal, Obsidian, Tailscale, Proton's apps, Arc's UI). Distinctiveness comes from a brand display face or from the mark, not from the UI font.
- **Security is made calm by subtraction.** Signal leaves out status signals, Dia hides secondary buttons, and Tailscale relies on white space ([Signal](https://blakecrosley.com/guides/design/signal), [Dia](https://browsercompany.substack.com/p/the-strategy-behind-dias-design), [Together](https://together.agency/work/tailscale/)).
- **Marks are physical metaphors**: obsidian rock, keyhole, mole, P-as-portal, speech bubble. The abstract marks are the weaker ones; Zen's circles are criticised as indistinct at small sizes ([havn.blog](https://havn.blog/2024/12/12/i-tried-to.html)).
- **Delight lives at one threshold moment**: 1Password's lock opening into rings, Dia's swell on opening Chat. It is not spread everywhere.
- **Outline icons** around 16–20 px for Signal and Tailscale. No stroke widths were published first-party; 1.5 px at 24 px is the common convention (**assumption**).

## Transferable takeaways

1. **Keep a single-hue identity and use it rarely.** Container's jade-only-for-live-state rule already matches the best of this cohort. Desaturate or warm the hero hue rather than going neon (1Password, Tailscale).
2. **Swap pure black and grey for warm near-blacks and warm greys** (Tailscale's `#181717` logic applied to a dark-only theme). It reads calmer and more human.
3. **The UI font matters less than consistency.** Figtree, already bundled and only 61 KB variable, is a sound choice. If mainstream legibility is the priority, **Atkinson Hyperlegible Next** (112 KB, OFL, 7 weights) is the most defensible upgrade. Inter is safe but generic and heavy (857 KB variable).
4. **Use three weights at most** (400, 500, 600), as Obsidian does. Use light display weights for big headings, as Tailscale does, for a calm rather than shouting tone.
5. **Pair the sans with one monospace** for hosts, routes and PINs. Plex Mono is already bundled; Geist plus Geist Mono or Atkinson Next plus Atkinson Mono are matched-family alternatives.
6. **Build the logo from a physical metaphor that survives 16 px**: a sealed box or nested container, a keyhole-like single object, or a grid-built mark like Tailscale's dots. Avoid thin concentric strokes, the lesson from Zen's logo.
7. **Spend a "novelty budget"** (Dia). Keep browsing chrome familiar, and put colour and motion only where Container is new: isolation, the shield (`6c`) and the Tor or security level.
8. **Earn trust by subtraction and plain words** (Signal). Hide secondary controls, explain protection in sentences and not jargon, and group technical strings for scanning.
9. **Give each workspace or site a distinct colour or monogram** (Zen's workspaces, Proton's purple-to-service gradients), so users always know which isolated context they are in.
10. **Put one moment of delight at the unlock threshold** (1Password's lock opening into rings), and keep everything else still. Use soft radii (8 px controls, 16 px sheets) and barely-there shadows rather than cards, in line with Container's hairline rule.
