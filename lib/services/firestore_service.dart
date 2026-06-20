import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/action_model.dart';
import '../models/user_model.dart';
import '../models/comment_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- ACTIONS ---

  Stream<List<VolunteerAction>> streamValidatedActions({String category = 'Tous'}) {
    try {
      Query query = _firestore.collection('actions');

      // Les clauses .where() doivent toujours précéder .orderBy() dans Firestore
      if (category != 'Tous') {
        query = query.where('categorie', isEqualTo: category);
      }
      query = query
          .where('statut', isEqualTo: 'validé')
          .orderBy('datePublication', descending: true);

      return query
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) =>
                  VolunteerAction.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList())
          .handleError((error) {
            debugPrint('🔴 Erreur Firestore streamValidatedActions : $error');
            throw error;
          });
    } catch (e) {
      debugPrint('🔴 Erreur lors de la construction de la requête : $e');
      rethrow;
    }
  }

  Stream<List<VolunteerAction>> streamPendingActions() {
    return _firestore
        .collection('actions')
        .where('statut', isEqualTo: 'en attente')
        .orderBy('datePublication', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => VolunteerAction.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<VolunteerAction>> streamUserActions(String userId) {
    return _firestore
        .collection('actions')
        .where('userId', isEqualTo: userId)
        .orderBy('datePublication', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => VolunteerAction.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<VolunteerUser>> streamTopUsers() {
    return _firestore
        .collection('users')
        .orderBy('points', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => VolunteerUser.fromMap(doc.data()))
            .toList());
  }

  Future<void> createAction(VolunteerAction action) async {
    try {
      await _firestore.collection('actions').add(action.toMap());
    } catch (e) {
      rethrow;
    }
    // Notification envoyée séparément pour ne pas bloquer en cas d'erreur
    try {
      await createGlobalNotification(
        'Nouvelle action publiée : « ${action.title} » par ${action.userName}',
        'activite',
      );
    } catch (e) {
      debugPrint('Erreur notification globale (non bloquante) : $e');
    }
  }

  Future<void> createActionWithId(VolunteerAction action, String actionId) async {
    try {
      final docRef = _firestore.collection('actions').doc(actionId);
      await docRef.set(action.copyWith(actionId: actionId).toMap());
    } catch (e) {
      rethrow;
    }
    // Notification envoyée séparément pour ne pas masquer une erreur d'écriture
    try {
      await createGlobalNotification(
        'Nouvelle action publiée : « ${action.title} » par ${action.userName}',
        'activite',
      );
    } catch (e) {
      debugPrint('Erreur notification globale (non bloquante) : $e');
    }
  }

  Future<void> toggleLike(VolunteerAction action, String userId) async {
    try {
      final docRef = _firestore.collection('actions').doc(action.actionId);
      final isLiked = action.likes.contains(userId);
      await docRef.update({
        'likes': isLiked ? FieldValue.arrayRemove([userId]) : FieldValue.arrayUnion([userId])
      });
      
      if (!isLiked) {
        // Ajouter des points à l'auteur de l'action
        final userRef = _firestore.collection('users').doc(action.userId);
        await userRef.update({'points': FieldValue.increment(2)});
        
        // Notification à l'auteur de l'action
        if (action.userId != userId) {
          await createNotification(
            action.userId,
            'Quelqu\'un a applaudi votre action « ${action.title} » ! (+2 pts)',
            'like',
          );
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> validateAction(VolunteerAction action, {String comment = ''}) async {
    try {
      final docRef = _firestore.collection('actions').doc(action.actionId);
      await docRef.update({
        'statut': 'validé',
        'commentaireAdmin': comment,
      });

      final userRef = _firestore.collection('users').doc(action.userId);
      await userRef.update({'points': FieldValue.increment(10)});
      
      // Mettre à jour les badges
      await _updateBadges(action.userId);

      // Créer une notification pour le bénévole
      String notifMsg = 'Votre action « ${action.title} » a été validée ! (+10 pts)';
      if (comment.trim().isNotEmpty) {
        notifMsg += '\nCommentaire admin : "$comment"';
      }
      await createNotification(action.userId, notifMsg, 'validation');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> rejectAction(VolunteerAction action, {String comment = ''}) async {
    try {
      final docRef = _firestore.collection('actions').doc(action.actionId);
      await docRef.update({
        'statut': 'rejeté',
        'commentaireAdmin': comment,
      });

      // Créer une notification pour le bénévole
      String notifMsg = 'Votre action « ${action.title} » a été rejetée.';
      if (comment.trim().isNotEmpty) {
        notifMsg += '\nRaison : "$comment"';
      }
      await createNotification(action.userId, notifMsg, 'rejet');
    } catch (e) {
      rethrow;
    }
  }

  Future<VolunteerUser?> getUser(String uid) async {
    try {
      final snapshot = await _firestore.collection('users').doc(uid).get();
      if (!snapshot.exists) return null;
      return VolunteerUser.fromMap(snapshot.data()!);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _updateBadges(String userId) async {
    final actionsSnapshot = await _firestore
        .collection('actions')
        .where('userId', isEqualTo: userId)
        .where('statut', isEqualTo: 'validé')
        .get();
    final validatedActions = actionsSnapshot.docs.length;
    
    // Charger les badges actuels de l'utilisateur pour détecter les nouveaux obtentions
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final currentBadges = List<String>.from(userDoc.data()?['badges'] ?? []);

    final badgeIds = <String>[];
    if (validatedActions >= 1) badgeIds.add('Débutant');
    if (validatedActions >= 5) badgeIds.add('Solidaire');
    if (validatedActions >= 10) badgeIds.add('Engagé');
    if (validatedActions >= 25) badgeIds.add('Champion');
    if (validatedActions >= 50) badgeIds.add('Légende');

    await _firestore.collection('users').doc(userId).update({'badges': badgeIds});

    // Envoyer une notification pour chaque nouveau badge obtenu
    for (final b in badgeIds) {
      if (!currentBadges.contains(b)) {
        await createNotification(
          userId,
          'Félicitations ! Vous avez obtenu le badge « $b » ! 🎉',
          'badge',
        );
      }
    }
  }

  // --- COMMENTAIRES ---

  Stream<List<Comment>> streamComments(String actionId) {
    return _firestore
        .collection('actions')
        .doc(actionId)
        .collection('comments')
        .orderBy('dateCreation', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Comment.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> addComment(String actionId, Comment comment) async {
    try {
      await _firestore
          .collection('actions')
          .doc(actionId)
          .collection('comments')
          .add(comment.toMap());
    } catch (e) {
      rethrow;
    }
  }

  // --- NOTIFICATIONS ---

  Stream<List<Map<String, dynamic>>> streamNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList())
        .handleError((error) {
          debugPrint('🔴 Erreur Firestore streamNotifications : $error');
          throw error;
        });
  }

  Future<void> createNotification(String userId, String message, String type) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'message': message,
        'type': type,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      debugPrint('Erreur lors de la création de la notification : $e');
    }
  }

  Future<void> createGlobalNotification(String message, String type) async {
    try {
      // Envoyer à tous les utilisateurs (pour simplifier la démo, on peut l'ajouter à une collection globale 'global_notifications'
      // ou l'ajouter individuellement, ou simplement la poster dans une collection communautaire commune)
      await _firestore.collection('global_notifications').add({
        'message': message,
        'type': type,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Erreur de notification globale : $e');
    }
  }

  Stream<List<Map<String, dynamic>>> streamGlobalNotifications() {
    return _firestore
        .collection('global_notifications')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList());
  }
}
