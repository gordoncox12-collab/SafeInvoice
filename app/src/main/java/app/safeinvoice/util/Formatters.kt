package app.safeinvoice.util

import java.math.BigDecimal
import java.math.RoundingMode
import java.text.NumberFormat
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import java.util.UUID

object Za {
    val locale: Locale = Locale("en", "ZA")
    val zone: ZoneId = ZoneId.of("Africa/Johannesburg")
    private val dateFmt: DateTimeFormatter = DateTimeFormatter.ofPattern("dd MMM yyyy", locale)
    private val moneyFmt: NumberFormat = NumberFormat.getCurrencyInstance(locale).apply {
        currency = java.util.Currency.getInstance("ZAR")
    }

    fun money(amount: Double, currency: String = "ZAR"): String {
        return if (currency == "ZAR") {
            moneyFmt.format(amount)
        } else {
            NumberFormat.getCurrencyInstance(locale).apply {
                this.currency = java.util.Currency.getInstance(currency)
            }.format(amount)
        }
    }

    fun date(epochMillis: Long): String {
        return Instant.ofEpochMilli(epochMillis).atZone(zone).toLocalDate().format(dateFmt)
    }

    fun todayMillis(): Long = LocalDate.now(zone).atStartOfDay(zone).toInstant().toEpochMilli()

    fun plusDays(epochMillis: Long, days: Long): Long {
        return Instant.ofEpochMilli(epochMillis).atZone(zone).toLocalDate()
            .plusDays(days)
            .atStartOfDay(zone)
            .toInstant()
            .toEpochMilli()
    }

    fun newId(): String = UUID.randomUUID().toString()
}

object Money {
    fun round(value: Double): Double =
        BigDecimal.valueOf(value).setScale(2, RoundingMode.HALF_UP).toDouble()

    fun lineTotal(quantity: Double, unitPrice: Double): Double = round(quantity * unitPrice)

    data class Totals(
        val subtotal: Double,
        val discount: Double,
        val net: Double,
        val vat: Double,
        val total: Double,
    )

    fun totals(
        lineTotals: List<Double>,
        discountAmount: Double,
        discountPercent: Double,
        vatPercent: Double,
    ): Totals {
        val subtotal = round(lineTotals.sum())
        val discount = round(discountAmount + subtotal * discountPercent / 100.0)
        val net = round((subtotal - discount).coerceAtLeast(0.0))
        val vat = round(net * vatPercent / 100.0)
        val total = round(net + vat)
        return Totals(subtotal, discount, net, vat, total)
    }
}
