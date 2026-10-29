import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:tutorias_app/models/justificante_service.dart';
import 'package:tutorias_app/services/cloudinary_service.dart';

class StudentFormScreen extends StatefulWidget {
  final String currentUserId;
  final JustificanteModel? solicitudExistente;

  const StudentFormScreen({
    super.key,
    required this.currentUserId,
    this.solicitudExistente,
  });

  @override
  State<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends State<StudentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = JustificanteService();
  final ImagePicker _imagePicker = ImagePicker();
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  late TextEditingController _nombreCtrl;
  late TextEditingController _matriculaCtrl;
  late TextEditingController _grupoCtrl;
  late TextEditingController _motivoCtrl;

  String _licenciaturaSeleccionada = 'Software';
  DateTime _fechaInicio = DateTime.now();
  DateTime _fechaFin = DateTime.now();
  bool _esMotivoSalud = false;

  // Archivos locales para armar el PDF unificado
  File? _fotoIneAnverso;
  File? _fotoIneReverso;
  File? _fotoCartaTutor;

  // Archivo local para receta medica (imagen o PDF)
  File? _archivoRecetaMedica;
  bool _recetaEsPdf = false;

  // URL previa si se esta editando una solicitud rechazada
  String? _documentoSubidoUrl;
  bool _enviando = false;

  final List<String> _licenciaturas = [
    'Software',
    'Geodesica',
    'Civil',
    'Procesos Industriales',
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.solicitudExistente;
    _nombreCtrl = TextEditingController(text: s?.nombreEstudiante ?? '');
    _matriculaCtrl = TextEditingController(text: s?.matricula ?? '');
    _grupoCtrl = TextEditingController(text: s?.docentesGrupo ?? '');
    _motivoCtrl = TextEditingController(text: s?.motivo ?? '');
    if (s != null) {
      _licenciaturaSeleccionada = s.licenciatura;
      _fechaInicio = s.fechaInicio;
      _fechaFin = s.fechaFin;
      _esMotivoSalud = s.esMotivoSalud;
      _documentoSubidoUrl = s.cartaMotivoUrl;
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _matriculaCtrl.dispose();
    _grupoCtrl.dispose();
    _motivoCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFechas() async {
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _fechaInicio, end: _fechaFin),
      helpText: 'Selecciona los dias a justificar',
      cancelText: 'Cancelar',
      confirmText: 'Guardar dias',
    );

    if (rango != null) {
      setState(() {
        _fechaInicio = rango.start;
        _fechaFin = rango.end;
      });
    }
  }

  void _mostrarOpcionesDeArchivo(
    String tipoDocumento, {
    bool permitirPdf = false,
  }) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Tomar foto (Camara)'),
                onTap: () {
                  Navigator.of(context).pop();
                  _seleccionarArchivoLocal(tipoDocumento, 'camara');
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Elegir imagen de Galeria'),
                onTap: () {
                  Navigator.of(context).pop();
                  _seleccionarArchivoLocal(tipoDocumento, 'galeria');
                },
              ),
              if (permitirPdf)
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf),
                  title: const Text('Subir archivo PDF'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _seleccionarArchivoLocal(tipoDocumento, 'pdf');
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _seleccionarArchivoLocal(
    String tipoDocumento,
    String origen,
  ) async {
    try {
      File? archivoSeleccionado;
      bool esPdf = false;

      if (origen == 'camara') {
        final XFile? foto = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        );
        if (foto != null) archivoSeleccionado = File(foto.path);
      } else if (origen == 'galeria') {
        final XFile? imagen = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );
        if (imagen != null) archivoSeleccionado = File(imagen.path);
      } else if (origen == 'pdf') {
        FilePickerResult? resultado = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );
        if (resultado != null && resultado.files.single.path != null) {
          archivoSeleccionado = File(resultado.files.single.path!);
          esPdf = true;
        }
      }

      if (archivoSeleccionado != null) {
        setState(() {
          if (tipoDocumento == 'ine_anverso')
            _fotoIneAnverso = archivoSeleccionado;
          if (tipoDocumento == 'ine_reverso')
            _fotoIneReverso = archivoSeleccionado;
          if (tipoDocumento == 'carta_motivo')
            _fotoCartaTutor = archivoSeleccionado;
          if (tipoDocumento == 'receta_medica') {
            _archivoRecetaMedica = archivoSeleccionado;
            _recetaEsPdf = esPdf;
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Archivo cargado correctamente')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar archivo: $e')),
        );
      }
    }
  }

  /// Genera un unico documento PDF de 1 sola hoja con los documentos cargados
  Future<Uint8List> _generarDocumentoEscaneadoPdf() async {
    if (_esMotivoSalud && _recetaEsPdf && _archivoRecetaMedica != null) {
      return await _archivoRecetaMedica!.readAsBytes();
    }

    final pdf = pw.Document();
    final rangoFechas =
        '${_dateFormat.format(_fechaInicio)} al ${_dateFormat.format(_fechaFin)}';

    if (_esMotivoSalud) {
      final recetaBytes = await _archivoRecetaMedica!.readAsBytes();
      final imgReceta = pw.MemoryImage(recetaBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(
                  'EXPEDIENTE DE JUSTIFICANTE - MOTIVO DE SALUD',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Alumno: ${_nombreCtrl.text.trim()} | Matricula: ${_matriculaCtrl.text.trim()} | Grupo: ${_grupoCtrl.text.trim()}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  'Licenciatura: $_licenciaturaSeleccionada | Dias a justificar: $rangoFechas',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Divider(),
                pw.SizedBox(height: 8),
                pw.Text(
                  'RECETA / CONSTANCIA MEDICA:',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Expanded(
                  child: pw.Center(
                    child: pw.Image(imgReceta, fit: pw.BoxFit.contain),
                  ),
                ),
              ],
            );
          },
        ),
      );
    } else {
      final anversoBytes = await _fotoIneAnverso!.readAsBytes();
      final reversoBytes = await _fotoIneReverso!.readAsBytes();
      final cartaBytes = await _fotoCartaTutor!.readAsBytes();

      final imgAnverso = pw.MemoryImage(anversoBytes);
      final imgReverso = pw.MemoryImage(reversoBytes);
      final imgCarta = pw.MemoryImage(cartaBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(
                  'EXPEDIENTE DE JUSTIFICANTE - CARTA Y CREDENCIAL DEL TUTOR',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Alumno: ${_nombreCtrl.text.trim()} | Matricula: ${_matriculaCtrl.text.trim()} | Grupo: ${_grupoCtrl.text.trim()}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  'Licenciatura: $_licenciaturaSeleccionada | Dias a justificar: $rangoFechas',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Divider(),
                pw.Text(
                  '1. CREDENCIAL DEL TUTOR (AMBOS LADOS)',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.SizedBox(
                  height: 170,
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(4),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey400),
                          ),
                          child: pw.Column(
                            children: [
                              pw.Text(
                                'ANVERSO (FRENTE)',
                                style: const pw.TextStyle(fontSize: 8),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Expanded(
                                child: pw.Image(
                                  imgAnverso,
                                  fit: pw.BoxFit.contain,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 12),
                      pw.Expanded(
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(4),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey400),
                          ),
                          child: pw.Column(
                            children: [
                              pw.Text(
                                'REVERSO (ATRAS)',
                                style: const pw.TextStyle(fontSize: 8),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Expanded(
                                child: pw.Image(
                                  imgReverso,
                                  fit: pw.BoxFit.contain,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 14),
                pw.Text(
                  '2. CARTA FIRMADA POR EL TUTOR',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                    ),
                    child: pw.Center(
                      child: pw.Image(imgCarta, fit: pw.BoxFit.contain),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  bool get _documentosCompletos {
    if (_esMotivoSalud) {
      return _archivoRecetaMedica != null || _documentoSubidoUrl != null;
    } else {
      return (_fotoIneAnverso != null &&
              _fotoIneReverso != null &&
              _fotoCartaTutor != null) ||
          _documentoSubidoUrl != null;
    }
  }

  Future<void> _previsualizarPdfEscaneado() async {
    if (!_documentosCompletos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Carga primero las fotos para generar la vista previa.',
          ),
        ),
      );
      return;
    }

    final bytes = await _generarDocumentoEscaneadoPdf();
    if (!mounted) return;

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'Expediente_${_matriculaCtrl.text.trim()}.pdf',
    );
  }

  Future<void> _guardarSolicitud() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_documentosCompletos) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _esMotivoSalud
                ? 'Debes adjuntar la receta medica.'
                : 'Debes adjuntar los 2 lados de la INE y la carta firmada por el tutor.',
          ),
        ),
      );
      return;
    }

    setState(() => _enviando = true);
    try {
      String? urlFinal = _documentoSubidoUrl;

      // Si el estudiante selecciono nuevas fotos/archivos, generamos el PDF unico y lo subimos
      final seleccionoNuevosArchivos = _esMotivoSalud
          ? _archivoRecetaMedica != null
          : (_fotoIneAnverso != null &&
                _fotoIneReverso != null &&
                _fotoCartaTutor != null);

      if (seleccionoNuevosArchivos) {
        final pdfBytes = await _generarDocumentoEscaneadoPdf();
        final nombrePdf =
            'justificante_${_matriculaCtrl.text.trim()}_${DateTime.now().millisecondsSinceEpoch}.pdf';

        final cloudinary = CloudinaryService();
        urlFinal = await cloudinary.subirBytes(pdfBytes, nombrePdf);

        if (urlFinal == null) {
          throw Exception('No se recibio URL de Cloudinary.');
        }
      }

      final modelo = JustificanteModel(
        id: widget.solicitudExistente?.id ?? '',
        studentId: widget.currentUserId,
        nombreEstudiante: _nombreCtrl.text.trim(),
        matricula: _matriculaCtrl.text.trim(),
        docentesGrupo: _grupoCtrl.text.trim(),
        licenciatura: _licenciaturaSeleccionada,
        fechaInicio: _fechaInicio,
        fechaFin: _fechaFin,
        motivo: _motivoCtrl.text.trim(),
        esMotivoSalud: _esMotivoSalud,
        ineAnversoUrl: urlFinal!,
        ineReversoUrl: urlFinal,
        cartaMotivoUrl: urlFinal,
        estado: JustificanteStatus.PENDING,
        fechaSolicitud: DateTime.now(),
      );

      await _service.enviarOSubsanarSolicitud(modelo);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al enviar: $e')));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esRechazado =
        widget.solicitudExistente?.estado == JustificanteStatus.REJECTED;
    final textoFechas =
        'Del ${_dateFormat.format(_fechaInicio)} al ${_dateFormat.format(_fechaFin)}';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          esRechazado ? 'Corregir Solicitud' : 'Solicitar Justificante',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (esRechazado &&
                  widget.solicitudExistente?.motivoRechazo != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  color: Colors.red.shade100,
                  child: Text(
                    'Motivo de rechazo: ${widget.solicitudExistente!.motivoRechazo}',
                    style: TextStyle(
                      color: Colors.red.shade900,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo del estudiante',
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Campo obligatorio' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _matriculaCtrl,
                decoration: const InputDecoration(labelText: 'Matricula'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Campo obligatorio' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _grupoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Grupo y Docentes (ej. 3-01)',
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Campo obligatorio' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _licenciaturaSeleccionada,
                decoration: const InputDecoration(
                  labelText: 'Licenciatura en Ingenieria',
                ),
                items: _licenciaturas
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _licenciaturaSeleccionada = v!),
              ),
              const SizedBox(height: 16),
              // Selector de dias a justificar
              Card(
                elevation: 0,
                color: Colors.blue.shade50,
                child: ListTile(
                  leading: const Icon(Icons.calendar_month, color: Colors.blue),
                  title: const Text(
                    'Dias que necesita justificar:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  subtitle: Text(
                    textoFechas,
                    style: const TextStyle(fontSize: 15, color: Colors.black87),
                  ),
                  trailing: TextButton(
                    onPressed: _seleccionarFechas,
                    child: const Text('Cambiar'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _motivoCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Explicacion del motivo de inasistencia',
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Campo obligatorio' : null,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  '¿La inasistencia fue por problemas de salud?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  _esMotivoSalud
                      ? 'Solo se requiere subir la Receta Medica.'
                      : 'Se requiere INE del tutor (ambos lados) y carta firmada.',
                ),
                value: _esMotivoSalud,
                onChanged: (val) => setState(() => _esMotivoSalud = val),
              ),
              const Divider(),
              const SizedBox(height: 8),
              if (_esMotivoSalud) ...[
                const Text(
                  'Documento medico probatorio:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: Icon(
                    _archivoRecetaMedica != null
                        ? Icons.check_circle
                        : Icons.upload_file,
                    color: _archivoRecetaMedica != null ? Colors.green : null,
                  ),
                  onPressed: () => _mostrarOpcionesDeArchivo(
                    'receta_medica',
                    permitirPdf: true,
                  ),
                  label: Text(
                    _archivoRecetaMedica == null
                        ? 'Adjuntar Receta Medica (Foto o PDF)'
                        : 'Receta Medica lista (Reemplazar)',
                  ),
                ),
              ] else ...[
                const Text(
                  'Fotos para armar la hoja escaneada unica:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: Icon(
                    _fotoIneAnverso != null ? Icons.check_circle : Icons.badge,
                    color: _fotoIneAnverso != null ? Colors.green : null,
                  ),
                  onPressed: () => _mostrarOpcionesDeArchivo('ine_anverso'),
                  label: Text(
                    _fotoIneAnverso == null
                        ? '1. Foto INE del Tutor (Frente)'
                        : 'INE Frente lista (Reemplazar)',
                  ),
                ),
                OutlinedButton.icon(
                  icon: Icon(
                    _fotoIneReverso != null
                        ? Icons.check_circle
                        : Icons.badge_outlined,
                    color: _fotoIneReverso != null ? Colors.green : null,
                  ),
                  onPressed: () => _mostrarOpcionesDeArchivo('ine_reverso'),
                  label: Text(
                    _fotoIneReverso == null
                        ? '2. Foto INE del Tutor (Reverso)'
                        : 'INE Reverso lista (Reemplazar)',
                  ),
                ),
                OutlinedButton.icon(
                  icon: Icon(
                    _fotoCartaTutor != null
                        ? Icons.check_circle
                        : Icons.description,
                    color: _fotoCartaTutor != null ? Colors.green : null,
                  ),
                  onPressed: () => _mostrarOpcionesDeArchivo('carta_motivo'),
                  label: Text(
                    _fotoCartaTutor == null
                        ? '3. Foto Carta firmada por el Tutor'
                        : 'Carta firmada lista (Reemplazar)',
                  ),
                ),
              ],
              if (_documentosCompletos &&
                  !(_esMotivoSalud && _recetaEsPdf)) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  onPressed: _previsualizarPdfEscaneado,
                  label: const Text(
                    'Ver vista previa de la hoja escaneada (PDF)',
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _enviando ? null : _guardarSolicitud,
                child: _enviando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        esRechazado
                            ? 'Reenviar para Revision'
                            : 'Generar Escaneo y Enviar Solicitud',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
