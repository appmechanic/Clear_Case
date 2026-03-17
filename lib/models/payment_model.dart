import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentRecordModel {
  String? id;
  String? caseId;
  List<String>? childIds;
  List<String>? attachmentUrls;
  double? amount;
  DateTime? date;
  String? paymentType;
  String? paymentCategory; // The modern field name
  String? transactionType; // "PaymentReceived" | "PaymentPaid"
  String? paymentMethod;
  String? location;
  String? notes;
  bool? isReceived; // Kept for legacy compatibility
  bool? flagEntry;
  DateTime? createdAt;

  PaymentRecordModel({
    this.id,
    this.caseId,
    this.childIds,
    this.attachmentUrls,
    this.amount,
    this.date,
    this.paymentType,
    this.paymentCategory,
    this.transactionType,
    this.paymentMethod,
    this.location,
    this.notes,
    this.isReceived,
    this.flagEntry,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'caseId': caseId,
      'childIds': childIds ?? [],
      'attachmentUrls': attachmentUrls ?? [],
      'amount': amount,
      'date': date != null ? Timestamp.fromDate(date!) : null,
      'paymentType': paymentType,
      'paymentCategory': paymentCategory, // Primary field for category
      'transactionType': transactionType,
      'paymentMethod': paymentMethod,
      'location': location,
      'notes': notes,
      'isReceived': isReceived,
      'flagEntry': flagEntry,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      // 'category' has been removed to avoid duplicate data
    };
  }

  factory PaymentRecordModel.fromMap(Map<String, dynamic> map, String documentId) {
    // Determine transactionType from legacy 'isReceived' if 'transactionType' is missing
    String? tType = map['transactionType'];
    if (tType == null && map['isReceived'] != null) {
      tType = (map['isReceived'] == true) ? "PaymentReceived" : "PaymentPaid";
    }

    return PaymentRecordModel(
      id: documentId,
      caseId: map['caseId'] as String?,
      childIds: (map['childIds'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      attachmentUrls: (map['attachmentUrls'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      amount: (map['amount'] is int)
          ? (map['amount'] as int).toDouble()
          : (map['amount'] as double?),
      date: (map['date'] as Timestamp?)?.toDate(),
      paymentType: map['paymentType'] as String?,
      // Logic: Try to get 'paymentCategory' first; if null, look for the old 'category' key
      paymentCategory: map['paymentCategory'] as String? ?? map['category'] as String?,
      transactionType: tType,
      paymentMethod: map['paymentMethod'] as String?,
      location: map['location'] as String?,
      notes: map['notes'] as String?,
      isReceived: map['isReceived'] as bool?,
      flagEntry: map['flagEntry'] as bool?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}