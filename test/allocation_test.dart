import 'package:flutter_test/flutter_test.dart';
import 'package:safeinvoice/domain/balance.dart';
import 'package:safeinvoice/domain/models.dart';

Invoice _inv(String id, double total, {int issueDate = 1, String customerId = 'c1'}) {
  return Invoice(
    id: id,
    businessId: 'b1',
    customerId: customerId,
    number: 'INV-$id',
    status: InvoiceStatus.sent,
    issueDate: issueDate,
    dueDate: issueDate + 1,
    total: total,
    createdAt: issueDate,
    updatedAt: issueDate,
  );
}

Txn _pay(String invoiceId, double amount) {
  return Txn(
    id: 't-$invoiceId-$amount',
    businessId: 'b1',
    customerId: 'c1',
    invoiceId: invoiceId,
    type: TransactionType.payment,
    amount: amount,
    occurredAt: 1,
    createdAt: 1,
  );
}

void main() {
  test('unpaid orders sort oldest invoice date first and skip drafts/paid', () {
    final invoices = [
      _inv('new', 300, issueDate: 30),
      _inv('old', 200, issueDate: 10),
      _inv('mid', 100, issueDate: 20),
    ];
    final paid = Invoice(
      id: 'paid',
      businessId: 'b1',
      customerId: 'c1',
      number: 'INV-paid',
      status: InvoiceStatus.paid,
      issueDate: 5,
      dueDate: 6,
      total: 50,
      createdAt: 5,
      updatedAt: 5,
    );
    final draft = Invoice(
      id: 'draft',
      businessId: 'b1',
      customerId: 'c1',
      number: 'INV-draft',
      status: InvoiceStatus.draft,
      issueDate: 1,
      dueDate: 2,
      total: 80,
      createdAt: 1,
      updatedAt: 1,
    );
    final txs = [_pay('old', 50), _pay('paid', 50)];
    final unpaid = unpaidOrdersFor([...invoices, paid, draft], txs);
    expect(unpaid.map((o) => o.invoice.id).toList(), ['old', 'mid', 'new']);
    expect(unpaid.first.balance.invoiceOutstanding, closeTo(150, 0.001));
  });

  test('oldest-first allocation covers older invoices before newer', () {
    final unpaid = unpaidOrdersFor(
      [_inv('a', 100, issueDate: 1), _inv('b', 80, issueDate: 2), _inv('c', 50, issueDate: 3)],
      const [],
    );
    final slices = allocateOldestFirst(unpaid, 150);
    expect(slices.length, 2);
    expect(slices[0].invoiceId, 'a');
    expect(slices[0].amount, closeTo(100, 0.001));
    expect(slices[1].invoiceId, 'b');
    expect(slices[1].amount, closeTo(50, 0.001));
  });

  test('allocation of a single invoice is a partial on that invoice only', () {
    final unpaid = unpaidOrdersFor([_inv('only', 400)], const []);
    final slices = allocateOldestFirst(unpaid, 125);
    expect(slices.single.invoiceId, 'only');
    expect(slices.single.amount, closeTo(125, 0.001));
  });

  test('amount larger than outstanding stops at the last unpaid order', () {
    final unpaid = unpaidOrdersFor([_inv('a', 40, issueDate: 1), _inv('b', 10, issueDate: 2)], const []);
    final slices = allocateOldestFirst(unpaid, 999);
    expect(slices.map((s) => s.amount).toList(), [40.0, 10.0]);
  });
}
