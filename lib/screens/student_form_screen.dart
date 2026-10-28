import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
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

  late TextEditingController _nombreCtrl;
  late TextEditingController _matriculaCtrl;
  late TextEditingController _grupoCtrl;
  late TextEditingController _motivoCtrl;

  String _licenciaturaSeleccionada = 'Software';
  DateTime _fechaInicio = DateTime.now();
  DateTime _fechaFin = DateTime.now();

  String? _ineAnversoUrl;
  String? _ineReversoUrl;
  String? _cartaMotivoUrl;
  bool _enviando = false;
  bool _subiendoArchivo = false;

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
      _ineAnversoUrl = s.ineAnversoUrl;
      _ineReversoUrl = s.ineReversoUrl;
      _cartaMotivoUrl = s.cartaMotivoUrl;
    }
  }

  void _mostrarOpcionesDeArchivo(String tipoDocumento) {
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
                  _procesarArchivoSeleccionado(tipoDocumento, 'camara');
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Elegir de Galeria'),
                onTap: () {
                  Navigator.of(context).pop();
                  _procesarArchivoSeleccionado(tipoDocumento, 'galeria');
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: const Text('Subir Documento (PDF)'),
                onTap: () {
                  Navigator.of(context).pop();
                  _procesarArchivoSeleccionado(tipoDocumento, 'pdf');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _procesarArchivoSeleccionado(
    String tipoDocumento,
    String origen,
  ) async {
    File? archivoFisico;

    try {
      if (origen == 'camara') {
        final XFile? foto = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 80,
        );
        if (foto != null) archivoFisico = File(foto.path);
      } else if (origen == 'galeria') {
        final XFile? imagen = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 80,
        );
        if (imagen != null) archivoFisico = File(imagen.path);
      } else if (origen == 'pdf') {
        FilePickerResult? resultado = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );
        if (resultado != null && resultado.files.single.path != null) {
          archivoFisico = File(resultado.files.single.path!);
        }
      }

      if (archivoFisico != null) {
        setState(() => _subiendoArchivo = true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Subiendo archivo, por favor espera...'),
            ),
          );
        }

        CloudinaryService cloudinary = CloudinaryService();
        String? urlSubida = await cloudinary.subirImagen(archivoFisico);

        if (urlSubida != null) {
          setState(() {
            if (tipoDocumento == 'ine_anverso') _ineAnversoUrl = urlSubida;
            if (tipoDocumento == 'ine_reverso') _ineReversoUrl = urlSubida;
            if (tipoDocumento == 'carta_motivo') _cartaMotivoUrl = urlSubida;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Archivo subido con exito')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Error al subir el archivo. Intenta de nuevo.'),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _subiendoArchivo = false);
      }
    }
  }

  Future<void> _guardarSolicitud() async {
    if (!_formKey.currentState!.validate()) return;
    if (_ineAnversoUrl == null ||
        _ineReversoUrl == null ||
        _cartaMotivoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes adjuntar los 3 documentos obligatorios.'),
        ),
      );
      return;
    }

    setState(() => _enviando = true);
    try {
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
        ineAnversoUrl: _ineAnversoUrl!,
        ineReversoUrl: _ineReversoUrl!,
        cartaMotivoUrl: _cartaMotivoUrl!,
        estado: JustificanteStatus.PENDING,
        fechaSolicitud: DateTime.now(),
      );

      await _service.enviarOSubsanarSolicitud(modelo);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esRechazado =
        widget.solicitudExistente?.estado == JustificanteStatus.REJECTED;

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
                  labelText: 'Grupo (ej. 3-01)',
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
              const SizedBox(height: 12),
              TextFormField(
                controller: _motivoCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Motivo de inasistencia (ej. consulta medica)',
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Campo obligatorio' : null,
              ),
              const SizedBox(height: 20),
              const Text(
                'Documentos probatorios obligatorios:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _subiendoArchivo
                    ? null
                    : () => _mostrarOpcionesDeArchivo('ine_anverso'),
                child: Text(
                  _ineAnversoUrl == null
                      ? 'Subir INE del Tutor (Anverso)'
                      : 'INE Anverso cargada (Reemplazar)',
                ),
              ),
              OutlinedButton(
                onPressed: _subiendoArchivo
                    ? null
                    : () => _mostrarOpcionesDeArchivo('ine_reverso'),
                child: Text(
                  _ineReversoUrl == null
                      ? 'Subir INE del Tutor (Reverso)'
                      : 'INE Reverso cargada (Reemplazar)',
                ),
              ),
              OutlinedButton(
                onPressed: _subiendoArchivo
                    ? null
                    : () => _mostrarOpcionesDeArchivo('carta_motivo'),
                child: Text(
                  _cartaMotivoUrl == null
                      ? 'Subir Carta firmada por el Tutor'
                      : 'Carta firmada cargada (Reemplazar)',
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: (_enviando || _subiendoArchivo)
                    ? null
                    : _guardarSolicitud,
                child: Text(
                  esRechazado ? 'Reenviar para Revision' : 'Enviar Solicitud',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
