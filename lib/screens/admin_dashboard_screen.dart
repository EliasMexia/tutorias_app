import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tutorias_app/models/justificante_service.dart';
import 'package:tutorias_app/services/pdf_generator.dart';

class AdminDashboardScreen extends StatelessWidget {
  final JustificanteService _service = JustificanteService();

  AdminDashboardScreen({super.key});

  void _mostrarDialogoRechazo(BuildContext context, JustificanteModel item) {
    final motivoCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar Solicitud'),
        content: TextField(
          controller: motivoCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText:
                'Escribe el motivo del rechazo (ej. INE borrosa o falta firma)...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (motivoCtrl.text.trim().isEmpty) return;
              await _service.rechazarSolicitud(item.id, motivoCtrl.text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Confirmar Rechazo'),
          ),
        ],
      ),
    );
  }

  Future<void> _aprobarEImprimir(
    BuildContext context,
    JustificanteModel item,
  ) async {
    final fechaEmision = await _service.aprobarSolicitud(item.id);
    final itemActualizado = JustificanteModel(
      id: item.id,
      studentId: item.studentId,
      nombreEstudiante: item.nombreEstudiante,
      matricula: item.matricula,
      docentesGrupo: item.docentesGrupo,
      licenciatura: item.licenciatura,
      fechaInicio: item.fechaInicio,
      fechaFin: item.fechaFin,
      motivo: item.motivo,
      ineAnversoUrl: item.ineAnversoUrl,
      ineReversoUrl: item.ineReversoUrl,
      cartaMotivoUrl: item.cartaMotivoUrl,
      estado: JustificanteStatus.APPROVED,
      fechaSolicitud: item.fechaSolicitud,
      fechaEmision: fechaEmision,
    );
    await JustificantePdfGenerator.generarEImprimir(itemActualizado);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bandeja de Entrada - Tutorias FIM')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('justificantes')
            .orderBy('fechaSolicitud', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay solicitudes registradas.'));
          }

          final solicitudes = snapshot.data!.docs
              .map((doc) => JustificanteModel.fromDoc(doc))
              .toList();

          return ListView.builder(
            itemCount: solicitudes.length,
            itemBuilder: (context, index) {
              final item = solicitudes[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item.nombreEstudiante} (${item.matricula})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Ingenieria ${item.licenciatura} | Grupo: ${item.docentesGrupo}',
                      ),
                      Text('Motivo: ${item.motivo}'),
                      Text('Estado actual: ${item.estado.name}'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (item.estado == JustificanteStatus.PENDING) ...[
                            OutlinedButton(
                              onPressed: () =>
                                  _mostrarDialogoRechazo(context, item),
                              child: const Text('Rechazar'),
                            ),
                            ElevatedButton(
                              onPressed: () => _aprobarEImprimir(context, item),
                              child: const Text('Aprobar e Imprimir PDF'),
                            ),
                          ],
                          if (item.estado == JustificanteStatus.APPROVED) ...[
                            OutlinedButton(
                              onPressed: () =>
                                  JustificantePdfGenerator.generarEImprimir(
                                    item,
                                  ),
                              child: const Text('Reimprimir PDF'),
                            ),
                            ElevatedButton(
                              onPressed: () => _service.marcarListoParaRecoger(
                                item.id,
                                item.studentId,
                              ),
                              child: const Text('Avisar al estudiante (Listo)'),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
