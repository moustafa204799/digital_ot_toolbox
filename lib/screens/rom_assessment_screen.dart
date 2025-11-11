import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/patient.dart';
import 'report_generation_screen.dart'; 
import 'package:flutter/services.dart'; 

class ROMAssessmentScreen extends StatefulWidget {
  final Patient patient;
  const ROMAssessmentScreen({super.key, required this.patient});

  @override
  State<ROMAssessmentScreen> createState() => _ROMAssessmentScreenState();
}

// 🆕 (تعديل) إضافة 'SingleTickerProviderStateMixin' لدعم TabBar
class _ROMAssessmentScreenState extends State<ROMAssessmentScreen> with SingleTickerProviderStateMixin {
  
  // (هيكل البيانات الديناميكي للمفاصل - كما هو)
  final Map<String, List<Map<String, String>>> _jointMotions = const {
    'Shoulder': [
      {'motion': 'Flexion', 'ar': 'ثني'},
      {'motion': 'Extension', 'ar': 'بسط'},
      {'motion': 'Abduction', 'ar': 'تبعيد'},
      {'motion': 'Adduction', 'ar': 'تقريب'},
      {'motion': 'Internal Rotation', 'ar': 'تدوير داخلي'},
      {'motion': 'External Rotation', 'ar': 'تدوير خارجي'},
    ],
    'Elbow': [
      {'motion': 'Flexion', 'ar': 'ثني'},
      {'motion': 'Extension', 'ar': 'بسط'},
      {'motion': 'Pronation', 'ar': 'كب'},
      {'motion': 'Supination', 'ar': 'بسط/لف خارجي'},
    ],
    'Wrist': [
      {'motion': 'Flexion', 'ar': 'ثني لأسفل'},
      {'motion': 'Extension', 'ar': 'بسط لأعلى'},
      {'motion': 'Radial Deviation', 'ar': 'لف للداخل'},
      {'motion': 'Ulnar Deviation', 'ar': 'لف للخارج'},
    ],
  };
  
  final Map<String, Map<String, dynamic>> _results = {};
  
  @override
  void initState() {
    super.initState();
    _initializeResults();
  }

  void _initializeResults() {
    for (var side in ['Right', 'Left']) {
      _jointMotions.forEach((joint, motions) {
        for (var motion in motions) {
          final key = '${side}_${joint}_${motion['motion']!}';
          _results[key] = {'active': null, 'passive': null, 'pain': 'None', 'note': null};
        }
      });
    }
  }

  // ----------------------------------------------------
  // دالة الحفظ (كما هي - لا تحتاج تعديل)
  // ----------------------------------------------------
  Future<void> _saveAssessment(String status) async {
    List<Map<String, dynamic>> resultsToSave = [];
    
    _results.forEach((key, value) {
      final parts = key.split('_'); // [Right, Shoulder, Flexion]
      
      if (value['active'] != null || value['passive'] != null || value['note'] != null) {
        resultsToSave.add({
          'joint_name': '${parts[0]} ${parts[1]}', 
          'motion_type': parts[2], 
          'active_range': value['active'] ?? 0.0,
          'passive_range': value['passive'] ?? 0.0,
          'pain_level': value['pain'],
          'clinical_note': value['note'], 
        });
      }
    });
    
    if (resultsToSave.isEmpty && status == 'Completed') {
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('الرجاء تقييم حركة واحدة على الأقل قبل الإنهاء.')),
          );
       }
       return;
    }

    try {
      final int assessmentId = await DatabaseHelper.instance.saveROMAssessment(
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

  // ----------------------------------------------------
  // دوال إدخال البيانات المنبثقة (كما هي)
  // ----------------------------------------------------
  Future<void> _showNumericInputDialog(String key, String type) async {
    final controller = TextEditingController(
      text: _results[key]![type]?.toString() ?? '',
    );
    final double? newValue = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('إدخال الدرجة (0-360)'),
          content: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(hintText: 'أدخل الزاوية'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                final val = double.tryParse(controller.text);
                Navigator.of(context).pop(val);
              },
              child: const Text('تأكيد'),
            ),
          ],
        );
      },
    );
    if (newValue != null) {
      setState(() {
        _results[key]![type] = newValue;
      });
    }
  }

  Future<void> _showNoteInputDialog(String key) async {
    final controller = TextEditingController(
      text: _results[key]!['note'] ?? '',
    );
    final String? newNote = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('إضافة ملاحظة سريعة'),
          content: TextFormField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'اكتب ملاحظتك هنا (مثل: ألم عند 90 درجة)...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(controller.text);
              },
              child: const Text('حفظ الملاحظة'),
            ),
          ],
        );
      },
    );
    if (newNote != null) {
      setState(() {
        _results[key]!['note'] = newNote.isNotEmpty ? newNote : null;
      });
    }
  }

  // ----------------------------------------------------
  // 🆕 (✅ تعديل) بناء الواجهة باستخدام TabBar
  // ----------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // 1. إضافة DefaultTabController
    return DefaultTabController(
      length: 2, // (الطرف الأيمن / الأيسر)
      child: Scaffold(
        appBar: AppBar(
          title: Text('تقييم مدى الحركة (ROM) لـ: ${widget.patient.fullName}'),
          // 2. إضافة الـ TabBar
          bottom: const TabBar(
            tabs: [
              Tab(text: 'الطرف الأيمن (Right)'),
              Tab(text: 'الطرف الأيسر (Left)'),
            ],
          ),
        ),
        body: Column(
          children: [
            // 3. إضافة الـ TabBarView
            Expanded(
              child: TabBarView(
                children: [
                  // --- Tab 1: Right Side ---
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(8.0),
                    child: _buildSideAssessment(context, 'Right', 'الأيمن'),
                  ),
                  
                  // --- Tab 2: Left Side ---
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(8.0),
                    child: _buildSideAssessment(context, 'Left', 'الأيسر'),
                  ),
                ],
              ),
            ),
            
            // 4. أزرار الحفظ تبقى في الأسفل
            _buildSaveButtons(),
          ],
        ),
      ),
    );
  }

  // بناء بطاقة للطرف (الأيمن أو الأيسر)
  Widget _buildSideAssessment(BuildContext context, String side, String sideArabic) {
    return Card(
      elevation: 0, // 🆕 (تعديل) إزالة الظل الداخلي
      color: Colors.transparent, // 🆕 (تعديل) إزالة اللون الداخلي
      margin: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🆕 (تعديل) لا نحتاج لعنوان "الطرف" هنا لأنه موجود في التاب
          // Loop through joints
          ..._jointMotions.entries.map((entry) {
            final jointName = entry.key;
            final motions = entry.value;
            return _buildJointExpansionTile(side, jointName, motions);
          }).toList(),
        ],
      ),
    );
  }

  // بناء قائمة منسدلة لكل مفصل
  Widget _buildJointExpansionTile(String side, String jointName, List<Map<String, String>> motions) {
    return Card( // 🆕 (جديد) إضافة Card لكل مفصل
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      child: ExpansionTile(
        title: Text(
          jointName,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        subtitle: const Text('اضغط لعرض الحركات'),
        children: [
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2),    // الحركة
              1: FlexColumnWidth(1.2),  // Active
              2: FlexColumnWidth(1.2),  // Passive
              3: FlexColumnWidth(1.5),  // ألم
              4: FlexColumnWidth(0.8),  // 💬
            },
            border: TableBorder.all(color: Colors.grey.shade300),
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade100),
                children: const [
                  Padding(padding: EdgeInsets.all(8), child: Text('الحركة', style: TextStyle(fontWeight: FontWeight.bold))),
                  Padding(padding: EdgeInsets.all(8), child: Text('Active', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                  Padding(padding: EdgeInsets.all(8), child: Text('Passive', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                  Padding(padding: EdgeInsets.all(8), child: Text('ألم', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                  Padding(padding: EdgeInsets.all(8), child: Icon(Icons.notes, size: 18)),
                ],
              ),
              
              ...motions.map((motion) {
                final key = '${side}_${jointName}_${motion['motion']!}';
                
                return TableRow(
                  children: [
                    Padding(padding: const EdgeInsets.all(8), child: Text('${motion['motion']} (${motion['ar']})')),
                    _buildRangeDisplayField(key, 'active'), 
                    _buildRangeDisplayField(key, 'passive'), 
                    _buildPainDropdown(key),
                    _buildNoteButton(key), 
                  ],
                );
              }).toList(),
            ],
          ),
        ],
      ),
    );
  }

  // --- دوال مساعدة بناء الحقول (كما هي) ---
  Widget _buildRangeDisplayField(String key, String type) {
    final value = _results[key]![type];
    return InkWell(
      onTap: () => _showNumericInputDialog(key, type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.transparent),
        ),
        child: Text(
          value?.toString() ?? '---',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: value != null ? Colors.black : Colors.grey,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildPainDropdown(String key) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
      child: DropdownButtonFormField<String>(
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          border: InputBorder.none, 
        ),
        initialValue: _results[key]!['pain'],
        items: const [
          DropdownMenuItem(value: 'None', child: Text('لا يوجد', style: TextStyle(fontSize: 12))),
          DropdownMenuItem(value: 'Mild', child: Text('خفيف', style: TextStyle(fontSize: 12))),
          DropdownMenuItem(value: 'Moderate', child: Text('متوسط', style: TextStyle(fontSize: 12))),
          DropdownMenuItem(value: 'Severe', child: Text('شديد', style: TextStyle(fontSize: 12))),
        ],
        onChanged: (String? newValue) {
          setState(() {
            _results[key]!['pain'] = newValue;
          });
        },
      ),
    );
  }

  Widget _buildNoteButton(String key) {
    final bool hasNote = _results[key]!['note'] != null && _results[key]!['note'].isNotEmpty;
    return IconButton(
      icon: Icon(
        hasNote ? Icons.chat : Icons.chat_bubble_outline,
        color: hasNote ? Colors.blue : Colors.grey,
        size: 20,
      ),
      onPressed: () => _showNoteInputDialog(key),
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