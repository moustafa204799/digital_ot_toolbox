import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // 🆕
import '../models/patient.dart'; 
import 'rom_assessment_screen.dart'; 
import 'grip_assessment_screen.dart'; 
import 'skills_assessment_screen.dart'; 

class AddAssessmentScreen extends StatelessWidget {
  final Patient patient;
  const AddAssessmentScreen({super.key, required this.patient});

  @override
  Widget build(BuildContext context) {
    // التحقق من الوضع الداكن
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.grey[800] : Colors.blue.shade50;
    final iconColor = isDark ? Colors.blue.shade200 : Colors.blue;

    return Scaffold(
      appBar: AppBar(
        title: Text('بدء تقييم جديد', style: TextStyle(fontSize: 20.sp)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w), // 🆕
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // بيانات المريض
            Card(
              elevation: 2,
              color: cardColor, // 🆕 لون متجاوب
              margin: EdgeInsets.only(bottom: 20.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              child: ListTile(
                leading: Icon(Icons.person, color: iconColor, size: 32.w),
                title: Text(patient.fullName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.sp)),
                subtitle: Text(
                  'العمر: ${patient.calculateAge()} | التشخيص: ${patient.diagnosis ?? 'لا يوجد'}',
                  style: TextStyle(fontSize: 14.sp),
                ),
              ),
            ),
            
            Text(
              'اختر نوع التقييم:',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600),
            ),
            Divider(thickness: 2, height: 20.h),

            // 1. ROM
            _buildAssessmentOption(
              context,
              icon: Icons.accessibility_new,
              title: 'تقييم مدى الحركة (ROM)',
              subtitle: 'قياس الزوايا والمجالات الحركية للمفاصل.',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => ROMAssessmentScreen(patient: patient)),
                );
              },
            ),

            // 2. Grip
            _buildAssessmentOption(
              context,
              icon: Icons.fitness_center,
              title: 'تقييم قوة القبضة',
              subtitle: 'التقييم النوعي للقبضات (قوية، خطافية...).',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => GripAssessmentScreen(patient: patient)),
                );
              },
            ),

            // 3. Skills
            _buildAssessmentOption(
              context,
              icon: Icons.gesture,
              title: 'تقييم المهارات الدقيقة',
              subtitle: 'تقييم مهارات الإمساك، الكتابة، والتآزر.',
              onTap: () {
                 Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => SkillsAssessmentScreen(patient: patient)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssessmentOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3,
      margin: EdgeInsets.symmetric(vertical: 8.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          radius: 25.r,
          child: Icon(icon, size: 28.w, color: Theme.of(context).primaryColor),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp)),
        subtitle: Padding(
          padding: EdgeInsets.only(top: 4.h),
          child: Text(subtitle, style: TextStyle(fontSize: 12.sp)),
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16.w),
        onTap: onTap,
      ),
    );
  }
}