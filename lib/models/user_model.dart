import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  String uid;
  String email;
  String firstName;
  String lastName;
  DateTime createdAt;

  // Firestore-இல் உள்ள சரியான பெயர்கள்
  bool isDailyReminderEnabled;
  bool isRemindersEnabled;
  bool isScheduledDatesEnabled;
  String notificationTime;
  String timezone;
  String utcOffset;

  UserModel({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.createdAt,
    this.isDailyReminderEnabled = false,
    this.isRemindersEnabled = true,
    this.isScheduledDatesEnabled = true,
    this.notificationTime = "09:00",
    this.timezone = "",
    this.utcOffset = "",
  });

  // --- FROM MAP ---
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      firstName: map['firstName'] ?? '', // Firestore-இல் உள்ளபடியே 'firstName'
      lastName: map['lastName'] ?? '',   // Firestore-இல் உள்ளபடியே 'lastName'

      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),

      // Firestore-இல் உள்ள பெயர்களுடன் மேட்ச் செய்கிறோம்
      isDailyReminderEnabled: map['isDailyReminderEnabled'] ?? false,
      isRemindersEnabled: map['isRemindersEnabled'] ?? true,
      isScheduledDatesEnabled: map['isScheduledDatesEnabled'] ?? true,
      notificationTime: map['notificationTime'] ?? "09:00",
      timezone: map['timezone'] ?? "",
      utcOffset: map['utcOffset'] ?? "",
    );
  }

  // --- TO MAP ---
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'createdAt': Timestamp.fromDate(createdAt),
      'isDailyReminderEnabled': isDailyReminderEnabled,
      'isRemindersEnabled': isRemindersEnabled,
      'isScheduledDatesEnabled': isScheduledDatesEnabled,
      'notificationTime': notificationTime,
      'timezone': timezone,
      'utcOffset': utcOffset,
    };
  }
}