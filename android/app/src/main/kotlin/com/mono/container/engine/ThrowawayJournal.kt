package com.mono.container.engine

import java.io.File

/**
 * Throwaway containers whose profile may still be on disk (browser-chrome
 * spec §5.4), one opaque profile id per line in `filesDir/throwaway-profiles`.
 *
 * `open(throwaway = true)` lists the id before the profile is created, and it
 * leaves the list once its container's close has wiped the profile or `keep`
 * has saved the site. Anything still listed when the engine starts belonged
 * to a page the app died with, and is wiped then. Panic's `wipeAll` destroys
 * every profile and clears the list.
 *
 * A separate file from [PendingDeletions], which it stores through (the same
 * one-id-per-line format and atomic rewrite): that file lists profiles to
 * *delete* at the next start because a wipe could only clear them in place;
 * this one lists profiles to *wipe*. A throwaway wiped while in use goes
 * through [ProfileManager.wipe] like any other profile, so it lands in both
 * until the next start deals with each.
 *
 * Holds random ids only, never a host, name or URL. It sits in plaintext in
 * `filesDir`, which is within the threat model: coerced unlock, not disk
 * imaging.
 */
class ThrowawayJournal(file: File) {
    private val ids = PendingDeletions(file)

    fun names(): List<String> = ids.names()

    fun add(profileId: String) = ids.add(profileId)

    fun remove(profileId: String) = ids.remove(profileId)

    /** Panic: every profile is gone already. */
    fun clear() = ids.sweep {}

    /** Engine start: [wipe] each listed profile. One whose wipe throws stays
     *  listed for the start after. */
    fun sweep(wipe: (String) -> Unit) = ids.sweep(wipe)
}

/**
 * How a view's wipe-on-exit ends: [wipe], then — only if it did not throw —
 * off the journal. For a wipe-on-exit site that was never a throwaway, the
 * removal is a no-op.
 */
internal fun wipeThenForget(profileId: String, journal: ThrowawayJournal, wipe: () -> Unit) {
    wipe()
    journal.remove(profileId)
}

/**
 * `keep` (spec §5.3): a throwaway saved as a site stops being wiped on exit —
 * [stopWiping] — and stops being a leftover for the start sweep.
 */
internal fun keepThrowaway(profileId: String, journal: ThrowawayJournal, stopWiping: () -> Unit) {
    stopWiping()
    journal.remove(profileId)
}
