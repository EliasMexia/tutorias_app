import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class CloudinaryService {
  // Reemplaza con tus datos de Cloudinary
  static const String cloudName = 'TU_CLOUD_NAME';
  static const String uploadPreset = 'tutorias_preset';

  Future<String?> subirImagen(File imagenFisica) async {
    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/auto/upload',
      );

      final peticion = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(
          await http.MultipartFile.fromPath('file', imagenFisica.path),
        );

      final respuesta = await peticion.send();

      if (respuesta.statusCode == 200) {
        final respuestaData = await respuesta.stream.toBytes();
        final respuestaString = String.fromCharCodes(respuestaData);
        final jsonMap = jsonDecode(respuestaString);

        // Retorna la URL segura (HTTPS) de la imagen subida
        return jsonMap['secure_url'];
      } else {
        print('Error al subir imagen. Codigo: ${respuesta.statusCode}');
        return null;
      }
    } catch (e) {
      print('Excepcion al subir a Cloudinary: $e');
      return null;
    }
  }
}
