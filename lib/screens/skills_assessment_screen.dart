import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../database/database_helper.dart';
import '../models/patient.dart';
import 'report_generation_screen.dart'; 

class SkillsAssessmentScreen extends StatefulWidget {
  final Patient patient;
  final int? assessmentId; // 🆕 معامل لاستكمال المسودة

  const SkillsAssessmentScreen({super.key, required this.patient, this.assessmentId});

  @override
  State<SkillsAssessmentScreen> createState() => _SkillsAssessmentScreenState();
}

class _SkillsAssessmentScreenState extends State<SkillsAssessmentScreen> {
  Future<List<Map<String, dynamic>>>? _skillsFuture;
  
  // لتخزين النتائج: المفتاح هو skill_id والقيمة هي التقييم (String)
  final Map<int, String?> _skillScores = {}; 
  
  // لتخزين الملاحظات: المفتاح هو اسم المجموعة (String) والقيمة هي الملاحظة
  final Map<String, String?> _clinicalNotes = {};
  
  // لتخزين المهارات بعد تجميعها (للاستخدام المتكرر)
  Map<String, List<Map<String, dynamic>>> _groupedSkillsCache = {};

  // حساب العمر بالأشهر لجلب المهارات المناسبة
  int get _patientAgeInMonths {
    final birthDate = DateTime.parse(widget.patient.dob);
    return (DateTime.now().difference(birthDate).inDays / 30).round();
  }

  @override
  void initState() {
    super.initState();
    // تحميل المهارات المناسبة لعمر المريض
    _skillsFuture = DatabaseHelper.instance.getSkillsByAge(_patientAgeInMonths);
    
    // 🆕 إذا كان هناك معرف تقييم (مسودة)، نقوم تحميل البيانات المحفوظة
    if (widget.assessmentId != null) {
      _loadDraftData(); 
    }
  }

  // 🆕 دالة تحميل بيانات المسودة
  Future<void> _loadDraftData() async {
    // ننتظر حتى يتم تحميل المهارات الأساسية أولاً لضمان وجود الـ IDs
    await _skillsFuture;
    
    // جلب النتائج المحفوظة (شاملة الكل) باستخدام الدالة الجديدة في DatabaseHelper
    final results = await DatabaseHelper.instance.getAllSkillsResultsForEdit(widget.assessmentId!);
    
    if (mounted) {
      setState(() {
        for (var row in results) {
          if (row['skill_id'] != null) {
             // تحميل النتيجة
             _skillScores[row['skill_id']] = row['score'];
             
             // تحميل الملاحظة (الملاحظة محفوظة لكل مهارة، لكننا نعرضها للمجموعة)
             String group = row['skill_group'];
             if (row['clinical_note'] != null) {
               _clinicalNotes[group] = row['clinical_note'];
             }
          }
        }
      });
    }
  }

  // دالة الحفظ (مسودة أو نهائي)
  Future<void> _saveAssessment(String status) async {
    List<Map<String, dynamic>> resultsToSave = [];
    
    // تجميع النتائج المدخلة
    _skillScores.forEach((skillId, score) {
      if (score != null) {
        String groupName = _findGroupNameBySkillId(skillId);
        resultsToSave.add({
          'skill_id': skillId, 
          'score': score, 
          'clinical_note': _clinicalNotes[groupName], // حفظ ملاحظة المجموعة مع كل مهارة فيها
        });
      }
    });

    // التحقق من الإدخال عند الإنهاء
    if (resultsToSave.isEmpty && status == 'Completed') {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء تقييم مهارة واحدة على الأقل.')));
       return;
    }

    try {
      // حفظ في قاعدة البيانات (تحديث أو جديد)
      final int id = await DatabaseHelper.instance.saveSkillsAssessment(
        patientId: widget.patient.patientId!, 
        status: status, 
        results: resultsToSave,
        existingAssessmentId: widget.assessmentId, // 🆕 تمرير المعرف للتحديث
      );
      
      if (!mounted) return;
      
      if (status == 'Completed') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم الحفظ!')));
        // الانتقال للتقرير
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => ReportGenerationScreen(assessmentId: id, patient: widget.patient, cameFromAssessmentFlow: true),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🕓 تم حفظ المسودة.')));
        Navigator.of(context)..pop()..pop(); // العودة لملف المريض
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  // دالة مساعدة لمعرفة اسم المجموعة من رقم المهارة
  String _findGroupNameBySkillId(int skillId) {
    for (var entry in _groupedSkillsCache.entries) {
      if (entry.value.any((skill) => skill['skill_id'] == skillId)) return entry.key;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('تقييم المهارات', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _skillsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.isEmpty) return Center(child: Text('لا توجد مهارات مسجلة لهذا العمر', style: TextStyle(fontSize: 16.sp)));

          final skills = snapshot.data!;
          _groupedSkillsCache = _groupSkills(skills); 

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.all(16.w),
                  children: _groupedSkillsCache.entries.map((entry) => _buildSkillGroup(entry.key, entry.value)).toList(),
                ),
              ),
              _buildSaveButtons(),
            ],
          );
        },
      ),
    );
  }

  // تجميع المهارات حسب الـ Group
  Map<String, List<Map<String, dynamic>>> _groupSkills(List<Map<String, dynamic>> skills) {
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var skill in skills) {
      final group = skill['skill_group'] as String;
      if (!grouped.containsKey(group)) grouped[group] = [];
      grouped[group]!.add(skill);
    }
    return grouped;
  }

  // بناء بطاقة مجموعة المهارات
  Widget _buildSkillGroup(String groupName, List<Map<String, dynamic>> groupSkills) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // ألوان متكيفة
    final textColor = isDark ? Colors.white : Colors.black87;
    final titleColor = isDark ? Colors.blueAccent : Colors.blue.shade800;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      elevation: 2,
      // لون البطاقة من الثيم
      color: Theme.of(context).cardTheme.color,
      child: ExpansionTile(
        title: Text(
          groupName, 
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: titleColor),
        ),
        children: [
          ...groupSkills.map((skill) {
            final skillId = skill['skill_id'] as int;
            return ListTile(
              title: Text(
                skill['skill_description'], 
                style: TextStyle(fontSize: 14.sp, color: textColor)
              ),
              subtitle: Text(
                'العمر: ${skill['min_age_months']} شهر', 
                style: TextStyle(fontSize: 12.sp, color: subtitleColor)
              ),
              trailing: DropdownButton<String>(
                value: _skillScores[skillId],
                hint: Text('التقييم', style: TextStyle(fontSize: 12.sp, color: textColor)),
                dropdownColor: isDark ? Colors.grey[800] : Colors.white,
                underline: Container(), // إزالة الخط السفلي الافتراضي
                items: [
                  DropdownMenuItem(value: 'يستطيع', child: Text('✅ يستطيع', style: TextStyle(color: isDark ? Colors.white : Colors.black))),
                  DropdownMenuItem(value: 'بمساعدة', child: Text('🤝 بمساعدة', style: TextStyle(color: isDark ? Colors.white : Colors.black))),
                  DropdownMenuItem(value: 'لا يستطيع', child: Text('❌ لا يستطيع', style: TextStyle(color: isDark ? Colors.white : Colors.black))),
                ],
                onChanged: (v) => setState(() => _skillScores[skillId] = v),
              ),
            );
          }),
          
          // حقل الملاحظات للمجموعة
          Padding(
            padding: EdgeInsets.all(8.w),
            child: TextFormField(
              controller: TextEditingController(text: _clinicalNotes[groupName]), // لعرض النص المحفوظ
              style: TextStyle(fontSize: 14.sp, color: textColor),
              decoration: InputDecoration(
                labelText: 'ملاحظات للمجموعة',
                labelStyle: TextStyle(color: subtitleColor),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                prefixIcon: const Icon(Icons.edit_note),
              ),
              onChanged: (v) => _clinicalNotes[groupName] = v,
            ),
          )
        ],
      ),
    );
  }

  // شريط الأزرار السفلي
  Widget _buildSaveButtons() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor, // لون الخلفية حسب الثيم
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 5.r, offset: const Offset(0, -2))
        ],
      ),
      child: Row(
        children: [
          // زر مسودة
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _saveAssessment('Draft'),
              icon: const Icon(Icons.save_as_outlined, color: Colors.white),
              label: Text('مسودة', style: TextStyle(color: Colors.white, fontSize: 14.sp)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, 
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          // زر إنهاء
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _saveAssessment('Completed'),
              icon: const Icon(Icons.check_circle_outline, color: Colors.white),
              label: Text('إنهاء', style: TextStyle(color: Colors.white, fontSize: 14.sp)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, 
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}