// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

enum LineItemType { normal, header }

class LineItem {
  final int? id;
  final int? estimateId;
  final String? description;
  final double? quantity;
  final double? unitPrice;
  final double? headerValue;
  final bool addBlankRowBefore;
  final LineItemType type;
  final int sortOrder;

  LineItem({
    this.id,
    this.estimateId,
    this.description,
    this.quantity,
    this.unitPrice,
    this.headerValue,
    this.addBlankRowBefore = true,
    this.type = LineItemType.normal,
    required this.sortOrder,
  });

  LineItem copyWith({
    int? id,
    int? estimateId,
    String? description,
    double? quantity,
    double? unitPrice,
    double? headerValue,
    bool? addBlankRowBefore,
    LineItemType? type,
    int? sortOrder,
  }) {
    return LineItem(
      id: id ?? this.id,
      estimateId: estimateId ?? this.estimateId,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      headerValue: headerValue ?? this.headerValue,
      addBlankRowBefore: addBlankRowBefore ?? this.addBlankRowBefore,
      type: type ?? this.type,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  bool get isHeader => type == LineItemType.header;
  bool get hasQuantity => quantity != null;
  bool get hasUnitPrice => unitPrice != null;
  bool get hasHeaderValue => headerValue != null;

  double get total {
    if (isHeader || unitPrice == null) {
      return 0;
    }

    final effectiveQuantity = quantity ?? 1;
    return effectiveQuantity * unitPrice!;
  }

  LineItem clearDescription() => LineItem(
    id: id,
    estimateId: estimateId,
    description: null,
    quantity: quantity,
    unitPrice: unitPrice,
    headerValue: headerValue,
    addBlankRowBefore: addBlankRowBefore,
    type: type,
    sortOrder: sortOrder,
  );

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      if (id != null) 'id': id,
      'estimate_id': estimateId,
      'description': description,
      'quantity': quantity,
      'unit_price': unitPrice,
      'header_value': headerValue,
      'add_blank_row_before': addBlankRowBefore,
      'type': type.index,
      'sort_order': sortOrder,
    };
  }

  factory LineItem.fromMap(Map<String, dynamic> map) {
    return LineItem(
      id: map['id'] as int?,
      estimateId: map['estimate_id'] as int?,
      description: map['description'] as String?,
      quantity: (map['quantity'] as num?)?.toDouble(),
      unitPrice: (map['unit_price'] as num?)?.toDouble(),
      headerValue: (map['header_value'] as num?)?.toDouble(),
      addBlankRowBefore:
          ((map['add_blank_row_before'] as num?)?.toInt() ?? 1) == 1,
      type: LineItemType.values[map['type'] as int],
      sortOrder: map['sort_order'] as int,
    );
  }

  String toJson() => json.encode(toMap());

  factory LineItem.fromJson(String source) =>
      LineItem.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'LineItem(id: $id, estimateId: $estimateId, description: $description, quantity: $quantity, unitPrice: $unitPrice, headerValue: $headerValue, addBlankRowBefore: $addBlankRowBefore, type: $type, sortOrder: $sortOrder)';
  }

  @override
  bool operator ==(covariant LineItem other) {
    if (identical(this, other)) return true;

    return other.id == id &&
        other.estimateId == estimateId &&
        other.description == description &&
        other.quantity == quantity &&
        other.unitPrice == unitPrice &&
        other.headerValue == headerValue &&
        other.addBlankRowBefore == addBlankRowBefore &&
        other.type == type &&
        other.sortOrder == sortOrder;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        estimateId.hashCode ^
        description.hashCode ^
        quantity.hashCode ^
        unitPrice.hashCode ^
        headerValue.hashCode ^
        addBlankRowBefore.hashCode ^
        type.hashCode ^
        sortOrder.hashCode;
  }
}
