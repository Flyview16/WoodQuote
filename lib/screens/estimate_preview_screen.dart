import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:wood_quote/bloc/cubit/estimates_cubit.dart';
import 'package:wood_quote/models/estimate.dart';
import 'package:wood_quote/models/line_item.dart';
import 'package:wood_quote/screens/create_screen.dart';
import 'package:wood_quote/screens/shared_widgets/custom_appbar.dart';
import 'package:wood_quote/services/estimate_document_service.dart';
import 'package:wood_quote/utils/colors.dart';

enum _SaveEstimateChoice { pdf, image }

const BorderSide _tableBorderSide = BorderSide(color: Colors.black, width: 0.7);
const double _sectionBorderWidth = 0.85;
const double _sectionInnerWidth = 0.85;

const Color _sheetStroke = Color(0xFF161616);
const Color _sheetInnerLine = Color(0xFF2F2F2F);

const BorderSide _sectionBorderSide = BorderSide(
  color: _sheetStroke,
  width: _sectionBorderWidth,
);

const double _topSectionGap = 12;
const EdgeInsets _sectionLabelPadding = EdgeInsets.fromLTRB(10, 7, 10, 6);
const EdgeInsets _sectionValuePadding = EdgeInsets.fromLTRB(10, 6, 10, 6);

class EstimatePreviewScreen extends StatefulWidget {
  final Estimate estimate;

  const EstimatePreviewScreen({super.key, required this.estimate});

  @override
  State<EstimatePreviewScreen> createState() => _EstimatePreviewScreenState();
}

class _EstimatePreviewScreenState extends State<EstimatePreviewScreen> {
  final _documentKey = GlobalKey();
  final _documentService = const EstimateDocumentService();

  Estimate? _estimate;
  bool _loading = true;
  bool _busy = false;

  static const double _paperWidth = 720;
  static const double _paperHeight = 1160;

  final TransformationController _previewController =
      TransformationController();
  bool _initialZoomApplied = false;

  @override
  void initState() {
    super.initState();
    _loadFullEstimate();
  }

  @override
  void dispose() {
    _previewController.dispose();
    super.dispose();
  }

  Future<void> _loadFullEstimate() async {
    final id = widget.estimate.id;

    if (id == null) {
      setState(() {
        _estimate = widget.estimate;
        _loading = false;
      });
      return;
    }

    final fullEstimate = await context.read<EstimatesCubit>().getEstimateById(
      id,
    );

    if (!mounted) return;

    setState(() {
      _estimate = fullEstimate ?? widget.estimate;
      _loading = false;
    });
  }

  Future<void> _runBusyTask(Future<void> Function() task) async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      await task();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _editDraft() async {
    final estimate = _estimate;
    if (estimate == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CreateScreen(estimate: estimate)),
    );

    await _loadFullEstimate();
  }

  Future<void> _finaliseAndGeneratePdf() async {
    final estimate = _estimate;

    if (estimate == null || estimate.id == null) return;

    await _runBusyTask(() async {
      final pdfPath = await _documentService.generateAndSavePdf(estimate);

      await context.read<EstimatesCubit>().finaliseEstimateWithPdf(
        estimateId: estimate.id!,
        pdfPath: pdfPath,
      );

      final updatedEstimate = await context
          .read<EstimatesCubit>()
          .getEstimateById(estimate.id!);

      if (!mounted) return;

      setState(() {
        _estimate =
            updatedEstimate ??
            estimate.copyWith(
              status: EstimateStatus.finalised,
              pdfPath: pdfPath,
              pdfGeneratedAt: DateTime.now(),
            );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estimate finalised and PDF generated.')),
      );
    });
  }

  Future<String> _ensurePdfExists(Estimate estimate) async {
    if (estimate.id == null) {
      throw Exception('Cannot generate PDF for an estimate without an id.');
    }
    final isMutableDraft = estimate.status == EstimateStatus.draft;

    if (!isMutableDraft) {
      final existingPath = estimate.pdfPath;

      if (existingPath != null && existingPath.trim().isNotEmpty) {
        final file = File(existingPath);

        if (await file.exists()) {
          return existingPath;
        }
      }
    }

    final pdfPath = await _documentService.generateAndSavePdf(estimate);

    await context.read<EstimatesCubit>().updateEstimatePdfPath(
      estimateId: estimate.id!,
      pdfPath: pdfPath,
    );

    final updatedEstimate = await context
        .read<EstimatesCubit>()
        .getEstimateById(estimate.id!);

    if (mounted) {
      setState(() {
        _estimate =
            updatedEstimate ??
            estimate.copyWith(pdfPath: pdfPath, pdfGeneratedAt: DateTime.now());
      });
    }

    return pdfPath;
  }

  Future<void> _shareAsPdf() async {
    final estimate = _estimate;
    if (estimate == null || estimate.id == null) return;

    await _runBusyTask(() async {
      final pdfPath = await _ensurePdfExists(estimate);

      await _documentService.sharePdf(
        pdfPath: pdfPath,
        text: 'WoodQuote estimate for ${estimate.customerName ?? 'client'}',
      );

      await context.read<EstimatesCubit>().markEstimateAsShared(
        estimateId: estimate.id!,
      );

      final updatedEstimate = await context
          .read<EstimatesCubit>()
          .getEstimateById(estimate.id!);

      if (!mounted) return;

      setState(() {
        _estimate =
            updatedEstimate ??
            estimate.copyWith(
              status: EstimateStatus.shared,
              sharedAt: DateTime.now(),
            );
      });
    });
  }

  Future<void> _shareAsImage() async {
    final estimate = _estimate;
    if (estimate == null || estimate.id == null) return;

    await _runBusyTask(() async {
      final imageBytes = await _capturePreviewAsImage();
      final imagePath = await _documentService.saveEstimateImage(
        estimateId: estimate.id!,
        imageBytes: imageBytes,
      );

      await _documentService.shareImage(
        imagePath: imagePath,
        text: 'WoodQuote estimate for ${estimate.customerName ?? 'client'}',
      );

      await context.read<EstimatesCubit>().markEstimateAsShared(
        estimateId: estimate.id!,
      );

      final updatedEstimate = await context
          .read<EstimatesCubit>()
          .getEstimateById(estimate.id!);

      if (!mounted) return;

      setState(() {
        _estimate =
            updatedEstimate ??
            estimate.copyWith(
              status: EstimateStatus.shared,
              sharedAt: DateTime.now(),
            );
      });
    });
  }

  Future<void> _showSaveOptionsDialog() async {
    final estimate = _estimate;
    if (estimate == null || estimate.id == null) return;

    final choice = await showDialog<_SaveEstimateChoice>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Save estimate'),
          content: const Text('How do you want to save this estimate?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(_SaveEstimateChoice.pdf);
              },
              child: const Text('Save as PDF'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(_SaveEstimateChoice.image);
              },
              child: const Text('Save as Image'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (choice == null) return;

    switch (choice) {
      case _SaveEstimateChoice.pdf:
        await _savePdfToFiles();
        break;
      case _SaveEstimateChoice.image:
        await _saveImageToGallery();
        break;
    }
  }

  Future<void> _savePdfToFiles() async {
    final estimate = _estimate;
    if (estimate == null || estimate.id == null) return;

    await _runBusyTask(() async {
      final savedPath = await _documentService.savePdfToUserSelectedLocation(
        estimate,
      );

      if (!mounted) return;

      if (savedPath == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('PDF save cancelled.')));
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('PDF saved successfully.')));
    });
  }

  Future<void> _saveImageToGallery() async {
    final estimate = _estimate;
    if (estimate == null || estimate.id == null) return;

    await _runBusyTask(() async {
      final imageBytes = await _capturePreviewAsImage();

      await _documentService.saveImageToGallery(
        imageBytes: imageBytes,
        albumName: 'WoodQuote',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Image saved to gallery.')));
    });
  }

  Future<Uint8List> _capturePreviewAsImage() async {
    final boundary =
        _documentKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;

    if (boundary == null) {
      throw Exception('Could not capture estimate preview.');
    }

    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      throw Exception('Could not convert preview to image.');
    }

    return byteData.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    final estimate = _estimate;

    if (_loading || estimate == null) {
      return Scaffold(
        backgroundColor: neutral,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final double bottomSpace = estimate.status == EstimateStatus.draft
        ? 190
        : 250;

    return Scaffold(
      backgroundColor: neutral,
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: CustomScrollView(
                slivers: [
                  CustomAppBar(),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 28, 16, bottomSpace),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        const _PreviewHeader(),
                        const SizedBox(height: 24),

                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.62,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              if (!_initialZoomApplied) {
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (!mounted) return;

                                  final scale =
                                      (constraints.maxWidth / _paperWidth)
                                          .clamp(0.42, 1.0);

                                  _previewController.value = Matrix4.identity()
                                    ..translateByDouble(0.0, 0.0, 0.0, 1.0)
                                    ..scaleByDouble(scale, scale, scale, 1.0);

                                  _initialZoomApplied = true;
                                });
                              }

                              return ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: InteractiveViewer(
                                  transformationController: _previewController,
                                  minScale: 0.35,
                                  maxScale: 3.0,
                                  boundaryMargin: const EdgeInsets.all(500),
                                  constrained: false,
                                  child: RepaintBoundary(
                                    key: _documentKey,
                                    child: SizedBox(
                                      width: _paperWidth,
                                      height: _paperHeight,
                                      child: _EstimateDocumentView(
                                        estimate: estimate,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _PreviewBottomActions(
              estimate: estimate,
              busy: _busy,
              onEdit: _editDraft,
              onFinalise: _finaliseAndGeneratePdf,
              onSharePdf: _shareAsPdf,
              onShareImage: _shareAsImage,
              onOpenPdf: _showSaveOptionsDialog,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Estimate Preview',
          style: TextStyle(
            color: textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Review professional document before sending',
          style: TextStyle(
            color: Color(0xFF5F5145),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

const Color _ink = Color(0xFF1A1209);
const Color _inkLight = Color(0xFF4A4035);

class _EstimateDocumentView extends StatelessWidget {
  final Estimate estimate;

  const _EstimateDocumentView({required this.estimate});

  @override
  Widget build(BuildContext context) {
    final documentItems = List<LineItem>.from(estimate.lineItems)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final dateText = estimate.date == null
        ? 'No date'
        : DateFormat('MMM d, yyyy').format(estimate.date!);

    final total = estimate.computedTotal;

    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD6C5B6), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CompanyHeader(),
          const SizedBox(height: _topSectionGap),
          const _EstimateTitleDivider(),
          const SizedBox(height: _topSectionGap),
          _CustomerAndMetaSection(estimate: estimate, dateText: dateText),
          const SizedBox(height: _topSectionGap),
          _DescriptionSection(description: estimate.jobDescription),
          const SizedBox(height: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ItemsTable(items: documentItems, total: total),

                const SizedBox(height: 35),

                _DocumentFooter(
                  dateText: dateText,
                  validity: estimate.validity,
                  termsOfPayment: estimate.termsOfPayment,
                ),

                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanyHeader extends StatelessWidget {
  const _CompanyHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'LUMBER SHAPES FURNITURE',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _ink,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            fontFamily: 'serif',
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'P.O. BOX DS 877, Dasoman, Accra  0244607278 / 0206528863',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _ink,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            fontFamily: 'serif',
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: _sheetStroke, width: _sectionBorderWidth),
          ),
          child: const Text(
            'Expert in Office & Domestic Furniture, Fabricating of Aluminium Doors & Windows, General Construction',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _ink,
              fontSize: 11, // same as company address
              height: 1.15,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w700,
              fontFamily: 'serif',
            ),
          ),
        ),
      ],
    );
  }
}

class _EstimateTitleDivider extends StatelessWidget {
  const _EstimateTitleDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      decoration: const BoxDecoration(
        border: Border.fromBorderSide(_sectionBorderSide),
      ),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
        color: Colors.black,
        child: const Text(
          'ESTIMATE / QUOTATION',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
            fontFamily: 'serif',
          ),
        ),
      ),
    );
  }
}

class _CustomerAndMetaSection extends StatelessWidget {
  final Estimate estimate;
  final String dateText;

  const _CustomerAndMetaSection({
    required this.estimate,
    required this.dateText,
  });

  @override
  Widget build(BuildContext context) {
    final jobNo = estimate.id != null ? '#${estimate.id}' : '—';

    return SizedBox(
      height: 96,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 2,
            child: _DocumentBox(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: _sectionLabelPadding,
                    child: _TopSectionLabel("Customer's Name & Address"),
                  ),
                  const _SectionRule(),
                  Expanded(
                    child: Padding(
                      padding: _sectionValuePadding,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _DocumentStrongText(
                          estimate.customerName ?? 'Unnamed client',
                        ),
                      ),
                    ),
                  ),
                  const _SectionRule(),
                  Expanded(
                    child: Padding(
                      padding: _sectionValuePadding,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _DocumentStrongText(
                          estimate.address ?? 'No address',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // const SizedBox(width: 50),
          const Spacer(),
          SizedBox(
            width: 174,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 48,
                  child: Column(
                    children: const [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _MetaSideLabel('Date'),
                        ),
                      ),
                      SizedBox(height: 10),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _MetaSideLabel('Job No'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: _MetaValueBox(value: dateText)),
                      const SizedBox(height: 10),
                      Expanded(child: _MetaValueBox(value: jobNo)),
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
}

class _DescriptionSection extends StatelessWidget {
  final String? description;

  const _DescriptionSection({required this.description});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 100,
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _sheetStroke,
                width: _sectionBorderWidth,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DocumentStrongText(description ?? 'No description'),

                const SizedBox(height: 6),
                const _DescriptionWritingLine(),

                const SizedBox(height: 30),
                const _DescriptionWritingLine(),
              ],
            ),
          ),
          Positioned(
            left: 14,
            top: -8,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              child: const _TopSectionLabel('Job Description / Specification'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemsTable extends StatelessWidget {
  final List<LineItem> items;
  final double total;

  const _ItemsTable({required this.items, required this.total});

  static const int _visibleRows = 14;

  // Adjust this if the description breaks too early or too late.
  static const int _descriptionCharsPerRow = 55;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat('#,##0.00', 'en_US');

    final tableRows = <TableRow>[];
    int itemNumber = 0;

    TableRow emptyRow() {
      return const TableRow(
        children: [
          _TableCell('', center: true, height: 30),
          _TableCell('', height: 30),
          _TableCell('', center: true, height: 30),
          _TableCell('', alignRight: true, height: 30),
          _TableCell('', alignRight: true, height: 30),
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
            : money.format(item.headerValue!);

        for (int partIndex = 0; partIndex < headerParts.length; partIndex++) {
          final isLastPart = partIndex == headerParts.length - 1;

          tableRows.add(
            TableRow(
              children: [
                const _TableCell('', center: true, height: 30),
                _TableCell(
                  headerParts[partIndex],
                  bold: true,
                  center: false,
                  height: 30,
                ),
                const _TableCell('', center: true, height: 30),
                const _TableCell('', alignRight: true, height: 30),
                _TableCell(
                  isLastPart ? headerAmount : '',
                  alignRight: true,
                  height: 30,
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

        final quantityText = isLastPart && item.quantity != null
            ? _formatQuantity(item.quantity!)
            : '';

        final unitPriceText = isLastPart && item.unitPrice != null
            ? money.format(item.unitPrice!)
            : '';

        final amountText = isLastPart && item.unitPrice != null
            ? money.format(item.total)
            : '';

        tableRows.add(
          TableRow(
            children: [
              _TableCell(
                isFirstPart ? '$itemNumber' : '',
                bold: true,
                center: true,
                height: 30,
              ),

              _TableCell(descriptionParts[partIndex], bold: true, height: 30),

              _TableCell(quantityText, bold: true, center: true, height: 30),

              _TableCell(
                unitPriceText,
                bold: true,
                alignRight: true,
                height: 30,
              ),

              _TableCell(amountText, bold: true, alignRight: true, height: 30),
            ],
          ),
        );
      }
    }

    while (tableRows.length < _visibleRows) {
      tableRows.add(emptyRow());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Table(
          border: const TableBorder(
            top: _tableBorderSide,
            bottom: _tableBorderSide,
            left: _tableBorderSide,
            right: _tableBorderSide,
            horizontalInside: _tableBorderSide,
            verticalInside: _tableBorderSide,
          ),
          columnWidths: const {
            0: FixedColumnWidth(54),
            1: FlexColumnWidth(),
            2: FixedColumnWidth(54),
            3: FixedColumnWidth(90),
            4: FixedColumnWidth(94),
          },
          children: [
            const TableRow(
              decoration: BoxDecoration(color: Color(0xFFF3EDE6)),
              children: [
                _TableHeaderCell('Item', center: true),
                _TableHeaderCell('Description', center: true),
                _TableHeaderCell('Qty', center: true),
                _TableHeaderCell('Unit\nCost', center: true),
                _TableHeaderCell('Amount', center: true),
              ],
            ),
            ...tableRows.take(_visibleRows),
          ],
        ),

        _GrandTotalRow(amountText: money.format(total)),
      ],
    );
  }

  static List<String> _splitDescriptionIntoRows(String text) {
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
      if (word.length > _descriptionCharsPerRow) {
        flushBuffer();

        for (
          int start = 0;
          start < word.length;
          start += _descriptionCharsPerRow
        ) {
          final end = start + _descriptionCharsPerRow > word.length
              ? word.length
              : start + _descriptionCharsPerRow;

          rows.add(word.substring(start, end));
        }

        continue;
      }

      final currentText = buffer.toString();

      final nextLength = currentText.isEmpty
          ? word.length
          : currentText.length + 1 + word.length;

      if (nextLength > _descriptionCharsPerRow) {
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

  static String _formatQuantity(double value) {
    if (value % 1 == 0) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }
}

class _GrandTotalRow extends StatelessWidget {
  final String amountText;

  const _GrandTotalRow({required this.amountText});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: Row(
        children: [
          const Spacer(),
          const Text(
            'Grand Total',
            style: TextStyle(
              color: _ink,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              fontFamily: 'serif',
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 94,
            height: 38,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: const BoxDecoration(
              border: Border(
                left: _tableBorderSide,
                right: _tableBorderSide,
                top: _tableBorderSide,
                bottom: _tableBorderSide,
              ),
            ),
            child: Text(
              amountText,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: _ink,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                fontFamily: 'serif',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentFooter extends StatelessWidget {
  final String dateText;
  final String? validity;
  final String? termsOfPayment;

  const _DocumentFooter({
    required this.dateText,
    required this.validity,
    required this.termsOfPayment,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _FooterLineField(
                label: 'VALIDITY:',
                value: validity?.trim() ?? '',
              ),
            ),
            SizedBox(width: 36),
            Expanded(
              flex: 2,
              child: _FooterLineField(
                label: 'TERMS OF PAYMENT:',
                value: termsOfPayment?.trim() ?? '',
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        Row(
          children: [
            const Expanded(
              child: _FooterLineField(label: 'SIGNATURE:', value: ''),
            ),
            const SizedBox(width: 18),
            const Expanded(
              child: _FooterLineField(
                label: 'NAME:',
                value: 'Raphael Degadzor',
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: _FooterLineField(label: 'DATE:', value: dateText),
            ),
          ],
        ),
      ],
    );
  }
}

class _FooterLineField extends StatelessWidget {
  final String label;
  final String value;

  const _FooterLineField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _ink,
            fontSize: 11,
            fontFamily: 'serif',
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: SizedBox(
            height: 20,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 2,
                  child: CustomPaint(
                    painter: _DottedLinePainter(),
                    child: const SizedBox(height: 1),
                  ),
                ),
                if (value.trim().isNotEmpty)
                  Positioned(
                    left: 4,
                    bottom: 3,
                    right: 0,
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 11,
                        fontFamily: 'serif',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _inkLight
      ..strokeWidth = 1;

    const dashWidth = 2.5;
    const dashSpace = 3.5;
    double x = 0;

    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashWidth, 0), paint);
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DocumentBox extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _DocumentBox({
    required this.child,
    this.padding = const EdgeInsets.all(10),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: const BoxDecoration(
        border: Border.fromBorderSide(_sectionBorderSide),
      ),
      child: child,
    );
  }
}

class _TopSectionLabel extends StatelessWidget {
  final String text;

  const _TopSectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: _ink,
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        fontFamily: 'serif',
      ),
    );
  }
}

class _MetaSideLabel extends StatelessWidget {
  final String text;

  const _MetaSideLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: _ink,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        fontFamily: 'serif',
      ),
    );
  }
}

class _SectionRule extends StatelessWidget {
  const _SectionRule();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: _sectionInnerWidth,
      child: ColoredBox(color: _sheetInnerLine),
    );
  }
}

class _DescriptionWritingLine extends StatelessWidget {
  const _DescriptionWritingLine();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: double.infinity,
      height: 1.15,
      child: ColoredBox(color: _sheetInnerLine),
    );
  }
}

class _MetaValueBox extends StatelessWidget {
  final String value;

  const _MetaValueBox({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.centerLeft,
      decoration: const BoxDecoration(
        border: Border.fromBorderSide(_sectionBorderSide),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: _ink,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          fontFamily: 'serif',
        ),
      ),
    );
  }
}

class _DocumentStrongText extends StatelessWidget {
  final String text;

  const _DocumentStrongText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: _ink,
        fontSize: 13,
        fontWeight: FontWeight.w800,
        fontFamily: 'serif',
      ),
    );
  }
}

class _TableHeaderCell extends StatelessWidget {
  final String text;
  final bool center;

  const _TableHeaderCell(this.text, {this.center = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      alignment: center ? Alignment.center : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Text(
        text,
        textAlign: center ? TextAlign.center : TextAlign.left,
        maxLines: 2,
        overflow: TextOverflow.visible,
        style: const TextStyle(
          // ✅ Fully black header text
          color: _ink,
          fontSize: 13,
          height: 1.1,
          fontWeight: FontWeight.w900,
          fontFamily: 'serif',
        ),
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  final bool bold;
  final bool center;
  final bool alignRight;
  final double height;

  const _TableCell(
    this.text, {
    this.bold = false,
    this.center = false,
    this.alignRight = false,
    this.height = 30,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      alignment: center
          ? Alignment.center
          : alignRight
          ? Alignment.centerRight
          : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Text(
        text,
        textAlign: alignRight
            ? TextAlign.right
            : center
            ? TextAlign.center
            : TextAlign.left,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: _ink,
          fontSize: 12,
          height: 1.2,
          fontWeight: bold ? FontWeight.w900 : FontWeight.w500,
          fontFamily: 'serif',
        ),
      ),
    );
  }
}

class _PreviewBottomActions extends StatelessWidget {
  final Estimate estimate;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onFinalise;
  final VoidCallback onSharePdf;
  final VoidCallback onShareImage;
  final VoidCallback onOpenPdf;

  const _PreviewBottomActions({
    required this.estimate,
    required this.busy,
    required this.onEdit,
    required this.onFinalise,
    required this.onSharePdf,
    required this.onShareImage,
    required this.onOpenPdf,
  });

  @override
  Widget build(BuildContext context) {
    final isDraft = estimate.status == EstimateStatus.draft;

    return Container(
      decoration: BoxDecoration(
        color: neutral.withValues(alpha: 0.98),
        border: Border(top: BorderSide(color: divider.withValues(alpha: 0.8))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: busy
              ? const SizedBox(
                  height: 92,
                  child: Center(child: CircularProgressIndicator()),
                )
              : isDraft
              ? _DraftActions(onEdit: onEdit, onFinalise: onFinalise)
              : _FinalActions(
                  onSharePdf: onSharePdf,
                  onShareImage: onShareImage,
                  onOpenPdf: onOpenPdf,
                ),
        ),
      ),
    );
  }
}

class _DraftActions extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onFinalise;

  const _DraftActions({required this.onEdit, required this.onFinalise});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PreviewActionButton(
            label: 'Edit Draft',
            icon: Icons.edit_outlined,
            filled: false,
            onTap: onEdit,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PreviewActionButton(
            label: 'Finalize PDF',
            icon: Icons.picture_as_pdf_outlined,
            filled: true,
            onTap: onFinalise,
          ),
        ),
      ],
    );
  }
}

class _FinalActions extends StatelessWidget {
  final VoidCallback onSharePdf;
  final VoidCallback onShareImage;
  final VoidCallback onOpenPdf;

  const _FinalActions({
    required this.onSharePdf,
    required this.onShareImage,
    required this.onOpenPdf,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _PreviewActionButton(
                label: 'Share PDF',
                icon: Icons.picture_as_pdf_outlined,
                filled: true,
                onTap: onSharePdf,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PreviewActionButton(
                label: 'Share Image',
                icon: Icons.image_outlined,
                filled: false,
                onTap: onShareImage,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: onOpenPdf,
          icon: Icon(Icons.save_outlined, color: primary),
          label: Text(
            'Save to device',
            style: TextStyle(
              color: primary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviewActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  const _PreviewActionButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = filled ? primary : Colors.transparent;
    final foregroundColor = filled ? Colors.white : primary;

    final labelWidget = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );

    return SizedBox(
      height: 58,
      width: double.infinity,
      child: filled
          ? ElevatedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 20),
              label: labelWidget,
              style: ElevatedButton.styleFrom(
                backgroundColor: backgroundColor,
                foregroundColor: foregroundColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 20),
              label: labelWidget,
              style: OutlinedButton.styleFrom(
                foregroundColor: foregroundColor,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                side: BorderSide(color: primary, width: 1.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
    );
  }
}
