import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import '../models/patient.dart'; 
import 'add_assessment_screen.dart'; 
import '../database/database_helper.dart'; 
import 'report_generation_screen.dart'; 
import 'dart:typed_data'; 
import 'package:printing/printing.dart'; 
import '../helpers/pdf_summary_generator.dart'; 

class PatientProfileScreen extends StatefulWidget {
  final Patient patient;
  const PatientProfileScreen({super.key, required this.patient});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  
  late Future<List<Map<String, dynamic>>> _assessmentsFuture;

  @override
  void initState() {
    super.initState();
    _loadAssessments();
  }

  void _loadAssessments() {
    setState(() {
      _assessmentsFuture = DatabaseHelper.instance.getAssessmentsForPatient(widget.patient.patientId!);
    });
  }

  Color _getStatusColor(String status) {
    if (status.toLowerCase() == 'completed') {
      return Colors.green; 
    } else if (status.toLowerCase() == 'draft') {
      return Colors.orange; 
    }
    return Colors.grey;
  }

  IconData _getAssessmentIcon(String type) {
    switch (type) {
      case 'ROM':
        return Icons.accessibility_new;
      case 'Grip':
        return Icons.fitness_center;
      case 'Skills':
        return Icons.gesture;
      default:
        return Icons.article;
    }
  }

  void _navigateToReport(int assessmentId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => ReportGenerationScreen(
        assessmentId: assessmentId,
        patient: widget.patient,
        cameFromAssessmentFlow: false, // 🆕 (✅ تعديل)
      )),
    ).then((_) {
      _loadAssessments();
    });
  }
  
  void _deleteAssessment(int assessmentId) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) { 
        return AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: const Text('هل أنت متأكد من رغبتك في حذف هذا التقييم؟ سيتم حذف نتائجه بشكل نهائي.'),
          actions: <Widget>[
            TextButton(
              child: const Text('إلغاء'),
              onPressed: () {
                Navigator.of(ctx).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('حذف'),
              onPressed: () async {
                await DatabaseHelper.instance.deleteAssessment(assessmentId);
                
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop(); 
                
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم حذف التقييم.')),
                );
                
                _loadAssessments();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _generateAndShareSummary() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final Uint8List pdfData = await PdfSummaryGenerator.generatePdfSummary(
        widget.patient,
      );

      if (context.mounted) {
        Navigator.of(context).pop(); 
      }

      await Printing.sharePdf(
        bytes: pdfData,
        filename: 'Summary_Report_${widget.patient.fullName}.pdf',
      );

    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل إنشاء ملخص PDF: $e')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, 
      child: Scaffold(
        appBar: AppBar(
          title: Text('ملف المريض: ${widget.patient.fullName}'), 
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.history), text: 'سجل التقييمات'),
              Tab(icon: Icon(Icons.show_chart), text: 'تتبع التقدم'),
            ],
          ),
          actions: [
            IconButton(
              // 🆕 (✅ هذا هو التعديل) تكبير الأيقونة
              icon: const Icon(Icons.print_outlined, size: 28), // يمكنك تغيير الحجم 28 إلى أي قيمة مناسبة
              tooltip: 'طباعة ملخص آخر التقييمات',
              onPressed: _generateAndShareSummary,
            ),
          ],
        ),
        body: Column(
          children: [
            _buildPatientDataCard(context),
            _buildActionButtons(context),
            Expanded(
              child: TabBarView(
                children: [
                  _buildAssessmentsList(),
                  const Center(child: Text('تتبع التقدم (سيتم عرض الرسوم البيانية هنا)')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPatientDataCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.patient.fullName, 
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            const Divider(),
            
            Text(
              'العمر: ${widget.patient.calculateAge()}', 
              style: const TextStyle(fontSize: 16)
            ),
            const SizedBox(height: 8),

            Text(
              'الجنس: ${widget.patient.gender ?? 'غير محدد'}', 
              style: const TextStyle(fontSize: 16)
            ),
            const SizedBox(height: 8),

            Text(
              'التشخيص: ${widget.patient.diagnosis ?? 'لا يوجد تشخيص مسجل'}', 
              style: const TextStyle(fontSize: 16)
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => AddAssessmentScreen(patient: widget.patient)), 
                ).then((_) => _loadAssessments()); 
              },
              icon: const Icon(Icons.rate_review, color: Colors.white),
              label: const Text('ابدأ تقييم جديد', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo, 
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('سيتم تطوير وظيفة جدولة موعد لاحقاً.')),
                );
              },
              icon: const Icon(Icons.calendar_month, color: Colors.blue),
              label: const Text('جدولة موعد متابعة', style: TextStyle(color: Colors.blue)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade50,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssessmentsList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _assessmentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('خطأ في جلب السجل: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text(
              'لا يوجد تقييمات سابقة لهذا المريض.\nابدأ تقييماً جديداً!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        final assessments = snapshot.data!;

        return ListView.builder(
          itemCount: assessments.length,
          itemBuilder: (context, index) {
            final assessment = assessments[index];
            final status = assessment['status'];
            final type = assessment['assessment_type'];
            final date = DateTime.parse(assessment['date_created']);
            final statusColor = _getStatusColor(status);
            
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: Icon(_getAssessmentIcon(type), color: statusColor, size: 30),
                title: Text(
                  '$type (${status == 'Completed' ? 'مكتمل' : 'مسودة'})', 
                  style: TextStyle(fontWeight: FontWeight.bold, color: statusColor),
                ),
                subtitle: Text(
                  'تاريخ الإنشاء: ${DateFormat('d MMMM yyyy, hh:mm a', 'ar').format(date)}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deleteAssessment(assessment['assessment_id']),
                  tooltip: 'حذف التقييم',
                ),
                onTap: () {
                  _navigateToReport(assessment['assessment_id']);
                },
              ),
            );
          },
        );
      },
    );
  }
}