import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  VolunteerUser? user;
  bool loading = false;
  bool _initialized = false;

  // Abonnement au stream du document utilisateur Firestore
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;

  AuthProvider() {
    // 1. Écoute les changements d'état d'authentification Firebase
    _authService.authStateChanges().listen((firebaseUser) {
      // Annule l'abonnement précédent si l'utilisateur change
      _userDocSub?.cancel();
      _userDocSub = null;

      if (firebaseUser == null) {
        // Déconnexion
        user = null;
        _initialized = true;
        loading = false;
        notifyListeners();
      } else {
        // Connexion : on écoute le document Firestore EN TEMPS RÉEL
        loading = true;
        notifyListeners();

        _userDocSub = FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid)
            .snapshots()
            .listen(
          (doc) {
            if (doc.exists && doc.data() != null) {
              final newUser = VolunteerUser.fromMap(doc.data()!);

              // Logs de diagnostic (visibles dans la console Flutter)
              debugPrint('👤 [AuthProvider] Document utilisateur chargé:');
              debugPrint('   uid     = ${newUser.uid}');
              debugPrint('   email   = ${newUser.email}');
              debugPrint('   role    = "${newUser.role}"');
              debugPrint('   isAdmin = ${newUser.isAdmin}');

              user = newUser;
            } else {
              debugPrint('⚠️ [AuthProvider] Document utilisateur introuvable pour uid=${firebaseUser.uid}');
              user = null;
            }

            _initialized = true;
            loading = false;
            notifyListeners();
          },
          onError: (error) {
            debugPrint('🔴 [AuthProvider] Erreur lecture document utilisateur: $error');
            _initialized = true;
            loading = false;
            notifyListeners();
          },
        );
      }
    });
  }

  bool get initialized => _initialized;

  bool get isAuthenticated =>
      FirebaseAuth.instance.currentUser != null && user != null;

  /// Admin si email historique OU champ role == 'admin' dans Firestore
  bool get isAdmin =>
      user?.email == 'admin@benevoles.com' || (user?.isAdmin ?? false);

  Future<void> login(String email, String password) async {
    try {
      loading = true;
      notifyListeners();
      await _authService.loginWithEmail(email, password);
      // Le stream authStateChanges() déclenchera automatiquement
      // l'abonnement au document Firestore
    } catch (e) {
      loading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String city,
  }) async {
    try {
      loading = true;
      notifyListeners();
      await _authService.registerWithEmail(
        name: name,
        email: email,
        password: password,
        city: city,
      );
      // Le stream authStateChanges() prendra le relais
    } catch (e) {
      loading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      _userDocSub?.cancel();
      _userDocSub = null;
      await _authService.signOut();
      user = null;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateProfile({
    String? name,
    String? city,
    String? photoUrl,
  }) async {
    if (user == null) return;
    try {
      loading = true;
      notifyListeners();
      await _authService.updateProfile(
        user!.uid,
        name: name,
        city: city,
        photoUrl: photoUrl,
      );
      // Le stream Firestore mettra automatiquement à jour `user`
    } catch (e) {
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      loading = true;
      notifyListeners();
      await _authService.sendPasswordResetEmail(email);
    } catch (e) {
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Force un rechargement explicite du document utilisateur
  /// (normalement inutile grâce au stream temps réel, mais utile pour debug)
  Future<void> refreshUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.server)); // Ignore le cache
      if (doc.exists && doc.data() != null) {
        user = VolunteerUser.fromMap(doc.data()!);
        debugPrint('🔄 [AuthProvider] refreshUser: role="${user?.role}", isAdmin=${user?.isAdmin}');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('🔴 [AuthProvider] refreshUser erreur: $e');
    }
  }

  @override
  void dispose() {
    _userDocSub?.cancel();
    super.dispose();
  }
}
