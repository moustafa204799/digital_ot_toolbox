import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../database/database_helper.dart';
import '../models/patient.dart';
import 'report_generation_screen.dart'; 

class GripAssessmentScreen extends StatefulWidget {
  final Patient patient;
  final int? assessmentId; // لاستكمال المسودة

  const GripAssessmentScreen({super.key, required this.patient, this.assessmentId});

  @override
  State<GripAssessmentScreen> createState() => _GripAssessmentScreenState();
}

class _GripAssessmentScreenState extends State<GripAssessmentScreen> {

  final Map<String, String> _gripTypeOptions = {
    'Crude Ulnar-Palmar Grasp (4-5 m)': 'قبضة راحة اليد على الزند: الطفل يمسك بجانب اليد وكفه.',
    'Palmar Grasp (5-6 m)': 'قبضة راحة اليد كاملة: الأصابع تغلق حول الشيء دون مشاركة فعالة للإبهام.',
    'Radial-Palmar Grasp (6-7 m)': 'قبضة راحة-شعاعية: يبدأ استخدام الإبهام.',
    'Raking Grasp (7-8 m)': 'قبضة كنس: يجمع الأشياء نحو الكف بأصابعه.',
    'Radial-Digital (8-9 m)': 'قبضة شعاعية-رقمية: استخدام الإبهام والسبابة (وسائد الأصابع).',
    'Pincer Grasp (10-12 m)': 'قبضة إصبعية: طرف الإبهام مع طرف السبابة.',
    'Palmar Supinate (1-1.5 y)': 'قبضة القلم الأولية: الكف للأعلى.',
    'Digital Pronate (2-3 y)': 'قبضة رقمية للأسفل: الأصابع تشارك، الكف للأسفل.',
    'Static Tripod (3-4 y)': 'ثلاثية ثابتة: حركة من المعصم.',
    'Dynamic Tripod (4-6 y)': 'ثلاثية ديناميكية: حركة دقيقة من الأصابع.',
  };

  final List<String> _holdingOptions = ['يمسك لفترة قصيرة', 'يمسك لفترة كافية', 'لا يمسك'];
  final List<String> _releaseOptions = ['يحرر بسلام', 'يتأخر في التحرير', 'لا يحرر'];
  final List<String> _coordinationOptions = ['يحرك بعد الإمساك', 'يمسك فقط', 'يصعب توجيه اليد'];
  final Map<String, bool> _atypicalSignsOptions = {
    'إبهام داخل الكف': false,
    'عدم امتداد المعصم': false,
    'يستخدم يد بديلة غالبًا': false,
  };

  Map<String, Map<String, dynamic>> _results = {};

  @override
  void initState() {
    super.initState();
    _results = {'Right': _initializeHandResults(), 'Left': _initializeHandResults()};
    
    // 🆕 تحميل البيانات إذا كانت مسودة
    if (widget.assessmentId != null) {
      _loadDraftData();
    }
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

  Future<void> _loadDraftData() async {
    final results = await DatabaseHelper.instance.getGripResultsForReport(widget.assessmentId!);
    if (mounted) {
      setState(() {
        for (var row in results) {
          String hand = row['hand']; 
          if (_results.containsKey(hand)) {
            List<String> signs = [];
            if (row['atypical_signs'] != null && row['atypical_signs'].toString().isNotEmpty) {
              signs = row['atypical_signs'].toString().split(', ');
            }
            _results[hand] = {
              'grasp_type': row['grasp_type'],
              'holding_ability': row['holding_ability'],
              'release_ability': row['release_ability'],
              'coordination': row['coordination'],
              'atypical_signs': signs,
              'clinical_note': row['clinical_note'],
            };
          }
        }
      });
    }
  }

  Future<void> _saveAssessment(String status) async {
    final rightData = Map<String, dynamic>.from(_results['Right']!);
    final leftData = Map<String, dynamic>.from(_results['Left']!);
    rightData['hand'] = 'Right';
    leftData['hand'] = 'Left';
    
    // تحويل القائمة إلى نص
    rightData['atypical_signs'] = (rightData['atypical_signs'] as List<String>).join(', ');
    leftData['atypical_signs'] = (leftData['atypical_signs'] as List<String>).join(', ');

    try {
      final int assessmentId = await DatabaseHelper.instance.saveGripAssessment(
        patientId: widget.patient.patientId!,
        status: status,
        results: [rightData, leftData],
        existingAssessmentId: widget.assessmentId, // 🆕 التحديث
      );
      
      if (!mounted) return;
      if (status == 'Completed') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم الحفظ!')));
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (context) => ReportGenerationScreen(assessmentId: assessmentId, patient: widget.patient, cameFromAssessmentFlow: true),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🕓 تم الحفظ كمسودة.')));
        Navigator.of(context).pop(); Navigator.of(context).pop();
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل: $e')));
    }
  }

  @override
  Widget build(BuildContext context) { 
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('تقييم القبضة', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold)),
          bottom: TabBar(
            labelStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
            indicatorColor: Colors.white,
            tabs: const [Tab(text: 'اليمين (Right)'), Tab(text: 'اليسار (Left)')],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: TabBarView(
                children: [_buildGripForm('Right'), _buildGripForm('Left')],
              ),
            ),
            _buildSaveButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildGripForm(String hand) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : Colors.black87;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDropdown('نوع القبضة (Grasp Type)', 'grasp_type', _gripTypeOptions.keys.toList(), hand, titleColor),
          SizedBox(height: 20.h),
          _buildDropdown('قدرة الإمساك', 'holding_ability', _holdingOptions, hand, titleColor),
          SizedBox(height: 20.h),
          _buildDropdown('التحرير (Release)', 'release_ability', _releaseOptions, hand, titleColor),
          SizedBox(height: 20.h),
          _buildDropdown('التنسيق', 'coordination', _coordinationOptions, hand, titleColor),
          SizedBox(height: 20.h),

          Text('علامات غير نمطية', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: titleColor)),
          ..._atypicalSignsOptions.keys.map((sign) {
            return CheckboxListTile(
              title: Text(sign, style: TextStyle(fontSize: 14.sp, color: titleColor)),
              contentPadding: EdgeInsets.zero,
              value: (_results[hand]!['atypical_signs'] as List<String>).contains(sign),
              onChanged: (val) => setState(() {
                val! ? (_results[hand]!['atypical_signs'] as List<String>).add(sign)
                     : (_results[hand]!['atypical_signs'] as List<String>).remove(sign);
              }),
            );
          }),

          SizedBox(height: 10.h),
          TextFormField(
            controller: TextEditingController(text: _results[hand]!['clinical_note']), // للحفاظ على النص عند التبديل
            maxLines: 3,
            style: TextStyle(fontSize: 14.sp, color: titleColor),
            decoration: InputDecoration(
              labelText: 'ملاحظات إضافية',
              labelStyle: TextStyle(color: isDark ? Colors.grey : Colors.black54),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
            ),
            onChanged: (val) => _results[hand]!['clinical_note'] = val,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String key, List<String> items, String hand, Color textColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: textColor)),
        SizedBox(height: 8.h),
        DropdownButtonFormField<String>(
          value: _results[hand]![key],
          isExpanded: true,
          dropdownColor: isDark ? Colors.grey[800] : Colors.white,
          style: TextStyle(fontSize: 13.sp, color: textColor),
          decoration: InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
          ),
          items: items.map((val) => DropdownMenuItem(
            value: val, 
            child: Text(val, style: TextStyle(fontSize: 13.sp, color: textColor), overflow: TextOverflow.ellipsis)
          )).toList(),
          onChanged: (val) => setState(() => _results[hand]![key] = val),
        ),
      ],
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