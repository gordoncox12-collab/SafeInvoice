import 'package:flutter_test/flutter_test.dart';
import 'package:safeinvoice/domain/balance.dart';
import 'package:safeinvoice/domain/models.dart';

Invoice _inv({
  required String id,
  required String customerId,
  required InvoiceStatus status,
  required double total,
  double broughtForward = 0,
}) {
  return Invoice(
    id: id,
    businessId: 'b1',
    customerId: customerId,
    number: 'INV-$id',
    status: status,
    issueDate: 1,
    dueDate: 2,
    total: total,
    broughtForward: broughtForward,
    createdAt: 1,
    updatedAt: 1,
  );
}

Txn _pay(String invoiceId, double amount, {TransactionType type = TransactionType.payment}) {
  return Txn(
    id: 't-$invoiceId-$amount',
    businessId: 'b1',
    customerId: 'c1',
    invoiceId: invoiceId,
    type: type,
    amount: amount,
    occurredAt: 1,
    createdAt: 1,
  );
}

void main() {
  test('balance math: paid, outstanding and brought forward', () {
    const balance = InvoiceBalance(invoiceTotal: 1000, broughtForward: 200, amountPaid: 400);
    expect(balance.amountDue, closeTo(1200, 0.001));
    expect(balance.amountPaid, closeTo(400, 0.001));
    expect(balance.invoiceOutstanding, closeTo(600, 0.001));
    expect(balance.documentOutstanding, closeTo(800, 0.001));
    expect(balance.isPartiallyPaid, isTrue);
    expect(balance.isFullyPaid, isFalse);
  });

  test('full payment clears invoice outstanding', () {
    const balance = InvoiceBalance(invoiceTotal: 977.5, amountPaid: 977.5);
    expect(balance.invoiceOutstanding, 0);
    expect(balance.suggestedStatus(current: InvoiceStatus.sent, pastDue: false), InvoiceStatus.paid);
  });

  test('partial payment becomes partially paid, not paid', () {
    const balance = InvoiceBalance(invoiceTotal: 1000, amountPaid: 250);
    expect(
      balance.suggestedStatus(current: InvoiceStatus.sent, pastDue: false),
      InvoiceStatus.partiallyPaid,
    );
    expect(
      balance.suggestedStatus(current: InvoiceStatus.draft, pastDue: false),
      InvoiceStatus.partiallyPaid,
    );
  });

  test('unpaid past-due sent invoice is overdue; draft stays draft', () {
    const unpaid = InvoiceBalance(invoiceTotal: 500, amountPaid: 0);
    expect(unpaid.suggestedStatus(current: InvoiceStatus.sent, pastDue: true), InvoiceStatus.overdue);
    expect(unpaid.suggestedStatus(current: InvoiceStatus.draft, pastDue: true), InvoiceStatus.draft);
    expect(unpaid.suggestedStatus(current: InvoiceStatus.cancelled, pastDue: true), InvoiceStatus.cancelled);
  });

  test('customer and books outstanding ignore drafts and do not double-count brought forward', () {
    final invoices = [
      _inv(id: 'old', customerId: 'c1', status: InvoiceStatus.sent, total: 400),
      _inv(id: 'new', customerId: 'c1', status: InvoiceStatus.sent, total: 1000, broughtForward: 400),
      _inv(id: 'draft', customerId: 'c1', status: InvoiceStatus.draft, total: 50),
      _inv(id: 'other', customerId: 'c2', status: InvoiceStatus.sent, total: 80),
    ];
    final txs = [_pay('old', 100), _pay('new', 200)];
    expect(InvoiceBalance.paidToward(txs, 'old'), closeTo(100, 0.001));
    expect(customerOutstandingFor(invoices, txs, 'c1'), closeTo(1100, 0.001));
    expect(booksOutstandingFor(invoices, txs), closeTo(1180, 0.001));
    expect(
      priorOutstandingFor(invoices: invoices, txs: txs, customerId: 'c1', excludeInvoiceId: 'new'),
      closeTo(300, 0.001),
    );
  });

  test('refunds reduce amount paid', () {
    final txs = [_pay('inv1', 500), _pay('inv1', 100, type: TransactionType.refund)];
    expect(InvoiceBalance.paidToward(txs, 'inv1'), closeTo(400, 0.001));
    expect(collectedPaymentsFor(txs), closeTo(400, 0.001));
  });
}
