package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

/**
 * [deviceSaveTempFile] is where a proxied "save to device" holds the body
 * before it goes to MediaStore.
 *
 * Found on a device: its prefix was `"dl"`, and `File.createTempFile` refuses
 * any prefix under three characters, so every proxied save failed with
 * "Download failed" before a single byte was fetched.
 */
class DeviceSaveTempFileTest {

    @get:Rule val folder = TemporaryFolder()

    @Test fun `it is created in the given directory`() {
        val temp = deviceSaveTempFile(folder.root)
        assertTrue(temp.isFile)
        assertEquals(folder.root, temp.parentFile)
    }

    @Test fun `each call gets its own file`() {
        val first = deviceSaveTempFile(folder.root)
        val second = deviceSaveTempFile(folder.root)
        assertTrue(first != second)
    }
}
