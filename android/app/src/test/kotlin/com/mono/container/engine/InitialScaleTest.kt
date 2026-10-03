package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * `setInitialScale` takes a percentage of physical pixels. Passing the site's
 * Page zoom straight through rendered every page at 1/density (about 38% on a
 * 2.625 screen) and made `width=device-width` lay out 1080 CSS px wide.
 */
class InitialScaleTest {

    @Test fun `100 percent leaves the scale to WebView and the page's viewport`() {
        assertEquals(0, initialScaleFor(pageZoom = 100, density = 2.625f))
    }

    @Test fun `another zoom is a percentage of physical pixels`() {
        assertEquals(289, initialScaleFor(pageZoom = 110, density = 2.625f))
        assertEquals(100, initialScaleFor(pageZoom = 50, density = 2f))
        assertEquals(600, initialScaleFor(pageZoom = 200, density = 3f))
    }

    @Test fun `a 1x screen takes the zoom as it is`() {
        assertEquals(150, initialScaleFor(pageZoom = 150, density = 1f))
    }
}
