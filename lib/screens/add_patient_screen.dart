import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // 🆕
import 'package:intl/intl.dart';
import '../models/patient.dart';
import '../database/database_helper.dart';

class AddPatientScreen extends StatefulWidget {
  const AddPatientScreen({super.key});

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _diagnosisController = TextEditingController();
  DateTime? _selectedDate;
  String? _selectedGender;

  void _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2018),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _savePatient() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى اختيار تاريخ الميلاد')),
        );
        return;
      }

      final newPatient = Patient(
        fullName: _nameController.text,
        diagnosis: _diagnosisController.text,
        dob: _selectedDate!.toIso8601String(),
        gender: _selectedGender,
      );

      await DatabaseHelper.instance.insertPatient(newPatient);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إضافة المريض بنجاح ✅')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('إضافة مريض جديد', style: TextStyle(fontSize: 20.sp)), // .sp
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w), // .w
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // أيقونة تعبيرية كبيرة
              Center(
                child: CircleAvatar(
                  radius: 40.r, // .r
                  backgroundColor: Colors.blue.shade100,
                  child: Icon(Icons.person_add, size: 40.w, color: Colors.blue), // .w
                ),
              ),
              SizedBox(height: 24.h), // .h

              // حقل الاسم
              TextFormField(
                controller: _nameController,
                style: TextStyle(fontSize: 16.sp), // .sp
                decoration: InputDecoration(
                  labelText: 'الاسم الكامل',
                  labelStyle: TextStyle(fontSize: 14.sp),
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person, size: 22.w),
                ),
                validator: (val) => val!.isEmpty ? 'الاسم مطلوب' : null,
              ),
              SizedBox(height: 16.h),

              // حقل تاريخ الميلاد
              ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                title: Text(
                  _selectedDate == null
                      ? 'تاريخ الميلاد'
                      : 'الميلاد: ${DateFormat('yyyy-MM-dd').format(_selectedDate!)}',
                  style: TextStyle(fontSize: 16.sp),
                ),
                trailing: Icon(Icons.calendar_today, size: 22.w),
                onTap: _pickDate,
              ),
              SizedBox(height: 16.h),

              // حقل الجنس (Dropdown)
              DropdownButtonFormField<String>(
                initialValue: _selectedGender,
                decoration: InputDecoration(
                  labelText: 'الجنس',
                  labelStyle: TextStyle(fontSize: 14.sp),
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(Icons.wc, size: 22.w),
                ),
                items: ['ذكر', 'أنثى'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: TextStyle(fontSize: 16.sp)),
                  );
                }).toList(),
                onChanged: (newValue) => setState(() => _selectedGender = newValue),
              ),
              SizedBox(height: 16.h),

              // حقل التشخيص
              TextFormField(
                controller: _diagnosisController,
                style: TextStyle(fontSize: 16.sp),
                decoration: InputDecoration(
                  labelText: 'التشخيص (اختياري)',
                  labelStyle: TextStyle(fontSize: 14.sp),
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes, size: 22.w),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 32.h),

              // زر الحفظ
              ElevatedButton.icon(
                onPressed: _savePatient,
                icon: Icon(Icons.save, size: 24.w),
                label: Text('حفظ البيانات', style: TextStyle(fontSize: 18.sp)),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}