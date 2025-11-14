import 'dart:io'; // ✅ لقراءة الملف
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
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
    
    // ✅ 1. تحميل الشعار هنا
    pw.MemoryImage? logoImage;
    if (settings?.clinicLogoPath != null) {
      final file = File(settings!.clinicLogoPath!);
      if (await file.exists()) {
        logoImage = pw.MemoryImage(await file.readAsBytes());
      }
    }

    final Map<String, dynamic>? assessment = await db.getAssessmentDetails(assessmentId);
    if (assessment == null) throw Exception('Assessment not found');

    final String assessmentType = assessment['assessment_type'];
    final String assessmentDate = DateFormat('d MMMM yyyy', 'ar')
        .format(DateTime.parse(assessment['date_created']));
        
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
          // ✅ 2. تمرير الشعار للهيدر
          return buildHeader(context, settings, patient, assessmentDate, logoImage);
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

  // ✅ 3. تعديل الهيدر ليرسم الصورة
  static pw.Widget buildHeader(pw.Context context, OtSettings? settings, Patient patient, String assessmentDate, [pw.MemoryImage? logo]) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // النصوص (اسم التقرير والعيادة)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('🩺 تقرير تقييم العلاج الوظيفي', style: pw.Theme.of(context).header3),
                pw.SizedBox(height: 5),
                pw.Text('الأخصائي: ${settings?.otName ?? 'غير محدد'}', style: pw.Theme.of(context).header5),
              ],
            ),
            // الصورة (الشعار)
            if (logo != null)
              pw.Container(
                width: 60,
                height: 60,
                child: pw.Image(logo),
              ),
          ],
        ),
        pw.Divider(thickness: 2),
        pw.SizedBox(height: 10),
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

  // ... (باقي الدوال buildFooter, _buildResults, buildROMResults ... كما هي في ملفك الأصلي)
  
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
      case 'ROM': return buildROMResults(context, results); 
      case 'Grip': return buildGripResults(context, results); 
      case 'Skills': return buildSkillsResults(context, results);
      default: return pw.Text('نوع تقييم غير معروف');
    }
  }

  static Future<List<Map<String, dynamic>>> _loadResultsData(int assessmentId, String assessmentType, DatabaseHelper db) {
    switch (assessmentType) {
      case 'ROM': return db.getROMResultsForReport(assessmentId);
      case 'Grip': return db.getGripResultsForReport(assessmentId);
      case 'Skills': return db.getSkillsResultsForReport(assessmentId);
      default: return Future.value([]);
    }
  }

  static pw.Widget buildROMResults(pw.Context context, List<Map<String, dynamic>> results) {
    final headers = ['الحركة/المفصل', 'نشط (Active)', 'سلبي (Passive)', 'الألم'];
    final data = results.map((res) => [
      '${res['joint_name']} (${res['motion_type']})',
      '${res['active_range'] ?? 'N/A'}°',
      '${res['passive_range'] ?? 'N/A'}°',
      res['pain_level'] ?? 'None',
    ]).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('نتائج تقييم مدى الحركة (ROM)', style: pw.Theme.of(context).header4),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(headers: headers, data: data, border: pw.TableBorder.all(width: 1, color: PdfColors.grey), headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold), cellAlignment: pw.Alignment.centerRight),
      ],
    );
  }

  static pw.Widget buildGripResults(pw.Context context, List<Map<String, dynamic>> results) {
    final rightHandData = results.firstWhere((r) => r['hand'] == 'Right', orElse: () => <String, dynamic>{});
    final leftHandData = results.firstWhere((r) => r['hand'] == 'Left', orElse: () => <String, dynamic>{});
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('نتائج تقييم القبضة (Grip Assessment)', style: pw.Theme.of(context).header4),
        pw.SizedBox(height: 15),
        _buildHandSection(context, 'الطرف الأيمن (Right Hand)', rightHandData),
        pw.SizedBox(height: 15),
        _buildHandSection(context, 'الطرف الأيسر (Left Hand)', leftHandData),
      ],
    );
  }

  static pw.Widget _buildHandSection(pw.Context context, String title, Map<String, dynamic> data) {
    if (data.isEmpty) return pw.Container();
    final Map<String, String> labels = {'grasp_type': 'نوع القبضة', 'holding_ability': 'قدرة الإمساك', 'release_ability': 'التحرير', 'coordination': 'التنسيق', 'atypical_signs': 'علامات غير نمطية', 'clinical_note': 'ملاحظات سريرية'};
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)), color: PdfColors.grey100),
      padding: const pw.EdgeInsets.all(12),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(title, style: pw.Theme.of(context).header5.copyWith(color: PdfColors.blue800)),
        pw.Divider(color: PdfColors.grey400, thickness: 0.5),
        ...labels.entries.map((entry) {
          final value = data[entry.key]?.toString() ?? '';
          if (value.isEmpty || value == 'null') return pw.Container();
          return pw.Row(children: [pw.SizedBox(width: 110, child: pw.Text('${entry.value}:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))), pw.Expanded(child: pw.Text(value, style: const pw.TextStyle(fontSize: 10)))]);
        }),
      ]),
    );
  }

  static pw.Widget buildSkillsResults(pw.Context context, List<Map<String, dynamic>> results) {
    Map<String, List<Map<String, dynamic>>> groupedSkills = {};
    for (var res in results) { final group = res['skill_group'] as String; if (!groupedSkills.containsKey(group)) groupedSkills[group] = []; groupedSkills[group]!.add(res); }
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text('نتائج تقييم المهارات الدقيقة (Skills)', style: pw.Theme.of(context).header4),
      pw.SizedBox(height: 10),
      ...groupedSkills.entries.map((entry) {
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(entry.key, style: pw.Theme.of(context).header5),
          pw.TableHelper.fromTextArray(headers: ['المهارة', 'الدرجة'], data: entry.value.map((skill) => [skill['skill_description'], '${skill['score']} / 5']).toList(), border: pw.TableBorder.all(width: 1, color: PdfColors.grey), headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold), cellAlignment: pw.Alignment.centerRight),
          pw.SizedBox(height: 10)
        ]);
      })
    ]);
  }
}