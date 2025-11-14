import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../database/database_helper.dart';
import '../models/patient.dart';
import 'add_patient_screen.dart';
import 'patient_list_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _totalPatients = 0;
  Patient? _lastPatient;
  List<Map<String, dynamic>> _scheduledAppointments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    final total = await DatabaseHelper.instance.getTotalPatientsCount();
    final last = await DatabaseHelper.instance.getLastUpdatedPatient();
    final appointments = await DatabaseHelper.instance.getScheduledAppointmentsToday();

    if (mounted) {
      setState(() {
        _totalPatients = total;
        _lastPatient = last;
        _scheduledAppointments = appointments;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'لوحة التحكم',
          style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings, size: 28.w),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              ).then((_) => _loadDashboardData());
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // بطاقة الترحيب والإحصائيات (مع دعم الوضع الداكن)
                  _buildSummaryCard(),
                  SizedBox(height: 20.h),
                  
                  // قسم المواعيد
                  Text(
                    'مواعيد اليوم 📅',
                    style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10.h),
                  _buildAppointmentsList(),
                  SizedBox(height: 20.h),

                  // أزرار الإجراءات السريعة
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          context,
                          icon: Icons.person_add,
                          label: 'مريض جديد',
                          color: Colors.teal,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => const AddPatientScreen()),
                            ).then((_) => _loadDashboardData());
                          },
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _buildActionButton(
                          context,
                          icon: Icons.list_alt,
                          label: 'قائمة المرضى',
                          color: Colors.indigo,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => const PatientListScreen()),
                            ).then((_) => _loadDashboardData());
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  // ✅ التعديل: جعل ألوان البطاقة والنصوص متغيرة حسب الثيم
  Widget _buildSummaryCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // ألوان متكيفة
    final cardColor = isDark ? Colors.grey[800] : Colors.blue.shade50;
    final textColor = isDark ? Colors.white : Colors.blue.shade900;
    final labelColor = isDark ? Colors.grey[300] : Colors.grey.shade700;
    final dividerColor = isDark ? Colors.grey[600] : Colors.grey.shade300;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
      color: cardColor, 
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem(
                  'إجمالي المرضى', 
                  '$_totalPatients', 
                  Icons.groups, 
                  textColor, 
                  labelColor!
                ),
                Container(height: 40.h, width: 1, color: dividerColor),
                _buildStatItem(
                  'آخر نشاط', 
                  _lastPatient != null ? _lastPatient!.fullName.split(' ').first : '-', 
                  Icons.history,
                  textColor,
                  labelColor
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color textColor, Color labelColor) {
    return Column(
      children: [
        Icon(icon, size: 30.w, color: Colors.blue),
        SizedBox(height: 8.h),
        Text(
          value, 
          style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold, color: textColor),
        ),
        Text(
          label, 
          style: TextStyle(fontSize: 14.sp, color: labelColor),
        ),
      ],
    );
  }

  Widget _buildAppointmentsList() {
    if (_scheduledAppointments.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Center(
            child: Text(
              'لا توجد مواعيد مسجلة لليوم.', 
              style: TextStyle(fontSize: 16.sp, color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _scheduledAppointments.length,
      itemBuilder: (context, index) {
        final appt = _scheduledAppointments[index];
        final time = DateTime.parse(appt['appointment_date']).toString().substring(11, 16);
        
        return Card(
          margin: EdgeInsets.only(bottom: 8.h),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange.shade100,
              child: Icon(Icons.access_time, color: Colors.orange, size: 20.w),
            ),
            title: Text(
              appt['full_name'], 
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'الساعة: $time', 
              style: TextStyle(fontSize: 14.sp),
            ),
            trailing: Icon(Icons.arrow_forward_ios, size: 16.w, color: Colors.grey),
          ),
        );
      },
    );
  }

  Widget _buildActionButton(BuildContext context, {required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: EdgeInsets.symmetric(vertical: 16.h),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32.w, color: Colors.white),
          SizedBox(height: 8.h),
          Text(
            label, 
            style: TextStyle(fontSize: 16.sp, color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}