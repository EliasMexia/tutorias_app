import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tutorias_app/models/justificante_service.dart';
import 'package:tutorias_app/services/local_notifications_service.dart';

class StudentListenerService {
  static void iniciarEscucha(String matriculaEstudiante) {
    FirebaseFirestore.instance
        .collection('justificantes')
        .where('studentId', isEqualTo: matriculaEstudiante)
        .snapshots()
        .listen((snapshot) {
          for (var cambio in snapshot.docChanges) {
            // Solo nos interesan los documentos que fueron modificados por la administradora
            if (cambio.type == DocumentChangeType.modified) {
              final data = cambio.doc.data() as Map<String, dynamic>;
              final estado = data['estado'] as String?;

              if (estado == JustificanteStatus.REJECTED.name) {
                LocalNotificationsService.showNotification(
                  'Solicitud Rechazada',
                  'Motivo: ${data['motivoRechazo']}. Toca para corregir.',
                );
              } else if (estado == JustificanteStatus.READY_FOR_PICKUP.name) {
                LocalNotificationsService.showNotification(
                  'Justificante Listo',
                  'Tu justificante ya fue impreso y firmado. Pasa a Tutorias a recogerlo.',
                );
              }
            }
          }
        });
  }
}
