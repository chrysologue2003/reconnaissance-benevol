import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<VolunteerUser?> getUserDocument(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return VolunteerUser.fromMap(doc.data()!);
    } catch (e) {
      rethrow;
    }
  }

  Future<User?> loginWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return credential.user;
    } catch (e) {
      rethrow;
    }
  }

  Future<User?> registerWithEmail({required String name, required String email, required String password, required String city}) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      final user = credential.user;
      if (user == null) return null;
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'nom': name,
        'email': email,
        'photoUrl': user.photoURL ?? '',
        'ville': city,
        'points': 0,
        'badges': <String>[],
        'dateInscription': Timestamp.now(),
      });
      return user;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateProfile(String uid, {String? name, String? city, String? photoUrl}) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['nom'] = name;
      if (city != null) data['ville'] = city;
      if (photoUrl != null) data['photoUrl'] = photoUrl;
      if (data.isNotEmpty) {
        await _firestore.collection('users').doc(uid).update(data);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }
}
