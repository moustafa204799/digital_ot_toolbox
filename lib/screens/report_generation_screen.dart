import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart'; 
import 'package:intl/intl.dart'; 
import 'dart:typed_data'; 
import 'package:printing/printing.dart'; 
import 'dart:io'; 
import 'package:path_provider/path_provider.dart'; 

import '../models/patient.dart';
import '../database/database_helper.dart'; 
import '../models/ot_settings.dart'; 
import '../helpers/pdf_generator.dart';
import 'pdf_preview_screen.dart'; 

class ReportGenerationScreen extends StatefulWidget {
  final int assessmentId;
  final Patient patient;
  final bool cameFromAssessmentFlow; 

  const ReportGenerationScreen({
    super.key,
    required this.assessmentId,
    required this.patient,
    required this.cameFromAssessmentFlow, 
  });

  @override
  State<ReportGenerationScreen> createState() => _ReportGenerationScreenState();
}

class _ReportData {
  final String reportString;
  final Uint8List pdfBytes;
  _ReportData(this.reportString, this.pdfBytes);
}


class _ReportGenerationScreenState extends State<ReportGenerationScreen> {
  
  late Future<_ReportData> _reportDataFuture;

  @override
  void initState() {
    super.initState();
    _reportDataFuture = _loadReportData();
  }

  Future<_ReportData> _loadReportData() async {
    final String reportString = await _buildReportString();
    final Uint8List pdfBytes = await PdfReportGenerator.generatePdfReport(
      widget.assessmentId,
      widget.patient,
    );
    return _ReportData(reportString, pdfBytes);
  }

  // -------------------------------------------------
  // (✅ معدلة) دالة بناء نص التقرير
  // -------------------------------------------------
  Future<String> _buildReportString() async {
    final db = DatabaseHelper.instance;
    final OtSettings? settings = await db.getSettings();
    final String therapistName = settings?.otName ?? 'أخصائي العلاج الوظيفي';
    final assessment = await db.getAssessmentDetails(widget.assessmentId);
    if (assessment == null) throw Exception('لم يتم العثور على التقييم.');
    
    final String assessmentType = assessment['assessment_type'];
    final String assessmentDate = DateFormat('d MMMM yyyy', 'ar')
        .format(DateTime.parse(assessment['date_created']));

    final StringBuffer reportText = StringBuffer();
    reportText.writeln('🩺 تقرير تقييم العلاج الوظيفي');
    reportText.writeln('====================');
    reportText.writeln('👤 المريض: ${widget.patient.fullName}');
    reportText.writeln(' diagnosing: ${widget.patient.diagnosis ?? 'غير محدد'}');
    reportText.writeln('🎂 العمر: ${widget.patient.calculateAge()}');
    reportText.writeln('📅 تاريخ التقييم: $assessmentDate');
    reportText.writeln('👨‍⚕️ الأخصائي: $therapistName');
    reportText.writeln();

    switch (assessmentType) {
      case 'ROM':
        reportText.writeln('🔸 تقييم مدى الحركة (ROM)');
        reportText.writeln('--------------------');
        final results = await db.getROMResultsForReport(widget.assessmentId);
        for (var res in results) {
          reportText.writeln(
            '- ${res['joint_name']} (${res['motion_type']}):',
          );
          reportText.writeln(
            '  نشط (Active): ${res['active_range'] ?? 'N/A'}°',
          );
          reportText.writeln(
            '  سلبي (Passive): ${res['passive_range'] ?? 'N/A'}°',
          );
          if (res['pain_level'] != null && res['pain_level'] != 'None') {
            reportText.writeln('  الألم: ${res['pain_level']}');
          }
          if (res['clinical_note'] != null && res['clinical_note'].isNotEmpty) {
             reportText.writeln('  ملحوظة: ${res['clinical_note']}');
          }
        }
        break;
        
      // 🆕 (✅ تعديل) هذا القسم تم تعديله بالكامل
      case 'Grip':
        reportText.writeln('🔸 تقييم مكونات القبضة (Grip Components)');
        reportText.writeln('--------------------');
        
        final results = await db.getGripResultsForReport(widget.assessmentId);
        // جلب بيانات اليد اليمنى واليسرى
        final rightHand = results.firstWhere((r) => r['hand'] == 'Right', orElse: () => {});
        final leftHand = results.firstWhere((r) => r['hand'] == 'Left', orElse: () => {});

        // دالة مساعدة لطباعة بيانات اليد
        void buildHandText(String title, Map<String, dynamic> data) {
          if (data.isEmpty) return;
          reportText.writeln('\n--- $title ---');
          reportText.writeln('  - نوع القبضة: ${data['grasp_type'] ?? 'N/A'}');
          reportText.writeln('  - قدرة الإمساك: ${data['holding_ability'] ?? 'N/A'}');
          reportText.writeln('  - التحرير: ${data['release_ability'] ?? 'N/A'}');
          reportText.writeln('  - التنسيق: ${data['coordination'] ?? 'N/A'}');
          if (data['atypical_signs'] != null && data['atypical_signs'].isNotEmpty) {
            reportText.writeln('  - علامات غير نمطية: ${data['atypical_signs']}');
          }
          if (data['clinical_note'] != null && data['clinical_note'].isNotEmpty) {
            reportText.writeln('  - ملحوظة: ${data['clinical_note']}');
          }
        }
        
        buildHandText('اليد اليمنى (Right)', rightHand);
        buildHandText('اليد اليسرى (Left)', leftHand);
        break;

      case 'Skills':
        reportText.writeln('🔸 تقييم المهارات الدقيقة (نقاط العمل)');
        reportText.writeln('--------------------');
        reportText.writeln('(يتم عرض المهارات التي "لا يستطيع" أو "بمساعدة" فقط)');
        
        final results = await db.getSkillsResultsForReport(widget.assessmentId);
        String currentGroup = '';
        Map<String, String> notesByGroup = {};

        if (results.isEmpty) {
          reportText.writeln('\n✅ ممتاز! جميع المهارات المقيّمة "يستطيع".');
        }

        for (var res in results) {
          if (res['skill_group'] != currentGroup) {
            currentGroup = res['skill_group'];
            reportText.writeln('\n- مجموعة: $currentGroup');
          }
          reportText.writeln(
            '  - ${res['skill_description']}: ${res['score']}',
          );
          
          if (res['clinical_note'] != null && res['clinical_note'].isNotEmpty) {
            notesByGroup[currentGroup] = res['clinical_note'];
          }
        }
        
        if (notesByGroup.isNotEmpty) {
          reportText.writeln('\nملحوظات سريرية (Skills):');
          notesByGroup.forEach((group, note) {
            reportText.writeln('- $group: $note');
          });
        }
        break;
    }

    reportText.writeln('\n--- نهاية التقرير ---');
    return reportText.toString();
  }


  void _generateAndShareText(String reportString) {
    Share.share(reportString);
  }

  Future<void> _generateAndSharePdf(Uint8List pdfBytes) async {
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'OT_Report_${widget.patient.fullName}_${widget.assessmentId}.pdf',
    );
  }

  Future<void> _generateAndShareFile(BuildContext context, String reportString) async {
     try {
      final Directory tempDir = await getTemporaryDirectory();
      final String filePath = '${tempDir.path}/OT_Report_${widget.assessmentId}.txt';
      final File reportFile = File(filePath);
      await reportFile.writeAsString(reportString);

      final xFile = XFile(filePath);
      await Share.shareXFiles(
        [xFile], 
        text: 'ملف تقرير نصي لـ: ${widget.patient.fullName}',
      );

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل إنشاء ملف TXT: $e')),
        );
      }
    }
  }

  void _navigateToPdfPreview(BuildContext context, Uint8List pdfBytes) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PdfPreviewScreen(
          pdfData: pdfBytes,
          patientName: widget.patient.fullName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('التقرير النهائي لـ: ${widget.patient.fullName}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (widget.cameFromAssessmentFlow) {
              Navigator.of(context).pop(); 
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pop(); 
            }
          },
        ),
      ),
      body: FutureBuilder<_ReportData>(
        future: _reportDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('جارٍ إعداد التقرير...'),
                ],
              ),
            );
          }
          
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'حدث خطأ أثناء إعداد التقرير:\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          if (snapshot.hasData) {
            final reportData = snapshot.data!;
            
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  
                  Card(
                    elevation: 2,
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ملخص التقرير (للمراجعة السريعة)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              fontSize: 16,
                              color: Colors.blue.shade800
                            ),
                          ),
                          const Divider(),
                          SizedBox(
                            height: 200, 
                            child: SingleChildScrollView( 
                              child: Text(
                                reportData.reportString,
                                style: const TextStyle(
                                  fontFamilyFallback: ['NotoColorEmoji'],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  const Text('1. المعاينة الرسمية (PDF)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Divider(),
                  ElevatedButton.icon(
                    onPressed: () => _navigateToPdfPreview(context, reportData.pdfBytes),
                    icon: const Icon(Icons.find_in_page_outlined),
                    label: const Text('📄 فتح المعاينة قبل المشاركة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                  const SizedBox(height: 30),

                  const Text('2. المشاركة السريعة (نص)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Divider(),
                  ElevatedButton.icon(
                    onPressed: () => _generateAndShareText(reportData.reportString), 
                    icon: const Icon(Icons.share),
                    label: const Text('مشاركة النص (واتساب، تليجرام، إلخ)'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                  const SizedBox(height: 30),

                  const Text('3. المشاركة الرسمية (PDF)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Divider(),
                  ElevatedButton.icon(
                    onPressed: () => _generateAndSharePdf(reportData.pdfBytes),
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                    label: const Text('حفظ أو مشاركة كـ PDF', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                  const SizedBox(height: 30),

                  const Text('4. الأرشفة والتعديل (ملف)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Divider(),
                  ElevatedButton.icon(
                    onPressed: () => _generateAndShareFile(context, reportData.reportString), 
                    icon: const Icon(Icons.edit_document, color: Colors.black),
                    label: const Text('حفظ كملف نصي (TXT)', style: TextStyle(color: Colors.black)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ],
              ),
            );
          }
          
          return const Center(child: Text('حدث خطأ غير متوقع.'));
        },
      ),
    );
  }
}