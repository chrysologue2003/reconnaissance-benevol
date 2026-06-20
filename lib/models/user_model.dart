import 'package:cloud_firestore/cloud_firestore.dart';

class VolunteerUser {
  final String uid;
  final String name;
  final String email;
  final String photoUrl;
  final String city;
  final int points;
  final List<String> badges;
  final Timestamp dateJoined;
  final String role; // 'admin' | '' (vide = bénévole normal)

  VolunteerUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.city,
    required this.points,
    required this.badges,
    required this.dateJoined,
    this.role = '',
  });

  factory VolunteerUser.fromMap(Map<String, dynamic> data) {
    return VolunteerUser(
      uid: data['uid'] as String? ?? '',
      name: data['nom'] as String? ?? '',
      email: data['email'] as String? ?? '',
      photoUrl: data['photoUrl'] as String? ?? '',
      city: data['ville'] as String? ?? '',
      points: (data['points'] as num?)?.toInt() ?? 0,
      badges: List<String>.from(data['badges'] ?? []),
      dateJoined: data['dateInscription'] as Timestamp? ?? Timestamp.now(),
      role: data['role'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'nom': name,
      'email': email,
      'photoUrl': photoUrl,
      'ville': city,
      'points': points,
      'badges': badges,
      'dateInscription': dateJoined,
      'role': role,
    };
  }

  bool get isAdmin => role == 'admin';
}
