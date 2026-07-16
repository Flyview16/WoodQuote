import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:wood_quote/bloc/cubit/estimates_cubit.dart';
import 'package:wood_quote/models/estimate.dart';
import 'package:wood_quote/models/line_item.dart';
import 'package:wood_quote/screens/estimate_preview_screen.dart';
import 'package:wood_quote/screens/shared_widgets/custom_appbar.dart';
import 'package:wood_quote/utils/colors.dart';

class CreateScreen extends StatefulWidget {
  final Estimate? estimate;

  const CreateScreen({super.key, this.estimate});

  bool get isEditing => estimate != null;

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  final _formKey = GlobalKey<FormState>();

  final _clientNameController = TextEditingController();
  final _dateController = TextEditingController();
  final _addressController = TextEditingController();
  final _jobDescriptionController = TextEditingController();
  final _validityController = TextEditingController();
  final _termsOfPaymentController = TextEditingController();

  DateTime _selectedDate = DateTime.now();

  final List<_EditableLineItem> _items = [];

  @override
  void initState() {
    super.initState();
    final estimate = widget.estimate;

    if (estimate == null) {
      _selectedDate = DateTime.now();
      _dateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate);
      _items.add(_EditableLineItem.normal());
      return;
    }

    _clientNameController.text = estimate.customerName ?? '';
    _addressController.text = estimate.address ?? '';
    _jobDescriptionController.text = estimate.jobDescription ?? '';
    _validityController.text = estimate.validity ?? '';
    _termsOfPaymentController.text = estimate.termsOfPayment ?? '';

    _selectedDate = estimate.date ?? DateTime.now();
    _dateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate);

    final sortedItems = List<LineItem>.from(estimate.lineItems)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    if (sortedItems.isEmpty) {
      _items.add(_EditableLineItem.normal());
    } else {
      _items.addAll(sortedItems.map(_EditableLineItem.fromLineItem));
    }
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    _dateController.dispose();
    _addressController.dispose();
    _jobDescriptionController.dispose();
    _validityController.dispose();
    _termsOfPaymentController.dispose();

    for (final item in _items) {
      item.dispose();
    }

    super.dispose();
  }

  double get _estimatedTotal {
    return _items.fold<double>(0, (sum, item) {
      if (item.type == LineItemType.header) return sum;
      return sum + item.total;
    });
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null) return;

    setState(() {
      _selectedDate = pickedDate;
      _dateController.text = DateFormat('dd/MM/yyyy').format(pickedDate);
    });
  }

  void _addLineItem() {
    setState(() {
      _items.add(_EditableLineItem.normal());
    });
  }

  void _addHeader() {
    setState(() {
      _items.add(_EditableLineItem.header());
    });
  }

  void _removeItem(int index) {
    setState(() {
      final removed = _items.removeAt(index);
      removed.dispose();

      if (_items.isEmpty) {
        _items.add(_EditableLineItem.normal());
      }
    });
  }

  Estimate? _buildDraftEstimateFromForm() {
    final lineItems = <LineItem>[];

    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      final description = item.description.trim();

      if (item.type == LineItemType.header) {
        if (description.isEmpty && item.headerValue == null) {
          continue;
        }
      } else {
        if (description.isEmpty &&
            item.quantity == null &&
            item.unitPrice == null) {
          continue;
        }
      }

      lineItems.add(
        LineItem(
          description: description.isEmpty ? null : description,
          quantity: item.type == LineItemType.normal ? item.quantity : null,
          unitPrice: item.type == LineItemType.normal ? item.unitPrice : null,
          headerValue: item.type == LineItemType.header
              ? item.headerValue
              : null,
          addBlankRowBefore: item.type == LineItemType.header
              ? item.addBlankRowBefore
              : false,
          type: item.type,
          sortOrder: i,
        ),
      );
    }

    if (_clientNameController.text.trim().isEmpty && lineItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a client name or at least one line item.'),
        ),
      );
      return null;
    }

    return Estimate(
      id: widget.estimate?.id,
      customerName: _emptyToNull(_clientNameController.text),
      address: _emptyToNull(_addressController.text),
      date: _selectedDate,
      jobDescription: _emptyToNull(_jobDescriptionController.text),
      validity: _emptyToNull(_validityController.text),
      termsOfPayment: _emptyToNull(_termsOfPaymentController.text),
      lineItems: lineItems,
      status: EstimateStatus.draft,
      pdfPath: widget.estimate?.pdfPath,
      pdfGeneratedAt: widget.estimate?.pdfGeneratedAt,
      sharedAt: widget.estimate?.sharedAt,
    );
  }

  Future<Estimate?> _saveDraftToDatabase() async {
    final estimate = _buildDraftEstimateFromForm();

    if (estimate == null) return null;

    if (widget.isEditing) {
      return context.read<EstimatesCubit>().updateEstimate(estimate);
    }

    return context.read<EstimatesCubit>().createEstimate(estimate);
  }

  Future<void> _saveDraft() async {
    final savedEstimate = await _saveDraftToDatabase();

    if (!mounted || savedEstimate == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.isEditing
              ? 'Draft estimate updated.'
              : 'Estimate saved as draft.',
        ),
      ),
    );

    Navigator.pop(context);
  }

  Future<void> _previewEstimate() async {
    final savedEstimate = await _saveDraftToDatabase();

    if (!mounted || savedEstimate == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EstimatePreviewScreen(estimate: savedEstimate),
      ),
    );

    if (!mounted) return;

    if (!widget.isEditing) {
      Navigator.pop(context);
    }
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return trimmed;
  }

  void _reorderItem(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }

      final movedItem = _items.removeAt(oldIndex);
      _items.insert(newIndex, movedItem);
    });
  }

  @override
  Widget build(BuildContext context) {
    final formattedTotal = NumberFormat(
      '#,##0.00',
      'en_US',
    ).format(_estimatedTotal);

    return Scaffold(
      backgroundColor: neutral,
      body: CustomScrollView(
        slivers: [
          CustomAppBar(),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _PageHeader(isEditing: widget.isEditing),
                const SizedBox(height: 24),

                _ClientDetailsCard(
                  formKey: _formKey,
                  clientNameController: _clientNameController,
                  dateController: _dateController,
                  addressController: _addressController,
                  jobDescriptionController: _jobDescriptionController,
                  onDateTap: _pickDate,
                ),

                const SizedBox(height: 24),

                _EstimateTermsCard(
                  validityController: _validityController,
                  termsOfPaymentController: _termsOfPaymentController,
                ),

                const SizedBox(height: 34),

                const _SectionTitle(title: 'LINE ITEMS & SECTIONS'),
                const SizedBox(height: 20),
              ]),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverReorderableList(
              itemCount: _items.length,
              onReorder: _reorderItem,

              proxyDecorator: (child, index, animation) {
                return Material(type: MaterialType.transparency, child: child);
              },

              itemBuilder: (context, index) {
                final item = _items[index];

                final dragHandle = _DragHandle(index: index);

                if (item.type == LineItemType.header) {
                  return Padding(
                    key: item.reorderKey,
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _HeaderCard(
                      item: item,
                      dragHandle: dragHandle,
                      onChanged: () => setState(() {}),
                      onDelete: () => _removeItem(index),
                    ),
                  );
                }

                return Padding(
                  key: item.reorderKey,
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _LineItemCard(
                    item: item,
                    dragHandle: dragHandle,
                    onChanged: () => setState(() {}),
                    onDelete: () => _removeItem(index),
                  ),
                );
              },
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 160),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: _DashedActionButton(
                      icon: Icons.add_circle_outline_rounded,
                      label: 'Line Item',
                      onTap: _addLineItem,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DashedActionButton(
                      icon: Icons.format_list_bulleted_rounded,
                      label: 'Header',
                      onTap: _addHeader,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _EstimateBottomBar(
        total: formattedTotal,
        onSave: _saveDraft,
        onPreview: _previewEstimate,
      ),
    );
  }
}

class _EditableLineItem {
  final Key reorderKey;
  final LineItemType type;
  final TextEditingController descriptionController;
  final TextEditingController quantityController;
  final TextEditingController unitPriceController;
  final TextEditingController headerValueController;
  bool addBlankRowBefore;

  _EditableLineItem._({
    required this.type,
    required String description,
    required String quantity,
    required String unitPrice,
    required String headerValue,
    required this.addBlankRowBefore,
  }) : reorderKey = UniqueKey(),
       descriptionController = TextEditingController(text: description),
       quantityController = TextEditingController(text: quantity),
       unitPriceController = TextEditingController(text: unitPrice),
       headerValueController = TextEditingController(text: headerValue);

  factory _EditableLineItem.normal() {
    return _EditableLineItem._(
      type: LineItemType.normal,
      description: '',
      quantity: '',
      unitPrice: '',
      headerValue: '',
      addBlankRowBefore: false,
    );
  }

  factory _EditableLineItem.header() {
    return _EditableLineItem._(
      type: LineItemType.header,
      description: '',
      quantity: '',
      unitPrice: '',
      headerValue: '',
      addBlankRowBefore: true,
    );
  }

  factory _EditableLineItem.fromLineItem(LineItem item) {
    return _EditableLineItem._(
      type: item.type,
      description: item.description ?? '',
      quantity: _formatNumberForInput(item.quantity),
      unitPrice: _formatNumberForInput(item.unitPrice),
      headerValue: _formatNumberForInput(item.headerValue),
      addBlankRowBefore: item.addBlankRowBefore,
    );
  }

  static String _formatNumberForInput(double? value) {
    if (value == null) return '';

    if (value % 1 == 0) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  String get description => descriptionController.text;

  double? get quantity {
    final value = quantityController.text.trim();

    if (value.isEmpty) return null;

    return double.tryParse(value);
  }

  double? get unitPrice {
    final value = unitPriceController.text.trim();

    if (value.isEmpty) return null;

    return double.tryParse(value);
  }

  double? get headerValue {
    final value = headerValueController.text.trim();

    if (value.isEmpty) return null;

    return double.tryParse(value);
  }

  double get total {
    if (type == LineItemType.header || unitPrice == null) {
      return 0;
    }

    return (quantity ?? 1) * unitPrice!;
  }

  bool get hasCalculatedTotal =>
      type == LineItemType.normal && unitPrice != null;

  void dispose() {
    descriptionController.dispose();
    quantityController.dispose();
    unitPriceController.dispose();
    headerValueController.dispose();
  }
}

class _PageHeader extends StatelessWidget {
  final bool isEditing;

  const _PageHeader({required this.isEditing});

  @override
  Widget build(BuildContext context) {
    return Text(
      isEditing ? 'Edit Estimate' : 'New Estimate',
      style: const TextStyle(
        color: textPrimary,
        fontSize: 24,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _ClientDetailsCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController clientNameController;
  final TextEditingController dateController;
  final TextEditingController addressController;
  final TextEditingController jobDescriptionController;
  final VoidCallback onDateTap;

  const _ClientDetailsCard({
    required this.formKey,
    required this.clientNameController,
    required this.dateController,
    required this.addressController,
    required this.jobDescriptionController,
    required this.onDateTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: divider, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          children: [
            _LabeledInput(
              label: 'CLIENT NAME',
              hint: 'e.g. Samuel Arhin',
              controller: clientNameController,
            ),
            const SizedBox(height: 20),
            _LabeledInput(
              label: 'DATE',
              hint: '24/05/2024',
              controller: dateController,
              readOnly: true,
              onTap: onDateTap,
              suffixIcon: Icons.calendar_today_rounded,
            ),
            const SizedBox(height: 20),
            _LabeledInput(
              label: 'CLIENT ADDRESS',
              hint: 'Street name, City, Region',
              controller: addressController,
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            _LabeledInput(
              label: 'JOB DESCRIPTION',
              hint: 'Outline the scope of wood work needed...',
              controller: jobDescriptionController,
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }
}

class _EstimateTermsCard extends StatelessWidget {
  final TextEditingController validityController;
  final TextEditingController termsOfPaymentController;

  const _EstimateTermsCard({
    required this.validityController,
    required this.termsOfPaymentController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: divider, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ESTIMATE TERMS',
            style: TextStyle(
              color: textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),

          const SizedBox(height: 20),

          _LabeledInput(
            label: 'VALIDITY',
            hint: 'e.g. 30 days',
            controller: validityController,
          ),

          const SizedBox(height: 20),

          _LabeledInput(
            label: 'TERMS OF PAYMENT',
            hint: 'e.g. 60% deposit, 40% upon completion',
            controller: termsOfPaymentController,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

class _LabeledInput extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final IconData? suffixIcon;
  final int maxLines;

  const _LabeledInput({
    required this.label,
    required this.hint,
    required this.controller,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.suffixIcon,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          onTap: onTap,
          onChanged: onChanged,
          maxLines: maxLines,
          style: const TextStyle(
            color: textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: textSecondary.withValues(alpha: 0.48),
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
            filled: true,
            fillColor: neutral.withValues(alpha: 0.45),
            suffixIcon: suffixIcon == null
                ? null
                : Icon(suffixIcon, color: textPrimary, size: 18),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 16,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: secondary.withValues(alpha: 0.28),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: secondary.withValues(alpha: 0.7),
                width: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.3,
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  final int index;

  const _DragHandle({required this.index});

  @override
  Widget build(BuildContext context) {
    return ReorderableDragStartListener(
      index: index,
      child: const Padding(
        padding: EdgeInsets.all(4),
        child: Icon(
          Icons.drag_indicator_rounded,
          color: textSecondary,
          size: 24,
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final _EditableLineItem item;
  final Widget dragHandle;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const _HeaderCard({
    required this.item,
    required this.dragHandle,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: divider, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              dragHandle,
              const Spacer(),
              GestureDetector(
                onTap: onDelete,
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _LabeledInput(
            label: 'SECTION HEADER',
            hint: 'e.g. Materials, Labour, Finishing',
            controller: item.descriptionController,
            onChanged: (_) => onChanged(),
          ),

          const SizedBox(height: 18),

          _SmallNumberInput(
            label: 'HEADER TOTAL (OPTIONAL)',
            controller: item.headerValueController,
            onChanged: onChanged,
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: neutral.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: secondary.withValues(alpha: 0.18)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EMPTY ROW ABOVE HEADER',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Add spacing before this section header',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                Switch.adaptive(
                  value: item.addBlankRowBefore,
                  activeTrackColor: primary,
                  onChanged: (value) {
                    item.addBlankRowBefore = value;
                    onChanged();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LineItemCard extends StatelessWidget {
  final _EditableLineItem item;
  final Widget dragHandle;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const _LineItemCard({
    required this.item,
    required this.dragHandle,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final total = item.hasCalculatedTotal
        ? NumberFormat('#,##0.00', 'en_US').format(item.total)
        : '';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: divider, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              dragHandle,
              const Spacer(),
              GestureDetector(
                onTap: onDelete,
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                  size: 22,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          _LabeledInput(
            label: 'ITEM DESCRIPTION',
            hint: 'e.g. Mahogany Timber Planks',
            controller: item.descriptionController,
            onChanged: (_) => onChanged(),
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: _SmallNumberInput(
                  label: 'QTY',
                  controller: item.quantityController,
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SmallNumberInput(
                  label: 'UNIT PRICE',
                  controller: item.unitPriceController,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: neutral.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: secondary.withValues(alpha: 0.18),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Text(
                  'TOTAL (GH₵)',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
                const Spacer(),
                Text(
                  total,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
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

class _SmallNumberInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;

  const _SmallNumberInput({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: false,
          ),
          textInputAction: TextInputAction.next,
          onChanged: (_) => onChanged(),
          style: const TextStyle(
            color: textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: TextStyle(
              color: textSecondary.withValues(alpha: 0.48),
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
            filled: true,
            fillColor: neutral.withValues(alpha: 0.45),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 13,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: BorderSide(
                color: secondary.withValues(alpha: 0.24),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: BorderSide(
                color: secondary.withValues(alpha: 0.65),
                width: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DashedActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DashedActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 56,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: primary, size: 22),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: primary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = secondary.withValues(alpha: 0.4)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    const dashWidth = 6.0;
    const dashSpace = 5.0;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(14),
    );

    final path = Path()..addRRect(rrect);
    final metric = path.computeMetrics().first;

    double distance = 0;

    while (distance < metric.length) {
      final next = distance + dashWidth;

      canvas.drawPath(metric.extractPath(distance, next), paint);

      distance = next + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EstimateBottomBar extends StatelessWidget {
  final String total;
  final VoidCallback onSave;
  final VoidCallback onPreview;

  const _EstimateBottomBar({
    required this.total,
    required this.onSave,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: neutral.withValues(alpha: 0.95),
        border: Border(top: BorderSide(color: divider.withValues(alpha: 0.8))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text(
                    'ESTIMATED TOTAL',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: 'GH₵ ',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        TextSpan(
                          text: total,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    style: const TextStyle(color: textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onSave,
                      icon: const Icon(Icons.save_outlined, size: 20),
                      label: const Text('Save Draft'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primary,
                        side: BorderSide(color: primary, width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onPreview,
                      icon: const Icon(Icons.visibility_outlined, size: 20),
                      label: const Text('Preview'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
