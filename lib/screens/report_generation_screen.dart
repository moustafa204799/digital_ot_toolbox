import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
    final Uint8List pdfBytes = await PdfReportGenerator.generatePdfReport(widget.assessmentId, widget.patient);
    return _ReportData(reportString, pdfBytes);
  }

  // بناء نص التقرير للمشاركة النصية
  Future<String> _buildReportString() async {
    final db = DatabaseHelper.instance;
    final OtSettings? settings = await db.getSettings();
    final String therapistName = settings?.otName ?? 'أخصائي العلاج الوظيفي';
    final assessment = await db.getAssessmentDetails(widget.assessmentId);
    
    if (assessment == null) return "خطأ في تحميل البيانات";

    final String assessmentDate = DateFormat('d MMMM yyyy', 'ar')
        .format(DateTime.parse(assessment['date_created']));
    
    return """
🩺 تقرير تقييم العلاج الوظيفي
====================
👤 المريض: ${widget.patient.fullName}
📅 التاريخ: $assessmentDate
👨‍⚕️ الأخصائي: $therapistName
نوع التقييم: ${assessment['assessment_type']}

(تم إنشاء هذا التقرير عبر تطبيق Digital OT Toolbox)
""";
  }

  void _generateAndShareText(String t) => Share.share(t);
  Future<void> _generateAndSharePdf(Uint8List b) async => await Printing.sharePdf(bytes: b, filename: 'Report.pdf');
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.grey[850] : Colors.blue.shade50;
    final titleColor = isDark ? Colors.blue[200] : Colors.blue.shade800;
    final textColor = isDark ? Colors.grey[300] : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: Text('التقرير النهائي', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (widget.cameFromAssessmentFlow) {
              Navigator.of(context)..pop()..pop()..pop();
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
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
             return Center(child: Text('حدث خطأ: ${snapshot.error}'));
          }
          
          final data = snapshot.data!;
          return SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 2,
                  color: cardColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ملخص (للمعاينة السريعة)', 
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, color: titleColor)
                        ),
                        Divider(color: isDark ? Colors.grey : Colors.blue.shade200),
                        SizedBox(
                          height: 120.h,
                          child: SingleChildScrollView(
                            child: Text(
                              data.reportString, 
                              style: TextStyle(fontSize: 14.sp, color: textColor, height: 1.5)
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 30.h),
                
                // الأزرار
                _buildBtn(context, 'معاينة PDF (التقرير الكامل)', Icons.visibility, Colors.blue, 
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => PdfPreviewScreen(pdfData: data.pdfBytes, patientName: widget.patient.fullName)))),
                SizedBox(height: 15.h),
                _buildBtn(context, 'مشاركة PDF', Icons.picture_as_pdf, Colors.red, 
                  () => _generateAndSharePdf(data.pdfBytes)),
                SizedBox(height: 15.h),
                _buildBtn(context, 'مشاركة نص', Icons.share, Colors.green, 
                  () => _generateAndShareText(data.reportString)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBtn(BuildContext context, String label, IconData icon, Color color, VoidCallback tap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: tap,
        icon: Icon(icon, color: Colors.white),
        label: Text(label, style: TextStyle(color: Colors.white, fontSize: 16.sp)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color, 
          padding: EdgeInsets.symmetric(vertical: 14.h),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
        ),
      ),
    );
  }
}