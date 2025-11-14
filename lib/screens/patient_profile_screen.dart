import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'package:printing/printing.dart';

import '../models/patient.dart';
import '../database/database_helper.dart';
import '../helpers/pdf_summary_generator.dart';

import 'add_assessment_screen.dart';
import 'report_generation_screen.dart';
import 'schedule_appointment_screen.dart'; 
import '../widgets/progress_chart.dart'; 
// 🆕 استيراد شاشات التقييم
import 'rom_assessment_screen.dart';
import 'grip_assessment_screen.dart';
import 'skills_assessment_screen.dart';

class PatientProfileScreen extends StatefulWidget {
  final Patient patient;
  const PatientProfileScreen({super.key, required this.patient});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  late Future<List<Map<String, dynamic>>> _assessmentsFuture;
  late Patient _currentPatient;

  String? _selectedJoint;
  String? _selectedMotion;
  Future<List<Map<String, dynamic>>>? _chartDataFuture;

  final List<String> _joints = ['الكتف (Shoulder)', 'المرفق (Elbow)', 'الرسغ (Wrist)', 'الورك (Hip)', 'الركبة (Knee)'];
  final Map<String, List<String>> _motions = {
    'الكتف (Shoulder)': ['Flexion', 'Extension', 'Abduction', 'Adduction', 'Internal Rotation', 'External Rotation'],
    'المرفق (Elbow)': ['Flexion', 'Extension'],
    'الرسغ (Wrist)': ['Flexion', 'Extension', 'Ulnar Deviation', 'Radial Deviation'],
    'الورك (Hip)': ['Flexion', 'Extension', 'Abduction', 'Adduction'],
    'الركبة (Knee)': ['Flexion', 'Extension'],
  };

  @override
  void initState() {
    super.initState();
    _currentPatient = widget.patient;
    _loadAssessments();
    _selectedJoint = 'الكتف (Shoulder)';
    _selectedMotion = 'Flexion';
    _loadChartData();
  }

  void _loadAssessments() {
    final int safeId = _currentPatient.patientId ?? 0;
    setState(() {
      _assessmentsFuture = DatabaseHelper.instance.getAssessmentsForPatient(safeId);
    });
  }

  void _loadChartData() {
    if (_selectedJoint != null && _selectedMotion != null) {
      setState(() {
        _chartDataFuture = DatabaseHelper.instance.getRomProgress(
          patientId: _currentPatient.patientId ?? 0,
          jointName: _selectedJoint!,
          motionType: _selectedMotion!,
        );
      });
    }
  }

  Future<void> _generateAndShareSummary() async {
    try {
      showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
      final Uint8List pdfData = await PdfSummaryGenerator.generatePdfSummary(_currentPatient);
      if (mounted) Navigator.of(context).pop();
      await Printing.sharePdf(bytes: pdfData, filename: 'Summary_${_currentPatient.fullName}.pdf');
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل: $e')));
      }
    }
  }

  void _deleteAssessment(int id) {
     showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف التقييم'), content: const Text('هل أنت متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          TextButton(
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
            onPressed: () async {
              Navigator.pop(ctx);
              await DatabaseHelper.instance.deleteAssessment(id);
              if (mounted) { _loadAssessments(); _loadChartData(); }
            },
          )
        ],
      ),
    );
  }

  void _showEditPatientDialog() {
    // (كود التعديل - اختصاراً)
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('ملف المريض', style: TextStyle(fontSize: 20.sp)),
          bottom: TabBar(
            labelStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
            tabs: const [
              Tab(icon: Icon(Icons.history), text: 'السجل'),
              Tab(icon: Icon(Icons.show_chart), text: 'التقدم'),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.print_outlined, size: 26.w),
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
                  _buildProgressTab(),
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
      margin: EdgeInsets.all(8.w), 
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.w), 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _currentPatient.fullName,
                    style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.grey, size: 24.w),
                  onPressed: _showEditPatientDialog,
                ),
              ],
            ),
            Divider(height: 20.h),
            Text('العمر: ${_currentPatient.calculateAge()}', style: TextStyle(fontSize: 16.sp)),
            SizedBox(height: 8.h),
            Text('الجنس: ${_currentPatient.gender ?? 'غير محدد'}', style: TextStyle(fontSize: 16.sp)),
            SizedBox(height: 8.h),
            Text('التشخيص: ${_currentPatient.diagnosis ?? '-'}', style: TextStyle(fontSize: 16.sp)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddAssessmentScreen(patient: _currentPatient)));
                if(mounted) { _loadAssessments(); _loadChartData(); }
              },
              icon: Icon(Icons.rate_review, color: Colors.white, size: 20.w),
              label: Text('تقييم جديد', style: TextStyle(color: Colors.white, fontSize: 14.sp)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                padding: EdgeInsets.symmetric(vertical: 12.h),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ScheduleAppointmentScreen(patient: _currentPatient))),
              icon: Icon(Icons.calendar_month, color: Colors.blue, size: 20.w),
              label: Text('حجز موعد', style: TextStyle(color: Colors.blue, fontSize: 14.sp)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade50,
                padding: EdgeInsets.symmetric(vertical: 12.h),
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
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('لا توجد تقييمات سابقة', style: TextStyle(fontSize: 16.sp, color: Colors.grey)));
        }
        final assessments = snapshot.data!;
        return ListView.builder(
          itemCount: assessments.length,
          itemBuilder: (context, index) {
            final item = assessments[index];
            final bool isDraft = item['status'] == 'Draft';
            
            return Card(
              margin: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              child: ListTile(
                leading: Icon(
                  Icons.assignment, 
                  size: 28.w, 
                  color: isDraft ? Colors.orange : Colors.green
                ),
                title: Text(
                  '${item['assessment_type']} (${isDraft ? "مسودة" : "مكتمل"})', 
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)
                ),
                subtitle: Text(
                  DateFormat('yyyy-MM-dd hh:mm a', 'ar').format(DateTime.parse(item['date_created'])), 
                  style: TextStyle(fontSize: 12.sp)
                ),
                trailing: IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red, size: 24.w),
                  onPressed: () => _deleteAssessment(item['assessment_id']),
                ),
                onTap: () async {
                  // 🆕 منطق التوجيه الجديد
                  if (isDraft) {
                    // توجيه للتعديل
                    if (item['assessment_type'] == 'ROM') {
                       await Navigator.push(context, MaterialPageRoute(builder: (_) => ROMAssessmentScreen(patient: _currentPatient, assessmentId: item['assessment_id'])));
                    } else if (item['assessment_type'] == 'Grip') {
                       await Navigator.push(context, MaterialPageRoute(builder: (_) => GripAssessmentScreen(patient: _currentPatient, assessmentId: item['assessment_id'])));
                    } else if (item['assessment_type'] == 'Skills') {
                       await Navigator.push(context, MaterialPageRoute(builder: (_) => SkillsAssessmentScreen(patient: _currentPatient, assessmentId: item['assessment_id'])));
                    }
                  } else {
                    // توجيه للتقرير
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => ReportGenerationScreen(assessmentId: item['assessment_id'], patient: _currentPatient, cameFromAssessmentFlow: false)));
                  }
                  if(mounted) _loadAssessments();
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProgressTab() {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          Text('تتبع ROM', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedJoint,
                  decoration: InputDecoration(labelText: 'المفصل', contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h), border: const OutlineInputBorder()),
                  items: _joints.map((j) => DropdownMenuItem(value: j, child: Text(j, style: TextStyle(fontSize: 12.sp)))).toList(),
                  onChanged: (v) => setState(() { _selectedJoint = v; _selectedMotion = _motions[v]!.first; _loadChartData(); }),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedMotion,
                  decoration: InputDecoration(labelText: 'الحركة', contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h), border: const OutlineInputBorder()),
                  items: _selectedJoint == null ? [] : _motions[_selectedJoint]!.map((m) => DropdownMenuItem(value: m, child: Text(m, style: TextStyle(fontSize: 12.sp)))).toList(),
                  onChanged: (v) => setState(() { _selectedMotion = v; _loadChartData(); }),
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          Expanded(
            child: _chartDataFuture == null
                ? Center(child: Text('اختر البيانات', style: TextStyle(fontSize: 14.sp)))
                : FutureBuilder(
                    future: _chartDataFuture,
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                        return SingleChildScrollView(child: ProgressChart(data: snapshot.data!, title: '$_selectedJoint'));
                      }
                      return Center(child: Text('لا توجد بيانات', style: TextStyle(fontSize: 14.sp)));
                    },
                  ),
          ),
        ],
      ),
    );
  }
}