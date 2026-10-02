package com.mono.container.engine

import androidx.webkit.Profile
import androidx.webkit.ProfileStore
import androidx.webkit.WebViewFeature

/**
 * One WebView profile per site. A profile owns its own cookies, localStorage
 * and cache, which is what makes "Each site gets its own storage" true.
 *
 * Profile names are the opaque ids stored in the vault. They are never derived
 * from a host — see Global Constraints.
 *
 * **A wipe cannot always delete.** WebView refuses to delete a profile this
 * process has loaded, for the rest of the process's life ([PendingDeletions]
 * has the Chromium detail). So [wipe] deletes when it can, and otherwise
 * clears the profile in place and leaves it in [pending] for
 * [sweepPendingDeletions] at the next start. It never throws for a profile in
 * use — every wipe used to, which is how panic failed open and ephemeral sites
 * were silently never wiped.
 */
class ProfileManager(private val pending: PendingDeletions) {

    fun isAvailable(): Boolean =
        WebViewFeature.isFeatureSupported(WebViewFeature.MULTI_PROFILE)

    /**
     * Returns this site's profile, creating it on first use. A profile used
     * again is live data now, so it stops being pending deletion.
     * @throws IllegalStateException when the device cannot isolate. Callers
     * must surface this, never degrade to the default profile.
     */
    fun profileFor(profileId: String): Profile {
        check(isAvailable()) { "This device cannot isolate containers." }
        pending.remove(profileId)
        return ProfileStore.getInstance().getOrCreateProfile(profileId)
    }

    /**
     * Destroys everything the profile holds: now if nothing has loaded it this
     * run, otherwise its cookies, web storage and permissions now and the rest
     * at the next start. What waits for the next start (history, network
     * state) is not reachable from anywhere in the app meanwhile.
     */
    fun wipe(profileId: String) {
        check(isAvailable()) { "This device cannot isolate containers." }
        val store = ProfileStore.getInstance()
        if (!store.allProfileNames.contains(profileId)) {
            pending.remove(profileId)
            return
        }
        wipeProfile(
            profileId,
            delete = { store.deleteProfile(profileId) },
            clear = { store.getProfile(profileId)?.let(::clearInPlace) },
            pending = pending,
        )
    }

    /**
     * Destroys every profile the store holds, default excluded, with [wipe]'s
     * delete-or-clear-and-journal rule for each.
     *
     * Panic's first step. Dart cannot supply the id list: profile ids live in
     * `Site` rows inside the encrypted vaults, and the vault that is not open
     * cannot be read at all. `allProfileNames` is the only enumeration that
     * covers both.
     */
    fun wipeAll() {
        check(isAvailable()) { "This device cannot isolate containers." }
        for (name in ProfileStore.getInstance().allProfileNames.toList()) {
            if (name == Profile.DEFAULT_PROFILE_NAME) continue
            wipe(name)
        }
    }

    /**
     * Deletes what earlier runs could only clear. Must run before anything in
     * this process loads a profile, since a loaded one cannot be deleted; a
     * delete that still fails stays pending for the start after. Skips WebView
     * start-up entirely when nothing is pending.
     */
    fun sweepPendingDeletions() {
        if (pending.names().isEmpty() || !isAvailable()) return
        val store = ProfileStore.getInstance()
        pending.sweep { name ->
            if (store.allProfileNames.contains(name)) store.deleteProfile(name)
        }
    }

    /**
     * Wipes every throwaway that outlived its page — the app died with it
     * open, so its container never closed (browser-chrome spec §5.4).
     * Like [sweepPendingDeletions] this runs before anything loads a profile,
     * so each [wipe] deletes outright. One whose wipe throws stays listed for
     * the next start. With nothing listed, WebView is not started at all.
     */
    fun sweepThrowaways(journal: ThrowawayJournal, deleteDownloads: (String) -> Unit) {
        if (journal.names().isEmpty()) return
        // A device that cannot isolate never created a profile to leak.
        if (!isAvailable()) {
            journal.clear()
            return
        }
        journal.sweep { profileId ->
            deleteDownloads(profileId)
            wipe(profileId)
        }
    }

    private fun clearInPlace(profile: Profile) {
        profile.cookieManager.removeAllCookies(null)
        profile.cookieManager.flush()
        profile.webStorage.deleteAllData()
        profile.geolocationPermissions.clearAll()
    }
}

/** Removes files kept by the download manager for one isolated profile. */
fun deleteDownloadsDir(context: android.content.Context, profileId: String) {
    java.io.File(context.filesDir, "downloads/$profileId").deleteRecursively()
}
