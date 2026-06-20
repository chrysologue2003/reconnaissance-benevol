import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class CertificateHelper {
  static Future<void> generateAndPrintCertificate({
    required String userName,
    required int points,
    required int actionsCount,
    required List<String> badges,
  }) async {
    // Charger des polices supportant tous les caractères accentués (Français)
    final robotoRegular = await PdfGoogleFonts.robotoRegular();
    final robotoBold = await PdfGoogleFonts.robotoBold();
    final robotoItalic = await PdfGoogleFonts.robotoItalic();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: robotoRegular,
        bold: robotoBold,
        italic: robotoItalic,
      ),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(32),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.green, width: 8),
            ),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Logo/Header decoration
                pw.Align(
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'BÉNÉVOLESAPP',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green800,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                pw.SizedBox(height: 16),
                
                // Main Title
                pw.Text(
                  'CERTIFICAT DE BÉNÉVOLAT',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                ),
                pw.Text(
                  'Décerné pour engagement communautaire exceptionnel',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 32),

                // Statement
                pw.Text(
                  'Ce certificat officiel est fier de valoriser l\'action citoyenne de',
                  style: pw.TextStyle(fontSize: 14),
                ),
                pw.SizedBox(height: 12),
                pw.Text(
                  userName.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green900,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Container(
                  width: 500,
                  child: pw.Text(
                    'qui a activement participé aux initiatives d\'entraide collective, en apportant un soutien inestimable à la communauté.',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: 13, color: PdfColors.grey900),
                  ),
                ),
                pw.SizedBox(height: 32),

                // Stats row
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    _buildStatCol('Points accumulés', '$points pts'),
                    pw.SizedBox(width: 48),
                    _buildStatCol('Actions validées', '$actionsCount'),
                    pw.SizedBox(width: 48),
                    _buildStatCol('Niveau atteint', '${(points / 50).floor() + 1}'),
                  ],
                ),
                pw.SizedBox(height: 48),

                // Signature & Date
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Date : ${DateFormat('dd MMMM yyyy').format(DateTime.now())}'),
                        pw.Text('Lieu : Paris, France', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          'Signature du Comité',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          'BénévolesApp Officiel',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontStyle: pw.FontStyle.italic,
                            color: PdfColors.green700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    // Lance l'aperçu avant impression/téléchargement natif de la plateforme
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Certificat_Benevolat_${userName.replaceAll(' ', '_')}.pdf',
    );
  }

  static pw.Widget _buildStatCol(String label, String val) {
    return pw.Column(
      children: [
        pw.Text(
          val,
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.green800,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
      ],
    );
  }
}
