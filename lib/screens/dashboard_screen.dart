import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../database/database_helper.dart';
import '../models/patient.dart';
import 'patient_list_screen.dart';
import 'add_patient_screen.dart';
import 'settings_screen.dart'; 
import 'patient_profile_screen.dart'; 
import 'report_generation_screen.dart'; 

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _patientsCount = 0;
  Patient? _lastPatient;
  List<Map<String, dynamic>> _scheduledAppointments = [];
  List<Map<String, dynamic>> _lastAssessments = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }
  
  Future<void> _loadDashboardData() async {
    final count = await DatabaseHelper.instance.getTotalPatientsCount();
    final lastPatient = await DatabaseHelper.instance.getLastUpdatedPatient();
    // ⬅️ (✅ تعديل...): تم تطبيق هذا الإصلاح في إجابتنا السابقة
    final appointments = await DatabaseHelper.instance.getScheduledAppointmentsToday(); 
    final assessments = await DatabaseHelper.instance.getLastAssessments(5); 

    if (mounted) { 
      setState(() {
        _patientsCount = count;
        _lastPatient = lastPatient;
        _scheduledAppointments = appointments;
        _lastAssessments = assessments;
      });
    }
  }

  Color _getStatusColor(String status) {
    if (status.toLowerCase() == 'completed') {
      return Colors.green; 
    } else if (status.toLowerCase() == 'draft') {
      return Colors.orange; 
    } else if (status.toLowerCase() == 'scheduled') {
      return Colors.blue; 
    }
    return Colors.grey;
  }
  
  // ⬅️ (✅ تعديل: تم تحويل الدالة إلى async/await)
  Future<void> _navigateToPatientProfile(int patientId) async {
    final patient = await DatabaseHelper.instance.getPatient(patientId);
    
    // التحقق من (mounted) أصبح في الأعلى لأمان أكثر
    if (!mounted) return; 

    if (patient != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => PatientProfileScreen(patient: patient)),
      );
      // يتم استدعاءها الآن بعد العودة من الشاشة
      _loadDashboardData(); 
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لم يتم العثور على ملف المريض.')),
      );
    }
  }
  
  void _navigateToReport(BuildContext context, Map<String, dynamic> assessmentData) async {
    final int patientId = assessmentData['patient_id'];
    final int assessmentId = assessmentData['assessment_id'];
    
    final patient = await DatabaseHelper.instance.getPatient(patientId);
    
    if (patient != null) {
      if (!context.mounted) return; 
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => ReportGenerationScreen(
          assessmentId: assessmentId,
          patient: patient,
          cameFromAssessmentFlow: false, 
        )),
      ).then((_) => _loadDashboardData()); 
    } else {
      if (!context.mounted) return; 
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لم يتم العثور على ملف المريض المرتبط بهذا التقييم.')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التحكم الرئيسية'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              ).then((_) => _loadDashboardData()); 
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData, 
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h), 
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildStatsSection(),
              SizedBox(height: 25.h), 
              _buildSmartShortcuts(context),
              SizedBox(height: 25.h), 
              _buildCoreButtons(context),
              SizedBox(height: 30.h), 
              Text('متابعة المهام', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)), 
              const Divider(),
              _buildScheduledAppointments(), 
              SizedBox(height: 20.h), 
              _buildLastAssessments(), 
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatCard(
          icon: Icons.people_alt, 
          label: 'إجمالي المرضى', 
          value: _patientsCount.toString(),
          color: Colors.indigo,
        ),
      ],
    );
  }

  Widget _buildStatCard({required IconData icon, required String label, required String value, required Color color}) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.w), 
        child: Column(
          children: [
            Icon(icon, color: color, size: 30.sp), 
            SizedBox(height: 5.h), 
            Text(value, style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold, color: color)), 
            Text(label, style: TextStyle(fontSize: 14.sp)), 
          ],
        ),
      ),
    );
  }

  Widget _buildSmartShortcuts(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: Icon(Icons.cached, color: Colors.blueGrey, size: 30.sp), 
          title: const Text('🔁 متابعة آخر مريض'),
          subtitle: Text(_lastPatient != null ? 'ملف: ${_lastPatient!.fullName}' : 'لا يوجد مرضى سابقون'),
          trailing: Icon(Icons.arrow_forward_ios, size: 16.sp), 
          onTap: _lastPatient != null 
              ? () => _navigateToPatientProfile(_lastPatient!.patientId!)
              : null,
          enabled: _lastPatient != null,
        ),
        const Divider(height: 0),
        ListTile(
          leading: Icon(Icons.flash_on, color: Colors.amber, size: 30.sp), 
          title: const Text('🧠 ابدأ تقييماً سريعاً'),
          subtitle: const Text('افتح شاشة اختيار نوع التقييم مباشرة'),
          trailing: Icon(Icons.arrow_forward_ios, size: 16.sp), 
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const PatientListScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCoreButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const PatientListScreen()),
              ).then((_) => _loadDashboardData());
            },
            icon: const Icon(Icons.list_alt, color: Colors.white),
            label: const Text('عرض قائمة المرضى', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              padding: EdgeInsets.symmetric(vertical: 15.h), 
            ),
          ),
        ),
        SizedBox(width: 10.w), 
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AddPatientScreen()),
              ).then((_) => _loadDashboardData());
            },
            icon: Icon(Icons.person_add, color: Colors.blue.shade900), 
            label: Text('إضافة مريض جديد', style: TextStyle(color: Colors.blue.shade900)), 
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade100,
              padding: EdgeInsets.symmetric(vertical: 15.h), 
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildScheduledAppointments() {
    if (_scheduledAppointments.isEmpty) {
      return const SizedBox();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_today, color: _getStatusColor('scheduled'), size: 20.sp), 
            SizedBox(width: 5.w), 
            const Text('التقييمات المجدولة اليوم', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          ],
        ),
        SizedBox(height: 8.h), 
        ..._scheduledAppointments.map((app) => ListTile(
              leading: Icon(Icons.circle, size: 10.sp, color: _getStatusColor('scheduled')), 
              title: Text(app['full_name'] ?? 'مريض غير معروف'),
              // ⬅️ (✅ تعديل...): تم تطبيق هذا الإصلاح في إجابتنا السابقة
              subtitle: Text('موعد في: ${DateFormat('hh:mm a', 'ar').format(DateTime.parse(app['appointment_date']))}'),
              onTap: () => _navigateToPatientProfile(app['patient_id']),
            )),
      ],
    );
  }

  Widget _buildLastAssessments() {
    if (_lastAssessments.isEmpty) {
      return const Center(child: Text('لا توجد تقييمات سابقة.', style: TextStyle(color: Colors.grey)));
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('آخر التقييمات التي تمت', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8.h), 
        ..._lastAssessments.map((assessment) {
          final statusColor = _getStatusColor(assessment['status']);
          final statusIcon = assessment['status'].toLowerCase() == 'completed' ? Icons.check_circle : Icons.edit;
          
          return ListTile(
            leading: Icon(statusIcon, color: statusColor),
            title: Text(assessment['full_name'] ?? 'مريض غير معروف'),
            subtitle: Text(
              // ⬅️ (✅ تعديل...): تم تطبيق هذا الإصلاح في إجابتنا السابقة
              '${assessment['assessment_type']} - ${assessment['status']} | ${DateFormat('MMM d, y', 'ar').format(DateTime.parse(assessment['date_created']))}',
            ),
            trailing: Icon(Icons.arrow_forward_ios, size: 16.sp, color: statusColor), 
            onTap: () => _navigateToReport(context, assessment),
          );
        }),
      ],
    );
  }
}