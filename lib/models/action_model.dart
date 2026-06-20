import 'package:cloud_firestore/cloud_firestore.dart';

class VolunteerAction {
  final String actionId;
  final String title;
  final String description;
  final String photoUrl;
  final String category;
  final String location;
  final DateTime date;
  final String userId;
  final String userName;
  final String userPhoto;
  final List<String> likes;
  final Timestamp datePublication;
  final String status;
  final String commentaireAdmin;

  VolunteerAction({
    required this.actionId,
    required this.title,
    required this.description,
    required this.photoUrl,
    required this.category,
    required this.location,
    required this.date,
    required this.userId,
    required this.userName,
    required this.userPhoto,
    required this.likes,
    required this.datePublication,
    required this.status,
    this.commentaireAdmin = '',
  });

  factory VolunteerAction.fromMap(Map<String, dynamic> data, String id) {
    return VolunteerAction(
      actionId: id,
      title: data['titre'] as String? ?? '',
      description: data['description'] as String? ?? '',
      photoUrl: data['photoUrl'] as String? ?? '',
      category: data['categorie'] as String? ?? '',
      location: data['lieu'] as String? ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? '',
      userPhoto: data['userPhoto'] as String? ?? '',
      likes: List<String>.from(data['likes'] ?? []),
      datePublication: data['datePublication'] as Timestamp? ?? Timestamp.now(),
      status: data['statut'] as String? ?? 'en attente',
      commentaireAdmin: data['commentaireAdmin'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'actionId': actionId,
      'titre': title,
      'description': description,
      'photoUrl': photoUrl,
      'categorie': category,
      'lieu': location,
      'date': Timestamp.fromDate(date),
      'userId': userId,
      'userName': userName,
      'userPhoto': userPhoto,
      'likes': likes,
      'datePublication': datePublication,
      'statut': status,
      'commentaireAdmin': commentaireAdmin,
    };
  }

  VolunteerAction copyWith({
    String? actionId,
    String? title,
    String? description,
    String? photoUrl,
    String? category,
    String? location,
    DateTime? date,
    String? userId,
    String? userName,
    String? userPhoto,
    List<String>? likes,
    Timestamp? datePublication,
    String? status,
    String? commentaireAdmin,
  }) {
    return VolunteerAction(
      actionId: actionId ?? this.actionId,
      title: title ?? this.title,
      description: description ?? this.description,
      photoUrl: photoUrl ?? this.photoUrl,
      category: category ?? this.category,
      location: location ?? this.location,
      date: date ?? this.date,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userPhoto: userPhoto ?? this.userPhoto,
      likes: likes ?? this.likes,
      datePublication: datePublication ?? this.datePublication,
      status: status ?? this.status,
      commentaireAdmin: commentaireAdmin ?? this.commentaireAdmin,
    );
  }
}
