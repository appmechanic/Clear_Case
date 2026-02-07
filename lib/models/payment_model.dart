import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentRecordModel {
  String? id;
  String? caseId;
  double? amount;
  DateTime? date;
  String? paymentType;     
  String? category;        
  String? paymentMethod;   
  String? location;
  String? notes;
  bool? isReceived;      
  bool? flagEntry;          
  DateTime? createdAt;

  PaymentRecordModel({
    this.id,
    this.caseId,
    this.amount,
    this.date,
    this.paymentType,
    this.category,
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
      'amount': amount,
      'date': date != null ? Timestamp.fromDate(date!) : null,
      'paymentType': paymentType,
      'category': category,
      'paymentMethod': paymentMethod,
      'location': location,
      'notes': notes,
      'isReceived': isReceived,
      'flagEntry': flagEntry,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    };
  }

  factory PaymentRecordModel.fromMap(Map<String, dynamic> map, String documentId) {
    return PaymentRecordModel(
      id: documentId,
      caseId: map['caseId'] as String?,
      amount: (map['amount'] is int) 
          ? (map['amount'] as int).toDouble() 
          : (map['amount'] as double?),
      date: (map['date'] as Timestamp?)?.toDate(),
      paymentType: map['paymentType'] as String?,
      category: map['category'] as String?,
      paymentMethod: map['paymentMethod'] as String?,
      location: map['location'] as String?,
      notes: map['notes'] as String?,
      isReceived: map['isReceived'] as bool?,
      flagEntry: map['flagEntry'] as bool?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}