package com.myemailspamfilter

/**
 * Sprint 81 Task 5 (F303, #513): builds the new-mail diagnostics map one field
 * at a time. A field that throws reports "error: <Type>: <message>" in its own
 * slot and every other field still returns. Before this, one expression built
 * the whole map, so one failing read lost every field. adb is blocked on the
 * test phones, so the diagnostic log is the only evidence.
 *
 * Pure Kotlin (no Android types) so a JVM unit test covers it.
 */
object DiagnosticsSnapshot {
    const val ERROR_PREFIX = "error: "

    /** Reads each field in its own guard, in the order given. */
    fun collect(fields: List<Pair<String, () -> Any?>>): Map<String, Any?> {
        val out = LinkedHashMap<String, Any?>()
        for ((name, read) in fields) {
            out[name] = try {
                read()
            } catch (t: Throwable) {
                describe(t)
            }
        }
        return out
    }

    /** Type and message only; never notification content. */
    fun describe(t: Throwable): String =
        "$ERROR_PREFIX${t.javaClass.simpleName}: ${t.message}"
}
