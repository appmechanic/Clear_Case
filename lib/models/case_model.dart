import 'package:cloud_firestore/cloud_firestore.dart';

class CaseModel {
  String id;
  String userId;
  String caseNumber;
  String legalRep;
  List<ChildModel> children; 
  
  // Rules Config
  bool isCustodyRuleSet;
  bool isPaymentRuleSet;
  
  // Stored as Maps for flexibility
  Map<String, dynamic>? custodyRule; 
  Map<String, dynamic>? paymentRule;
  Map<String, dynamic>? customRule;

  DateTime createdAt;

  CaseModel({
    this.id = '',
    required this.userId,
    this.caseNumber = '',
    this.legalRep = '',
    List<ChildModel>? children, 
    this.isCustodyRuleSet = false,
    this.isPaymentRuleSet = false,
    this.custodyRule,
    this.paymentRule,
    this.customRule,
    required this.createdAt,
  }) : children = children ?? [];

  // --- TO MAP (Saving to Firebase) ---
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'caseNumber': caseNumber,
      'legalRep': legalRep,
      'children': children.map((x) => x.toMap()).toList(),
      'isCustodyRuleSet': isCustodyRuleSet,
      'isPaymentRuleSet': isPaymentRuleSet,
      'custodyRule': custodyRule,
      'paymentRule': paymentRule,
      'customRule': customRule,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // --- FROM MAP (Reading from Firebase) ---
  factory CaseModel.fromMap(Map<String, dynamic> map) {
    return CaseModel(
      // ID is typically set separately from the doc ID, but if stored in map:
      id: map['id'] ?? '', 
      userId: map['userId'] ?? '',
      caseNumber: map['caseNumber'] ?? '',
      legalRep: map['legalRep'] ?? '',
      
      // Safety check for Children List
      children: map['children'] != null 
          ? List<ChildModel>.from(
              (map['children'] as List<dynamic>).map(
                (x) => ChildModel.fromMap(x as Map<String, dynamic>)
              ),
            )
          : [],

      isCustodyRuleSet: map['isCustodyRuleSet'] ?? false,
      isPaymentRuleSet: map['isPaymentRuleSet'] ?? false,
      
      // Maps do not need conversion, just casting
      custodyRule: map['custodyRule'] as Map<String, dynamic>?,
      paymentRule: map['paymentRule'] as Map<String, dynamic>?,
      customRule: map['customRule'] as Map<String, dynamic>?,
      
      // Timestamp Conversion
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class ChildModel {
  String id;
  String name;
  DateTime dob;

  ChildModel({required this.id, required this.name, required this.dob});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'dob': Timestamp.fromDate(dob),
    };
  }

  factory ChildModel.fromMap(Map<String, dynamic> map) {
    return ChildModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      dob: (map['dob'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}