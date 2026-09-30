package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Found on a device: a service worker squoosh.app registered in a SOCKS5
 * throwaway fetched from squoosh.app directly. Every site runs in its own
 * profile, and each profile has its own service-worker controller; the
 * site's interceptor had only ever been set on the default profile's, which
 * no site uses, so no site's service worker was intercepted at all.
 */
class ServiceWorkerRoutingTest {

    private class Recorder : ServiceWorkerControllers<String> {
        val byProfile = mutableMapOf<String, String>()
        var onDefault: String? = null
        override fun setOnProfile(profileId: String, client: String) { byProfile[profileId] = client }
        override fun setOnDefaultProfile(client: String) { onDefault = client }
    }

    @Test fun `the site's interceptor goes on the site's own profile`() {
        val controllers = Recorder()
        routeServiceWorkers(controllers, profileId = "p1", site = "site", refuseAll = "refuse")
        assertEquals(mapOf("p1" to "site"), controllers.byProfile)
    }

    @Test fun `the default profile refuses every request, since no site lives there`() {
        val controllers = Recorder()
        routeServiceWorkers(controllers, profileId = "p1", site = "site", refuseAll = "refuse")
        assertEquals("refuse", controllers.onDefault)
    }
}
