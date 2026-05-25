import 'package:intl/intl.dart';
import 'package:listapay/core/utils/currency_format.dart';
import 'package:listapay/core/utils/ph_time.dart';
import 'package:listapay/domain/entities/completed_sale.dart';
import 'package:listapay/domain/entities/debt_record.dart';
import 'package:listapay/domain/entities/payment_method.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReceiptService {
  Future<void> printReceipt(CompletedSale sale) async {
    final doc = await _buildDocument(sale);
    await Printing.layoutPdf(onLayout: (_) => doc.save());
  }

  Future<void> shareReceipt(CompletedSale sale) async {
    final doc = await _buildDocument(sale);
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'listapay_receipt_${sale.saleId}.pdf',
    );
  }

  Future<void> printDebtStatement(DebtRecord debt) async {
    final doc = await _buildDebtStatementDocument(debt);
    await Printing.layoutPdf(onLayout: (_) => doc.save());
  }

  Future<void> shareDebtStatement(DebtRecord debt) async {
    final doc = await _buildDebtStatementDocument(debt);
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'listapay_debt_${debt.id}.pdf',
    );
  }

  Future<void> printCustomerDebtStatement({
    required String customerName,
    String? customerPhone,
    required List<DebtRecord> debts,
  }) async {
    final doc = await _buildCustomerDebtStatementDocument(
      customerName: customerName,
      customerPhone: customerPhone,
      debts: debts,
    );
    await Printing.layoutPdf(onLayout: (_) => doc.save());
  }

  Future<void> shareCustomerDebtStatement({
    required String customerName,
    String? customerPhone,
    required List<DebtRecord> debts,
  }) async {
    final doc = await _buildCustomerDebtStatementDocument(
      customerName: customerName,
      customerPhone: customerPhone,
      debts: debts,
    );
    final slug = customerName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'listapay_customer_tab_${slug.isEmpty ? 'customer' : slug}.pdf',
    );
  }

  Future<pw.Document> _buildDocument(CompletedSale sale) async {
    final dateFormat = DateFormat('MMM d, yyyy · h:mm a');
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'ListaPay',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  'Official Receipt',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                'Sale #${sale.saleId}',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.Text(
                PhTime.format(dateFormat, sale.createdAt),
                style: const pw.TextStyle(fontSize: 9),
              ),
              if (sale.customerName != null)
                pw.Text(
                  'Customer: ${sale.customerName}',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              pw.Divider(),
              pw.Table(
                border: pw.TableBorder(
                  bottom: pw.BorderSide(color: PdfColors.grey300),
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    children: [
                      _cell('Item', bold: true),
                      _cell('Qty', bold: true),
                      _cell('Amount', bold: true, align: pw.TextAlign.right),
                    ],
                  ),
                  ...sale.lines.map(
                    (line) => pw.TableRow(
                      children: [
                        _cell(line.name),
                        _cell('${line.qty}'),
                        _cell(
                          formatPeso(line.subtotal),
                          align: pw.TextAlign.right,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    formatPeso(sale.total),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text('Paid via: ${sale.paymentMethod.label}'),
              if (sale.paymentMethod == PaymentMethod.cash) ...[
                pw.SizedBox(height: 6),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Amount paid'),
                    pw.Text(formatPeso(sale.amountPaid)),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Change'),
                    pw.Text(formatPeso(sale.changeAmount)),
                  ],
                ),
              ],
              pw.SizedBox(height: 16),
              pw.Center(
                child: pw.Text(
                  'Salamat po!',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
            ],
          );
        },
      ),
    );

    return doc;
  }

  Future<pw.Document> _buildDebtStatementDocument(DebtRecord debt) async {
    final dateFormat = DateFormat('MMM d, yyyy');
    final dateTimeFormat = DateFormat('MMM d, yyyy · h:mm a');
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text(
            'ListaPay',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Customer Debt Statement',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  debt.customerName,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (debt.customerPhone != null)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 2),
                    child: pw.Text('Phone: ${debt.customerPhone}'),
                  ),
                pw.SizedBox(height: 8),
                pw.Text('Debt #: ${debt.id}'),
                pw.Text(
                  'Created: ${PhTime.format(dateTimeFormat, debt.createdAt)}',
                ),
                pw.Text('Due date: ${PhTime.format(dateFormat, debt.dueDate)}'),
                pw.Text('Status: ${debt.displayStatus.label}'),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Items',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          if (debt.items.isEmpty)
            pw.Text('No item details available for this debt.')
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(4),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _tableCell('Item', bold: true),
                    _tableCell('Qty', bold: true, align: pw.TextAlign.center),
                    _tableCell(
                      'Unit Price',
                      bold: true,
                      align: pw.TextAlign.right,
                    ),
                    _tableCell(
                      'Subtotal',
                      bold: true,
                      align: pw.TextAlign.right,
                    ),
                  ],
                ),
                ...debt.items.map(
                  (item) => pw.TableRow(
                    children: [
                      _tableCell(item.productName),
                      _tableCell('${item.qty}', align: pw.TextAlign.center),
                      _tableCell(
                        formatPeso(item.unitPrice),
                        align: pw.TextAlign.right,
                      ),
                      _tableCell(
                        formatPeso(item.subtotal),
                        align: pw.TextAlign.right,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 220,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                children: [
                  _summaryRow('Original amount', formatPeso(debt.amount)),
                  _summaryRow('Paid', formatPeso(debt.paidAmount)),
                  pw.Divider(),
                  _summaryRow(
                    'Remaining',
                    formatPeso(debt.remaining),
                    bold: true,
                  ),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Payment History',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          if (debt.payments.isEmpty)
            pw.Text('No payments yet.')
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(3),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _tableCell('Amount', bold: true),
                    _tableCell('Date', bold: true),
                  ],
                ),
                ...debt.payments.map(
                  (payment) => pw.TableRow(
                    children: [
                      _tableCell(formatPeso(payment.amount)),
                      _tableCell(PhTime.format(dateTimeFormat, payment.paidAt)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );

    return doc;
  }

  Future<pw.Document> _buildCustomerDebtStatementDocument({
    required String customerName,
    String? customerPhone,
    required List<DebtRecord> debts,
  }) async {
    final dateFormat = DateFormat('MMM d, yyyy');
    final dateTimeFormat = DateFormat('MMM d, yyyy · h:mm a');
    final generatedAt = PhTime.now();
    final activeDebts = [...debts]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final totalRemaining = activeDebts.fold<double>(
      0,
      (sum, debt) => sum + debt.remaining,
    );

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text(
            'ListaPay',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Customer Tab Statement',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  customerName,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (customerPhone != null && customerPhone.trim().isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 2),
                    child: pw.Text('Phone: $customerPhone'),
                  ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Generated: ${PhTime.format(dateTimeFormat, generatedAt)}',
                ),
                pw.Text('Active utang entries: ${activeDebts.length}'),
                pw.Text('Total unpaid balance: ${formatPeso(totalRemaining)}'),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          if (activeDebts.isEmpty)
            pw.Text('This customer has no active unpaid utang.')
          else
            ...activeDebts.expand(
              (debt) => [
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'Debt #${debt.id}',
                                style: pw.TextStyle(
                                  fontSize: 13,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                'Added: ${PhTime.format(dateTimeFormat, debt.createdAt)}',
                              ),
                              pw.Text(
                                'Due date: ${PhTime.format(dateFormat, debt.dueDate)}',
                              ),
                              pw.Text('Status: ${debt.displayStatus.label}'),
                            ],
                          ),
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text(
                                formatPeso(debt.remaining),
                                style: pw.TextStyle(
                                  fontSize: 13,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.Text('Remaining'),
                            ],
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 10),
                      _summaryRow('Original amount', formatPeso(debt.amount)),
                      _summaryRow('Paid', formatPeso(debt.paidAmount)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Items taken',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                if (debt.items.isEmpty)
                  pw.Text('No item details available for this debt.')
                else
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(4),
                      1: const pw.FlexColumnWidth(1),
                      2: const pw.FlexColumnWidth(2),
                      3: const pw.FlexColumnWidth(2),
                    },
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.grey200,
                        ),
                        children: [
                          _tableCell('Item', bold: true),
                          _tableCell(
                            'Qty',
                            bold: true,
                            align: pw.TextAlign.center,
                          ),
                          _tableCell(
                            'Unit Price',
                            bold: true,
                            align: pw.TextAlign.right,
                          ),
                          _tableCell(
                            'Subtotal',
                            bold: true,
                            align: pw.TextAlign.right,
                          ),
                        ],
                      ),
                      ...debt.items.map(
                        (item) => pw.TableRow(
                          children: [
                            _tableCell(item.productName),
                            _tableCell(
                              '${item.qty}',
                              align: pw.TextAlign.center,
                            ),
                            _tableCell(
                              formatPeso(item.unitPrice),
                              align: pw.TextAlign.right,
                            ),
                            _tableCell(
                              formatPeso(item.subtotal),
                              align: pw.TextAlign.right,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                pw.SizedBox(height: 12),
                pw.Text(
                  'Payment History',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                if (debt.payments.isEmpty)
                  pw.Text('No payments yet.')
                else
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(2),
                      1: const pw.FlexColumnWidth(3),
                    },
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.grey200,
                        ),
                        children: [
                          _tableCell('Amount', bold: true),
                          _tableCell('Date', bold: true),
                        ],
                      ),
                      ...debt.payments.map(
                        (payment) => pw.TableRow(
                          children: [
                            _tableCell(formatPeso(payment.amount)),
                            _tableCell(
                              PhTime.format(dateTimeFormat, payment.paidAt),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                pw.SizedBox(height: 18),
              ],
            ),
        ],
      ),
    );

    return doc;
  }

  pw.Widget _cell(
    String text, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _tableCell(
    String text, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _summaryRow(String label, String value, {bool bold = false}) {
    final weight = bold ? pw.FontWeight.bold : pw.FontWeight.normal;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontWeight: weight)),
          pw.Text(value, style: pw.TextStyle(fontWeight: weight)),
        ],
      ),
    );
  }
}
