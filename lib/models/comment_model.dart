import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String commentId;
  final String userId;
  final String userName;
  final String userPhoto;
  final String text;
  final Timestamp dateCreated;

  Comment({
    required this.commentId,
    required this.userId,
    required this.userName,
    required this.userPhoto,
    required this.text,
    required this.dateCreated,
  });

  factory Comment.fromMap(Map<String, dynamic> data, String id) {
    return Comment(
      commentId: id,
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? '',
      userPhoto: data['userPhoto'] as String? ?? '',
      text: data['texte'] as String? ?? '',
      dateCreated: data['dateCreation'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userPhoto': userPhoto,
      'texte': text,
      'dateCreation': dateCreated,
    };
  }
}
