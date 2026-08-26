// lib/models/app_user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { admin, producer }

UserRole userRoleFromString(String value) {
  return UserRole.values.firstWhere(
    (r) => r.name == value,
    orElse: () => UserRole.producer,
  );
}

class AppUserModel {
  final String uid;
  final String email;
  final String name;
  final UserRole role;
  final String? propertyId; // preenchido só se role == producer
  final DateTime? createdAt;

  const AppUserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.propertyId,
    this.createdAt,
  });

  bool get isAdmin => role == UserRole.admin;
  bool get isProducer => role == UserRole.producer;

  factory AppUserModel.fromMap(String uid, Map<String, dynamic> map) {
    return AppUserModel(
      uid: uid,
      email: map['email'] as String? ?? '',
      // fallback pro email evita "nome vazio" na UI pra qualquer doc
      // antigo criado antes desse campo existir (ex: o admin do seed).
      name: (map['name'] as String?)?.trim().isNotEmpty == true
          ? map['name'] as String
          : (map['email'] as String? ?? ''),
      role: userRoleFromString(map['role'] as String? ?? 'producer'),
      propertyId: map['propertyId'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'email': email,
        'name': name,
        'role': role.name,
        'propertyId': propertyId,
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
      };
}