import 'dart:convert'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../database/database_helper.dart';
import '../models/patient.dart';
import 'report_generation_screen.dart';
import '../widgets/interactive_joint_visualizer.dart'; // 🆕 تأكد من صحة المسار

class ROMAssessmentScreen extends StatefulWidget {
  final Patient patient;
  final int? assessmentId; 

  const ROMAssessmentScreen({super.key, required this.patient, this.assessmentId});

  @override
  State<ROMAssessmentScreen> createState() => _ROMAssessmentScreenState();
}

class _ROMAssessmentScreenState extends State<ROMAssessmentScreen> with SingleTickerProviderStateMixin {
  
  // القيم القياسية كما طلبت
  final Map<String, List<Map<String, dynamic>>> _jointMotions = {
    'Shoulder': [
      {'motion': 'Flexion', 'ar': 'ثني', 'max': 180.0},
      {'motion': 'Extension', 'ar': 'بسط', 'max': 60.0},
      {'motion': 'Abduction', 'ar': 'تبعيد', 'max': 180.0},
      {'motion': 'Adduction', 'ar': 'تقريب', 'max': 45.0},
      {'motion': 'Internal Rotation', 'ar': 'تدوير داخلي', 'max': 70.0},
      {'motion': 'External Rotation', 'ar': 'تدوير خارجي', 'max': 90.0},
    ],
    'Elbow': [
      {'motion': 'Flexion', 'ar': 'ثني', 'max': 150.0},
      {'motion': 'Extension', 'ar': 'بسط', 'max': 10.0},
      {'motion': 'Pronation', 'ar': 'كب', 'max': 80.0},
      {'motion': 'Supination', 'ar': 'بسط/لف خارجي', 'max': 90.0},
    ],
    'Wrist': [
      {'motion': 'Flexion', 'ar': 'ثني لأسفل', 'max': 80.0},
      {'motion': 'Extension', 'ar': 'بسط لأعلى', 'max': 70.0},
      {'motion': 'Radial Deviation', 'ar': 'انحراف شعاعي', 'max': 20.0},
      {'motion': 'Ulnar Deviation', 'ar': 'انحراف زندي', 'max': 45.0},
    ],
  };

  final Map<String, Map<String, dynamic>> _results = {};
  bool _isHighContrast = false; 

  @override
  void initState() {
    super.initState();
    _initializeResults();
    if (widget.assessmentId != null) {
      _loadDraftData();
    }
  }

  void _initializeResults() {
    for (var side in ['Right', 'Left']) {
      _jointMotions.forEach((joint, motions) {
        for (var motion in motions) {
          final key = '${side}_${joint}_${motion['motion']!}';
          _results[key] = {
            'active': 0.0, 'passive': 0.0, 'pain': 'None', 'note': null, 'is_set': false 
          };
        }
      });
    }
  }

  Future<void> _loadDraftData() async {
    final results = await DatabaseHelper.instance.getROMResultsForReport(widget.assessmentId!);
    setState(() {
      for (var row in results) {
        final jointParts = row['joint_name'].toString().split(' ');
        String side = jointParts[0];
        String joint = jointParts[1];
        String motion = row['motion_type'];
        
        String key = '${side}_${joint}_${motion}';
        
        if (_results.containsKey(key)) {
          _results[key] = {
            'active': row['active_range'],
            'passive': row['passive_range'],
            'pain': row['pain_level'],
            'note': row['clinical_note'],
            'is_set': true
          };
        }
      }
    });
  }

  void _showUnifiedInputSheet(String key, String jointName, String motionName, double maxROM, String side) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
      builder: (context) => _RomInputSheet(
        jointName: jointName,
        motionName: motionName,
        maxROM: maxROM,
        side: side,
        isHighContrast: _isHighContrast,
        initialData: _results[key]!,
        onSave: (newData) {
          setState(() {
            _results[key] = newData;
            _results[key]!['is_set'] = true; 
          });
        },
      ),
    );
  }

  Future<void> _saveAssessment(String status) async {
    List<Map<String, dynamic>> resultsToSave = [];
    _results.forEach((key, value) {
      if (value['is_set'] == true) { 
        final parts = key.split('_');
        resultsToSave.add({
          'joint_name': '${parts[0]} ${parts[1]}', 
          'motion_type': parts[2], 
          'active_range': value['active'],
          'passive_range': value['passive'],
          'pain_level': value['pain'],
          'clinical_note': value['note'], 
        });
      }
    });
    
    if (resultsToSave.isEmpty && status == 'Completed') {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء تقييم حركة واحدة على الأقل.')));
       return;
    }

    try {
      final int assessmentId = await DatabaseHelper.instance.saveROMAssessment(
        patientId: widget.patient.patientId!,
        status: status,
        results: resultsToSave,
        existingAssessmentId: widget.assessmentId,
      );
      if (!mounted) return;
      if (status == 'Completed') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم الحفظ!')));
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => ReportGenerationScreen(assessmentId: assessmentId, patient: widget.patient, cameFromAssessmentFlow: true)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🕓 تم حفظ المسودة.')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('تقييم ROM', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: Icon(_isHighContrast ? Icons.contrast : Icons.brightness_medium),
              tooltip: 'وضع التباين العالي',
              onPressed: () => setState(() => _isHighContrast = !_isHighContrast),
            ),
          ],
          bottom: TabBar(
            labelStyle: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
            indicatorColor: Colors.white,
            tabs: const [Tab(text: 'الطرف الأيمن'), Tab(text: 'الطرف الأيسر')],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: TabBarView(
                children: [_buildSideList('Right'), _buildSideList('Left')],
              ),
            ),
            _buildSaveButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildSideList(String side) {
    return ListView.builder(
      padding: EdgeInsets.all(12.w),
      itemCount: _jointMotions.keys.length,
      itemBuilder: (context, index) {
        String joint = _jointMotions.keys.elementAt(index);
        return _buildJointCard(side, joint, _jointMotions[joint]!);
      },
    );
  }

  Widget _buildJointCard(String side, String jointName, List<Map<String, dynamic>> motions) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: EdgeInsets.only(bottom: 16.h),
      elevation: 2,
      color: Theme.of(context).cardTheme.color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: ExpansionTile(
        initiallyExpanded: true,
        shape: const Border(),
        title: Text(jointName, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        children: motions.map((motion) {
          final key = '${side}_${jointName}_${motion['motion']!}';
          final data = _results[key]!;
          final bool isSet = data['is_set'];

          return ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
            title: Text('${motion['motion']} (${motion['ar']})', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600)),
            subtitle: isSet 
              ? Text('Act: ${data['active'].toInt()}° | Pas: ${data['passive'].toInt()}°', style: TextStyle(color: Colors.green, fontSize: 12.sp))
              : Text('اضغط للتقييم', style: TextStyle(color: Colors.grey, fontSize: 12.sp)),
            trailing: Icon(Icons.edit_outlined, color: Colors.blue),
            onTap: () => _showUnifiedInputSheet(key, jointName, motion['motion'], motion['max'], side),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSaveButtons() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -5))]),
      child: Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: () => _saveAssessment('Draft'), icon: const Icon(Icons.save_as_outlined), label: const Text('مسودة'), style: OutlinedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14.h)))),
        SizedBox(width: 12.w),
        Expanded(child: FilledButton.icon(onPressed: () => _saveAssessment('Completed'), icon: const Icon(Icons.check), label: const Text('إنهاء وحفظ'), style: FilledButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14.h)))),
      ]),
    );
  }
}

class _RomInputSheet extends StatefulWidget {
  final String jointName;
  final String motionName;
  final String side;
  final double maxROM;
  final Map<String, dynamic> initialData;
  final bool isHighContrast;
  final Function(Map<String, dynamic>) onSave;

  const _RomInputSheet({
    required this.jointName, required this.motionName, required this.side, required this.maxROM, required this.initialData, required this.onSave, required this.isHighContrast,
  });

  @override
  State<_RomInputSheet> createState() => _RomInputSheetState();
}

class _RomInputSheetState extends State<_RomInputSheet> {
  late double activeValue;
  late double passiveValue;
  late String painValue;
  String? note;
  Set<String> _selectedType = {'Active'}; 
  int _stepSize = 5; 

  @override
  void initState() {
    super.initState();
    activeValue = widget.initialData['active'] ?? 0.0;
    passiveValue = widget.initialData['passive'] ?? 0.0;
    painValue = widget.initialData['pain'] ?? 'None';
    note = widget.initialData['note'];
  }

  double get currentValue => _selectedType.contains('Active') ? activeValue : passiveValue;
  
  void updateValue(double val) {
    setState(() {
      val = val.clamp(0.0, widget.maxROM);
      if (_selectedType.contains('Active')) activeValue = val; else passiveValue = val;
    });
  }

  void _resetValues() {
    setState(() {
      activeValue = 0.0;
      passiveValue = 0.0;
    });
  }

  void _copyJsonToClipboard() {
    final data = {
      'joint': widget.jointName, 'motion': widget.motionName, 'side': widget.side,
      'active': activeValue, 'passive': passiveValue, 'pain': painValue, 'note': note
    };
    Clipboard.setData(ClipboardData(text: jsonEncode(data)));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ البيانات (JSON)')));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 20.h),
      height: 750.h, 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Container(width: 40.w, height: 4.h, margin: EdgeInsets.only(bottom: 10.h), decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)))),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(icon: const Icon(Icons.refresh), onPressed: _resetValues, tooltip: 'Reset'),
              Column(
                children: [
                  Text('${widget.side} ${widget.jointName}', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: textColor)),
                  Text(widget.motionName, style: TextStyle(fontSize: 14.sp, color: Colors.grey)),
                ],
              ),
              IconButton(icon: const Icon(Icons.copy_all), onPressed: _copyJsonToClipboard, tooltip: 'Copy JSON'),
            ],
          ),
          
          SizedBox(height: 10.h),

          // استخدام الويدجت الجديد للرسم
          Center(
            child: InteractiveJointVisualizer(
              angle: currentValue,
              maxAngle: widget.maxROM,
              jointName: widget.jointName,
              motionName: widget.motionName,
              side: widget.side,
              isHighContrast: widget.isHighContrast,
              onAngleChanged: updateValue,
            ),
          ),

          SizedBox(height: 10.h),

          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Active', label: Text('Active'), icon: Icon(Icons.accessibility_new)),
              ButtonSegment(value: 'Passive', label: Text('Passive'), icon: Icon(Icons.pan_tool)),
            ],
            selected: _selectedType,
            onSelectionChanged: (v) => setState(() => _selectedType = v),
          ),

          SizedBox(height: 10.h),
          Row(
            children: [
              IconButton.filledTonal(onPressed: () => updateValue(currentValue - _stepSize), icon: const Icon(Icons.remove)),
              Expanded(
                child: Slider(
                  value: currentValue,
                  min: 0,
                  max: widget.maxROM, 
                  divisions: widget.maxROM.toInt(),
                  label: currentValue.round().toString(),
                  onChanged: updateValue,
                ),
              ),
              IconButton.filledTonal(onPressed: () => updateValue(currentValue + _stepSize), icon: const Icon(Icons.add)),
            ],
          ),

          Center(
            child: ToggleButtons(
              isSelected: [_stepSize == 1, _stepSize == 5],
              onPressed: (i) => setState(() => _stepSize = i == 0 ? 1 : 5),
              borderRadius: BorderRadius.circular(8.r),
              children: const [Text('1°'), Text('5°')],
            ),
          ),

          const Divider(height: 20),

          Text('مستوى الألم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
          SizedBox(height: 5.h),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'None', label: Text('لا')),
              ButtonSegment(value: 'Mild', label: Text('خفيف')),
              ButtonSegment(value: 'Moderate', label: Text('متوسط')),
              ButtonSegment(value: 'Severe', label: Text('شديد')),
            ],
            selected: {painValue},
            onSelectionChanged: (v) => setState(() => painValue = v.first),
          ),

          const Spacer(),

          FilledButton(
            onPressed: () {
              widget.onSave({
                'active': activeValue, 'passive': passiveValue, 'pain': painValue, 'note': note, 'is_set': true,
              });
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 16.h)),
            child: const Text('حفظ', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }
}