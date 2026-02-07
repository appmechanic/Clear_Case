import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  String uid;
  String email;
  String firstName;
  String lastName;
  DateTime createdAt;
  
  // Notification Settings
  bool pushNotificationsEnabled;
  String notificationTime; // Stored as "HH:mm"

  UserModel({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.createdAt,
    this.pushNotificationsEnabled = true, // Default true
    this.notificationTime = "09:00",      // Default 9 AM
  });

  // --- TO MAP ---
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'createdAt': Timestamp.fromDate(createdAt),
      'pushNotificationsEnabled': pushNotificationsEnabled,
      'notificationTime': notificationTime,
    };
  }

  // --- FROM MAP ---
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      
      // Safe Timestamp conversion
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      
      // Settings with fallbacks
      pushNotificationsEnabled: map['pushNotificationsEnabled'] ?? true,
      notificationTime: map['notificationTime'] ?? "09:00",
    );
  }
}