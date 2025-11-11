import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/patient.dart';
import 'report_generation_screen.dart'; 

class GripAssessmentScreen extends StatefulWidget {
  final Patient patient;
  const GripAssessmentScreen({super.key, required this.patient});

  @override
  State<GripAssessmentScreen> createState() => _GripAssessmentScreenState();
}

class _GripAssessmentScreenState extends State<GripAssessmentScreen> with SingleTickerProviderStateMixin {

  // -------------------------------------------------
  // 🆕 (✅ هذا هو التعديل)
  // -------------------------------------------------

  // 1. بيانات "نوع القبضة" مع الشرح + العمر
  final Map<String, String> _gripTypeOptions = {
    'Crude Ulnar-Palmar Grasp (قبضة راحة اليد على الزند) (4-5 أشهر)': 'الطفل يمسك باستخدام جانب اليد البعيد من الإبهام (جانب الزند)، والكف غالباً، والإبهام ليس مشارك بفعالية.',
    'Palmar Grasp (قبضة راحة اليد كاملة) (5-6 أشهر)': 'الطفل يمسك بالكف بأكمله تقريباً، الأصابع تغلق حول الشيء، لكن الإبهام مازال ليس في موقع فعال ليمسك معه.',
    'Radial-Palmar Grasp (قبضة راحة-شعاعية) (6-7 أشهر)': 'يبدأ الطفل يشرك الإبهام وجانب الإبهام في القبضة، يمسك باتجاه جانب الإبهام من الكف، تحسّن في التحكم.',
    'Raking Grasp (قبضة كنس-جرف) (7-8 أشهر)': 'الطفل يحاول يجمع أو “يكنس” الأجسام نحو الكف بأصابعه، الإمساك أقل دقة ويستخدم الأصابع كلها تقريباً.',
    'Radial-Digital / Inferior Pincer Grasp (قبضة شعاعية-رقمية / إصبعية منخفضة) (8-10 أشهر)': 'الطفل يستخدم الإبهام والسبابة لكن غالباً باستخدام وسائد الأصابع (pads) وليس طرفيها، يمسك عناصر أكثر دقة.',
    'Pincer Grasp – Tip to Tip (قبضة إصبعية كاملة) (10-12 شهر)': 'الطفل يمسك باستخدام طرف الإبهام وطرف السبابة لالتقاط شيء صغير — قبضة دقيقة.',
    'Palmar Supinate Grasp (قبضة راحة-موجهة للأعلى) (1 - 1.5 سنة)': 'الطفل يمسك أداة (مثل قلم) بقبضة أولية: كفه موجهة للأعلى أو للأمام، القبضة ليست ثابتة بعد.',
    'Digital Pronate Grasp (قبضة رقمية موجهة للأسفل) (2-3 سنوات)': 'الطفل يمسك بأصابع أكثر مشاركة، كفه موجهة للأسفل، لكن ما زالت حركة المعصم/الذراع تظهر.',
    'Static Tripod/Quadrupod Grasp (قبضة ثلاثية/رباعية ثابتة) (3-4 سنوات)': 'الطفل يمسك قلم/أداة بثلاث أو أربع أصابع، لكن الحركة داخل الأصابع قليلة، المعصم/الذراع قد تتحرك أكثر من اللازم.',
    'Dynamic Tripod/Quadrupod Grasp (قبضة ثلاثية/رباعية ديناميكية) (4-6 سنوات)': 'القبضة المثالية تقريباً: الإبهام والسبابة والوسطى يتحكّموا بالأداة، الحركة داخل الأصابع مش الذراع، تحكّم دقيق.',
  };

  // 2. باقي الخيارات
  final List<String> _holdingOptions = ['يمسك لفترة قصيرة', 'يمسك لفترة كافية', 'لا يمسك'];
  final List<String> _releaseOptions = ['يحرر بسلام', 'يتأخر في التحرير', 'لا يحرر'];
  final List<String> _coordinationOptions = ['يحرك بعد الإمساك', 'يمسك فقط', 'يصعب توجيه اليد'];
  final Map<String, bool> _atypicalSignsOptions = {
    'إبهام داخل الكف': false,
    'عدم امتداد المعصم': false,
    'يستخدم يد بديلة غالبًا': false,
  };

  // 3. متغير لحفظ النتائج لكل يد
  Map<String, Map<String, dynamic>> _results = {};

  @override
  void initState() {
    super.initState();
    _results = {
      'Right': _initializeHandResults(),
      'Left': _initializeHandResults(),
    };
  }

  Map<String, dynamic> _initializeHandResults() {
    return {
      'grasp_type': null,
      'holding_ability': null,
      'release_ability': null,
      'coordination': null,
      'atypical_signs': <String>[], 
      'clinical_note': null,
    };
  }


  // -------------------------------------------------
  // دالة الحفظ (كما هي - لا تحتاج تعديل)
  // -------------------------------------------------
  Future<void> _saveAssessment(String status) async {
    
    final rightData = Map<String, dynamic>.from(_results['Right']!);
    final leftData = Map<String, dynamic>.from(_results['Left']!);

    rightData['hand'] = 'Right';
    leftData['hand'] = 'Left';

    rightData['atypical_signs'] = (rightData['atypical_signs'] as List<String>).join(', ');
    leftData['atypical_signs'] = (leftData['atypical_signs'] as List<String>).join(', ');

    List<Map<String, dynamic>> resultsToSave = [rightData, leftData];

    try {
      final int assessmentId = await DatabaseHelper.instance.saveGripAssessment(
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


  @override
  Widget build(BuildContext context) { 
    return DefaultTabController(
      length: 2, // يمين ويسار
      child: Scaffold(
        appBar: AppBar(
          title: Text('تقييم القبضة لـ: ${widget.patient.fullName}'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'الطرف الأيمن (Right)'),
              Tab(text: 'الطرف الأيسر (Left)'),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: TabBarView(
                children: [
                  _buildGripForm('Right'),
                  _buildGripForm('Left'),
                ],
              ),
            ),
            
            _buildSaveButtons(),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------
  // بناء واجهة النموذج لكل يد (كما هي)
  // -------------------------------------------------
  Widget _buildGripForm(String hand) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. نوع القبضة (Grasp Type)
          Text('نوع القبضة (Grasp Type)', style: Theme.of(context).textTheme.titleMedium),
          DropdownButtonFormField<String>(
            initialValue: _results[hand]!['grasp_type'],
            hint: const Text('اختر نوع القبضة السائد'),
            isExpanded: true,
            items: _gripTypeOptions.entries.map((entry) {
              return DropdownMenuItem<String>(
                value: entry.key,
                child: Tooltip( // إضافة شرح عند الضغط المطول
                  message: entry.value,
                  child: Text(entry.key, overflow: TextOverflow.ellipsis), // 🆕 (تعديل)
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _results[hand]!['grasp_type'] = newValue;
              });
            },
          ),
          const SizedBox(height: 20),

          // 2. قدرة الإمساك
          Text('قدرة الإمساك', style: Theme.of(context).textTheme.titleMedium),
          DropdownButtonFormField<String>(
            initialValue: _results[hand]!['holding_ability'],
            hint: const Text('اختر قدرة الإمساك'),
            isExpanded: true,
            items: _holdingOptions.map((option) {
              return DropdownMenuItem<String>(value: option, child: Text(option));
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _results[hand]!['holding_ability'] = newValue;
              });
            },
          ),
          const SizedBox(height: 20),

          // 3. التحرير
          Text('تحرير', style: Theme.of(context).textTheme.titleMedium),
          DropdownButtonFormField<String>(
            initialValue: _results[hand]!['release_ability'],
            hint: const Text('اختر نوع التحرير'),
            isExpanded: true,
            items: _releaseOptions.map((option) {
              return DropdownMenuItem<String>(value: option, child: Text(option));
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _results[hand]!['release_ability'] = newValue;
              });
            },
          ),
          const SizedBox(height: 20),

          // 4. تنسيق اليد-عين
          Text('تنسيق اليد-عين/اليد-أداة', style: Theme.of(context).textTheme.titleMedium),
          DropdownButtonFormField<String>(
            initialValue: _results[hand]!['coordination'],
            hint: const Text('اختر مستوى التنسيق'),
            isExpanded: true,
            items: _coordinationOptions.map((option) {
              return DropdownMenuItem<String>(value: option, child: Text(option));
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _results[hand]!['coordination'] = newValue;
              });
            },
          ),
          const SizedBox(height: 20),

          // 5. علامات غير نمطية (Checkboxes)
          Text('علامات الشلل/اختلال الحركات', style: Theme.of(context).textTheme.titleMedium),
          ..._atypicalSignsOptions.keys.map((sign) {
            return CheckboxListTile(
              title: Text(sign),
              value: (_results[hand]!['atypical_signs'] as List<String>).contains(sign),
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
                    (_results[hand]!['atypical_signs'] as List<String>).add(sign);
                  } else {
                    (_results[hand]!['atypical_signs'] as List<String>).remove(sign);
                  }
                });
              },
            );
          }).toList(),

          // 6. ملاحظات إضافية
          ExpansionTile(
            title: const Text('📝 ملاحظات إضافية', style: TextStyle(color: Colors.grey)),
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextFormField(
                  initialValue: _results[hand]!['clinical_note'],
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'أضف ملاحظاتك هنا...',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    _results[hand]!['clinical_note'] = value;
                  },
                ),
              ),
            ],
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