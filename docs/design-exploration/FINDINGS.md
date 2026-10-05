# Findings

Bugs and oddities spotted during the restyle run and deliberately **not**
touched (the run changes visuals only). Each with where it was seen.

Found by the screen inventories (`inventory/`), 2026-10-05, fire-cd6e6b.
Not touched.

1. **`2c`'s header is always plural**, "1 OPEN SESSIONS", although the
   2026-10-05 ruling made counts of 1 singular elsewhere (`9b`, `3c`, Today).
   `inventory/screens-1-5.md` §2c.
2. **`8a`'s opening checklist never shows a done or connecting step**: every
   step is drawn pending (also recorded in CLAUDE.md under Plan 17's device
   check; still true). `inventory/screens-6-10.md` §8a.
3. **`10a`/`10c` storage reads `0 MB` for every workspace**: storage is never
   measured. §10a.
4. **`10b`'s "Ask for PIN to enter" saves but is enforced nowhere.** §10b.
5. **Canvas vs code colour/emphasis differences with no recorded ruling:**
   `6a` makes "Allow once" the jade action where the canvas makes "Keep
   blocked" jade (this one matters: the canvas's jade is the safe choice);
   `8c`'s body text is `#8A6A62` (canvas `#9A9089`) and always says "failed
   just now"; `10e`'s "+ Add site" chip border is solid (canvas dashed); `7b`'s
   subtitle is the full stored address, not the canvas's
   `forum.example.com · ephemeral`. The restyle keeps the code's behaviour and
   flags these for the user.
6. **Strings in the canvas the app never shows:** "Fingerprint unavailable"
   (`4c`), "Content hidden" / "Screenshots blocked…" (`9a`, the recents card is
   Android's own), "Use fingerprint" on a cold `3a`. `1a` and `1c` were never
   built as screens.
