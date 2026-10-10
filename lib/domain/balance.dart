import 'models.dart';
import 'money.dart';

/// Paid / outstanding figures for one invoice.
///
/// [invoiceOutstanding] is this invoice's remaining total (Home / customer
/// roll-ups). [documentOutstanding] is what the PDF prints: total plus optional
/// previous balance, minus payments.
class InvoiceBalance {
  const InvoiceBalance({
    required this.invoiceTotal,
    this.broughtForward = 0,
    this.amountPaid = 0,
  });

  final double invoiceTotal;
  final double broughtForward;
  final double amountPaid;

  double get amountDue => Money.round(invoiceTotal + broughtForward);

  /// Remaining on this invoice only — never includes brought-forward, so Home
  /// and customer totals do not double-count older invoices.
  double get invoiceOutstanding =>
      Money.round((invoiceTotal - amountPaid).clamp(0, double.infinity));

  /// Balance due printed on the invoice (total + previous − paid).
  double get documentOutstanding =>
      Money.round((amountDue - amountPaid).clamp(0, double.infinity));

  bool get isFullyPaid => amountDue > 0 && documentOutstanding <= 0 && amountPaid > 0;

  bool get isPartiallyPaid => amountPaid > 0 && invoiceOutstanding > 0;

  static double paidToward(Iterable<Txn> txs, String invoiceId) {
    var paid = 0.0;
    for (final tx in txs) {
      if (tx.invoiceId != invoiceId) continue;
      if (tx.type == TransactionType.payment) paid += tx.amount;
      if (tx.type == TransactionType.refund) paid -= tx.amount;
    }
    return Money.round(paid.clamp(0, double.infinity));
  }

  static InvoiceBalance of(Invoice invoice, Iterable<Txn> txs) {
    return InvoiceBalance(
      invoiceTotal: invoice.total,
      broughtForward: invoice.broughtForward,
      amountPaid: paidToward(txs, invoice.id),
    );
  }

  InvoiceStatus suggestedStatus({
    required InvoiceStatus current,
    required bool pastDue,
  }) {
    if (current == InvoiceStatus.cancelled) return InvoiceStatus.cancelled;
    if (invoiceTotal <= 0 && broughtForward <= 0 && amountPaid <= 0) {
      return current == InvoiceStatus.draft ? InvoiceStatus.draft : current;
    }
    if (invoiceOutstanding <= 0 && invoiceTotal > 0) return InvoiceStatus.paid;
    if (amountPaid > 0 && invoiceOutstanding > 0) return InvoiceStatus.partiallyPaid;
    if (current == InvoiceStatus.draft) return InvoiceStatus.draft;
    if (pastDue) return InvoiceStatus.overdue;
    return InvoiceStatus.sent;
  }
}

/// Sum of remaining invoice totals (excludes drafts and cancelled).
double booksOutstandingFor(Iterable<Invoice> invoices, Iterable<Txn> txs) {
  var sum = 0.0;
  for (final inv in invoices) {
    if (inv.status == InvoiceStatus.cancelled || inv.status == InvoiceStatus.draft) {
      continue;
    }
    sum += InvoiceBalance.of(inv, txs).invoiceOutstanding;
  }
  return Money.round(sum);
}

double customerOutstandingFor(
  Iterable<Invoice> invoices,
  Iterable<Txn> txs,
  String customerId,
) {
  return booksOutstandingFor(
    invoices.where((i) => i.customerId == customerId),
    txs,
  );
}

/// Other invoices' remaining totals — suggested previous balance.
double priorOutstandingFor({
  required Iterable<Invoice> invoices,
  required Iterable<Txn> txs,
  required String customerId,
  String? excludeInvoiceId,
}) {
  return booksOutstandingFor(
    invoices.where((i) => i.customerId == customerId && i.id != excludeInvoiceId),
    txs,
  );
}

double collectedPaymentsFor(Iterable<Txn> txs) {
  var sum = 0.0;
  for (final tx in txs) {
    if (tx.type == TransactionType.payment) sum += tx.amount;
    if (tx.type == TransactionType.refund) sum -= tx.amount;
  }
  return Money.round(sum.clamp(0, double.infinity));
}
