# 01 — Market share and the major browsers' design conventions

Research for the Container redesign aimed at mainstream users. Compiled 2026-10-05.
Every claim carries its source. Values marked **(uncertain)** come from
third-party colour/logo sites, from press screenshots, or from inference, and
should be checked on a device before they are relied on.

---

## 1. Market share

### 1.1 Mobile, worldwide

| Browser | StatCounter, Sept 2026 | Cloudflare Radar, 2025 (all devices) |
|---|---|---|
| Chrome | 67.64% | ~66% ("two-thirds") |
| Safari | 24.71% | 15.4% |
| Samsung Internet | 3.50% | 2.3% |
| Opera | 1.38% | — |
| UC Browser | 0.78% | — |
| Firefox | 0.69% | 3.7% (all devices) |
| Edge | — | 7.4% (all devices, desktop-heavy) |

- StatCounter mobile, worldwide, September 2026: https://gs.statcounter.com/browser-market-share/mobile/worldwide
- Cloudflare Radar 2025 Year in Review (request traffic, all platforms): https://blog.cloudflare.com/radar-2025-year-in-review/
- Mobile OS split, StatCounter Sept 2026: **Android 69.17%, iOS 30.81%** — https://gs.statcounter.com/os-market-share/mobile/worldwide

### 1.2 Desktop, worldwide (StatCounter, Sept 2026)

Chrome 65.09%, Edge 14.64%, Safari 8.06%, Firefox 6.11%, Opera 2.38%, Brave 1.12% —
https://gs.statcounter.com/browser-market-share/desktop/worldwide

Cloudflare's 2025 review gives the Windows-only picture: **Chrome 69%, Edge 19%**, despite Edge being Windows' default —
https://blog.cloudflare.com/radar-2025-year-in-review/

A third source, W3Counter (Sept 2026, all platforms), reports Chrome 83.8%, Safari 5.0%, IE/Edge 1.7%, Firefox 1.0%, Opera 0.2% —
https://www.w3counter.com/globalstats.php. Its Safari figure is far below
the other two sources; W3Counter's sample (sites running its tracker) skews
it, so treat it as an outlier that confirms only Chrome's dominance.

### 1.3 Android only

Cloudflare Radar 2025: **on Android, 85% of requests are from Chrome; Samsung Internet is second with 6.6%.** On iOS, Safari 79% vs Chrome 19% —
https://blog.cloudflare.com/radar-2025-year-in-review/

StatCounter does not publish a ready-made Android-only browser table; its
Samsung Internet share (3.5% of all mobile) divided by Android's 69% of
mobile gives roughly **5% of Android** — consistent with Cloudflare's 6.6%
(derived, uncertain).

### 1.4 Mobile by region (StatCounter, Sept 2026)

| Region | Chrome | Safari | Samsung Internet | Next |
|---|---|---|---|---|
| North America | 48.15% | 45.91% | 3.25% | Firefox 1.19% |
| Europe | 62.79% | 28.01% | **5.45%** | Firefox 1.11%, Opera 1.07% |
| Asia | 76.28% | 16.13% | 2.6% | UC 1.52%, Opera 1.51% |

Sources: https://gs.statcounter.com/browser-market-share/mobile/north-america ,
https://gs.statcounter.com/browser-market-share/mobile/europe ,
https://gs.statcounter.com/browser-market-share/mobile/asia .
Cloudflare notes Russia as the outlier, where Yandex Browser reached 33% vs Chrome's 44% —
https://blog.cloudflare.com/radar-2025-year-in-review/

### 1.5 Who a mainstream Android user is arriving from

- **Overwhelmingly Chrome** (~85% of Android traffic). Chrome's layout,
  iconography and gestures are the de facto mental model.
- **Samsung Internet is the only other material source** (~5–7% of Android,
  higher in Europe), and it is the default on Galaxy phones.
- **iPhone switchers bring Safari habits** (bottom/compact bar, glassy
  chrome, Private tab section). In North America iOS is close to half of
  mobile browsing, so a meaningful share of new Android users have
  Safari muscle memory.
- Firefox, Opera and Edge each sit at ~1% or below on mobile; their users
  are already privacy- or feature-minded and not the "bounce" audience.

---

## 2. Design facts per browser

### 2.1 Chrome for Android

- **Address bar position.** Top by default; a bottom option rolled out to stable from June 2025. Long-press the bar → "Move address bar to bottom", or Settings › Address bar. Moving it moves the tab switcher, overflow menu and shortcuts too —
  https://9to5google.com/2025/06/24/chrome-bottom-address-bar-android/ ,
  https://techcrunch.com/2025/06/24/chrome-for-android-now-lets-you-move-the-address-bar-to-the-bottom-too
- **Toolbar layout (phone).** One bar: home (optional), the address pill
  (with a site-info icon), an optional contextual button, the tab-count square,
  and ⋮. Chromium sources define the bar as **56dp** (`toolbar_height_no_shadow` = `default_action_bar_height` = 56dp; `location_bar_height` 56dp) and the
  visible location pill as a **40dp-high pill** (comment "40dp height pill to match location bar", with a 20dp corner radius) —
  https://chromium.googlesource.com/chromium/src/+/refs/heads/main/chrome/browser/ui/android/omnibox/java/res/values/dimens.xml ,
  https://chromium.googlesource.com/chromium/src/+/refs/heads/main/components/browser_ui/styles/android/java/res/values/dimens.xml ,
  https://chromium.googlesource.com/chromium/src/+/refs/heads/main/chrome/browser/ui/android/toolbar/java/res/values/dimens.xml
- **Touch targets.** `min_touch_target_size` = **48dp**; optional toolbar buttons are 52dp wide; toolbar icons 24dp —
  https://chromium.googlesource.com/chromium/src/+/refs/heads/main/components/browser_ui/styles/android/java/res/values/dimens.xml ,
  https://chromium.googlesource.com/chromium/src/+/refs/heads/main/chrome/browser/ui/android/toolbar/java/res/values/dimens.xml
- **Tab switcher.** A two-column **grid of cards** with page thumbnails; cards have a **24dp** background radius, thumbnails 12dp (top)/20dp (bottom), group dialogs 24dp —
  https://chromium.googlesource.com/chromium/src/+/refs/heads/main/chrome/android/features/tab_ui/java/res/values/dimens.xml .
  Since the Material 3 Expressive update (Chrome 141, complete late Oct 2025) the "+" sits in a rounded square on a Dynamic Color background, and the Tabs / Incognito / Groups switcher marks the current section with a rounded-square container; groups are tinted with their chosen colour; buttons were **not** enlarged —
  https://9to5google.com/2025/10/26/chrome-141-android-m3-expressive-redesign/
- **Other radii.** Omnibox suggestion backgrounds 16dp; Custom Tabs sheet 16dp —
  https://chromium.googlesource.com/chromium/src/+/refs/heads/main/chrome/browser/ui/android/omnibox/java/res/values/dimens.xml ,
  https://chromium.googlesource.com/chromium/src/+/refs/heads/main/chrome/android/java/res/values/dimens.xml
- **Colour.** Chrome's UI chrome uses Material You **Dynamic Color** from the
  wallpaper, not brand colours (9to5Google above). The logo uses Google's four
  brand colours, commonly given as #4285F4 / #EA4335 / #FBBC05 / #34A853
  **(uncertain — widely cited, no official Chrome page found)**.
- **Typeface.** Chrome's UI styles reference an `accent_font` resource and
  "google-sans-text-medium" for links —
  https://chromium.googlesource.com/chromium/src/+/refs/heads/main/components/browser_ui/styles/android/java/res/values/styles.xml .
  In practice Google Sans / Google Sans Text for headings and Roboto (system)
  for body **(uncertain — exact mapping not confirmed)**.
- **Incognito.** Always a dark theme regardless of system mode —
  https://www.androidheadlines.com/2021/04/google-chrome-incognito-mode-native-dark-theme.html .
  Commonly cited palette #202124 / #282C2F / #323639 **(uncertain, third-party:** https://www.schemecolor.com/google-chrome-incognito-mode-ui-colors.php **)**. Icon: the hat-and-glasses figure. Copy on the new tab page: title "You've gone Incognito", then "Others who use this device won't see your activity, so you can browse more privately. This won't change how data is collected by websites you visit…", followed by "Chrome won't save:" and "Your activity might still be visible to:" lists —
  https://chromium.googlesource.com/chromium/src/+/refs/heads/main/components/new_or_sad_tab_strings.grdp .
  Android also offers "Locked Incognito" ("Unlock Incognito" re-auth) —
  https://chromium.googlesource.com/chromium/src/+/refs/heads/main/chrome/browser/ui/android/strings/android_chrome_strings.grd
- **Protection visualisation.** None per page: no tracker counter, only the site-info (tune) icon and Safety Check in settings.
- **Light/dark.** Follows system by default ("System default" theme) —
  https://support.google.com/chrome/answer/9275525?hl=en&co=GENIE.Platform%3DAndroid
- **Icon at 48px.** A four-segment circle with a blue centre; reads as
  "Chrome" purely by colour and round silhouette.

### 2.2 Safari on iOS (iOS 26)

- **Address bar.** Three layouts under Settings › Safari › Tabs: **Compact**
  (new), **Bottom**, **Top**. Compact tucks share/bookmark/tabs behind a "…"
  button at the left of the bar; on scroll the bar collapses to a small URL
  pill. Bottom combines URL and tab bar in one full-width bottom bar; Top puts
  the URL at the top and the toolbar at the bottom —
  https://www.macrumors.com/guide/ios-26-safari-features/ ,
  https://www.idownloadblog.com/2025/06/12/ios-26-safari-tab-bar-designs/ .
  Which is the out-of-box default is not stated in those sources; press
  coverage implies Compact for new setups **(uncertain)**.
- **Material.** "Liquid Glass": translucent, rounder controls with page
  content visible beneath — https://www.macrumors.com/guide/ios-26-safari-features/
- **Tab switcher.** Grid of rounded cards, with a swipeable Private section
  (9to5Mac below). Tab groups in the same view.
- **Typeface.** SF Pro (system). **Touch target**: Apple's HIG minimum is
  44×44 pt — https://developer.apple.com/design/human-interface-guidelines/accessibility
- **Accent.** System blue (#007AFF light / #0A84FF dark is Apple's standard
  system blue) **(uncertain — not re-verified on Apple's page this session)**.
- **Private Browsing.** The address bar goes black/dark; Private tabs are a
  separate section in the tab view; since iOS 17 they are locked behind Face
  ID/Touch ID with the message "Private Browsing is Locked" —
  https://support.apple.com/en-us/105030 ,
  https://9to5mac.com/2023/09/18/ios-17-private-browsing-tabs-behind-face-id/ ,
  https://support.apple.com/en-us/105028
- **Protection.** iOS 26 extends advanced fingerprinting protection to all
  browsing by default; Private Browsing also blocks known trackers and strips
  tracking URL parameters —
  https://www.macrumors.com/guide/ios-26-safari-features/ ,
  https://support.apple.com/guide/iphone/browse-the-web-privately-iphb01fc3c85/ios .
  The protection is mostly invisible in browsing chrome (a Privacy Report
  exists in the page menu; not re-verified here).
- **Light/dark.** Follows system.
- **Icon at 48px.** Blue compass on white; instantly legible.

### 2.3 Samsung Internet

- **Address bar.** Top by default; Bottom available in Settings › Layout and
  menu — https://www.androidpolice.com/samsung-internet-tips-and-tricks/ ,
  https://androidcommunity.com/samsung-internet-now-lets-you-move-url-bar-to-bottom-20211129/ .
  The One UI 8.5 redesign (reported Nov 2025) adds a **blurred floating
  address bar** split into two parts (URL + Home; then Tabs + Options), with
  **Compact / Standard / Bottom** styles, hiding on scroll —
  https://www.androidheadlines.com/2025/11/samsung-internet-browser-app-ui-redesign-one-ui-8-5.html .
  A frosted "toolbar blur effect" was found in test builds (May 2026) —
  https://www.sammyfans.com/2026/05/13/samsung-browser-may-soon-roll-out-a-refresh-toolbar-appearance/
- **Toolbar layout.** Classic layout is a top URL bar plus a **bottom
  toolbar** (back, forward, home, bookmarks, tabs, menu) — Android Police above.
- **Tab switcher.** User's choice of **List, Stack or Grid** (tab view › ⋮ ›
  View as) — https://www.androidpolice.com/samsung-internet-tips-and-tricks/ .
  The redesign's grid echoes the Gallery album layout, semi-transparent —
  AndroidHeadlines above.
- **Brand colour.** Periwinkle/indigo: #7882FF, #3F4FBC, #CFD3FF
  **(uncertain — third-party:** https://whatthelogo.com/logo/samsung-internet/284324 **)**.
  Samsung's own developer blog calls the browser "purple" —
  https://medium.com/samsung-internet-dev/samsung-internet-13-0-beta-692d2673d9fe
- **Typeface.** One UI Sans (One UI 6+, replacing earlier SamsungOne
  defaults) — https://www.sammobile.com/news/one-ui-6-new-font-not-looking-good-switch-back-old-one/ ,
  https://en.wikipedia.org/wiki/One_UI
- **Secret mode.** Toggled from the Tabs screen ("Turn on Secret mode"); the
  top and bottom bars turn grey/dark and a mask icon sits next to the address
  bar; it can be PIN/biometric locked —
  https://www.samsung.com/us/support/answer/ANS10010475/ ,
  https://techwiser.com/what-is-secret-mode-in-samsung-internet-and-how-to-turn-it-on-or-off/
- **Protection visualisation.** The most explicit of the majors: Smart
  anti-tracking on by default, and a **Privacy dashboard** (More › Privacy)
  showing trackers blocked daily/weekly —
  https://www.androidpolice.com/samsung-internet-tips-and-tricks/ ,
  https://www.sammobile.com/news/samsung-internet-17-beta-update-smarter-anti-tracking-improved-tab-management/
- **Light/dark.** Follows system (One UI dark mode).
- **Icon at 48px.** A purple planet with an orbit ring in a squircle; reads
  as "Samsung" because of the One UI squircle and colour.

### 2.4 Microsoft Edge (Android)

- **Address bar.** Top by default; bottom option in Settings › Appearance ›
  Address bar, public since late 2024/2025 —
  https://www.windowslatest.com/2024/11/01/after-chrome-microsoft-edge-plans-to-move-address-bar-to-bottom-on-android/ ,
  https://www.windowscentral.com/phones/windows-phone-fans-get-loved-feature-for-microsoft-edge-on-android-ios
- **Toolbar.** Persistent **bottom toolbar** (back, forward, new tab "+",
  tab count, ⋯ menu that swipes up into a full sheet) —
  https://privacy.kaspersky.com/articles/edge-android-medium/ (menu at the
  bottom, swipe up for the whole menu). Exact button order **(uncertain)**.
- **Tab switcher.** Grid of thumbnails with InPrivate as a separate tab
  section **(uncertain, from product use rather than a doc)**.
- **Colour.** Logo wave gradient from deep blue to teal/green; cited hexes
  #0C59A4, #0078D4, #1B9DE2, #2BC3D2, #36C752 **(uncertain — third-party:**
  https://logotyp.us/logo/microsoft-edge/ , https://1000logos.net/edge-logo/ **)**.
- **Typeface.** Segoe UI is Windows-only; on Android Edge uses the system
  font (Roboto / One UI Sans) **(uncertain)**.
- **InPrivate.** Dark theme with "InPrivate" label; always uses **Strict**
  tracking prevention —
  https://privacy.kaspersky.com/articles/edge-android-medium/
- **Protection.** Tracking prevention levels Basic / Balanced (default) /
  Strict; a per-site count of trackers blocked appears in the site-info panel
  **(count uncertain)** — https://privacy.kaspersky.com/articles/edge-android-medium/
- **Icon at 48px.** Blue-green swirl; reads as "Microsoft" by gradient.

### 2.5 Firefox for Android

- **Address bar.** Top on first run; Settings › Customize › Address bar
  location: Top / Bottom — https://support.mozilla.org/en-US/kb/move-navigation-bar ,
  https://support.mozilla.org/en-US/kb/toolbar-firefox-android .
  Recent builds add a **navigation bar** with back/forward on the toolbar,
  and both bars hide on scroll —
  https://connect.mozilla.org/t5/discussions/updates-to-android-navigation/td-p/62811
- **Design system.** "Acorn". Brand colours include **Orange 50 #FF7139**
  and **Violet 50 #9059FF**; on Android, **violet is the primary accent**
  (icons, borders, text, tab-collection colour coding) —
  https://acorn.firefox.com/latest/styles/color-MZHBVuZc ,
  https://acorn.firefox.com/latest/mobile/styles/color/full-palette-5n2jpXyR
- **Typeface.** System font (Roboto) on Android; Inter and Metropolis appear
  in Mozilla brand/web material **(uncertain)**.
- **Private browsing.** A **purple theme** across the private home, search bar
  and menu, plus a mask icon —
  https://browserhow.com/how-to-open-private-mode-and-new-tabs-in-firefox-for-android/ ,
  https://connect.mozilla.org/t5/ideas/purple-background-for-private-tabs-tray-firefox-for-android/idi-p/63790
- **Protection.** Enhanced Tracking Protection on by default (Standard /
  Strict / Custom). A **shield** icon in the address bar opens a panel per
  site; the per-site toggle turns **purple** when on —
  https://support.mozilla.org/en-US/kb/enhanced-tracking-protection-firefox-android
  (snippet via search; the page did not render for WebFetch).
- **Tab switcher.** Tabs tray as a grid or list (setting) **(uncertain)**.
- **Icon at 48px.** Orange-to-purple fox around a globe; the gradient reads
  well, the fox silhouette less so at small sizes.

### 2.6 Opera for Android

- **Address bar.** Top, with a **customisable bottom bar**: long-press it →
  "Edit toolbar" to rearrange or replace the first three icons —
  https://blogs.opera.com/mobile/2024/05/opera-for-android-update-82/ ,
  https://x.com/opera/status/1790420810215096328
- **Tab switcher.** Version 89 (May 2025) put a **large tab-counter in the
  centre** of the bottom bar, with **bigger, easier-to-tap icons**, and a tab
  gallery offering **Carousel, Grid and List** plus Tab Islands (groups) and
  tab search — https://blogs.opera.com/mobile/2025/05/new-opera-for-android-89-comes-with-the-most-complete-tab-management-system-out-there/
- **Colour.** Opera red **#FF1B2D** ("Scarlet") **(uncertain — third-party:**
  https://brandpalettes.com/opera-logo-colors/ **)**.
- **Protection.** Built-in ad blocker with Balanced and Enhanced (uBlock /
  AdGuard-based) modes, with an ads-blocked count —
  https://press.opera.com/2024/12/11/opera-ad-blocker-on-android-more-powerful-improved-efficiency-privacy/ ,
  https://blogs.opera.com/security/2024/12/ofa-86-improved-ad-blocker/
- **Private tabs.** Dark private tabs **(colour and copy uncertain; not found
  in a source)**.
- **Icon at 48px.** Red "O" ring; one of the most legible at small sizes.

---

## 3. Cross-browser patterns (synthesis)

| | Chrome | Safari | Samsung | Edge | Firefox | Opera |
|---|---|---|---|---|---|---|
| Default bar | Top | Compact/bottom (iOS 26, uncertain) | Top | Top | Top | Top |
| Bottom option | Yes (2025) | Yes | Yes | Yes | Yes | Bottom bar always |
| Tab view | Grid | Grid | List/Stack/Grid | Grid | Grid/List | Carousel/Grid/List |
| Private signal | Dark theme, hat icon | Black bar, Face ID lock | Grey bars, mask, lock | Dark, "InPrivate" | Purple, mask | Dark |
| Visible protection | None | Mostly hidden | Privacy dashboard counts | Site-info count | Shield + panel | Ads-blocked count |

Every major follows the system light/dark setting by default; none is
dark-only. Every one now lets the address bar live at the bottom, and the
newest designs (Safari 26, Samsung One UI 8.5) float it as a translucent
pill that shrinks on scroll.

---

## Transferable takeaways

- **Design for a Chrome refugee first.** ~85% of Android browsing is Chrome
  (Cloudflare 2025); Samsung Internet is the only other real source. Match
  Chrome's grammar: address pill, tab-count square, ⋮ / ☰ menu, grid of tab cards.
- **Offer top and bottom address bar; default to top** like Chrome and
  Samsung, with a one-tap long-press "Move to bottom" as Chrome does.
- **Sizes to copy:** a 56dp bar holding a 40dp pill (20dp radius), 48dp
  minimum touch targets, 24dp icons, 16–24dp card radii (Chromium sources).
- **Tab view as a two-column card grid** with thumbnails and 24dp cards;
  a list option is a nice-to-have (Samsung, Opera, Firefox all offer one).
- **Private/isolated state is signalled by a whole-theme shift plus an icon**,
  not by a small badge: Chrome dark, Firefox purple, Samsung grey + mask,
  Safari black + biometric lock. Container could do the same per container
  type (e.g. throwaway vs saved).
- **Use a single brand accent sparingly** over a neutral (Dynamic-Color-like)
  surface; Firefox's violet and Samsung's periwinkle show one hue can own
  "privacy". Container's jade fits that slot.
- **Show protection plainly but calmly**: Samsung's privacy dashboard and
  Firefox's shield-and-panel are the models mainstream users already know;
  Chrome shows nothing. A shield in the pill opening a panel (Container's
  `6c`) is on-pattern.
- **Respect the system theme.** Every major defaults to "follow system";
  a dark-only app is the exception mainstream users notice.
- **Copy should be plain and bounded**, like Chrome's "You've gone Incognito
  … Your activity might still be visible to:", which says what it does and
  does not protect against.
- **A launcher icon must read by colour and silhouette at 48px**: Chrome's
  four-colour circle, Opera's red ring and Safari's compass all do; a
  thin-line glyph on near-black will not.
