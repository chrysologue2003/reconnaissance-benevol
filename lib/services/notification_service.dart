import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
      final token = await _messaging.getToken();
      if (token != null) {
        // Le token peut être envoyé au backend ou stocké pour l'utilisateur.
        // print('FCM Token: $token');
      }
      FirebaseMessaging.onMessage.listen((message) {
        // Gestion des notifications entrantes en premier plan.
      });
    } catch (e) {
      rethrow;
    }
  }
}
