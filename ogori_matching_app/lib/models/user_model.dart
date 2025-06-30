import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String displayName;
  final String email;
  final String? profileImageUrl;
  final int? age;
  final String? bio;
  final String? location;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    this.profileImageUrl,
    this.age,
    this.bio,
    this.location,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'profileImageUrl': profileImageUrl,
      'age': age,
      'bio': bio,
      'location': location,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'profileImageUrl': profileImageUrl,
      'age': age,
      'bio': bio,
      'location': location,
      'createdAt': Timestamp.fromDate(createdAt), // Timestamp形式で保存
      'updatedAt': Timestamp.fromDate(updatedAt), // Timestamp形式で保存
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      displayName: map['displayName'] ?? '',
      email: map['email'] ?? '',
      profileImageUrl: map['profileImageUrl'],
      age: map['age'],
      bio: map['bio'],
      location: map['location'],
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
    );
  }

  factory UserModel.fromFirestore(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? '',
      displayName: data['displayName'] ?? '',
      email: data['email'] ?? '',
      profileImageUrl: data['profileImageUrl'],
      age: data['age'],
      bio: data['bio'],
      location: data['location'],
      createdAt: _parseDateTime(data['createdAt']),
      updatedAt: _parseDateTime(data['updatedAt']),
    );
  }

  // Timestamp または int を DateTime に変換するヘルパーメソッド
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();

    if (value is Timestamp) {
      return value.toDate();
    } else if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    } else if (value is DateTime) {
      return value;
    } else {
      return DateTime.now();
    }
  }

  UserModel copyWith({
    String? uid,
    String? displayName,
    String? email,
    String? profileImageUrl,
    int? age,
    String? bio,
    String? location,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      age: age ?? this.age,
      bio: bio ?? this.bio,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
