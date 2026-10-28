import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:tutorias_app/models/justificante_service.dart';

class JustificantePdfGenerator {
  static const List<String> _meses = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  static String _formatearFechaCorta(DateTime f) {
    return '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';
  }

  static Future<void> generarEImprimir(JustificanteModel data) async {
    await Printing.layoutPdf(
      name: 'Justificante_${data.matricula}.pdf',
      onLayout: (PdfPageFormat format) async => _construirPdf(data, format),
    );
  }

  static Future<Uint8List> _construirPdf(
    JustificanteModel data,
    PdfPageFormat format,
  ) async {
    final pdf = pw.Document();
    final fechaEmision = data.fechaEmision ?? DateTime.now();
    final diaEmision = fechaEmision.day.toString();
    final mesEmision = _meses[fechaEmision.month - 1];
    final anioEmision = fechaEmision.year.toString();

    final rangoFechas = data.fechaInicio.isAtSameMomentAs(data.fechaFin)
        ? 'el dia ${_formatearFechaCorta(data.fechaInicio)}'
        : 'del ${_formatearFechaCorta(data.fechaInicio)} al ${_formatearFechaCorta(data.fechaFin)}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.symmetric(horizontal: 50, vertical: 40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Encabezado Institucional UAS - FIM Tutorias
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'UAS | FIM',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'UNIVERSIDAD AUTONOMA DE SINALOA',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'FACULTAD DE INGENIERIA MOCHIS',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'TUTORIAS',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1.5),
              pw.SizedBox(height: 15),

              // Asunto
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Asunto: Justificante de estudiante',
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ),
              pw.SizedBox(height: 25),

              // Docentes del grupo
              pw.RichText(
                text: pw.TextSpan(
                  style: const pw.TextStyle(
                    fontSize: 11,
                    color: PdfColors.black,
                  ),
                  children: [
                    pw.TextSpan(
                      text: 'DOCENTES DEL GRUPO: ',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.TextSpan(
                      text: '  ${data.docentesGrupo}  ',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        decoration: pw.TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // Cuerpo del justificante con datos inyectados
              pw.RichText(
                textAlign: pw.TextAlign.justify,
                text: pw.TextSpan(
                  style: const pw.TextStyle(
                    fontSize: 12,
                    lineSpacing: 6,
                    color: PdfColors.black,
                  ),
                  children: [
                    const pw.TextSpan(
                      text:
                          'Por este medio reciba un cordial saludo, igualmente me permito hacer de su conocimiento que el/la estudiante ',
                    ),
                    pw.TextSpan(
                      text: ' ${data.nombreEstudiante} ',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        decoration: pw.TextDecoration.underline,
                      ),
                    ),
                    const pw.TextSpan(text: ' del '),
                    pw.TextSpan(
                      text: ' ${data.docentesGrupo} ',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        decoration: pw.TextDecoration.underline,
                      ),
                    ),
                    const pw.TextSpan(
                      text: ' de la Licenciatura en Ingenieria ',
                    ),
                    pw.TextSpan(
                      text: ' ${data.licenciatura} ',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        decoration: pw.TextDecoration.underline,
                      ),
                    ),
                    const pw.TextSpan(text: ' no asistio a clases '),
                    pw.TextSpan(
                      text: ' $rangoFechas ',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        decoration: pw.TextDecoration.underline,
                      ),
                    ),
                    const pw.TextSpan(text: ' debido a '),
                    pw.TextSpan(
                      text: ' ${data.motivo}. ',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        decoration: pw.TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Agradezco las atenciones que brinde al presente justificante. Anexo comprobante.',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 60),

              // Firma del Responsable de Tutorias
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'Atentamente',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                  pw.SizedBox(height: 45),
                  pw.Container(
                    width: 220,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(width: 1)),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Dra. Alicia Jaquelin Cardenas Valenzuela',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Responsable de Tutorias',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                ],
              ),
              pw.SizedBox(height: 50),

              // Fecha y lugar de emision
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.RichText(
                  text: pw.TextSpan(
                    style: const pw.TextStyle(
                      fontSize: 11,
                      color: PdfColors.black,
                    ),
                    children: [
                      const pw.TextSpan(text: 'Los Mochis, Sinaloa; a '),
                      pw.TextSpan(
                        text: ' $diaEmision ',
                        style: const pw.TextStyle(
                          decoration: pw.TextDecoration.underline,
                        ),
                      ),
                      const pw.TextSpan(text: ' de '),
                      pw.TextSpan(
                        text: ' $mesEmision ',
                        style: const pw.TextStyle(
                          decoration: pw.TextDecoration.underline,
                        ),
                      ),
                      pw.TextSpan(text: ' de $anioEmision.'),
                    ],
                  ),
                ),
              ),

              pw.Spacer(),

              // Pie de pagina institucional
              pw.Divider(thickness: 1),
              pw.Text(
                'Facultad de Ingenieria Mochis, Ciudad Universitaria, Fuente de Poseidon y Prol. Angel Flores S/N, Fracc. Las Fuentes.\nLos Mochis, Sinaloa, Mexico - Tel: (668) 812-7641 - Email: tutorias.fim@uas.edu.mx - https://fim.uas.edu.mx',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}
