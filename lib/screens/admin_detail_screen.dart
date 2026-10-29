import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:tutorias_app/models/justificante_service.dart';
import 'package:tutorias_app/services/pdf_generator.dart';

class AdminDetailScreen extends StatefulWidget {
  final JustificanteModel solicitud;

  const AdminDetailScreen({super.key, required this.solicitud});

  @override
  State<AdminDetailScreen> createState() => _AdminDetailScreenState();
}

class _AdminDetailScreenState extends State<AdminDetailScreen> {
  final JustificanteService _service = JustificanteService();
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  late JustificanteModel _item;
  bool _procesando = false;
  Future<Uint8List>? _pdfBytesFuture;

  @override
  void initState() {
    super.initState();
    _item = widget.solicitud;
    if (_esArchivoPdf(_item.cartaMotivoUrl)) {
      _pdfBytesFuture = _descargarBytes(_item.cartaMotivoUrl);
    }
  }

  bool _esArchivoPdf(String url) {
    final limpia = url.toLowerCase().split('?').first;
    return limpia.endsWith('.pdf');
  }

  Future<Uint8List> _descargarBytes(String url) async {
    final respuesta = await http.get(Uri.parse(url));
    if (respuesta.statusCode == 200) {
      return respuesta.bodyBytes;
    }
    throw Exception('Error al descargar documento (${respuesta.statusCode})');
  }

  void _abrirVisorPantallaCompleta(String titulo, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenDocumentViewer(
          title: titulo,
          documentUrl: url,
          esPdf: _esArchivoPdf(url),
        ),
      ),
    );
  }

  Future<void> _mostrarDialogoRechazo() async {
    final motivoCtrl = TextEditingController();
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Motivo de Rechazo'),
        content: TextField(
          controller: motivoCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText:
                'Ej. La foto del INE esta borrosa o falta la firma del tutor',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (motivoCtrl.text.trim().isNotEmpty) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Rechazar y Notificar'),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      setState(() => _procesando = true);
      try {
        await _service.rechazarSolicitud(_item.id, motivoCtrl.text.trim());
        if (mounted) Navigator.pop(context);
      } finally {
        if (mounted) setState(() => _procesando = false);
      }
    }
  }

  Future<void> _aprobarYGenerarPdf() async {
    setState(() => _procesando = true);
    try {
      final fechaEmision = await _service.aprobarSolicitud(_item.id);
      setState(() {
        _item = JustificanteModel(
          id: _item.id,
          studentId: _item.studentId,
          nombreEstudiante: _item.nombreEstudiante,
          matricula: _item.matricula,
          docentesGrupo: _item.docentesGrupo,
          licenciatura: _item.licenciatura,
          fechaInicio: _item.fechaInicio,
          fechaFin: _item.fechaFin,
          motivo: _item.motivo,
          esMotivoSalud: _item.esMotivoSalud,
          ineAnversoUrl: _item.ineAnversoUrl,
          ineReversoUrl: _item.ineReversoUrl,
          cartaMotivoUrl: _item.cartaMotivoUrl,
          estado: JustificanteStatus.APPROVED,
          fechaSolicitud: _item.fechaSolicitud,
          fechaEmision: fechaEmision,
        );
      });
      await JustificantePdfGenerator.generarEImprimir(_item);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _notificarListoParaRecoger() async {
    setState(() => _procesando = true);
    try {
      await _service.marcarListoParaRecoger(_item.id, _item.studentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notificacion enviada al estudiante correctamente.'),
          ),
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Widget _construirVisorExpedienteUnico(String titulo, String url) {
    final esPdf = _esArchivoPdf(url);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.grey.shade200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    titulo,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _abrirVisorPantallaCompleta(titulo, url),
                  icon: const Icon(Icons.open_in_full, size: 18),
                  label: const Text('Pantalla completa'),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 420,
            child: esPdf
                ? FutureBuilder<Uint8List>(
                    future: _pdfBytesFuture ?? _descargarBytes(url),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError || !snapshot.hasData) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'No se pudo cargar el PDF escaneado: ${snapshot.error}',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      return PdfPreview(
                        build: (PdfPageFormat format) async => snapshot.data!,
                        useActions: false,
                        canChangeOrientation: false,
                        canChangePageFormat: false,
                        canDebug: false,
                      );
                    },
                  )
                : InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Text(
                            'No se pudo cargar la vista previa del documento',
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rangoDias =
        'Del ${_dateFormat.format(_item.fechaInicio)} al ${_dateFormat.format(_item.fechaFin)}';
    final esExpedienteUnificado =
        _item.ineAnversoUrl == _item.cartaMotivoUrl || _item.esMotivoSalud;

    return Scaffold(
      appBar: AppBar(title: Text('Revision: ${_item.matricula}')),
      body: _procesando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _item.nombreEstudiante,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('Matricula: ${_item.matricula}'),
                          Text(
                            'Licenciatura en Ingenieria: ${_item.licenciatura}',
                          ),
                          Text('Docentes / Grupo: ${_item.docentesGrupo}'),
                          const Divider(height: 16),
                          Text(
                            'Dias a justificar: $rangoDias',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tipo de comprobante: ${_item.esMotivoSalud ? "Receta Medica (Salud)" : "Hoja escaneada con INE (ambos lados) y Carta de Tutor"}',
                          ),
                          const SizedBox(height: 4),
                          Text('Motivo declarado: ${_item.motivo}'),
                          const SizedBox(height: 8),
                          Chip(label: Text('Estado: ${_item.estado.name}')),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Inspeccion de Expediente:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (esExpedienteUnificado)
                    _construirVisorExpedienteUnico(
                      _item.esMotivoSalud
                          ? 'Expediente Medico (Receta / Constancia)'
                          : 'Hoja Escaneada Unica (INE Ambos Lados + Carta Tutor)',
                      _item.cartaMotivoUrl,
                    )
                  else ...[
                    _construirVisorExpedienteUnico(
                      '1. INE del Tutor (Anverso)',
                      _item.ineAnversoUrl,
                    ),
                    _construirVisorExpedienteUnico(
                      '2. INE del Tutor (Reverso)',
                      _item.ineReversoUrl,
                    ),
                    _construirVisorExpedienteUnico(
                      '3. Carta de Motivo Firmada',
                      _item.cartaMotivoUrl,
                    ),
                  ],
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (_item.estado == JustificanteStatus.PENDING) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _procesando ? null : _mostrarDialogoRechazo,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                    ),
                    child: const Text('Rechazar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _procesando ? null : _aprobarYGenerarPdf,
                    child: const Text('Aprobar e Imprimir'),
                  ),
                ),
              ],
              if (_item.estado == JustificanteStatus.APPROVED) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _procesando
                        ? null
                        : () =>
                              JustificantePdfGenerator.generarEImprimir(_item),
                    child: const Text('Reimprimir'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _procesando ? null : _notificarListoParaRecoger,
                    child: const Text('Avisar al Estudiante (Listo)'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class FullScreenDocumentViewer extends StatelessWidget {
  final String title;
  final String documentUrl;
  final bool esPdf;

  const FullScreenDocumentViewer({
    super.key,
    required this.title,
    required this.documentUrl,
    required this.esPdf,
  });

  Future<Uint8List> _descargarBytes() async {
    final respuesta = await http.get(Uri.parse(documentUrl));
    if (respuesta.statusCode == 200) {
      return respuesta.bodyBytes;
    }
    throw Exception('No se pudo descargar el archivo');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: esPdf
          ? PdfPreview(
              build: (PdfPageFormat format) async => await _descargarBytes(),
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
            )
          : Center(
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.8,
                maxScale: 6.0,
                child: Image.network(documentUrl),
              ),
            ),
    );
  }
}
