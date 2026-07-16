import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:gal/gal.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:wood_quote/models/estimate.dart';
import 'package:wood_quote/models/line_item.dart';

const double _pdfTableBorderWidth = 0.5;
const double _pdfSectionBorderWidth = 0.55;
const double _pdfSectionInnerWidth = 0.55;
const double _pdfDescriptionLineWidth = 0.75;
const double _pdfTopSectionGap = 9;

class EstimateDocumentService {
  const EstimateDocumentService();

  Future<String> generateAndSavePdf(Estimate estimate) async {
    if (estimate.id == null) {
      throw Exception('Cannot generate PDF for an estimate without an id.');
    }

    final pdfBytes = await _buildPdfBytes(estimate);
    final file = await _createEstimatePdfFile(estimate.id!);

    await file.writeAsBytes(pdfBytes, flush: true);

    return file.path;
  }

  Future<void> openPdf(String pdfPath) async {
    final file = File(pdfPath);

    if (!await file.exists()) {
      throw Exception('PDF file does not exist.');
    }

    await OpenFilex.open(pdfPath);
  }

  Future<void> sharePdf({required String pdfPath, String? text}) async {
    final file = File(pdfPath);

    if (!await file.exists()) {
      throw Exception('PDF file does not exist.');
    }

    await SharePlus.instance.share(
      ShareParams(
        text: text ?? 'WoodQuote estimate',
        files: [XFile(pdfPath, mimeType: 'application/pdf')],
      ),
    );
  }

  Future<String> saveEstimateImage({
    required int estimateId,
    required Uint8List imageBytes,
  }) async {
    final directory = await _getEstimateDocumentsDirectory();
    final file = File('${directory.path}/estimate_$estimateId.png');

    await file.writeAsBytes(imageBytes, flush: true);

    return file.path;
  }

  Future<void> shareImage({required String imagePath, String? text}) async {
    final file = File(imagePath);

    if (!await file.exists()) {
      throw Exception('Image file does not exist.');
    }

    await SharePlus.instance.share(
      ShareParams(
        text: text ?? 'WoodQuote estimate',
        files: [XFile(imagePath, mimeType: 'image/png')],
      ),
    );
  }

  Future<File> _createEstimatePdfFile(int estimateId) async {
    final directory = await _getEstimateDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return File('${directory.path}/estimate_${estimateId}_$timestamp.pdf');
  }

  Future<Directory> _getEstimateDocumentsDirectory() async {
    final appDirectory = await getApplicationDocumentsDirectory();
    final estimatesDirectory = Directory('${appDirectory.path}/estimates');

    if (!await estimatesDirectory.exists()) {
      await estimatesDirectory.create(recursive: true);
    }

    return estimatesDirectory;
  }

  Future<String?> savePdfToUserSelectedLocation(Estimate estimate) async {
    if (estimate.id == null) {
      throw Exception('Cannot save PDF for an estimate without an id.');
    }

    final pdfBytes = await _buildPdfBytes(estimate);

    final safeClientName = _safeFileName(
      estimate.customerName?.trim().isNotEmpty == true
          ? estimate.customerName!.trim()
          : 'client',
    );

    final outputPath = await FilePicker.saveFile(
      dialogTitle: 'Save estimate as PDF',
      fileName: 'estimate_${estimate.id}_$safeClientName.pdf',
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      bytes: pdfBytes,
    );

    if (outputPath == null) return null;

    final outputFile = File(outputPath);

    if (!await outputFile.exists()) {
      await outputFile.writeAsBytes(pdfBytes, flush: true);
    }

    return outputPath;
  }

  Future<void> saveImageToGallery({
    required Uint8List imageBytes,
    String albumName = 'WoodQuote',
  }) async {
    final hasAccess = await Gal.hasAccess();

    if (!hasAccess) {
      await Gal.requestAccess();
    }

    await Gal.putImageBytes(imageBytes, album: albumName);
  }

  String _safeFileName(String value) {
    return value
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
  }

  Future<Uint8List> _buildPdfBytes(Estimate estimate) async {
    final pdf = pw.Document();

    final documentItems = List<LineItem>.from(estimate.lineItems)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final total = estimate.computedTotal;
    final dateText = estimate.date == null
        ? 'No date'
        : DateFormat('MMM d, yyyy').format(estimate.date!);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(14),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _companyHeader(),
                pw.SizedBox(height: _pdfTopSectionGap),
                _estimateTitleBar(),
                pw.SizedBox(height: _pdfTopSectionGap),
                _customerAndMetaSection(estimate: estimate, dateText: dateText),
                pw.SizedBox(height: _pdfTopSectionGap),
                _descriptionSection(estimate),
                pw.SizedBox(height: 11),
                _itemsTable(items: documentItems, total: total),
                pw.SizedBox(height: 24),
                _footerSection(
                  dateText: dateText,
                  validity: estimate.validity,
                  termsOfPayment: estimate.termsOfPayment,
                ),
                pw.Spacer(),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _companyHeader() {
    return pw.Column(
      children: [
        pw.Text(
          'LUMBER SHAPES FURNITURE',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'P.O. BOX DS 877, Dasoman, Accra  0244607278 / 0206528863',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(
              color: PdfColors.black,
              width: _pdfSectionBorderWidth,
            ),
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: pw.Text(
            'Expert in Office & Domestic Furniture, Fabricating of Aluminium Doors & Windows, General Construction',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 10,
              height: 1.15,
              fontStyle: pw.FontStyle.italic,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _estimateTitleBar() {
    return pw.Container(
      height: 24,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          color: PdfColors.black,
          width: _pdfSectionBorderWidth,
        ),
      ),
      alignment: pw.Alignment.center,
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 22, vertical: 3.5),
        color: PdfColors.black,
        child: pw.Text(
          'ESTIMATE / QUOTATION',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            color: PdfColors.white,
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  pw.Widget _customerAndMetaSection({
    required Estimate estimate,
    required String dateText,
  }) {
    final jobNo = estimate.id != null ? '#${estimate.id}' : '—';

    return pw.SizedBox(
      height: 72,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                  color: PdfColors.black,
                  width: _pdfSectionBorderWidth,
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.fromLTRB(8, 5, 8, 4),
                    child: _topSectionLabel("Customer's Name & Address"),
                  ),
                  _pdfSectionRule(),
                  pw.Expanded(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.fromLTRB(8, 4, 8, 4),
                      child: pw.Align(
                        alignment: pw.Alignment.centerLeft,
                        child: _boldText(
                          estimate.customerName ?? 'Unnamed client',
                        ),
                      ),
                    ),
                  ),
                  _pdfSectionRule(),
                  pw.Expanded(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.fromLTRB(8, 4, 8, 4),
                      child: pw.Align(
                        alignment: pw.Alignment.centerLeft,
                        child: _boldText(estimate.address ?? 'No address'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          pw.Spacer(),

          pw.SizedBox(
            width: 126,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.SizedBox(
                  width: 38,
                  child: pw.Column(
                    children: [
                      pw.Expanded(
                        child: pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: _metaSideLabel('Date'),
                        ),
                      ),
                      pw.SizedBox(height: 7),
                      pw.Expanded(
                        child: pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: _metaSideLabel('Job No'),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 3),
                pw.Expanded(
                  child: pw.Column(
                    children: [
                      pw.Expanded(child: _pdfMetaValueBox(dateText)),
                      pw.SizedBox(height: 7),
                      pw.Expanded(child: _pdfMetaValueBox(jobNo)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfMetaValueBox(String value) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 7),
      alignment: pw.Alignment.centerLeft,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          color: PdfColors.black,
          width: _pdfSectionBorderWidth,
        ),
      ),
      child: pw.Text(
        value,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  pw.Widget _descriptionSection(Estimate estimate) {
    return pw.SizedBox(
      height: 74,
      child: pw.Stack(
        children: [
          pw.Positioned(
            left: 0,
            right: 0,
            top: 5,
            bottom: 0,
            child: pw.Container(
              padding: const pw.EdgeInsets.fromLTRB(10, 13, 10, 7),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                  color: PdfColors.black,
                  width: _pdfSectionBorderWidth,
                ),
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _boldText(estimate.jobDescription ?? 'No description'),
                  pw.SizedBox(height: 4),
                  _pdfDescriptionLine(),
                  pw.SizedBox(height: 21),
                  _pdfDescriptionLine(),
                ],
              ),
            ),
          ),
          pw.Positioned(
            left: 10,
            top: 0,
            child: pw.Container(
              color: PdfColors.white,
              padding: const pw.EdgeInsets.symmetric(horizontal: 4),
              child: _topSectionLabel('Job Description / Specification'),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _itemsTable({
    required List<LineItem> items,
    required double total,
  }) {
    final currency = NumberFormat('#,##0.00', 'en_US');
    const visibleRows = 14;

    final tableRows = <pw.TableRow>[];
    int itemNumber = 0;

    pw.TableRow emptyRow() {
      return pw.TableRow(
        children: [
          _tableCell('', center: true, height: 25),
          _tableCell('', height: 25),
          _tableCell('', center: true, height: 25),
          _tableCell('', alignRight: true, height: 25),
          _tableCell('', alignRight: true, height: 25),
        ],
      );
    }

    for (int index = 0; index < items.length; index++) {
      final item = items[index];

      if (item.type == LineItemType.header) {
        if (item.addBlankRowBefore && tableRows.isNotEmpty) {
          tableRows.add(emptyRow());
        }

        final headerParts = _splitDescriptionIntoRows(item.description ?? '');

        final headerAmount = item.headerValue == null
            ? ''
            : currency.format(item.headerValue);

        for (int partIndex = 0; partIndex < headerParts.length; partIndex++) {
          final isLastPart = partIndex == headerParts.length - 1;

          tableRows.add(
            pw.TableRow(
              children: [
                _tableCell('', center: true, height: 25),
                _tableCell(headerParts[partIndex], bold: true, height: 25),
                _tableCell('', center: true, height: 25),
                _tableCell('', alignRight: true, height: 25),
                _tableCell(
                  isLastPart ? headerAmount : '',
                  bold: true,
                  alignRight: true,
                  height: 25,
                ),
              ],
            ),
          );
        }

        continue;
      }

      itemNumber++;

      final descriptionParts = _splitDescriptionIntoRows(
        item.description ?? '',
      );

      for (
        int partIndex = 0;
        partIndex < descriptionParts.length;
        partIndex++
      ) {
        final isFirstPart = partIndex == 0;
        final isLastPart = partIndex == descriptionParts.length - 1;

        tableRows.add(
          pw.TableRow(
            children: [
              _tableCell(
                isFirstPart ? '$itemNumber' : '',
                bold: true,
                center: true,
                height: 25,
              ),

              _tableCell(descriptionParts[partIndex], bold: true, height: 25),

              _tableCell(
                isLastPart && item.quantity != null
                    ? _formatQuantity(item.quantity!)
                    : '',
                bold: true,
                center: true,
                height: 25,
              ),

              _tableCell(
                isLastPart && item.unitPrice != null
                    ? currency.format(item.unitPrice)
                    : '',
                bold: true,
                alignRight: true,
                height: 25,
              ),

              _tableCell(
                isLastPart && item.unitPrice != null
                    ? currency.format(item.total)
                    : '',
                bold: true,
                alignRight: true,
                height: 25,
              ),
            ],
          ),
        );
      }
    }

    while (tableRows.length < visibleRows) {
      tableRows.add(emptyRow());
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Table(
          border: pw.TableBorder.all(
            color: PdfColors.black,
            width: _pdfTableBorderWidth,
          ),
          columnWidths: const {
            0: pw.FixedColumnWidth(38),
            1: pw.FlexColumnWidth(),
            2: pw.FixedColumnWidth(42),
            3: pw.FixedColumnWidth(62),
            4: pw.FixedColumnWidth(68),
          },
          children: [
            pw.TableRow(
              children: [
                _tableHeader('Item', center: true),
                _tableHeader('Description', center: true),
                _tableHeader('Qty', center: true),
                _tableHeader('Unit\nCost', center: true),
                _tableHeader('Amount', center: true),
              ],
            ),
            ...tableRows.take(visibleRows),
          ],
        ),

        pw.SizedBox(
          height: 26,
          child: pw.Row(
            children: [
              pw.Spacer(),
              pw.Text(
                'Grand Total',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Container(
                width: 68,
                height: 26,
                alignment: pw.Alignment.centerRight,
                padding: const pw.EdgeInsets.symmetric(horizontal: 5),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: PdfColors.black,
                    width: _pdfTableBorderWidth,
                  ),
                ),
                child: pw.Text(
                  currency.format(total),
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _footerSection({
    required String dateText,
    required String? validity,
    required String? termsOfPayment,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          children: [
            pw.Expanded(
              child: _pdfLineField(
                label: 'VALIDITY:',
                value: validity?.trim() ?? '',
              ),
            ),
            pw.SizedBox(width: 28),
            pw.Expanded(
              flex: 2,
              child: _pdfLineField(
                label: 'TERMS OF PAYMENT:',
                value: termsOfPayment?.trim() ?? '',
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 24),
        pw.Row(
          children: [
            pw.Expanded(
              child: _pdfLineField(label: 'SIGNATURE:', value: ''),
            ),
            pw.SizedBox(width: 18),
            pw.Expanded(
              child: _pdfLineField(label: 'NAME:', value: 'Raphael Degadzor'),
            ),
            pw.SizedBox(width: 18),
            pw.Expanded(
              child: _pdfLineField(label: 'DATE:', value: dateText),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _pdfLineField({required String label, required String value}) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(width: 4),
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.only(left: 4, bottom: 1),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey700, width: 0.6),
              ),
            ),
            child: pw.Text(
              value,
              maxLines: 1,
              style: const pw.TextStyle(fontSize: 8.5),
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _pdfSectionRule() {
    return pw.Container(
      height: _pdfSectionInnerWidth,
      width: double.infinity,
      color: PdfColors.black,
    );
  }

  pw.Widget _pdfDescriptionLine() {
    return pw.Container(
      height: _pdfDescriptionLineWidth,
      width: double.infinity,
      color: PdfColors.black,
    );
  }

  pw.Widget _topSectionLabel(String text) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 8.5,
        color: PdfColors.black,
        fontWeight: pw.FontWeight.bold,
      ),
    );
  }

  pw.Widget _metaSideLabel(String text) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 9,
        color: PdfColors.black,
        fontWeight: pw.FontWeight.bold,
      ),
    );
  }

  pw.Widget _boldText(String text) {
    return pw.Text(
      text,
      maxLines: 2,
      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
    );
  }

  pw.Widget _tableHeader(String text, {bool center = false}) {
    return pw.Container(
      height: 28,
      alignment: center ? pw.Alignment.center : pw.Alignment.centerLeft,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(
        text,
        textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: 10,
          height: 1.05,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _tableCell(
    String text, {
    bool bold = false,
    bool center = false,
    bool alignRight = false,
    double height = 26,
    int maxLines = 1,
  }) {
    return pw.Container(
      height: height,
      alignment: center
          ? pw.Alignment.center
          : alignRight
          ? pw.Alignment.centerRight
          : pw.Alignment.centerLeft,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(
        text,
        textAlign: alignRight
            ? pw.TextAlign.right
            : center
            ? pw.TextAlign.center
            : pw.TextAlign.left,
        maxLines: maxLines,
        softWrap: false,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  List<String> _splitDescriptionIntoRows(String text) {
    const int descriptionCharsPerRow = 58;

    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (normalized.isEmpty) return [''];

    final rows = <String>[];
    final words = normalized.split(' ');
    final buffer = StringBuffer();

    void flushBuffer() {
      if (buffer.isEmpty) return;

      rows.add(buffer.toString());
      buffer.clear();
    }

    for (final word in words) {
      if (word.length > descriptionCharsPerRow) {
        flushBuffer();

        for (
          int start = 0;
          start < word.length;
          start += descriptionCharsPerRow
        ) {
          final end = start + descriptionCharsPerRow > word.length
              ? word.length
              : start + descriptionCharsPerRow;

          rows.add(word.substring(start, end));
        }

        continue;
      }

      final currentText = buffer.toString();

      final nextLength = currentText.isEmpty
          ? word.length
          : currentText.length + 1 + word.length;

      if (nextLength > descriptionCharsPerRow) {
        flushBuffer();
        buffer.write(word);
      } else {
        if (buffer.isNotEmpty) {
          buffer.write(' ');
        }

        buffer.write(word);
      }
    }

    flushBuffer();

    return rows.isEmpty ? [''] : rows;
  }

  String _formatQuantity(double value) {
    if (value % 1 == 0) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }
}
