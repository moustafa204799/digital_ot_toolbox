import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/patient.dart';
import 'report_generation_screen.dart'; 

class SkillsAssessmentScreen extends StatefulWidget {
  final Patient patient;
  const SkillsAssessmentScreen({super.key, required this.patient});

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
    final today = DateTime.now();
    return (today.difference(birthDate).inDays / 30).round();
  }

  @override
  void initState() {
    super.initState();
    _skillsFuture = DatabaseHelper.instance.getSkillsByAge(_patientAgeInMonths);
  }

  // ----------------------------------------------------
  // دالة الحفظ (كما هي)
  // ----------------------------------------------------
  Future<void> _saveAssessment(String status) async {
    List<Map<String, dynamic>> resultsToSave = [];
    
    _skillScores.forEach((skillId, score) {
      if (score != null) {
        String groupName = _findGroupNameBySkillId(skillId);
        resultsToSave.add({
          'skill_id': skillId,
          'score': score, 
          'clinical_note': _clinicalNotes[groupName],
        });
      }
    });

    if (resultsToSave.isEmpty && status == 'Completed') {
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('الرجاء تقييم مهارة واحدة على الأقل قبل الإنهاء.')),
          );
       }
       return;
    }

    try {
      final int assessmentId = await DatabaseHelper.instance.saveSkillsAssessment(
        patientId: widget.patient.patientId!,
        status: status, 
        results: resultsToSave,
      );
      
      if (status == 'Completed') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('✅ تم حفظ التقييم! جارٍ إعداد التقرير...')),
          );
          Navigator.of(context).pushReplacement( 
            MaterialPageRoute(
              builder: (context) => ReportGenerationScreen(
                assessmentId: assessmentId,
                patient: widget.patient,
                cameFromAssessmentFlow: true,
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🕓 تم حفظ التقييم كمسودة.')),
          );
          Navigator.of(context).pop(); 
          Navigator.of(context).pop();
        }
      }
      
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الحفظ: $e')),
        );
      }
    }
  }

  String _findGroupNameBySkillId(int skillId) {
    for (var entry in _groupedSkillsCache.entries) {
      if (entry.value.any((skill) => skill['skill_id'] == skillId)) {
        return entry.key;
      }
    }
    return '';
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('تقييم المهارات الدقيقة لـ: ${widget.patient.fullName}'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _skillsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('خطأ: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('لا توجد مهارات متاحة لعمر هذا المريض.'));
          }

          final skills = snapshot.data!;
          // 🆕 (✅ تعديل) دالة التجميع ستعمل الآن حسب "نوع المهارة"
          _groupedSkillsCache = _groupSkills(skills); 

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: _groupedSkillsCache.entries.map((entry) {
                      final groupName = entry.key;
                      final groupSkills = entry.value;
                      return _buildSkillGroup(groupName, groupSkills);
                    }).toList(),
                  ),
                ),
              ),
              
              _buildSaveButtons(),
            ],
          );
        },
      ),
    );
  }

  // 🆕 (تعديل) هذه الدالة الآن ستقوم بالتجميع حسب "نوع المهارة"
  Map<String, List<Map<String, dynamic>>> _groupSkills(List<Map<String, dynamic>> skills) {
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var skill in skills) {
      final group = skill['skill_group'] as String;
      if (!grouped.containsKey(group)) {
        grouped[group] = [];
      }
      grouped[group]!.add(skill);
    }
    return grouped;
  }

  // 🆕 (تعديل) هذا هو التصميم الجديد الأنظف
  Widget _buildSkillGroup(String groupName, List<Map<String, dynamic>> groupSkills) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      child: ExpansionTile(
        title: Text(
          groupName, // (مثل: "مهارات ما قبل الكتابة")
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        subtitle: Text('لديك ${groupSkills.length} مهارة في هذه المجموعة'),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Column(
              children: [
                const Divider(thickness: 1),
                
                ...groupSkills.map((skill) {
                  final skillId = skill['skill_id'] as int;
                  return ListTile(
                    title: Text(skill['skill_description']),
                    // 🆕 (تعديل) عرض العمر بجانب المهارة
                    subtitle: Text('العمر المناسب: ${skill['min_age_months']} شهر'),
                    
                    trailing: DropdownButton<String>(
                      value: _skillScores[skillId],
                      hint: const Text('التقييم'),
                      items: const [
                        DropdownMenuItem(value: 'يستطيع', child: Text('يستطيع ✅', style: TextStyle(color: Colors.green))),
                        DropdownMenuItem(value: 'بمساعدة', child: Text('بمساعدة 🤝', style: TextStyle(color: Colors.orange))),
                        DropdownMenuItem(value: 'لا يستطيع', child: Text('لا يستطيع ❌', style: TextStyle(color: Colors.red))),
                      ],
                      onChanged: (String? newValue) {
                        setState(() {
                          _skillScores[skillId] = newValue;
                        });
                      },
                    ),
                  );
                }),
                
                const Divider(height: 20),
                
                ExpansionTile(
                  title: const Text('📝 ملحوظات سريرية للمجموعة', style: TextStyle(color: Colors.grey)),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextFormField(
                        initialValue: _clinicalNotes[groupName],
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'أضف ملاحظات محددة حول جودة الحركة/الأداء هنا...',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          _clinicalNotes[groupName] = value;
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButtons() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(77), 
            spreadRadius: 2,
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _saveAssessment('Draft'),
              icon: const Icon(Icons.drafts, color: Colors.white),
              label: const Text('حفظ كمسودة 🕓', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _saveAssessment('Completed'),
              icon: const Icon(Icons.check_circle, color: Colors.white),
              label: const Text('إنهاء وحفظ التقرير ✅', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}