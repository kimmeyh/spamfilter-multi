package com.myemailspamfilter

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * F303 T-1 (AC-1): one failing diagnostics field returns the others plus its
 * own error.
 *
 * What this does NOT catch: that MainActivity passes the real field readers
 * through collect (a Dart source gate pins the call), or which real Android
 * call fails on a phone (the Fold log shows that, AC-3).
 */
class DiagnosticsSnapshotTest {
    @Test
    fun aThrowingFieldReportsItsErrorAndTheOthersReturn() {
        val map = DiagnosticsSnapshot.collect(
            listOf(
                "a" to { true },
                "b" to { throw IllegalStateException("boom") },
                "c" to { 42L },
                "d" to { null },
            ),
        )
        assertEquals(listOf("a", "b", "c", "d"), map.keys.toList())
        assertEquals(true, map["a"])
        assertEquals("error: IllegalStateException: boom", map["b"])
        assertEquals(42L, map["c"])
        assertNull(map["d"])
    }

    @Test
    fun anErrorThrowableIsGuardedToo() {
        val map = DiagnosticsSnapshot.collect(
            listOf("x" to { throw NoSuchMethodError("gone") }, "y" to { "ok" }),
        )
        assertTrue((map["x"] as String).startsWith(DiagnosticsSnapshot.ERROR_PREFIX))
        assertEquals("ok", map["y"])
    }

    @Test
    fun allFieldsSucceedingReturnsThemUnchanged() {
        val map = DiagnosticsSnapshot.collect(listOf("a" to { 1 }, "b" to { "two" }))
        assertEquals(mapOf("a" to 1, "b" to "two"), map)
    }
}
