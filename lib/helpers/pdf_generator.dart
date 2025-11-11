// 📦 lib/helpers/pdf_generator.dart

import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
// import 'package:printing/printing.dart'; // 🆕 (تعديل) تم حذف هذا السطر لأنه غير مستخدم هنا
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../models/ot_settings.dart';
import '../models/patient.dart';

class PdfReportGenerator {
  
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


  static Future<Uint8List> generatePdfReport(int assessmentId, Patient patient) async {
    final db = DatabaseHelper.instance;
    final doc = pw.Document();
    
    final pw.Font arabicFont = await _getArabicFont();
    final pw.Font emojiFont = await _getEmojiFont(); 
    
    final OtSettings? settings = await db.getSettings();
    final Map<String, dynamic>? assessment = await db.getAssessmentDetails(assessmentId);
    
    if (assessment == null) {
      throw Exception('Assessment not found');
    }

    final String assessmentType = assessment['assessment_type'];
    final String assessmentDate = DateFormat('d MMMM yyyy', 'ar')
        .format(DateTime.parse(assessment['date_created']));
        
    // 🆕 (✅ تعديل) تم استدعاء الدالة المفقودة هنا
    final List<Map<String, dynamic>> results = await _loadResultsData(assessmentId, assessmentType, db);

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
          return buildHeader(context, settings, patient, assessmentDate);
        },
        
        build: (pw.Context context) {
          return [
            _buildResults(context, assessmentType, results),
          ];
        },
        
        footer: (pw.Context context) {
          return buildFooter(context);
        },
      ),
    );

    return doc.save();
  }

  // --- دوال مساعدة لبناء أجزاء الـ PDF ---

  // 🆕 (✅ تعديل) إضافة "static"
  static pw.Widget buildHeader(pw.Context context, OtSettings? settings, Patient patient, String assessmentDate) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '🩺 تقرير تقييم العلاج الوظيفي', 
          style: pw.Theme.of(context).header3,
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'الأخصائي: ${settings?.otName ?? 'غير محدد'}',
          style: pw.Theme.of(context).header5,
        ),
        // TODO: يمكن إضافة شعار العيادة هنا (settings.clinicLogoPath)
        pw.Divider(thickness: 2),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('المريض: ${patient.fullName}'),
            pw.Text('العمر: ${patient.calculateAge()}'),
          ],
        ),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('التشخيص: ${patient.diagnosis ?? 'لا يوجد'}'),
            pw.Text('تاريخ التقييم: $assessmentDate'),
          ],
        ),
        pw.SizedBox(height: 20),
      ],
    );
  }

  // 🆕 (✅ تعديل) إضافة "static"
  static pw.Widget buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.center,
      child: pw.Text(
        'صفحة ${context.pageNumber} من ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
      ),
    );
  }

  static pw.Widget _buildResults(pw.Context context, String assessmentType, List<Map<String, dynamic>> results) {
    
    if (results.isEmpty) {
      return pw.Center(child: pw.Text('لا توجد نتائج لعرضها.'));
    }
    
    switch (assessmentType) {
      case 'ROM':
        return buildROMResults(context, results); 
      case 'Grip':
        return buildGripResults(context, results);
      case 'Skills':
        return buildSkillsResults(context, results);
      default:
        return pw.Text('نوع تقييم غير معروف');
    }
  }

  // 🆕 (✅ تعديل) إضافة الدالة المفقودة
  static Future<List<Map<String, dynamic>>> _loadResultsData(int assessmentId, String assessmentType, DatabaseHelper db) {
    switch (assessmentType) {
      case 'ROM':
        return db.getROMResultsForReport(assessmentId);
      case 'Grip':
        return db.getGripResultsForReport(assessmentId);
      case 'Skills':
        return db.getSkillsResultsForReport(assessmentId);
      default:
        return Future.value([]);
    }
  }

  // --- دوال بناء الجداول (ROM, Grip, Skills) ---

  static pw.Widget buildROMResults(pw.Context context, List<Map<String, dynamic>> results) {
    final headers = ['الحركة/المفصل', 'نشط (Active)', 'سلبي (Passive)', 'الألم'];
    final data = results.map((res) {
      return [
        '${res['joint_name']} (${res['motion_type']})',
        '${res['active_range'] ?? 'N/A'}°',
        '${res['passive_range'] ?? 'N/A'}°',
        res['pain_level'] ?? 'None',
      ];
    }).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('نتائج تقييم مدى الحركة (ROM)', style: pw.Theme.of(context).header4),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray( 
          headers: headers,
          data: data,
          border: pw.TableBorder.all(width: 1, color: PdfColors.grey),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellAlignment: pw.Alignment.centerRight,
          cellPadding: const pw.EdgeInsets.all(5),
        ),
      ],
    );
  }

  static pw.Widget buildGripResults(pw.Context context, List<Map<String, dynamic>> results) {
    final headers = ['نوع القبضة', 'اليسرى (Score)', 'اليمنى (Score)', 'ملحوظات سريرية'];
    final data = results.map((res) {
      return [
        res['grip_type'],
        '${res['score_left'] ?? 'N/A'} / 5',
        '${res['score_right'] ?? 'N/A'} / 5',
        res['clinical_note'] ?? '',
      ];
    }).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('نتائج تقييم نوع القبضة (Grip)', style: pw.Theme.of(context).header4),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray( 
          headers: headers,
          data: data,
          border: pw.TableBorder.all(width: 1, color: PdfColors.grey),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellAlignment: pw.Alignment.centerRight,
          cellPadding: const pw.EdgeInsets.all(5),
          columnWidths: {
            3: const pw.FlexColumnWidth(2), 
          },
        ),
      ],
    );
  }

  static pw.Widget buildSkillsResults(pw.Context context, List<Map<String, dynamic>> results) {
    Map<String, List<Map<String, dynamic>>> groupedSkills = {};
    Map<String, String> notesByGroup = {};

    for (var res in results) {
      final group = res['skill_group'] as String;
      if (!groupedSkills.containsKey(group)) {
        groupedSkills[group] = [];
      }
      groupedSkills[group]!.add(res);
      
      if (res['clinical_note'] != null && res['clinical_note'].isNotEmpty) {
        notesByGroup[group] = res['clinical_note'];
      }
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('نتائج تقييم المهارات الدقيقة (Skills)', style: pw.Theme.of(context).header4),
        pw.SizedBox(height: 10),

        ...groupedSkills.entries.map((entry) {
          final groupName = entry.key;
          final skills = entry.value;

          final headers = ['المهارة', 'الدرجة (Score)'];
          final data = skills.map((skill) {
            return [
              skill['skill_description'],
              '${skill['score'] ?? 'N/A'} / 5',
            ];
          }).toList();

          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 15),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(groupName, style: pw.Theme.of(context).header5), 
                pw.TableHelper.fromTextArray( 
                  headers: headers,
                  data: data,
                  border: pw.TableBorder.all(width: 1, color: PdfColors.grey),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellAlignment: pw.Alignment.centerRight,
                  cellPadding: const pw.EdgeInsets.all(5),
                  columnWidths: {
                     0: const pw.FlexColumnWidth(3),
                     1: const pw.FlexColumnWidth(1),
                  },
                ),
                if (notesByGroup.containsKey(groupName))
                  pw.Container(
                    padding: const pw.EdgeInsets.all(5),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        left: pw.BorderSide(color: PdfColors.grey, width: 1),
                        right: pw.BorderSide(color: PdfColors.grey, width: 1),
                        bottom: pw.BorderSide(color: PdfColors.grey, width: 1),
                      ),
                    ),
                    child: pw.Text('ملحوظة سريرية: ${notesByGroup[groupName]}'),
                  ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
} // 🆕 (✅ تعديل) إضافة القوس المفقود