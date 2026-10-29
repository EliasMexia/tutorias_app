import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class CloudinaryService {
  // REEMPLAZA ESTOS DOS VALORES CON LOS DE TU CUENTA DE CLOUDINARY
  static const String cloudName = 'xgtbcvgi';
  static const String uploadPreset = 'tutorias_preset';

  Future<String?> subirImagen(File imagenFisica) async {
    final bytes = await imagenFisica.readAsBytes();
    final nombre = imagenFisica.path.split(Platform.pathSeparator).last;
    return subirBytes(bytes, nombre);
  }

  Future<String?> subirBytes(Uint8List bytes, String nombreArchivo) async {
    if (cloudName == 'TU_CLOUD_NAME' || cloudName.trim().isEmpty) {
      throw Exception(
        'Falta configurar tu cloudName real en cloudinary_service.dart',
      );
    }

    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/auto/upload',
      );

      final peticion = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: nombreArchivo),
        );

      final respuesta = await peticion.send();
      final respuestaData = await respuesta.stream.toBytes();
      final respuestaString = utf8.decode(respuestaData);

      if (respuesta.statusCode == 200) {
        final jsonMap = jsonDecode(respuestaString);
        return jsonMap['secure_url'];
      } else {
        print('Error Cloudinary (${respuesta.statusCode}): $respuestaString');
        return null;
      }
    } catch (e) {
      print('Excepcion al subir a Cloudinary: $e');
      rethrow;
    }
  }
}
