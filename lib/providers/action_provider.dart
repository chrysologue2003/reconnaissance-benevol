import 'package:flutter/material.dart';

import '../models/action_model.dart';
import '../models/comment_model.dart';
import '../services/firestore_service.dart';

class ActionProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  String selectedCategory = 'Tous';

  void setCategory(String category) {
    selectedCategory = category;
    notifyListeners();
  }

  Stream<List<VolunteerAction>> get actionsStream => _firestoreService.streamValidatedActions(category: selectedCategory);

  Stream<List<VolunteerAction>> get pendingStream => _firestoreService.streamPendingActions();

  Stream<List<VolunteerAction>> userActionsStream(String userId) => _firestoreService.streamUserActions(userId);

  Stream<List<VolunteerAction>> get leaderboardStream => _firestoreService.streamValidatedActions();

  Future<void> postAction(VolunteerAction action) async {
    await _firestoreService.createAction(action);
  }

  Future<void> toggleLike(VolunteerAction action, String userId) async {
    await _firestoreService.toggleLike(action, userId);
  }

  Future<void> validateAction(VolunteerAction action, {String comment = ''}) async {
    await _firestoreService.validateAction(action, comment: comment);
    notifyListeners();
  }

  Future<void> rejectAction(VolunteerAction action, {String comment = ''}) async {
    await _firestoreService.rejectAction(action, comment: comment);
    notifyListeners();
  }

  Stream<List<Comment>> commentsStream(String actionId) => _firestoreService.streamComments(actionId);

  Future<void> addComment(String actionId, Comment comment) async {
    await _firestoreService.addComment(actionId, comment);
  }

  Stream<List<Map<String, dynamic>>> notificationsStream(String userId) => _firestoreService.streamNotifications(userId);
  Stream<List<Map<String, dynamic>>> globalNotificationsStream() => _firestoreService.streamGlobalNotifications();
}
