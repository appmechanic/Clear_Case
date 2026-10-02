import 'package:cloud_firestore/cloud_firestore.dart';

class CaseModel {
  String id;
  String userId;
  String caseNumber;
  String legalRep;
  List<ChildModel> children; 

  // The other party named in the court order (usually the other parent).
  // Pre-fills the related party on new disputes and non-compliance records.
  // Null until the user enters one.
  String? relatedPartyName;
  String? relatedPartyRelation; // one of relatedPartyRelations
  
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
    this.relatedPartyName,
    this.relatedPartyRelation,
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
      'relatedPartyName': relatedPartyName,
      'relatedPartyRelation': relatedPartyRelation,
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

      relatedPartyName: map['relatedPartyName'] as String?,
      relatedPartyRelation: map['relatedPartyRelation'] as String?,

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

/// Relationship options for a related party.
const List<String> relatedPartyRelations = ["Mother", "Father", "Guardian"];

extension CaseRelatedParty on CaseModel {
  /// True once both the related party's relationship and name are saved.
  bool get hasRelatedParty =>
      (relatedPartyRelation ?? '').trim().isNotEmpty &&
      (relatedPartyName ?? '').trim().isNotEmpty;
}

class ChildModel {
  String id;
  String name;
  DateTime dob;
  // Nullable: children created before these fields existed have neither. Null
  // means "never entered" and renders as "—" on the report; don't coerce to ''.
  String? school;
  String? address;

  ChildModel({
    required this.id,
    required this.name,
    required this.dob,
    this.school,
    this.address,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'dob': Timestamp.fromDate(dob),
      'school': school,
      'address': address,
    };
  }

  factory ChildModel.fromMap(Map<String, dynamic> map) {
    return ChildModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      dob: (map['dob'] as Timestamp?)?.toDate() ?? DateTime.now(),
      school: map['school'] as String?,
      address: map['address'] as String?,
    );
  }
}