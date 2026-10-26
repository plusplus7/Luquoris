package com.loquiris.transcription

import org.junit.Assert.*
import org.junit.Test

class RefinementObserverScopeTest {
    @Test fun `partial registration closes every observer for exceptions and VM errors`() {
        for (failure in listOf(IllegalStateException("private"), LinkageError("private"), OutOfMemoryError("private"))) {
            val scope = RefinementObserverScope()
            val closed = mutableListOf<Int>()
            scope.register({}, { closed += 1 })
            try {
                scope.register({ throw failure }, { closed += 2 })
                fail("registration must throw")
            } catch (actual: Throwable) { assertSame(failure, actual) }
            assertEquals(listOf(2, 1), closed)
            assertTrue(scope.isClosed)
            scope.close()
            assertEquals(listOf(2, 1), closed)
        }
    }

    @Test fun `one unregister error cannot skip remaining cleanup or replace registration failure`() {
        val scope = RefinementObserverScope()
        var firstClosed = false
        val original = LinkageError("registration")
        scope.register({}, { firstClosed = true })
        try {
            scope.register({ throw original }, { throw OutOfMemoryError("cleanup") })
            fail("registration must throw")
        } catch (actual: Throwable) { assertSame(original, actual) }
        assertTrue(firstClosed)
        assertTrue(scope.isClosed)
    }

    @Test fun `ordinary close tries all unregisters and reports cleanup failure`() {
        val scope = RefinementObserverScope()
        var firstClosed = false
        val failure = LinkageError("cleanup")
        scope.register({}, { firstClosed = true })
        scope.register({}, { throw failure })
        try { scope.close(); fail("cleanup must throw") } catch (actual: Throwable) { assertSame(failure, actual) }
        assertTrue(firstClosed)
        assertTrue(scope.isClosed)
    }
}
