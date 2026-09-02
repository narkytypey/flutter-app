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
 */
class ProfileManager {

    fun isAvailable(): Boolean =
        WebViewFeature.isFeatureSupported(WebViewFeature.MULTI_PROFILE)

    /**
     * Returns this site's profile, creating it on first use.
     * @throws IllegalStateException when the device cannot isolate. Callers
     * must surface this, never degrade to the default profile.
     */
    fun profileFor(profileId: String): Profile {
        check(isAvailable()) { "This device cannot isolate containers." }
        return ProfileStore.getInstance().getOrCreateProfile(profileId)
    }

    /** Destroys everything the profile holds. Irreversible. */
    fun wipe(profileId: String) {
        check(isAvailable()) { "This device cannot isolate containers." }
        val store = ProfileStore.getInstance()
        if (store.allProfileNames.contains(profileId)) {
            store.deleteProfile(profileId)
        }
    }

    /**
     * Destroys every profile the store holds, default excluded. Irreversible.
     *
     * Panic's first step. Dart cannot supply the id list: profile ids live in
     * `Site` rows inside the encrypted vaults, and the vault that is not open
     * cannot be read at all. `allProfileNames` is the only enumeration that
     * covers both.
     *
     * `deleteProfile` throws while a profile is attached to a live WebView, so
     * callers close every session first — see `ContainerPanicService`.
     */
    fun wipeAll() {
        check(isAvailable()) { "This device cannot isolate containers." }
        val store = ProfileStore.getInstance()
        for (name in store.allProfileNames.toList()) {
            if (name == Profile.DEFAULT_PROFILE_NAME) continue
            store.deleteProfile(name)
        }
    }
}
