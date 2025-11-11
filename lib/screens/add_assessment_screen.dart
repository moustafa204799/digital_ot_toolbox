import 'package:flutter/material.dart';
import '../models/patient.dart'; 
// استيراد الشاشات الفعلية التي أنشأناها
import 'rom_assessment_screen.dart'; 
import 'grip_assessment_screen.dart'; 
import 'skills_assessment_screen.dart'; 

class AddAssessmentScreen extends StatelessWidget {
  final Patient patient;
  const AddAssessmentScreen({super.key, required this.patient});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('بدء تقييم لـ: ${patient.fullName}'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // بيانات المريض الأساسية كبطاقة سريعة
            Card(
              elevation: 2,
              color: Colors.blue.shade50,
              margin: const EdgeInsets.only(bottom: 20),
              child: ListTile(
                leading: const Icon(Icons.person, color: Colors.blue),
                title: Text(patient.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('العمر: ${patient.calculateAge()} | التشخيص: ${patient.diagnosis ?? 'لا يوجد'}'),
              ),
            ),
            
            const Text(
              'اختر نوع التقييم الذي تريد البدء به:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const Divider(thickness: 2),

            // 1. تقييم مدى الحركة (ROM)
            _buildAssessmentOption(
              context,
              icon: Icons.accessibility_new,
              title: 'تقييم مدى الحركة (ROM)',
              subtitle: 'قياس الزوايا والمجالات الحركية للمفاصل.',
              // الانتقال إلى شاشة ROM
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => ROMAssessmentScreen(patient: patient)),
                );
              },
            ),

            // 2. تقييم قوة القبضة (Grip Strength)
            _buildAssessmentOption(
              context,
              icon: Icons.fitness_center,
              title: 'تقييم قوة القبضة',
              subtitle: 'التقييم النوعي للقبضات (قوية، خطافية، كروية...).',
              // الانتقال إلى شاشة Grip
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => GripAssessmentScreen(patient: patient)),
                );
              },
            ),

            // 3. تقييم المهارات الدقيقة (Fine Motor Skills)
            _buildAssessmentOption(
              context,
              icon: Icons.gesture,
              title: 'تقييم المهارات الدقيقة',
              subtitle: 'تقييم مهارات الإمساك، الكتابة، والتآزر البصري الحركي.',
              // الانتقال إلى شاشة Skills
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

  // ويدجت مساعدة لبناء خيار التقييم
  Widget _buildAssessmentOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, size: 40, color: Theme.of(context).primaryColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward),
        onTap: onTap,
      ),
    );
  }
}