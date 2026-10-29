import 'package:cloud_firestore/cloud_firestore.dart';

enum JustificanteStatus { PENDING, REJECTED, APPROVED, READY_FOR_PICKUP }

class JustificanteModel {
  final String id;
  final String studentId;
  final String nombreEstudiante;
  final String matricula;
  final String docentesGrupo;
  final String licenciatura;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final String motivo;
  final bool esMotivoSalud;
  final String ineAnversoUrl;
  final String ineReversoUrl;
  final String cartaMotivoUrl;
  final JustificanteStatus estado;
  final String? motivoRechazo;
  final DateTime fechaSolicitud;
  final DateTime? fechaEmision;

  JustificanteModel({
    required this.id,
    required this.studentId,
    required this.nombreEstudiante,
    required this.matricula,
    required this.docentesGrupo,
    required this.licenciatura,
    required this.fechaInicio,
    required this.fechaFin,
    required this.motivo,
    this.esMotivoSalud = false,
    required this.ineAnversoUrl,
    required this.ineReversoUrl,
    required this.cartaMotivoUrl,
    required this.estado,
    this.motivoRechazo,
    required this.fechaSolicitud,
    this.fechaEmision,
  });

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'nombreEstudiante': nombreEstudiante,
      'matricula': matricula,
      'docentesGrupo': docentesGrupo,
      'licenciatura': licenciatura,
      'fechaInicio': Timestamp.fromDate(fechaInicio),
      'fechaFin': Timestamp.fromDate(fechaFin),
      'motivo': motivo,
      'esMotivoSalud': esMotivoSalud,
      'ineAnversoUrl': ineAnversoUrl,
      'ineReversoUrl': ineReversoUrl,
      'cartaMotivoUrl': cartaMotivoUrl,
      'estado': estado.name,
      'motivoRechazo': motivoRechazo,
      'fechaSolicitud': Timestamp.fromDate(fechaSolicitud),
      'fechaEmision': fechaEmision != null
          ? Timestamp.fromDate(fechaEmision!)
          : null,
    };
  }

  factory JustificanteModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return JustificanteModel(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      nombreEstudiante: data['nombreEstudiante'] ?? '',
      matricula: data['matricula'] ?? '',
      docentesGrupo: data['docentesGrupo'] ?? '',
      licenciatura: data['licenciatura'] ?? '',
      fechaInicio: (data['fechaInicio'] as Timestamp).toDate(),
      fechaFin: (data['fechaFin'] as Timestamp).toDate(),
      motivo: data['motivo'] ?? '',
      esMotivoSalud: data['esMotivoSalud'] ?? false,
      ineAnversoUrl: data['ineAnversoUrl'] ?? '',
      ineReversoUrl: data['ineReversoUrl'] ?? '',
      cartaMotivoUrl: data['cartaMotivoUrl'] ?? '',
      estado: JustificanteStatus.values.firstWhere(
        (e) => e.name == data['estado'],
        orElse: () => JustificanteStatus.PENDING,
      ),
      motivoRechazo: data['motivoRechazo'],
      fechaSolicitud: (data['fechaSolicitud'] as Timestamp).toDate(),
      fechaEmision: data['fechaEmision'] != null
          ? (data['fechaEmision'] as Timestamp).toDate()
          : null,
    );
  }
}

class JustificanteService {
  final CollectionReference _ref = FirebaseFirestore.instance.collection(
    'justificantes',
  );

  Future<void> enviarOSubsanarSolicitud(JustificanteModel item) async {
    if (item.id.isEmpty) {
      await _ref.add(item.toMap());
    } else {
      await _ref.doc(item.id).update({
        ...item.toMap(),
        'estado': JustificanteStatus.PENDING.name,
        'motivoRechazo': null,
      });
    }
  }

  Future<void> rechazarSolicitud(String id, String motivoRechazo) async {
    if (motivoRechazo.trim().isEmpty) {
      throw Exception('El motivo de rechazo es obligatorio.');
    }
    await _ref.doc(id).update({
      'estado': JustificanteStatus.REJECTED.name,
      'motivoRechazo': motivoRechazo.trim(),
    });
  }

  Future<DateTime> aprobarSolicitud(String id) async {
    final ahora = DateTime.now();
    await _ref.doc(id).update({
      'estado': JustificanteStatus.APPROVED.name,
      'fechaEmision': Timestamp.fromDate(ahora),
      'motivoRechazo': null,
    });
    return ahora;
  }

  Future<void> marcarListoParaRecoger(String id, String studentId) async {
    await _ref.doc(id).update({
      'estado': JustificanteStatus.READY_FOR_PICKUP.name,
    });
  }
}
