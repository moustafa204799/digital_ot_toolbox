import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../database/database_helper.dart';
import '../models/patient.dart';
import 'report_generation_screen.dart'; 

class SkillsAssessmentScreen extends StatefulWidget {
  final Patient patient;
  final int? assessmentId;

  const SkillsAssessmentScreen({super.key, required this.patient, this.assessmentId});

  @override
  State<SkillsAssessmentScreen> createState() => _SkillsAssessmentScreenState();
}

class _SkillsAssessmentScreenState extends State<SkillsAssessmentScreen> {
  Future<List<Map<String, dynamic>>>? _skillsFuture;
  final Map<int, String?> _skillScores = {}; 
  final Map<String, String?> _clinicalNotes = {};
  Map<String, List<Map<String, dynamic>>> _groupedSkillsCache = {};

  int get _patientAgeInMonths {
    final birthDate = DateTime.parse(widget.patient.dob);
    return (DateTime.now().difference(birthDate).inDays / 30).round();
  }

  @override
  void initState() {
    super.initState();
    _skillsFuture = DatabaseHelper.instance.getSkillsByAge(_patientAgeInMonths);
    
    // 🆕 تحميل البيانات إذا كانت مسودة
    if (widget.assessmentId != null) {
      _loadDraftData();
    }
  }

  Future<void> _loadDraftData() async {
    // ننتظر حتى يتم تحميل المهارات الأساسية أولاً
    await _skillsFuture;
    
    // جلب النتائج المحفوظة (شاملة الكل)
    final results = await DatabaseHelper.instance.getAllSkillsResultsForEdit(widget.assessmentId!);
    
    if (mounted) {
      setState(() {
        for (var row in results) {
          if (row['skill_id'] != null) {
             _skillScores[row['skill_id']] = row['score'];
             String group = row['skill_group'];
             if (row['clinical_note'] != null) {
               _clinicalNotes[group] = row['clinical_note'];
             }
          }
        }
      });
    }
  }

  Future<void> _saveAssessment(String status) async {
    List<Map<String, dynamic>> resultsToSave = [];
    _skillScores.forEach((skillId, score) {
      if (score != null) {
        String groupName = _findGroupNameBySkillId(skillId);
        resultsToSave.add({
          'skill_id': skillId, 'score': score, 'clinical_note': _clinicalNotes[groupName],
        });
      }
    });

    if (resultsToSave.isEmpty && status == 'Completed') {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء تقييم مهارة واحدة على الأقل.')));
       return;
    }

    try {
      final int id = await DatabaseHelper.instance.saveSkillsAssessment(
        patientId: widget.patient.patientId!, 
        status: status, 
        results: resultsToSave,
        existingAssessmentId: widget.assessmentId, // 🆕
      );
      if (!mounted) return;
      
      if (status == 'Completed') {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => ReportGenerationScreen(assessmentId: id, patient: widget.patient, cameFromAssessmentFlow: true),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🕓 تم حفظ المسودة.')));
        Navigator.of(context)..pop()..pop();
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  String _findGroupNameBySkillId(int skillId) {
    for (var entry in _groupedSkillsCache.entries) {
      if (entry.value.any((skill) => skill['skill_id'] == skillId)) return entry.key;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('تقييم المهارات', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold))),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _skillsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.isEmpty) return Center(child: Text('لا توجد مهارات لعمر هذا المريض', style: TextStyle(fontSize: 16.sp)));

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

  Map<String, List<Map<String, dynamic>>> _groupSkills(List<Map<String, dynamic>> skills) {
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var skill in skills) {
      final group = skill['skill_group'] as String;
      if (!grouped.containsKey(group)) grouped[group] = [];
      grouped[group]!.add(skill);
    }
    return grouped;
  }

  Widget _buildSkillGroup(String groupName, List<Map<String, dynamic>> groupSkills) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final titleColor = isDark ? Colors.blueAccent : Colors.blue.shade800;

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      elevation: 2,
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
                style: TextStyle(fontSize: 12.sp, color: Colors.grey)
              ),
              trailing: DropdownButton<String>(
                value: _skillScores[skillId],
                hint: Text('التقييم', style: TextStyle(fontSize: 12.sp, color: textColor)),
                dropdownColor: isDark ? Colors.grey[800] : Colors.white,
                underline: Container(),
                items: [
                  DropdownMenuItem(value: 'يستطيع', child: Text('✅ يستطيع', style: TextStyle(color: isDark ? Colors.white : Colors.black))),
                  DropdownMenuItem(value: 'بمساعدة', child: Text('🤝 بمساعدة', style: TextStyle(color: isDark ? Colors.white : Colors.black))),
                  DropdownMenuItem(value: 'لا يستطيع', child: Text('❌ لا يستطيع', style: TextStyle(color: isDark ? Colors.white : Colors.black))),
                ],
                onChanged: (v) => setState(() => _skillScores[skillId] = v),
              ),
            );
          }),
          Padding(
            padding: EdgeInsets.all(8.w),
            child: TextFormField(
              controller: TextEditingController(text: _clinicalNotes[groupName]),
              style: TextStyle(fontSize: 14.sp, color: textColor),
              decoration: InputDecoration(
                labelText: 'ملاحظات للمجموعة',
                labelStyle: TextStyle(color: isDark ? Colors.grey : Colors.black54),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
              ),
              onChanged: (v) => _clinicalNotes[groupName] = v,
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSaveButtons() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _saveAssessment('Draft'),
              icon: const Icon(Icons.save_as_outlined),
              label: const Text('مسودة'),
              style: OutlinedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14.h)),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _saveAssessment('Completed'),
              icon: const Icon(Icons.check),
              label: const Text('إنهاء وحفظ'),
              style: FilledButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14.h)),
            ),
          ),
        ],
      ),
    );
  }
}