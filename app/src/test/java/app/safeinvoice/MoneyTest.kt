package app.safeinvoice

import app.safeinvoice.util.Money
import org.junit.Assert.assertEquals
import org.junit.Test

class MoneyTest {
    @Test
    fun vatFifteenPercentOnNet() {
        val totals = Money.totals(listOf(1000.0, 500.0), discountAmount = 0.0, discountPercent = 0.0, vatPercent = 15.0)
        assertEquals(1500.0, totals.subtotal, 0.001)
        assertEquals(225.0, totals.vat, 0.001)
        assertEquals(1725.0, totals.total, 0.001)
    }

    @Test
    fun percentDiscountThenVat() {
        val totals = Money.totals(listOf(2000.0), discountAmount = 0.0, discountPercent = 10.0, vatPercent = 15.0)
        assertEquals(200.0, totals.discount, 0.001)
        assertEquals(1800.0, totals.net, 0.001)
        assertEquals(270.0, totals.vat, 0.001)
        assertEquals(2070.0, totals.total, 0.001)
    }

    @Test
    fun randDiscountAndPercentTogether() {
        val totals = Money.totals(listOf(1000.0), discountAmount = 50.0, discountPercent = 10.0, vatPercent = 15.0)
        assertEquals(150.0, totals.discount, 0.001)
        assertEquals(850.0, totals.net, 0.001)
        assertEquals(127.5, totals.vat, 0.001)
        assertEquals(977.5, totals.total, 0.001)
    }
}
