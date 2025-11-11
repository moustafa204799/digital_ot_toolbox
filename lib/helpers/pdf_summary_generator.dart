// 📦 lib/helpers/pdf_summary_generator.dart

import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../models/ot_settings.dart';
import '../models/patient.dart';
import 'pdf_generator.dart'; // 🆕 (✅ هذا هو الإصلاح)

class PdfSummaryGenerator {
  
  static pw.Font? _arabicFont;
  static pw.Font? _emojiFont;

  static Future<pw.Font> _getArabicFont() async {
    if (_arabicFont != null) return _arabicFont!;
    final fontData = await rootBundle.load("assets/fonts/NotoSansArabic-Regular.ttf");
    _arabicFont = pw.Font.ttf(fontData);
    return _arabicFont!;
  }

  static Future<pw.Font> _getEmojiFont() async {
    if (_emojiFont != null) return _emojiFont!;
    final fontData = await rootBundle.load("assets/fonts/NotoColorEmoji-Regular.ttf");
    _emojiFont = pw.Font.ttf(fontData);
    return _emojiFont!;
  }

  // الدالة الرئيسية
  static Future<Uint8List> generatePdfSummary(Patient patient) async {
    final db = DatabaseHelper.instance;
    final doc = pw.Document();
    
    final pw.Font arabicFont = await _getArabicFont();
    final pw.Font emojiFont = await _getEmojiFont(); 
    
    final OtSettings? settings = await db.getSettings();
    final String currentDate = DateFormat('d MMMM yyyy', 'ar').format(DateTime.now());
    
    final Map<String, int?> latestIds = await db.getLatestAssessmentIds(patient.patientId!);
    
    final romResults = latestIds['ROM'] != null 
        ? await db.getROMResultsForReport(latestIds['ROM']!) : null;
    final gripResults = latestIds['Grip'] != null
        ? await db.getGripResultsForReport(latestIds['Grip']!) : null;
    final skillsResults = latestIds['Skills'] != null
        ? await db.getSkillsResultsForReport(latestIds['Skills']!) : null;
        
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(
          base: arabicFont,
          bold: arabicFont,
          fontFallback: [emojiFont], 
        ),
        
        header: (pw.Context context) {
          return PdfReportGenerator.buildHeader(context, settings, patient, currentDate);
        },
        
        build: (pw.Context context) {
          List<pw.Widget> widgets = [];
          
          widgets.add(pw.Text('ملخص آخر التقييمات', style: pw.Theme.of(context).header3));
          widgets.add(pw.SizedBox(height: 20));

          if (romResults != null && romResults.isNotEmpty) {
            widgets.add(PdfReportGenerator.buildROMResults(context, romResults));
            widgets.add(pw.SizedBox(height: 25));
          }

          if (gripResults != null && gripResults.isNotEmpty) {
            widgets.add(PdfReportGenerator.buildGripResults(context, gripResults));
            widgets.add(pw.SizedBox(height: 25));
          }

          if (skillsResults != null && skillsResults.isNotEmpty) {
            widgets.add(PdfReportGenerator.buildSkillsResults(context, skillsResults));
            widgets.add(pw.SizedBox(height: 25));
          }

          if (romResults == null && gripResults == null && skillsResults == null) {
            widgets.add(pw.Center(child: pw.Text('لا توجد أي تقييمات مكتملة لهذا المريض.')));
          }

          return widgets;
        },
        
        footer: (pw.Context context) {
          return PdfReportGenerator.buildFooter(context);
        },
      ),
    );

    return doc.save();
  }
}