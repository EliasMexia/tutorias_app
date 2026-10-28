import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> inicializarYGuardarToken(String uid) async {
    // 1. Solicitar permisos en Android 13+ e iOS
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // 2. Obtener token actual del dispositivo y guardarlo en el perfil del alumno
      final String? token = await _fcm.getToken();
      if (token != null) {
        await _guardarTokenEnFirestore(uid, token);
      }

      // 3. Escuchar si el token se refresca automaticamente
      _fcm.onTokenRefresh.listen((nuevoToken) {
        _guardarTokenEnFirestore(uid, nuevoToken);
      });
    }
  }

  Future<void> _guardarTokenEnFirestore(String uid, String token) async {
    await _db.collection('users').doc(uid).set({
      'fcmToken': token,
      'ultimaConexion': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
