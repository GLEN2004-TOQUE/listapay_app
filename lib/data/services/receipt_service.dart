import 'package:intl/intl.dart';
import 'package:listapay/core/utils/currency_format.dart';
import 'package:listapay/domain/entities/completed_sale.dart';
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
              pw.Text('Sale #${sale.saleId}', style: const pw.TextStyle(fontSize: 9)),
              pw.Text(
                dateFormat.format(sale.createdAt),
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
}
