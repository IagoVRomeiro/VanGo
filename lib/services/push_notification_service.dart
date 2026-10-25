import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Mantém o token FCM do usuário logado salvo em `users/{uid}.fcmToken`,
/// que é onde as Cloud Functions buscam o destino das notificações.
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenSubscription;

  /// Registra o aparelho sempre que alguém faz login ou abre o app já logado.
  void init() {
    _authSubscription ??=
        FirebaseAuth.instance.authStateChanges().listen((user) {
      _tokenSubscription?.cancel();
      _tokenSubscription = null;
      if (user != null) {
        _registrar(user.uid);
      }
    });
  }

  Future<void> _registrar(String uid) async {
    try {
      final messaging = FirebaseMessaging.instance;
      // No Android 13+ e no iOS, sem essa permissão nenhuma notificação aparece.
      await messaging.requestPermission();

      final token = await messaging.getToken();
      if (token != null) await _salvarToken(uid, token);

      _tokenSubscription =
          messaging.onTokenRefresh.listen((novo) => _salvarToken(uid, novo));
    } catch (e) {
      debugPrint('Erro ao registrar notificações: $e');
    }
  }

  Future<void> _salvarToken(String uid, String token) {
    return FirebaseFirestore.instance.collection('users').doc(uid).set(
      {'fcmToken': token},
      SetOptions(merge: true),
    );
  }
}
