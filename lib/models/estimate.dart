// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:wood_quote/models/line_item.dart';

enum EstimateStatus { finalised, shared, draft }

class Estimate {
  final int? id;
  final String? customerName;
  final String? address;
  final DateTime? date;
  final String? jobDescription;
  final String? validity;
  final String? termsOfPayment;
  final List<LineItem> lineItems;
  final double amount;
  final EstimateStatus status;
  final String? pdfPath;
  final DateTime? pdfGeneratedAt;
  final DateTime? sharedAt;

  Estimate({
    this.id,
    this.customerName,
    this.address,
    this.date,
    this.jobDescription,
    this.validity,
    this.termsOfPayment,
    this.lineItems = const [],
    this.amount = 0,
    this.status = EstimateStatus.draft,
    this.pdfPath,
    this.pdfGeneratedAt,
    this.sharedAt,
  });

  Estimate copyWith({
    int? id,
    String? customerName,
    String? address,
    DateTime? date,
    String? jobDescription,
    String? validity,
    String? termsOfPayment,
    List<LineItem>? lineItems,
    double? amount,
    EstimateStatus? status,
    String? pdfPath,
    DateTime? pdfGeneratedAt,
    DateTime? sharedAt,
  }) {
    return Estimate(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      address: address ?? this.address,
      date: date ?? this.date,
      jobDescription: jobDescription ?? this.jobDescription,
      validity: validity ?? this.validity,
      termsOfPayment: termsOfPayment ?? this.termsOfPayment,
      lineItems: lineItems ?? this.lineItems,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      pdfPath: pdfPath ?? this.pdfPath,
      pdfGeneratedAt: pdfGeneratedAt ?? this.pdfGeneratedAt,
      sharedAt: sharedAt ?? this.sharedAt,
    );
  }

  String get statusLabel {
    switch (status) {
      case EstimateStatus.finalised:
        return 'FINAL';
      case EstimateStatus.shared:
        return 'SHARED';
      case EstimateStatus.draft:
        return 'DRAFT';
    }
  }

  bool get isDraft => status == EstimateStatus.draft;

  bool get isFinalised => status == EstimateStatus.finalised;

  bool get isShared => status == EstimateStatus.shared;

  bool get hasPdf => pdfPath != null && pdfPath!.trim().isNotEmpty;

  double get computedTotal => lineItems
      .where((item) => item.type == LineItemType.normal)
      .fold(0, (sum, item) => sum + item.total);

  Estimate clearCustomerName() => _copy(clearCustomerName: true);
  Estimate clearAddress() => _copy(clearAddress: true);
  Estimate clearDate() => _copy(clearDate: true);
  Estimate clearJobDescription() => _copy(clearJobDescription: true);
  Estimate clearValidity() => _copy(clearValidity: true);
  Estimate clearTermsOfPayment() => _copy(clearTermsOfPayment: true);
  Estimate clearPdfPath() => _copy(clearPdfPath: true);
  Estimate clearPdfGeneratedAt() => _copy(clearPdfGeneratedAt: true);
  Estimate clearSharedAt() => _copy(clearSharedAt: true);

  Estimate _copy({
    bool clearCustomerName = false,
    bool clearAddress = false,
    bool clearDate = false,
    bool clearJobDescription = false,
    bool clearValidity = false,
    bool clearTermsOfPayment = false,
    bool clearPdfPath = false,
    bool clearPdfGeneratedAt = false,
    bool clearSharedAt = false,
  }) {
    return Estimate(
      id: id,
      customerName: clearCustomerName ? null : customerName,
      address: clearAddress ? null : address,
      date: clearDate ? null : date,
      jobDescription: clearJobDescription ? null : jobDescription,
      validity: clearValidity ? null : validity,
      termsOfPayment: clearTermsOfPayment ? null : termsOfPayment,
      lineItems: lineItems,
      amount: amount,
      status: status,
      pdfPath: clearPdfPath ? null : pdfPath,
      pdfGeneratedAt: clearPdfGeneratedAt ? null : pdfGeneratedAt,
      sharedAt: clearSharedAt ? null : sharedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      if (id != null) 'id': id,
      'customer_name': customerName,
      'address': address,
      'date': date?.toIso8601String(),
      'job_description': jobDescription,
      'validity': validity,
      'terms_of_payment': termsOfPayment,
      'amount': amount,
      'status': status.index,
      'pdf_path': pdfPath,
      'pdf_generated_at': pdfGeneratedAt?.toIso8601String(),
      'shared_at': sharedAt?.toIso8601String(),
    };
  }

  factory Estimate.fromMap(
    Map<String, dynamic> map, {
    List<LineItem> lineItems = const [],
  }) {
    return Estimate(
      id: map['id'] as int?,
      customerName: map['customer_name'] as String?,
      address: map['address'] as String?,
      date: map['date'] != null ? DateTime.parse(map['date'] as String) : null,
      jobDescription: map['job_description'] as String?,
      validity: map['validity'] as String?,
      termsOfPayment: map['terms_of_payment'] as String?,
      lineItems: lineItems,
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      status: EstimateStatus.values[map['status'] as int],
      pdfPath: map['pdf_path'] as String?,
      pdfGeneratedAt: map['pdf_generated_at'] != null
          ? DateTime.parse(map['pdf_generated_at'] as String)
          : null,
      sharedAt: map['shared_at'] != null
          ? DateTime.parse(map['shared_at'] as String)
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory Estimate.fromJson(String source) =>
      Estimate.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'Estimate(id: $id, customerName: $customerName, address: $address, date: $date, jobDescription: $jobDescription, validity: $validity, termsOfPayment: $termsOfPayment, lineItems: $lineItems, amount: $amount, status: $status, pdfPath: $pdfPath, pdfGeneratedAt: $pdfGeneratedAt, sharedAt: $sharedAt)';
  }

  @override
  bool operator ==(covariant Estimate other) {
    if (identical(this, other)) return true;

    return other.id == id &&
        other.customerName == customerName &&
        other.address == address &&
        other.date == date &&
        other.jobDescription == jobDescription &&
        other.validity == validity &&
        other.termsOfPayment == termsOfPayment &&
        listEquals(other.lineItems, lineItems) &&
        other.amount == amount &&
        other.status == status &&
        other.pdfPath == pdfPath &&
        other.pdfGeneratedAt == pdfGeneratedAt &&
        other.sharedAt == sharedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        customerName.hashCode ^
        address.hashCode ^
        date.hashCode ^
        jobDescription.hashCode ^
        validity.hashCode ^
        termsOfPayment.hashCode ^
        lineItems.hashCode ^
        amount.hashCode ^
        status.hashCode ^
        pdfPath.hashCode ^
        pdfGeneratedAt.hashCode ^
        sharedAt.hashCode;
  }
}
