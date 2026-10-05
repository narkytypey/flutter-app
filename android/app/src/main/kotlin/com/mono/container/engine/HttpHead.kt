package com.mono.container.engine

import java.io.EOFException
import java.io.IOException
import java.io.InputStream

/** The longest single line of an HTTP head (or chunk-size / trailer line) this engine reads. */
const val MAX_HTTP_LINE = 8 * 1024

/** The most bytes of one HTTP head (status line plus fields, or a chunked trailer) this engine reads. */
const val MAX_HTTP_HEAD = 64 * 1024

/** A peer sent a line or a head longer than this engine will hold in memory. */
class HttpHeadTooLargeException(message: String) : IOException(message)

/**
 * Reads the CRLF- (or bare LF-) terminated lines of one HTTP head from
 * [input], refusing a line over [maxLine] bytes or a head over [maxHead]
 * bytes in all. Without the caps a peer (a proxy, an origin, anything on a
 * route) could stream a line with no newline for ever and grow the buffer
 * until the app runs out of memory.
 *
 * [readLine] returns null at end of stream with nothing read, and a partial
 * line at end of stream otherwise; callers decide what EOF means for them.
 */
class HttpHeadReader(
    private val input: InputStream,
    private val maxLine: Int = MAX_HTTP_LINE,
    private val maxHead: Int = MAX_HTTP_HEAD,
) {
    private var total = 0

    fun readLine(): String? {
        val line = StringBuilder()
        var sawAny = false
        while (true) {
            val byte = input.read()
            if (byte == -1) return if (sawAny) line.toString() else null
            sawAny = true
            if (++total > maxHead) throw HttpHeadTooLargeException("HTTP head longer than $maxHead bytes")
            if (byte == '\n'.code) return line.toString()
            if (byte != '\r'.code) {
                if (line.length >= maxLine) throw HttpHeadTooLargeException("HTTP line longer than $maxLine bytes")
                line.append(byte.toChar())
            }
        }
    }

    /** [readLine], with end of stream before the line's newline an [EOFException]. */
    fun readLineOrThrow(what: String): String {
        val line = StringBuilder()
        while (true) {
            val byte = input.read()
            if (byte == -1) throw EOFException("$what ended before its blank line")
            if (++total > maxHead) throw HttpHeadTooLargeException("HTTP head longer than $maxHead bytes")
            if (byte == '\n'.code) return line.toString()
            if (byte != '\r'.code) {
                if (line.length >= maxLine) throw HttpHeadTooLargeException("HTTP line longer than $maxLine bytes")
                line.append(byte.toChar())
            }
        }
    }
}
